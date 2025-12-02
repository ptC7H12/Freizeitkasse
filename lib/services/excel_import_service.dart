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

      // Read header row to map columns dynamically
      final headerRow = sheet.rows[0];
      final columnMapping = _buildColumnMapping(headerRow);

      print('DEBUG: Column Mapping: $columnMapping');

      // Skip header row (row 0)
      for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.rows[rowIndex];

        try {
          // Parse row data with dynamic column mapping
          final participantData = _parseRowWithMapping(row, columnMapping, rowIndex);

          print('DEBUG: Row ${rowIndex + 1} parsed: ${participantData.keys.toList()}');

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
          print('DEBUG: Participant created successfully: ${participantData['first_name']} ${participantData['last_name']}');
        } catch (e, stackTrace) {
          print('DEBUG: Error in row ${rowIndex + 1}: $e');
          print('DEBUG: StackTrace: $stackTrace');
          result.errors.add('Zeile ${rowIndex + 1}: $e');
        }
      }

      result.totalRows = sheet.maxRows - 1; // Exclude header
    } catch (e, stackTrace) {
      print('DEBUG: Fatal error: $e');
      print('DEBUG: StackTrace: $stackTrace');
      result.errors.add('Fehler beim Lesen der Excel-Datei: $e');
    }

    return result;
  }

  /// Build column mapping from header row
  Map<String, int> _buildColumnMapping(List<Data?> headerRow) {
    final mapping = <String, int>{};

    for (var i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null || cell.value == null) continue;

      final headerName = cell.value.toString().trim().toLowerCase();
      print('DEBUG: Header[$i]: "$headerName"');

      // Map known header names (case-insensitive, with variations)
      if (headerName.contains('vorname')) {
        mapping['first_name'] = i;
      } else if (headerName.contains('nachname')) {
        mapping['last_name'] = i;
      } else if (headerName.contains('geburtsdatum') || headerName.contains('geburtstag')) {
        mapping['birth_date'] = i;
      } else if (headerName.contains('geschlecht')) {
        mapping['gender'] = i;
      } else if (headerName.contains('e-mail') || headerName.contains('email')) {
        mapping['email'] = i;
      } else if (headerName.contains('telefon') || headerName.contains('phone')) {
        mapping['phone'] = i;
      } else if (headerName.contains('straße') || headerName.contains('strasse') || headerName.contains('adresse')) {
        mapping['street'] = i;
      } else if (headerName.contains('plz') || headerName.contains('postleitzahl')) {
        mapping['postal_code'] = i;
      } else if (headerName.contains('stadt') || headerName.contains('ort')) {
        mapping['city'] = i;
      } else if (headerName.contains('notfall') && headerName.contains('name')) {
        mapping['emergency_contact_name'] = i;
      } else if (headerName.contains('notfall') && (headerName.contains('telefon') || headerName.contains('phone'))) {
        mapping['emergency_contact_phone'] = i;
      } else if (headerName.contains('allergi')) {
        mapping['allergies'] = i;
      } else if (headerName.contains('medikament')) {
        mapping['medications'] = i;
      } else if (headerName.contains('ernährung') || headerName.contains('diät')) {
        mapping['dietary_restrictions'] = i;
      } else if (headerName.contains('schwimm')) {
        mapping['swim_ability'] = i;
      } else if (headerName.contains('notiz') || headerName.contains('bemerkung')) {
        mapping['notes'] = i;
      } else if (headerName.contains('familie')) {
        // Ignore family column for now
      }
    }

    return mapping;
  }

  /// Parse a single row with dynamic column mapping
  Map<String, dynamic> _parseRowWithMapping(
    List<Data?> row,
    Map<String, int> columnMapping,
    int rowIndex,
  ) {
    final data = <String, dynamic>{};

    // Parse each field using the column mapping
    if (columnMapping.containsKey('first_name')) {
      data['first_name'] = _getCellValue(row, columnMapping['first_name']!);
    }

    if (columnMapping.containsKey('last_name')) {
      data['last_name'] = _getCellValue(row, columnMapping['last_name']!);
    }

    // Parse birth date
    if (columnMapping.containsKey('birth_date')) {
      final birthDateCell = row[columnMapping['birth_date']!];
      if (birthDateCell != null && birthDateCell.value != null) {
        try {
          data['birth_date'] = _parseDateFromCell(birthDateCell);
        } catch (e) {
          throw Exception('Ungültiges Geburtsdatum: ${birthDateCell.value}');
        }
      }
    }

    if (columnMapping.containsKey('gender')) {
      data['gender'] = _getCellValue(row, columnMapping['gender']!);
    }

    if (columnMapping.containsKey('street')) {
      data['street'] = _getCellValue(row, columnMapping['street']!);
    }

    if (columnMapping.containsKey('postal_code')) {
      data['postal_code'] = _getCellValue(row, columnMapping['postal_code']!);
    }

    if (columnMapping.containsKey('city')) {
      data['city'] = _getCellValue(row, columnMapping['city']!);
    }

    if (columnMapping.containsKey('email')) {
      data['email'] = _getCellValue(row, columnMapping['email']!);
    }

    if (columnMapping.containsKey('phone')) {
      data['phone'] = _getCellValue(row, columnMapping['phone']!);
    }

    if (columnMapping.containsKey('emergency_contact_name')) {
      data['emergency_contact_name'] = _getCellValue(row, columnMapping['emergency_contact_name']!);
    }

    if (columnMapping.containsKey('emergency_contact_phone')) {
      data['emergency_contact_phone'] = _getCellValue(row, columnMapping['emergency_contact_phone']!);
    }

    if (columnMapping.containsKey('allergies')) {
      data['allergies'] = _getCellValue(row, columnMapping['allergies']!);
    }

    if (columnMapping.containsKey('medications')) {
      data['medications'] = _getCellValue(row, columnMapping['medications']!);
    }

    if (columnMapping.containsKey('dietary_restrictions')) {
      data['dietary_restrictions'] = _getCellValue(row, columnMapping['dietary_restrictions']!);
    }

    if (columnMapping.containsKey('swim_ability')) {
      data['swim_ability'] = _getCellValue(row, columnMapping['swim_ability']!);
    }

    if (columnMapping.containsKey('notes')) {
      data['notes'] = _getCellValue(row, columnMapping['notes']!);
    }

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

  /// Parse date from Excel cell (handles both DateCellValue and string formats)
  DateTime _parseDateFromCell(Data cell) {
    final value = cell.value;

    // Handle DateCellValue (native Excel date)
    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day);
    }

    // Handle DateTimeCellValue
    if (value is DateTimeCellValue) {
      return DateTime(value.year, value.month, value.day);
    }

    // Handle numeric value (Excel serial date number)
    if (value is IntCellValue || value is DoubleCellValue) {
      final numValue = value is IntCellValue ? value.value.toDouble() : (value as DoubleCellValue).value;
      // Excel date starts from 1900-01-01 (with a quirk for leap year 1900)
      // Excel serial date 1 = 1900-01-01
      final excelEpoch = DateTime(1899, 12, 30); // 30.12.1899 (Excel starts counting from 1)
      return excelEpoch.add(Duration(days: numValue.toInt()));
    }

    // Handle string formats
    if (value is TextCellValue) {
      return _parseDate(value.value.toString());
    }

    // Fallback: try to parse as string
    final dateStr = value.toString();
    return _parseDate(dateStr);
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
