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
      AppLogger.info('[ExcelImport] Starting import from file: $filePath');
      AppLogger.info('[ExcelImport] Target event ID: $eventId');

      // Read Excel file
      AppLogger.debug('[ExcelImport] Reading file bytes...');
      final bytes = File(filePath).readAsBytesSync();
      AppLogger.debug('[ExcelImport] File size: ${bytes.length} bytes');

      // Decode Excel
      AppLogger.debug('[ExcelImport] Decoding Excel file...');
      final excel = Excel.decodeBytes(bytes);
      AppLogger.info('[ExcelImport] Excel decoded. Found ${excel.tables.length} sheets');

      // Get first sheet
      if (excel.tables.isEmpty) {
        const error = 'Excel-Datei enthält keine Tabellen';
        AppLogger.error('[ExcelImport] $error');
        result.errors.add(error);
        return result;
      }

      final firstSheetName = excel.tables.keys.first;
      AppLogger.info('[ExcelImport] Using sheet: $firstSheetName');

      final sheet = excel.tables[firstSheetName];
      if (sheet == null) {
        final error = 'Sheet "$firstSheetName" ist null';
        AppLogger.error('[ExcelImport] $error');
        result.errors.add(error);
        return result;
      }

      AppLogger.info('[ExcelImport] Sheet has ${sheet.maxRows} rows and ${sheet.maxColumns} columns');

      // Validate sheet has data
      if (sheet.maxRows < 2) {
        const error = 'Excel-Datei muss mindestens eine Header-Zeile und eine Datenzeile enthalten';
        AppLogger.error('[ExcelImport] $error');
        result.errors.add(error);
        return result;
      }

      // Read header row to map columns dynamically
      AppLogger.debug('[ExcelImport] Reading header row...');
      final headerRow = sheet.rows.firstOrNull;
      if (headerRow == null) {
        const error = 'Header-Zeile konnte nicht gelesen werden';
        AppLogger.error('[ExcelImport] $error');
        result.errors.add(error);
        return result;
      }

      final columnMapping = _buildColumnMapping(headerRow);
      AppLogger.info('[ExcelImport] Column Mapping: $columnMapping');

      // Validate required columns
      if (!columnMapping.containsKey('first_name') ||
          !columnMapping.containsKey('last_name') ||
          !columnMapping.containsKey('birth_date')) {
        const error = 'Erforderliche Spalten fehlen: Vorname, Nachname, Geburtsdatum';
        AppLogger.error('[ExcelImport] $error');
        result.errors.add(error);
        return result;
      }

      // PHASE 1: Create families based on Familien-Nr
      AppLogger.info('[ExcelImport] PHASE 1: Creating families...');
      final familyMap = await _createFamilies(sheet, columnMapping, eventId, result);
      AppLogger.info('[ExcelImport] Created ${familyMap.length} families');

      // PHASE 2: Import participants with family assignments
      AppLogger.info('[ExcelImport] PHASE 2: Importing participants...');
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
          String? familyNumber;
          if (participantData.containsKey('family_number') &&
              participantData['family_number'] != null) {
            familyNumber = participantData['family_number'].toString().trim();
            if (familyNumber.isNotEmpty) {
              familyId = familyMap[familyNumber];
              if (familyId != null) {
                AppLogger.debug('[ExcelImport] Row ${rowIndex + 1}: Assigning to family $familyNumber (ID: $familyId)');
              } else {
                AppLogger.warning('[ExcelImport] Row ${rowIndex + 1}: Family number "$familyNumber" not found in familyMap!');
              }
            }
          }

          // Build address from either combined field or separate fields
          String? address;
          if (participantData.containsKey('address') && participantData['address'] != null) {
            // Use combined address field if available
            address = participantData['address'] as String?;
          } else {
            // Combine separate address fields if available
            final street = participantData['street'] as String?;
            final postalCode = participantData['postal_code'] as String?;
            final city = participantData['city'] as String?;

            if (street != null || postalCode != null || city != null) {
              final parts = <String>[];
              if (street != null && street.isNotEmpty) {
                parts.add(street);
              }
              if (postalCode != null && postalCode.isNotEmpty) {
                if (city != null && city.isNotEmpty) {
                  parts.add('$postalCode $city');
                } else {
                  parts.add(postalCode);
                }
              } else if (city != null && city.isNotEmpty) {
                parts.add(city);
              }
              address = parts.join(', ');
            }
          }

          // Create participant
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
          final familyInfo = familyId != null ? ' → Familie ID: $familyId (Nr: $familyNumber)' : ' → Einzelperson';
          AppLogger.info('[ExcelImport] ✓ Row ${rowIndex + 1}: ${participantData['first_name']} ${participantData['last_name']}$familyInfo');
        } catch (e, stackTrace) {
          AppLogger.error('[ExcelImport] Error in row ${rowIndex + 1}', error: e, stackTrace: stackTrace);
          result.errors.add('Zeile ${rowIndex + 1}: $e');
        }
      }

      result.totalRows = sheet.maxRows - 1; // Exclude header
      AppLogger.info('[ExcelImport] Import complete: ${result.successCount}/${result.totalRows} successful, ${result.errorCount} errors');
    } catch (e, stackTrace) {
      AppLogger.error('[ExcelImport] Fatal error during import', error: e, stackTrace: stackTrace);
      final errorMessage = 'Fehler beim Lesen der Excel-Datei: $e\n\nStack Trace:\n$stackTrace';
      AppLogger.error('[ExcelImport] Full error details: $errorMessage');
      result.errors.add('Fehler beim Lesen der Excel-Datei: $e');
    }

    AppLogger.info('[ExcelImport] Import result: $result');
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
      AppLogger.warning('[ExcelImport] No Familien-Nr column found - skipping family creation');
      return familyMap;
    }

    AppLogger.info('[ExcelImport] Starting family creation from Familien-Nr column (index: ${columnMapping['family_number']})');

    // Group rows by family number and track first person name
    final familyGroups = <String, List<String>>{};  // family_number -> [lastName, firstName]
    final familyMemberCounts = <String, int>{};  // family_number -> member count

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.rows[rowIndex];
      final familyNumberCell = _getCellValue(row, columnMapping['family_number']!);

      AppLogger.debug('[ExcelImport] Row $rowIndex: family_number cell = "$familyNumberCell"');

      if (familyNumberCell != null && familyNumberCell.isNotEmpty) {
        final familyNumber = familyNumberCell.toString().trim();

        // Count members in this family
        familyMemberCounts[familyNumber] = (familyMemberCounts[familyNumber] ?? 0) + 1;

        // Skip if already processed (we only need the first person)
        if (familyGroups.containsKey(familyNumber)) {
          AppLogger.debug('[ExcelImport] Family $familyNumber already processed, skipping');
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
          // Store as [lastName, firstName] like Python code does
          familyGroups[familyNumber] = [lastName, firstName];
          AppLogger.info('[ExcelImport] Found family $familyNumber: First member = "$lastName $firstName" (Row $rowIndex)');
        } else {
          AppLogger.warning('[ExcelImport] Row $rowIndex: Family number $familyNumber found but name is incomplete (firstName: $firstName, lastName: $lastName)');
        }
      }
    }

    AppLogger.info('[ExcelImport] Found ${familyGroups.length} unique families:');
    for (var entry in familyMemberCounts.entries) {
      AppLogger.info('[ExcelImport]   Familie ${entry.key}: ${entry.value} Mitglieder');
    }

    // Create families
    for (var entry in familyGroups.entries) {
      final familyNumber = entry.key;
      final names = entry.value;
      final lastName = names[0];
      final firstName = names[1];
      // Format like Python: "LastName FirstName" (Familie Mustermann Max)
      final familyName = 'Familie $lastName $firstName';
      final memberCount = familyMemberCounts[familyNumber] ?? 0;

      try {
        final familyId = await _familyRepository.createFamily(
          eventId: eventId,
          familyName: familyName,
        );

        familyMap[familyNumber] = familyId;
        AppLogger.info('[ExcelImport] ✓ Created family: "$familyName" (Nr: $familyNumber, ID: $familyId, Members: $memberCount)');
      } catch (e) {
        AppLogger.error('[ExcelImport] Failed to create family for number $familyNumber', error: e);
        result.errors.add('Fehler beim Erstellen der Familie "$familyName": $e');
      }
    }

    AppLogger.info('[ExcelImport] Family creation complete: ${familyMap.length} families created');
    return familyMap;
  }


  /// Build column mapping from header row
  Map<String, int> _buildColumnMapping(List<Data?> headerRow) {
    final mapping = <String, int>{};

    AppLogger.info('[ExcelImport] Building column mapping from ${headerRow.length} headers');

    for (var i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null || cell.value == null) {
        continue;
      }

      final headerName = cell.value.toString().trim().toLowerCase();
      AppLogger.debug('[ExcelImport] Header[$i]: "$headerName"');

      // Map known header names (case-insensitive, with variations)
      if (headerName.contains('vorname')) {
        mapping['first_name'] = i;
        AppLogger.info('[ExcelImport] ✓ Mapped first_name to column $i');
      } else if (headerName.contains('nachname')) {
        mapping['last_name'] = i;
        AppLogger.info('[ExcelImport] ✓ Mapped last_name to column $i');
      } else if (headerName.contains('geburtsdatum') || headerName.contains('geburtstag')) {
        mapping['birth_date'] = i;
        AppLogger.info('[ExcelImport] ✓ Mapped birth_date to column $i');
      } else if (headerName.contains('geschlecht')) {
        mapping['gender'] = i;
        AppLogger.info('[ExcelImport] ✓ Mapped gender to column $i');
      } else if (headerName.contains('e-mail') || headerName.contains('email')) {
        mapping['email'] = i;
      } else if (headerName.contains('telefon') || headerName.contains('phone')) {
        mapping['phone'] = i;
      } else if (headerName.contains('adresse')) {
        // Wenn "Adresse" gefunden wird, direkt als address mappen
        mapping['address'] = i;
      } else if (headerName.contains('straße') || headerName.contains('strasse')) {
        // Separate Straße-Spalte
        mapping['street'] = i;
      } else if (headerName.contains('plz') || headerName.contains('postleitzahl')) {
        // Separate PLZ-Spalte
        mapping['postal_code'] = i;
      } else if (headerName.contains('stadt') || headerName.contains('ort')) {
        // Separate Ort-Spalte
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
      } else if (headerName.contains('notiz') || headerName.contains('bemerkung')) {
        mapping['notes'] = i;
      } else if (headerName.contains('familie') && (headerName.contains('nr') || headerName.contains('nummer'))) {
        mapping['family_number'] = i;
        AppLogger.info('[ExcelImport] ✓ Mapped family_number to column $i (header: "$headerName")');
      }
    }

    AppLogger.info('[ExcelImport] Column mapping complete: ${mapping.length} columns mapped');
    if (mapping.containsKey('family_number')) {
      AppLogger.info('[ExcelImport] ✓ Family column detected at index ${mapping['family_number']}');
    } else {
      AppLogger.warning('[ExcelImport] ⚠ No family column detected - participants will not be grouped into families');
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
    try {
      if (columnIndex < 0 || columnIndex >= row.length) {
        return null;
      }

      final cell = row[columnIndex];
      if (cell == null || cell.value == null) {
        return null;
      }

      final value = cell.value.toString().trim();
      return value.isEmpty ? null : value;
    } catch (e) {
      AppLogger.error('[ExcelImport] Error reading cell at column $columnIndex', error: e);
      return null;
    }
  }

  /// Parse date from Excel cell (handles both DateCellValue and string formats)
  DateTime _parseDateFromCell(Data cell) {
    final value = cell.value;
    AppLogger.debug('DEBUG _parseDateFromCell: Cell value: $value');
    AppLogger.debug('DEBUG _parseDateFromCell: Cell value type: ${value.runtimeType}');

    // Handle DateCellValue (native Excel date)
    if (value is DateCellValue) {
      AppLogger.debug('DEBUG _parseDateFromCell: Detected DateCellValue');
      return DateTime(value.year, value.month, value.day);
    }

    // Handle DateTimeCellValue
    if (value is DateTimeCellValue) {
      AppLogger.debug('DEBUG _parseDateFromCell: Detected DateTimeCellValue');
      return DateTime(value.year, value.month, value.day);
    }

    // Handle numeric value (Excel serial date number)
    if (value is IntCellValue || value is DoubleCellValue) {
      AppLogger.debug('DEBUG _parseDateFromCell: Detected numeric value (Excel serial date)');
      final numValue = value is IntCellValue ? value.value.toDouble() : (value as DoubleCellValue).value;
      AppLogger.debug('DEBUG _parseDateFromCell: Numeric value: $numValue');
      final excelEpoch = DateTime(1899, 12, 30);
      final result = excelEpoch.add(Duration(days: numValue.toInt()));
      AppLogger.debug('DEBUG _parseDateFromCell: Converted to DateTime: $result');
      return result;
    }

    // Handle string formats
    if (value is TextCellValue) {
      AppLogger.debug('DEBUG _parseDateFromCell: Detected TextCellValue');
      return _parseDate(value.value.toString());
    }

    // Fallback: try to parse as string
    AppLogger.debug('DEBUG _parseDateFromCell: Fallback - treating as string');
    final dateStr = value.toString();
    return _parseDate(dateStr);
  }


  /// Parse date string (supports DD.MM.YYYY, YYYY-MM-DD, etc.)
  DateTime _parseDate(String dateStr) {
    AppLogger.debug('DEBUG _parseDate: Input string: "$dateStr"');
    AppLogger.debug('DEBUG _parseDate: String length: ${dateStr.length}');
    AppLogger.debug('DEBUG _parseDate: Codeunits: ${dateStr.codeUnits}');

    // Trim and clean the string
    final cleanedDateStr = dateStr.trim();
    AppLogger.debug('DEBUG _parseDate: Cleaned string: "$cleanedDateStr"');

    // Try DD.MM.YYYY format (German)
    if (cleanedDateStr.contains('.')) {
      AppLogger.debug('DEBUG _parseDate: Detected DOT format (German)');
      final parts = cleanedDateStr.split('.');
      AppLogger.debug('DEBUG _parseDate: Split parts: $parts (count: ${parts.length})');

      if (parts.length == 3) {
        try {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          AppLogger.debug('DEBUG _parseDate: Parsed values - Day: $day, Month: $month, Year: $year');

          final result = DateTime(year, month, day);
          AppLogger.debug('DEBUG _parseDate: Successfully created DateTime: $result');
          return result;
        } catch (e) {
          AppLogger.debug('DEBUG _parseDate: Error parsing German format: $e');
        }
      }
    }

    // Try YYYY-MM-DD format (ISO)
    if (cleanedDateStr.contains('-')) {
      AppLogger.debug('DEBUG _parseDate: Detected DASH format (ISO)');
      try {
        final result = DateTime.parse(cleanedDateStr);
        AppLogger.debug('DEBUG _parseDate: Successfully parsed ISO format: $result');
        return result;
      } catch (e) {
        AppLogger.debug('DEBUG _parseDate: Error parsing ISO format: $e');
      }
    }

    // Try DD/MM/YYYY format
    if (cleanedDateStr.contains('/')) {
      AppLogger.debug('DEBUG _parseDate: Detected SLASH format');
      final parts = cleanedDateStr.split('/');
      AppLogger.debug('DEBUG _parseDate: Split parts: $parts (count: ${parts.length})');

      if (parts.length == 3) {
        try {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          AppLogger.debug('DEBUG _parseDate: Parsed values - Day: $day, Month: $month, Year: $year');

          final result = DateTime(year, month, day);
          AppLogger.debug('DEBUG _parseDate: Successfully created DateTime: $result');
          return result;
        } catch (e) {
          AppLogger.debug('DEBUG _parseDate: Error parsing slash format: $e');
        }
      }
    }

    AppLogger.debug('DEBUG _parseDate: FAILED - No format matched for: "$cleanedDateStr"');
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
