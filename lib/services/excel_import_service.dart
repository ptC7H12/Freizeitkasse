import 'dart:io';
import 'package:excel/excel.dart';
import '../data/repositories/participant_repository.dart';

class ExcelImportService {
  final ParticipantRepository _participantRepository;

  ExcelImportService(this._participantRepository);

  /// Import participants from Excel file
  Future<ExcelImportResult> importParticipantsFromExcel({
    required String filePath,
    required int eventId,
  }) async {
    final result = ExcelImportResult();

    try {
      // Read Excel file
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Get first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        result.errors.add('Excel-Datei enthält keine Tabellen');
        return result;
      }

      // Skip header row (row 0)
      for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.rows[rowIndex];

        try {
          // Parse row data
          final participantData = _parseRow(row, rowIndex);

          // Validate required fields
          if (participantData['first_name'] == null ||
              participantData['last_name'] == null ||
              participantData['birth_date'] == null) {
            result.errors.add(
              'Zeile ${rowIndex + 1}: Vorname, Nachname und Geburtsdatum sind erforderlich',
            );
            continue;
          }

          // Create participant
          await _participantRepository.createParticipant(
            eventId: eventId,
            firstName: participantData['first_name'] as String,
            lastName: participantData['last_name'] as String,
            birthDate: participantData['birth_date'] as DateTime,
            gender: participantData['gender'] as String?,
            street: participantData['street'] as String?,
            postalCode: participantData['postal_code'] as String?,
            city: participantData['city'] as String?,
            email: participantData['email'] as String?,
            phone: participantData['phone'] as String?,
            emergencyContactName: participantData['emergency_contact_name'] as String?,
            emergencyContactPhone: participantData['emergency_contact_phone'] as String?,
            allergies: participantData['allergies'] as String?,
            medications: participantData['medications'] as String?,
            dietaryRestrictions: participantData['dietary_restrictions'] as String?,
            swimAbility: participantData['swim_ability'] as String?,
            notes: participantData['notes'] as String?,
          );

          result.successCount++;
        } catch (e) {
          result.errors.add('Zeile ${rowIndex + 1}: $e');
        }
      }

      result.totalRows = sheet.maxRows - 1; // Exclude header
    } catch (e) {
      result.errors.add('Fehler beim Lesen der Excel-Datei: $e');
    }

    return result;
  }

  /// Parse a single row from Excel
  Map<String, dynamic> _parseRow(List<Data?> row, int rowIndex) {
    final data = <String, dynamic>{};

    // Column mapping (0-based index)
    // 0: Vorname, 1: Nachname, 2: Geburtsdatum, 3: Geschlecht
    // 4: Straße und Hausnummer, 5: PLZ, 6: Stadt
    // 7: E-Mail, 8: Telefon
    // 9: Notfallkontakt Name, 10: Notfallkontakt Telefon
    // 11: Allergien, 12: Medikamente
    // 13: Ernährungseinschränkungen, 14: Schwimmfähigkeit, 15: Notizen

    data['first_name'] = _getCellValue(row, 0);
    data['last_name'] = _getCellValue(row, 1);

    // Parse birth date
    final birthDateStr = _getCellValue(row, 2);
    if (birthDateStr != null) {
      try {
        data['birth_date'] = _parseDate(birthDateStr);
      } catch (e) {
        throw Exception('Ungültiges Geburtsdatum: $birthDateStr');
      }
    }

    data['gender'] = _getCellValue(row, 3);
    data['street'] = _getCellValue(row, 4);
    data['postal_code'] = _getCellValue(row, 5);
    data['city'] = _getCellValue(row, 6);
    data['email'] = _getCellValue(row, 7);
    data['phone'] = _getCellValue(row, 8);
    data['emergency_contact_name'] = _getCellValue(row, 9);
    data['emergency_contact_phone'] = _getCellValue(row, 10);
    data['allergies'] = _getCellValue(row, 11);
    data['medications'] = _getCellValue(row, 12);
    data['dietary_restrictions'] = _getCellValue(row, 13);
    data['swim_ability'] = _getCellValue(row, 14);
    data['notes'] = _getCellValue(row, 15);

    return data;
  }

  /// Get cell value as string
  String? _getCellValue(List<Data?> row, int columnIndex) {
    if (columnIndex >= row.length) {
      return null;
    }

    final cell = row[columnIndex];
    if (cell == null || cell.value == null) {
      return null;
    }

    return cell.value.toString().trim();
  }

  /// Parse date string (supports DD.MM.YYYY, YYYY-MM-DD, etc.)
  DateTime _parseDate(String dateStr) {
    // Try DD.MM.YYYY format (German)
    if (dateStr.contains('.')) {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    }

    // Try YYYY-MM-DD format (ISO)
    if (dateStr.contains('-')) {
      return DateTime.parse(dateStr);
    }

    // Try DD/MM/YYYY format
    if (dateStr.contains('/')) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    }

    throw FormatException('Ungültiges Datumsformat: $dateStr');
  }

  /// Generate Excel template for participant import
  Future<String> generateImportTemplate(String outputPath) async {
    final excel = Excel.createExcel();
    final sheet = excel['Teilnehmer'];

    // Header row
    final headers = [
      'Vorname *',
      'Nachname *',
      'Geburtsdatum * (TT.MM.JJJJ)',
      'Geschlecht',
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

    // Example row
    final exampleData = [
      'Max',
      'Mustermann',
      '15.06.2010',
      'Männlich',
      'Musterstraße 42',
      '12345',
      'Musterstadt',
      'max@example.com',
      '0123456789',
      'Maria Mustermann',
      '0123456789',
      'Erdnüsse',
      'Keine',
      'Vegetarisch',
      'Schwimmer',
      'Spielt gerne Fußball',
    ];

    for (var i = 0; i < exampleData.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1)).value =
          TextCellValue(exampleData[i]);
    }

    // Save file
    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      return outputPath;
    }

    throw Exception('Fehler beim Erstellen der Vorlage');
  }
}

/// Result of Excel import operation
class ExcelImportResult {
  int totalRows = 0;
  int successCount = 0;
  List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;
  int get errorCount => errors.length;
  int get failedCount => totalRows - successCount;

  @override
  String toString() {
    return 'Gesamt: $totalRows, Erfolgreich: $successCount, Fehler: $errorCount';
  }
}
