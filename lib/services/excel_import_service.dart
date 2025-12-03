import 'dart:io';
import 'package:excel/excel.dart';
import '../data/repositories/participant_repository.dart';
import '../data/repositories/family_repository.dart';
import '../utils/logger.dart';

class ExcelImportService {
  final ParticipantRepository _participantRepository;
  final FamilyRepository _familyRepository;

  ExcelImportService(this._participantRepository, this._familyRepository);
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

      AppLogger.info('[ExcelImport] Column Mapping: $columnMapping');

      // PHASE 1: Create families based on Familien-Nr
      final familyMap = await _createFamilies(sheet, columnMapping, eventId, result);
      AppLogger.info('[ExcelImport] Created ${familyMap.length} families');

      // PHASE 2: Import participants with family assignments
      // Skip header row (row 0)
      for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.rows[rowIndex];

        try {
          // Parse row data with dynamic column mapping
          final participantData = _parseRowWithMapping(row, columnMapping, rowIndex);

          // Validate required fields
          if (participantData['first_name'] == null ||
              participantData['last_name'] == null ||
              participantData['birth_date'] == null) {
            result.errors.add(
              'Zeile ${rowIndex + 1}: Vorname, Nachname und Geburtsdatum sind erforderlich',
            );
            continue;
          }

          // Get family ID if Familien-Nr exists
          int? familyId;
          if (participantData.containsKey('family_number') &&
              participantData['family_number'] != null) {
            final familyNumber = participantData['family_number'].toString();
            familyId = familyMap[familyNumber];
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
            familyId: familyId,
          );

          result.successCount++;
          AppLogger.debug('[ExcelImport] Participant created: ${participantData['first_name']} ${participantData['last_name']}${familyId != null ? ' (Familie ID: $familyId)' : ''}');
        } catch (e, stackTrace) {
          AppLogger.error('[ExcelImport] Error in row ${rowIndex + 1}', error: e, stackTrace: stackTrace);
          result.errors.add('Zeile ${rowIndex + 1}: $e');
        }
      }

      result.totalRows = sheet.maxRows - 1; // Exclude header
    } catch (e, stackTrace) {
      AppLogger.error('[ExcelImport] Fatal error during import', error: e, stackTrace: stackTrace);
      result.errors.add('Fehler beim Lesen der Excel-Datei: $e');
    }

    return result;
  }

  /// Create families based on Familien-Nr column
  /// Returns a map of family_number -> family_id
  Future<Map<String, int>> _createFamilies(
    Sheet sheet,
    Map<String, int> columnMapping,
    int eventId,
    ExcelImportResult result,
  ) async {
    final familyMap = <String, int>{};

    // Return early if no family column
    if (!columnMapping.containsKey('family_number')) {
      AppLogger.info('[ExcelImport] No Familien-Nr column found');
      return familyMap;
    }

    // Group rows by family number and track first person name
    final familyGroups = <String, String>{};  // family_number -> first_person_name

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.rows[rowIndex];
      final familyNumberCell = _getCellValue(row, columnMapping['family_number']!);

      if (familyNumberCell != null && familyNumberCell.isNotEmpty) {
        final familyNumber = familyNumberCell.toString().trim();

        // Skip if already processed
        if (familyGroups.containsKey(familyNumber)) {
          continue;
        }

        // Get first person's name for family name
        String? firstName;
        String? lastName;

        if (columnMapping.containsKey('first_name')) {
          firstName = _getCellValue(row, columnMapping['first_name']!);
        }
        if (columnMapping.containsKey('last_name')) {
          lastName = _getCellValue(row, columnMapping['last_name']!);
        }

        if (firstName != null && lastName != null) {
          familyGroups[familyNumber] = '$firstName $lastName';
        }
      }
    }

    // Create families
    for (var entry in familyGroups.entries) {
      final familyNumber = entry.key;
      final firstPersonName = entry.value;
      final familyName = 'Familie $firstPersonName';

      try {
        final familyId = await _familyRepository.createFamily(
          eventId: eventId,
          familyName: familyName,
        );

        familyMap[familyNumber] = familyId;
        AppLogger.info('[ExcelImport] Created family: $familyName (Nr: $familyNumber, ID: $familyId)');
      } catch (e) {
        AppLogger.error('[ExcelImport] Failed to create family for number $familyNumber', error: e);
        result.errors.add('Fehler beim Erstellen der Familie "$familyName": $e');
      }
    }

    return familyMap;
  }


  /// Build column mapping from header row
  Map<String, int> _buildColumnMapping(List<Data?> headerRow) {
    final mapping = <String, int>{};

    for (var i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null || cell.value == null) {
        continue;
      }

      final headerName = cell.value.toString().trim().toLowerCase();
      debugPrint('DEBUG: Header[$i]: "$headerName"');

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
      } else if (headerName.contains('familie') && (headerName.contains('nr') || headerName.contains('nummer'))) {
        mapping['family_number'] = i;
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

    if (columnMapping.containsKey('family_number')) {
      data['family_number'] = _getCellValue(row, columnMapping['family_number']!);
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
    debugPrint('DEBUG _parseDateFromCell: Cell value: $value');
    debugPrint('DEBUG _parseDateFromCell: Cell value type: ${value.runtimeType}');

    // Handle DateCellValue (native Excel date)
    if (value is DateCellValue) {
      debugPrint('DEBUG _parseDateFromCell: Detected DateCellValue');
      return DateTime(value.year, value.month, value.day);
    }

    // Handle DateTimeCellValue
    if (value is DateTimeCellValue) {
      debugPrint('DEBUG _parseDateFromCell: Detected DateTimeCellValue');
      return DateTime(value.year, value.month, value.day);
    }

    // Handle numeric value (Excel serial date number)
    if (value is IntCellValue || value is DoubleCellValue) {
      debugPrint('DEBUG _parseDateFromCell: Detected numeric value (Excel serial date)');
      final numValue = value is IntCellValue ? value.value.toDouble() : (value as DoubleCellValue).value;
      debugPrint('DEBUG _parseDateFromCell: Numeric value: $numValue');
      final excelEpoch = DateTime(1899, 12, 30);
      final result = excelEpoch.add(Duration(days: numValue.toInt()));
      debugPrint('DEBUG _parseDateFromCell: Converted to DateTime: $result');
      return result;
    }

    // Handle string formats
    if (value is TextCellValue) {
      debugPrint('DEBUG _parseDateFromCell: Detected TextCellValue');
      return _parseDate(value.value.toString());
    }

    // Fallback: try to parse as string
    debugPrint('DEBUG _parseDateFromCell: Fallback - treating as string');
    final dateStr = value.toString();
    return _parseDate(dateStr);
  }


  /// Parse date string (supports DD.MM.YYYY, YYYY-MM-DD, etc.)
  DateTime _parseDate(String dateStr) {
    debugPrint('DEBUG _parseDate: Input string: "$dateStr"');
    debugPrint('DEBUG _parseDate: String length: ${dateStr.length}');
    debugPrint('DEBUG _parseDate: Codeunits: ${dateStr.codeUnits}');

    // Trim and clean the string
    final cleanedDateStr = dateStr.trim();
    debugPrint('DEBUG _parseDate: Cleaned string: "$cleanedDateStr"');

    // Try DD.MM.YYYY format (German)
    if (cleanedDateStr.contains('.')) {
      debugPrint('DEBUG _parseDate: Detected DOT format (German)');
      final parts = cleanedDateStr.split('.');
      debugPrint('DEBUG _parseDate: Split parts: $parts (count: ${parts.length})');

      if (parts.length == 3) {
        try {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          debugPrint('DEBUG _parseDate: Parsed values - Day: $day, Month: $month, Year: $year');

          final result = DateTime(year, month, day);
          debugPrint('DEBUG _parseDate: Successfully created DateTime: $result');
          return result;
        } catch (e) {
          debugPrint('DEBUG _parseDate: Error parsing German format: $e');
        }
      }
    }

    // Try YYYY-MM-DD format (ISO)
    if (cleanedDateStr.contains('-')) {
      debugPrint('DEBUG _parseDate: Detected DASH format (ISO)');
      try {
        final result = DateTime.parse(cleanedDateStr);
        debugPrint('DEBUG _parseDate: Successfully parsed ISO format: $result');
        return result;
      } catch (e) {
        debugPrint('DEBUG _parseDate: Error parsing ISO format: $e');
      }
    }

    // Try DD/MM/YYYY format
    if (cleanedDateStr.contains('/')) {
      debugPrint('DEBUG _parseDate: Detected SLASH format');
      final parts = cleanedDateStr.split('/');
      debugPrint('DEBUG _parseDate: Split parts: $parts (count: ${parts.length})');

      if (parts.length == 3) {
        try {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          debugPrint('DEBUG _parseDate: Parsed values - Day: $day, Month: $month, Year: $year');

          final result = DateTime(year, month, day);
          debugPrint('DEBUG _parseDate: Successfully created DateTime: $result');
          return result;
        } catch (e) {
          debugPrint('DEBUG _parseDate: Error parsing slash format: $e');
        }
      }
    }

    debugPrint('DEBUG _parseDate: FAILED - No format matched for: "$cleanedDateStr"');
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

    // Example rows (family with 2 members + 1 single person)
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
