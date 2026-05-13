import 'dart:io';
import 'package:excel/excel.dart';
import '../data/database/app_database.dart';
import '../data/repositories/participant_repository.dart';
import '../data/repositories/family_repository.dart';
import '../utils/logger.dart';
import '../utils/exceptions.dart';

class ExcelImportService {
  final AppDatabase _db;
  final ParticipantRepository _participantRepository;
  final FamilyRepository _familyRepository;

  ExcelImportService(this._db, this._participantRepository, this._familyRepository);

  Future<ExcelImportResult> importParticipantsFromExcel({
    required String filePath,
    required int eventId,
  }) async {
    final result = ExcelImportResult();

    try {
      AppLogger.info('[ExcelImport] Start Import von: $filePath (Event: $eventId)');

      // ── DATEI-PARSING (keine DB-Writes) ──────────────────────────────────
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      AppLogger.info('[ExcelImport] ${excel.tables.length} Tabellen gefunden');

      if (excel.tables.isEmpty) {
        result.errors.add('Excel-Datei enthält keine Tabellen');
        return result;
      }

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.maxRows < 2) {
        result.errors.add('Excel-Datei muss mindestens eine Header-Zeile und eine Datenzeile enthalten');
        return result;
      }

      result.totalRows = sheet.maxRows - 1;
      AppLogger.info('[ExcelImport] ${result.totalRows} Datenzeilen gefunden');

      final headerRow = sheet.rows.firstOrNull;
      if (headerRow == null) {
        result.errors.add('Header-Zeile konnte nicht gelesen werden');
        return result;
      }

      final columnMapping = _buildColumnMapping(headerRow);

      if (!columnMapping.containsKey('first_name') ||
          !columnMapping.containsKey('last_name') ||
          !columnMapping.containsKey('birth_date')) {
        result.errors.add('Erforderliche Spalten fehlen: Vorname, Nachname, Geburtsdatum');
        return result;
      }

      // ── DB-OPERATIONEN (atomar in einer Transaktion) ──────────────────────
      await _db.transaction(() async {
        // Phase 1: Familien anlegen
        AppLogger.info('[ExcelImport] Phase 1: Familien anlegen...');
        final familyMap = await _createFamilies(sheet, columnMapping, eventId, result);
        AppLogger.info('[ExcelImport] ${familyMap.length} Familien angelegt');

        // Phase 2: Teilnehmer importieren
        AppLogger.info('[ExcelImport] Phase 2: Teilnehmer importieren...');
        for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
          final row = sheet.rows[rowIndex];
          try {
            final participantData = _parseRowWithMapping(row, columnMapping, rowIndex);

            if (participantData['first_name'] == null ||
                participantData['last_name'] == null ||
                participantData['birth_date'] == null) {
              result.errors.add('Zeile ${rowIndex + 1}: Vorname, Nachname und Geburtsdatum sind erforderlich');
              continue;
            }

            int? familyId;
            String? familyNumber;
            if (participantData.containsKey('family_number') && participantData['family_number'] != null) {
              familyNumber = participantData['family_number'].toString().trim();
              if (familyNumber.isNotEmpty) {
                familyId = familyMap[familyNumber];
                if (familyId == null) {
                  AppLogger.warning('[ExcelImport] Zeile ${rowIndex + 1}: Familien-Nr "$familyNumber" nicht gefunden');
                }
              }
            }

            final address = _buildAddress(participantData);

            await _participantRepository.createParticipant(
              eventId: eventId,
              firstName: participantData['first_name'] as String,
              lastName: participantData['last_name'] as String,
              birthDate: participantData['birth_date'] as DateTime,
              gender: participantData['gender'] as String?,
              address: address,
              email: participantData['email'] as String?,
              phone: participantData['phone'] as String?,
              emergencyContactName: participantData['emergency_contact_name'] as String?,
              emergencyContactPhone: participantData['emergency_contact_phone'] as String?,
              allergies: participantData['allergies'] as String?,
              medications: participantData['medications'] as String?,
              dietaryRestrictions: participantData['dietary_restrictions'] as String?,
              notes: participantData['notes'] as String?,
              familyId: familyId,
            );

            result.successCount++;
            AppLogger.debug(
              '[ExcelImport] Zeile ${rowIndex + 1}: '
              '${participantData['first_name']} ${participantData['last_name']}'
              '${familyId != null ? " → Familie $familyNumber" : ""}',
            );
          } catch (e, stackTrace) {
            AppLogger.error('[ExcelImport] Fehler in Zeile ${rowIndex + 1}', error: e, stackTrace: stackTrace);
            result.errors.add('Zeile ${rowIndex + 1}: $e');
          }
        }

        // Fehler in Zeilen → Transaktion abbrechen, alles zurücksetzen
        if (result.errors.isNotEmpty) {
          AppLogger.warning(
            '[ExcelImport] ${result.errorCount} Fehler aufgetreten – '
            'Transaktion wird zurückgesetzt (${result.successCount} verarbeitete Zeilen werden verworfen)',
          );
          throw const _ImportRollbackException();
        }
      });

      AppLogger.info('[ExcelImport] Import erfolgreich: ${result.successCount}/${result.totalRows} Teilnehmer gespeichert');
    } on _ImportRollbackException {
      result.rolledBack = true;
      AppLogger.warning('[ExcelImport] Import zurückgesetzt – keine Daten gespeichert');
    } catch (e, stackTrace) {
      AppLogger.error('[ExcelImport] Fataler Fehler beim Import', error: e, stackTrace: stackTrace);
      result.errors.add('Fehler beim Lesen der Excel-Datei: $e');
    }

    AppLogger.info('[ExcelImport] Ergebnis: $result');
    return result;
  }

  /// Erstellt Familien aus der Familien-Nr-Spalte und gibt family_number→id zurück
  Future<Map<String, int>> _createFamilies(
    Sheet sheet,
    Map<String, int> columnMapping,
    int eventId,
    ExcelImportResult result,
  ) async {
    final familyMap = <String, int>{};

    if (!columnMapping.containsKey('family_number')) {
      AppLogger.info('[ExcelImport] Keine Familien-Nr-Spalte – Familien werden übersprungen');
      return familyMap;
    }

    // Eindeutige Familien sammeln (Familien-Nr → [Nachname, Vorname] des ersten Mitglieds)
    final familyGroups = <String, List<String>>{};
    final familyMemberCounts = <String, int>{};

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.rows[rowIndex];
      final familyNumber = _getCellValue(row, columnMapping['family_number']!);
      if (familyNumber == null || familyNumber.isEmpty) continue;

      familyMemberCounts[familyNumber] = (familyMemberCounts[familyNumber] ?? 0) + 1;
      if (familyGroups.containsKey(familyNumber)) continue;

      final firstName = columnMapping.containsKey('first_name')
          ? _getCellValue(row, columnMapping['first_name']!) : null;
      final lastName = columnMapping.containsKey('last_name')
          ? _getCellValue(row, columnMapping['last_name']!) : null;

      if (firstName != null && lastName != null) {
        familyGroups[familyNumber] = [lastName, firstName];
      }
    }

    AppLogger.info('[ExcelImport] ${familyGroups.length} Familien gefunden');

    for (final entry in familyGroups.entries) {
      final familyNumber = entry.key;
      final names = entry.value;
      final familyName = 'Familie ${names[0]} ${names[1]}';

      try {
        final familyId = await _familyRepository.createFamily(
          eventId: eventId,
          familyName: familyName,
        );
        familyMap[familyNumber] = familyId;
        AppLogger.debug('[ExcelImport] Familie "$familyName" angelegt (Nr: $familyNumber, ID: $familyId, ${familyMemberCounts[familyNumber]} Mitglieder)');
      } catch (e) {
        AppLogger.error('[ExcelImport] Familie "$familyName" konnte nicht angelegt werden', error: e);
        result.errors.add('Fehler beim Anlegen der Familie "$familyName": $e');
      }
    }

    return familyMap;
  }

  /// Baut das Column-Mapping aus der Header-Zeile
  Map<String, int> _buildColumnMapping(List<Data?> headerRow) {
    final mapping = <String, int>{};

    for (var i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null || cell.value == null) continue;

      final h = cell.value.toString().trim().toLowerCase();

      if (h.contains('vorname')) {
        mapping['first_name'] = i;
      } else if (h.contains('nachname')) {
        mapping['last_name'] = i;
      } else if (h.contains('geburtsdatum') || h.contains('geburtstag')) {
        mapping['birth_date'] = i;
      } else if (h.contains('geschlecht')) {
        mapping['gender'] = i;
      } else if (h.contains('e-mail') || h.contains('email')) {
        mapping['email'] = i;
      } else if (h.contains('telefon') || h.contains('phone')) {
        mapping['phone'] = i;
      } else if (h.contains('adresse')) {
        mapping['address'] = i;
      } else if (h.contains('straße') || h.contains('strasse')) {
        mapping['street'] = i;
      } else if (h.contains('plz') || h.contains('postleitzahl')) {
        mapping['postal_code'] = i;
      } else if (h.contains('stadt') || h.contains('ort')) {
        mapping['city'] = i;
      } else if (h.contains('notfall') && h.contains('name')) {
        mapping['emergency_contact_name'] = i;
      } else if (h.contains('notfall') && (h.contains('telefon') || h.contains('phone'))) {
        mapping['emergency_contact_phone'] = i;
      } else if (h.contains('allergi')) {
        mapping['allergies'] = i;
      } else if (h.contains('medikament')) {
        mapping['medications'] = i;
      } else if (h.contains('ernährung') || h.contains('diät')) {
        mapping['dietary_restrictions'] = i;
      } else if (h.contains('notiz') || h.contains('bemerkung')) {
        mapping['notes'] = i;
      } else if (h.contains('familie') && (h.contains('nr') || h.contains('nummer'))) {
        mapping['family_number'] = i;
      }
    }

    AppLogger.info('[ExcelImport] Spalten-Mapping: ${mapping.length} Spalten erkannt'
        '${mapping.containsKey('family_number') ? ' (inkl. Familien-Nr)' : ''}');
    return mapping;
  }

  /// Liest eine Zeile anhand des Column-Mappings
  Map<String, dynamic> _parseRowWithMapping(
    List<Data?> row,
    Map<String, int> columnMapping,
    int rowIndex,
  ) {
    final data = <String, dynamic>{};

    for (final key in ['first_name', 'last_name', 'gender', 'street', 'postal_code',
                       'city', 'email', 'phone', 'emergency_contact_name',
                       'emergency_contact_phone', 'allergies', 'medications',
                       'dietary_restrictions', 'notes', 'family_number', 'address']) {
      if (columnMapping.containsKey(key)) {
        data[key] = _getCellValue(row, columnMapping[key]!);
      }
    }

    if (columnMapping.containsKey('birth_date')) {
      final birthDateCell = row[columnMapping['birth_date']!];
      if (birthDateCell != null && birthDateCell.value != null) {
        try {
          data['birth_date'] = _parseDateFromCell(birthDateCell);
        } catch (e) {
          throw ExcelImportException('Ungültiges Geburtsdatum: ${birthDateCell.value}', row: rowIndex + 1);
        }
      }
    }

    return data;
  }

  /// Kombiniert Adressfelder (kombiniertes Feld oder Einzelfelder)
  String? _buildAddress(Map<String, dynamic> data) {
    if (data.containsKey('address') && data['address'] != null) {
      return data['address'] as String?;
    }

    final street = data['street'] as String?;
    final postalCode = data['postal_code'] as String?;
    final city = data['city'] as String?;

    if (street == null && postalCode == null && city == null) return null;

    final parts = <String>[];
    if (street != null && street.isNotEmpty) parts.add(street);
    if (postalCode != null && postalCode.isNotEmpty) {
      parts.add(city != null && city.isNotEmpty ? '$postalCode $city' : postalCode);
    } else if (city != null && city.isNotEmpty) {
      parts.add(city);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Liest einen Zellwert als String (null wenn leer)
  String? _getCellValue(List<Data?> row, int columnIndex) {
    try {
      if (columnIndex < 0 || columnIndex >= row.length) return null;
      final cell = row[columnIndex];
      if (cell == null || cell.value == null) return null;
      final value = cell.value.toString().trim();
      return value.isEmpty ? null : value;
    } catch (e) {
      AppLogger.error('[ExcelImport] Fehler beim Lesen von Spalte $columnIndex', error: e);
      return null;
    }
  }

  /// Parst das Datum aus einer Excel-Zelle (DateCellValue, DateTimeCellValue, numerisch, Text)
  DateTime _parseDateFromCell(Data cell) {
    final value = cell.value;

    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day);
    }

    if (value is DateTimeCellValue) {
      return DateTime(value.year, value.month, value.day);
    }

    // Excel-Seriennummer (Tage seit 1899-12-30)
    if (value is IntCellValue || value is DoubleCellValue) {
      final numValue = value is IntCellValue ? value.value.toDouble() : (value as DoubleCellValue).value;
      final excelEpoch = DateTime(1899, 12, 30);
      return excelEpoch.add(Duration(days: numValue.toInt()));
    }

    if (value is TextCellValue) {
      return _parseDate(value.value.toString());
    }

    return _parseDate(value.toString());
  }

  /// Parst einen Datumsstring (DD.MM.YYYY, YYYY-MM-DD, DD/MM/YYYY)
  DateTime _parseDate(String dateStr) {
    final s = dateStr.trim();

    if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length == 3) {
        try {
          return DateTime(int.parse(parts[2].trim()), int.parse(parts[1].trim()), int.parse(parts[0].trim()));
        } catch (_) {}
      }
    }

    if (s.contains('-')) {
      try {
        return DateTime.parse(s);
      } catch (_) {}
    }

    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 3) {
        try {
          return DateTime(int.parse(parts[2].trim()), int.parse(parts[1].trim()), int.parse(parts[0].trim()));
        } catch (_) {}
      }
    }

    AppLogger.warning('[ExcelImport] Ungültiges Datumsformat: "$s"');
    throw ExcelImportException('Ungültiges Datumsformat: $dateStr');
  }

  /// Erstellt eine Excel-Vorlage für den Teilnehmer-Import
  Future<String> generateImportTemplate(String outputPath) async {
    final excel = Excel.createExcel();
    final sheet = excel['Teilnehmer'];

    final headers = [
      'Vorname *',
      'Nachname *',
      'Geburtsdatum * (TT.MM.JJJJ)',
      'Geschlecht',
      'Familien-Nr',
      'Straße und Hausnummer',
      'PLZ',
      'Stadt',
      'E-Mail',
      'Telefon',
      'Notfallkontakt Name',
      'Notfallkontakt Telefon',
      'Allergien',
      'Medikamente',
      'Ernährungseinschränkungen',
      'Schwimmfähigkeit',
      'Notizen',
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value =
          TextCellValue(headers[i]);
    }

    final exampleData = [
      ['Max', 'Mustermann', '15.06.2010', 'Männlich', '1', 'Musterstraße 42', '12345', 'Musterstadt', 'max@example.com', '0123456789', 'Maria Mustermann', '0123456789', 'Erdnüsse', 'Keine', 'Vegetarisch', 'Schwimmer', 'Spielt gerne Fußball'],
      ['Anna', 'Mustermann', '10.03.2012', 'Weiblich', '1', 'Musterstraße 42', '12345', 'Musterstadt', 'anna@example.com', '0123456789', 'Maria Mustermann', '0123456789', '', 'Keine', '', 'Seepferdchen', ''],
      ['Lisa', 'Schmidt', '22.08.2011', 'Weiblich', '', 'Beispielweg 7', '54321', 'Beispielstadt', 'lisa@example.com', '9876543210', 'Peter Schmidt', '9876543210', '', 'Keine', '', 'Schwimmer', ''],
    ];

    for (var rowIndex = 0; rowIndex < exampleData.length; rowIndex++) {
      for (var colIndex = 0; colIndex < exampleData[rowIndex].length; colIndex++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1)).value =
            TextCellValue(exampleData[rowIndex][colIndex]);
      }
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      return outputPath;
    }

    throw ImportExportException('export', 'Fehler beim Erstellen der Vorlage', fileName: outputPath);
  }
}

/// Interne Exception zum kontrollierten Abbrechen der Transaktion bei Zeilenfehlern.
/// Wird NICHT an den Aufrufer weitergegeben – das `rolledBack`-Flag im Result übernimmt die Kommunikation.
class _ImportRollbackException implements Exception {
  const _ImportRollbackException();
}

/// Ergebnis eines Excel-Imports
class ExcelImportResult {
  int totalRows = 0;

  /// Zeilen die ohne Fehler verarbeitet wurden (bei rolledBack=true trotzdem nicht in der DB)
  int successCount = 0;

  /// true = Transaktion wurde zurückgesetzt, keine Daten wurden gespeichert
  bool rolledBack = false;

  List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;
  int get errorCount => errors.length;
  int get failedCount => totalRows - successCount;

  @override
  String toString() {
    if (rolledBack) {
      return 'ZURÜCKGESETZT – Gesamt: $totalRows, Verarbeitet: $successCount, Fehler: $errorCount';
    }
    return 'Gesamt: $totalRows, Erfolgreich: $successCount, Fehler: $errorCount';
  }
}
