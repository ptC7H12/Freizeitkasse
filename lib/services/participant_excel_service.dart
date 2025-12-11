import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/database/app_database.dart';
import '../data/repositories/participant_repository.dart';
import '../data/repositories/family_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../utils/logger.dart';

/// Service für Excel-Import/Export von Teilnehmern
class ParticipantExcelService {
  final ParticipantRepository _participantRepository;
  final FamilyRepository _familyRepository;
  final PaymentRepository _paymentRepository;

  ParticipantExcelService(
    this._participantRepository,
    this._familyRepository,
    this._paymentRepository,
  );

  /// Exportiere Teilnehmer als Excel
  Future<File> exportParticipants({
    required List<Participant> participants,
    required String eventName,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Teilnehmer'];

    // Header-Zeile
    final headers = [
      'ID',
      'Vorname',
      'Nachname',
      'Geburtsdatum',
      'Geschlecht',
      'Adresse',
      'Telefon',
      'E-Mail',
      'Notfallkontakt Name',
      'Notfallkontakt Telefon',
      'Medikamente',
      'Allergien',
      'Ernährungseinschränkungen',
      'Notizen',
      'Bildung & Teilhabe',
      'Rolle ID',
      'Familie ID',
      'Preis',
      'Manueller Preis',
      'Rabatt %',
      'Rabattgrund',
      'Direkte Zahlungen',
      'Anteilige Familienzahlungen',
      'Gesamt bezahlt',
      'Noch offen',
    ];

    // Header schreiben
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D3D3D3'),
      );
    }

    // Daten schreiben
    for (var rowIndex = 0; rowIndex < participants.length; rowIndex++) {
      final participant = participants[rowIndex];
      final excelRowIndex = rowIndex + 1; // +1 wegen Header

      // Zahlungsaufschlüsselung laden (inkl. anteiliger Familienzahlungen)
      final paymentBreakdown = await _paymentRepository.getPaymentBreakdown(participant.id);
      final directPayments = paymentBreakdown['directPayments'] ?? 0.0;
      final familyShare = paymentBreakdown['familyShare'] ?? 0.0;
      final totalPaid = paymentBreakdown['totalPaid'] ?? 0.0;
      final outstanding = paymentBreakdown['outstanding'] ?? 0.0;

      final rowData = [
        participant.id.toString(),
        participant.firstName,
        participant.lastName,
        _formatDate(participant.birthDate),
        participant.gender ?? '',
        participant.address ?? '',
        participant.phone ?? '',
        participant.email ?? '',
        participant.emergencyContactName ?? '',
        participant.emergencyContactPhone ?? '',
        participant.medications ?? '',
        participant.allergies ?? '',
        participant.dietaryRestrictions ?? '',
        participant.notes ?? '',
        participant.bildungUndTeilhabe ? 'Ja' : 'Nein',
        participant.roleId?.toString() ?? '',
        participant.familyId?.toString() ?? '',
        participant.calculatedPrice.toStringAsFixed(2),
        participant.manualPriceOverride?.toStringAsFixed(2) ?? '',
        participant.discountPercent.toStringAsFixed(0),
        participant.discountReason ?? '',
        directPayments.toStringAsFixed(2),
        familyShare.toStringAsFixed(2),
        totalPaid.toStringAsFixed(2),
        outstanding.toStringAsFixed(2),
      ];

      for (var colIndex = 0; colIndex < rowData.length; colIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: excelRowIndex),
        );
        cell.value = TextCellValue(rowData[colIndex]);
      }
    }

    // Auto-fit columns (approximation)
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 15.0);
    }

    // Datei speichern
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'Teilnehmer_${eventName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path.join(dir.path, fileName));

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Importiere Teilnehmer aus Excel
  Future<ImportResult> importParticipants({
    required int eventId,
  }) async {
    AppLogger.info('[ParticipantExcelService] ==================== IMPORT START ====================');
    AppLogger.info('[ParticipantExcelService] importParticipants() called');
    AppLogger.info('[ParticipantExcelService] eventId: $eventId');

    try {
      // File Picker
      AppLogger.info('[ParticipantExcelService] Opening file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowedExtensions: ['xlsx', 'xls'],
      );

      AppLogger.debug('[ParticipantExcelService] File picker result: ${result != null ? "File selected" : "Cancelled"}');

      if (result == null || result.files.isEmpty) {
        AppLogger.warning('[ParticipantExcelService] No file selected or result is empty');
        return ImportResult(
          success: false,
          message: 'Keine Datei ausgewählt',
        );
      }

      AppLogger.info('[ParticipantExcelService] File selected: ${result.files.single.name}');
      AppLogger.info('[ParticipantExcelService] File size: ${result.files.single.size} bytes');

      final filePath = result.files.single.path;
      if (filePath == null) {
        AppLogger.error('[ParticipantExcelService] File path is null!');
        return ImportResult(
          success: false,
          message: 'Dateipfad konnte nicht gelesen werden',
        );
      }

      AppLogger.info('[ParticipantExcelService] File path: $filePath');

      final file = File(filePath);
      if (!file.existsSync()) {
        AppLogger.error('[ParticipantExcelService] File does not exist at path: $filePath');
        return ImportResult(
          success: false,
          message: 'Datei nicht gefunden',
        );
      }

      AppLogger.info('[ParticipantExcelService] Reading file bytes...');
      final bytes = await file.readAsBytes();
      AppLogger.debug('[ParticipantExcelService] File size: ${bytes.length} bytes');

      AppLogger.info('[ParticipantExcelService] Decoding Excel...');
      Excel excel;
      try {
        excel = Excel.decodeBytes(bytes);
        AppLogger.info('[ParticipantExcelService] Excel decoded. Found ${excel.tables.length} sheets');
      } catch (e, stackTrace) {
        AppLogger.error('[ParticipantExcelService] Failed to decode Excel file', error: e, stackTrace: stackTrace);
        return ImportResult(
          success: false,
          message: 'Die Excel-Datei konnte nicht gelesen werden. '
              'Bitte stellen Sie sicher, dass:\n'
              '1. Die Datei im .xlsx Format ist (nicht .xls)\n'
              '2. Die Datei keine beschädigten Zellen enthält\n'
              '3. Alle Zellen einfache Werte enthalten (keine Formeln)\n'
              '4. Die Datei in Excel geöffnet und erneut gespeichert wurde\n\n'
              'Fehlerdetails: $e',
        );
      }

      if (excel.tables.isEmpty) {
        AppLogger.error('[ParticipantExcelService] Excel file contains no tables');
        return ImportResult(
          success: false,
          message: 'Excel-Datei enthält keine Tabellen',
        );
      }

      // Erste Tabelle verwenden
      final sheetName = excel.tables.keys.first;
      AppLogger.info('[ParticipantExcelService] Using sheet: $sheetName');

      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        AppLogger.error('[ParticipantExcelService] Sheet is null or empty');
        return ImportResult(
          success: false,
          message: 'Tabelle ist leer',
        );
      }

      final rows = sheet.rows;
      AppLogger.info('[ParticipantExcelService] Sheet has ${rows.length} rows');

      // Parse header row to build column mapping
      if (rows.isEmpty) {
        AppLogger.error('[ParticipantExcelService] Sheet has no rows');
        return ImportResult(
          success: false,
          message: 'Tabelle enthält keine Zeilen',
        );
      }

      final headerRow = rows[0];
      final columnMapping = _buildColumnMapping(headerRow);
      AppLogger.info('[ParticipantExcelService] Column mapping: $columnMapping');

      // Validate required columns
      if (!columnMapping.containsKey('first_name') ||
          !columnMapping.containsKey('last_name') ||
          !columnMapping.containsKey('birth_date')) {
        const error = 'Erforderliche Spalten fehlen: Vorname, Nachname, Geburtsdatum';
        AppLogger.error('[ParticipantExcelService] $error');
        return ImportResult(
          success: false,
          message: error,
        );
      }

      // PHASE 1: Create families based on Familien-Nr
      final familyMap = <String, int>{};
      if (columnMapping.containsKey('family_number')) {
        AppLogger.info('[ParticipantExcelService] PHASE 1: Creating families...');
        familyMap.addAll(await _createFamilies(rows, columnMapping, eventId));
        AppLogger.info('[ParticipantExcelService] Created ${familyMap.length} families');
      } else {
        AppLogger.info('[ParticipantExcelService] No Familien-Nr column - skipping family creation');
      }

      // PHASE 2: Import participants
      var imported = 0;
      var errors = <String>[];

      AppLogger.info('[ParticipantExcelService] PHASE 2: Starting import of ${rows.length - 1} rows (excluding header)...');

      for (var i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];

          AppLogger.debug('[ParticipantExcelService] Processing row ${i + 1}: ${row.length} columns');

          final firstName = _getCellValue(row, columnMapping['first_name']!);
          final lastName = _getCellValue(row, columnMapping['last_name']!);
          final birthDateStr = _getCellValue(row, columnMapping['birth_date']!);

          AppLogger.debug('[ParticipantExcelService] Row ${i + 1}: firstName="$firstName", lastName="$lastName", birthDate="$birthDateStr"');

          if (firstName.isEmpty || lastName.isEmpty) {
            final error = 'Zeile ${i + 1}: Vorname oder Nachname fehlt';
            AppLogger.warning('[ParticipantExcelService] $error');
            errors.add(error);
            continue;
          }

          if (birthDateStr.isEmpty) {
            final error = 'Zeile ${i + 1}: Geburtsdatum fehlt';
            AppLogger.warning('[ParticipantExcelService] $error');
            errors.add(error);
            continue;
          }

          final birthDate = _parseDate(birthDateStr);
          if (birthDate == null) {
            final error = 'Zeile ${i + 1}: Ungültiges Geburtsdatum: $birthDateStr';
            AppLogger.warning('[ParticipantExcelService] $error');
            errors.add(error);
            continue;
          }

          // Get family ID if Familien-Nr exists
          int? familyId;
          String? familyNumber;
          if (columnMapping.containsKey('family_number')) {
            familyNumber = _getCellValue(row, columnMapping['family_number']!);
            if (familyNumber.isNotEmpty) {
              familyId = familyMap[familyNumber];
              if (familyId != null) {
                AppLogger.debug('[ParticipantExcelService] Row ${i + 1}: Assigning to family $familyNumber (ID: $familyId)');
              } else {
                AppLogger.warning('[ParticipantExcelService] Row ${i + 1}: Family number "$familyNumber" not found in familyMap!');
              }
            }
          }

          AppLogger.debug('[ParticipantExcelService] Creating participant: $firstName $lastName, born: $birthDate');

          // Parse optional fields with column mapping
          String? gender;
          String? email;
          String? address;
          String? phone;
          String? emergencyContactName;
          String? emergencyContactPhone;
          String? medications;
          String? allergies;
          String? dietaryRestrictions;
          bool? bildungUndTeilhabe;

          if (columnMapping.containsKey('gender')) {
            gender = _getCellValue(row, columnMapping['gender']!);
          }
          if (columnMapping.containsKey('email')) {
            email = _getCellValue(row, columnMapping['email']!);
          }
          if (columnMapping.containsKey('address')) {
            address = _getCellValue(row, columnMapping['address']!);
          }
          if (columnMapping.containsKey('phone')) {
            phone = _getCellValue(row, columnMapping['phone']!);
          }
          if (columnMapping.containsKey('emergency_contact_name')) {
            emergencyContactName = _getCellValue(row, columnMapping['emergency_contact_name']!);
          }
          if (columnMapping.containsKey('emergency_contact_phone')) {
            emergencyContactPhone = _getCellValue(row, columnMapping['emergency_contact_phone']!);
          }
          if (columnMapping.containsKey('medications')) {
            medications = _getCellValue(row, columnMapping['medications']!);
          }
          if (columnMapping.containsKey('allergies')) {
            allergies = _getCellValue(row, columnMapping['allergies']!);
          }
          if (columnMapping.containsKey('dietary_restrictions')) {
            dietaryRestrictions = _getCellValue(row, columnMapping['dietary_restrictions']!);
          }
          if (columnMapping.containsKey('bildung_und_teilhabe')) {
            final value = _getCellValue(row, columnMapping['bildung_und_teilhabe']!);
            bildungUndTeilhabe = value.toLowerCase() == 'ja';
          }

          // Teilnehmer erstellen
          await _participantRepository.createParticipant(
            eventId: eventId,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            gender: gender,
            address: address,
            email: email,
            phone: phone,
            emergencyContactName: emergencyContactName,
            emergencyContactPhone: emergencyContactPhone,
            medications: medications,
            allergies: allergies,
            dietaryRestrictions: dietaryRestrictions,
            bildungUndTeilhabe: bildungUndTeilhabe ?? false,
            familyId: familyId,
          );

          imported++;
          final familyInfo = familyId != null ? ' → Familie ID: $familyId (Nr: $familyNumber)' : ' → Einzelperson';
          AppLogger.info('[ParticipantExcelService] ✓ Row ${i + 1}: Created participant $firstName $lastName$familyInfo');
        } catch (e, stackTrace) {
          final error = 'Zeile ${i + 1}: Fehler beim Importieren - $e';
          AppLogger.error('[ParticipantExcelService] $error', error: e, stackTrace: stackTrace);
          errors.add(error);
        }
      }

      AppLogger.info('[ParticipantExcelService] Import complete: $imported imported, ${errors.length} errors');
      AppLogger.info('[ParticipantExcelService] ==================== IMPORT END ====================');

      return ImportResult(
        success: true,
        message: '$imported Teilnehmer importiert${errors.isNotEmpty ? ', ${errors.length} Fehler' : ''}',
        importedCount: imported,
        errors: errors,
      );
    } catch (e, stackTrace) {
      AppLogger.error('[ParticipantExcelService] FATAL ERROR during import', error: e, stackTrace: stackTrace);
      AppLogger.error('[ParticipantExcelService] Error type: ${e.runtimeType}');
      AppLogger.error('[ParticipantExcelService] Error message: $e');
      AppLogger.info('[ParticipantExcelService] ==================== IMPORT END (WITH ERROR) ====================');

      return ImportResult(
        success: false,
        message: 'Fehler beim Lesen der Datei: $e',
      );
    }
  }

  /// Erstelle Excel-Template zum Herunterladen
  Future<File> createImportTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Teilnehmer'];

    // Header-Zeile in der korrekten Reihenfolge
    final headers = [
      'Vorname *',
      'Nachname *',
      'Geburtsdatum * (TT.MM.JJJJ)',
      'Familien-Nr',
      'Geschlecht',
      'E-Mail',
      'Adresse',
      'Telefon',
      'Notfallkontakt Name',
      'Notfallkontakt Telefon',
      'Medikamente',
      'Allergien',
      'Ernährung',
      'Bildung & Teilhabe (Ja/Nein)',
    ];

    // Header schreiben
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Beispiel-Zeilen (Familie mit 2 Kindern + 1 Einzelperson)
    final exampleData = [
      ['Max', 'Mustermann', '01.07.2010', '1', 'Männlich', 'max@example.com', 'Musterstraße 42, 12345 Musterstadt', '0123456789', 'Maria Mustermann', '0123456789', '', 'Erdnüsse', 'Vegetarisch', 'Nein'],
      ['Anna', 'Mustermann', '10.03.2012', '1', 'Weiblich', 'anna@example.com', 'Musterstraße 42, 12345 Musterstadt', '0123456789', 'Maria Mustermann', '0123456789', '', '', '', 'Nein'],
      ['Lisa', 'Schmidt', '22.08.2011', '', 'Weiblich', 'lisa@example.com', 'Beispielweg 7, 54321 Beispielstadt', '9876543210', 'Peter Schmidt', '9876543210', '', '', '', 'Nein'],
    ];

    // Beispiel-Daten schreiben
    for (var rowIndex = 0; rowIndex < exampleData.length; rowIndex++) {
      for (var colIndex = 0; colIndex < exampleData[rowIndex].length; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1));
        cell.value = TextCellValue(exampleData[rowIndex][colIndex]);
        cell.cellStyle = CellStyle(
          italic: true,
          fontColorHex: ExcelColor.fromHexString('#808080'),
        );
      }
    }

    // Auto-fit columns
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20.0);
    }

    // Datei speichern
    final dir = await getApplicationDocumentsDirectory();
    const fileName = 'Teilnehmer_Import_Vorlage.xlsx';
    final file = File(path.join(dir.path, fileName));

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  // ===== HELPER METHODS =====

  String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final cell = row[index];
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  DateTime? _parseDate(String dateStr) {
    try {
      // ISO-Format mit Zeit (z.B. 1991-07-01T00:00:00.000Z)
      if (dateStr.contains('T')) {
        return DateTime.parse(dateStr);
      }

      // ISO-Format ohne Zeit (z.B. 1991-07-01)
      if (dateStr.contains('-') && !dateStr.contains('.')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2]);
          if (year != null && month != null && day != null) {
            return DateTime(year, month, day);
          }
        }
      }

      // Deutsches Format: DD.MM.YYYY oder DD/MM/YYYY
      final parts = dateStr.split(RegExp(r'[./]'));
      if (parts.length != 3) return null;

      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day == null || month == null || year == null) return null;

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Build column mapping from header row
  /// Maps German column names to internal field names and their column indices
  Map<String, int> _buildColumnMapping(List<Data?> headerRow) {
    AppLogger.debug('[ParticipantExcelService] _buildColumnMapping() - parsing ${headerRow.length} header cells');

    final mapping = <String, int>{};

    for (var i = 0; i < headerRow.length; i++) {
      final header = _getCellValue(headerRow, i).toLowerCase().trim();

      // Remove asterisks and notes from headers (e.g. "Vorname *" → "vorname")
      final cleanHeader = header.replaceAll('*', '').replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

      AppLogger.debug('[ParticipantExcelService] Header[$i]: "$header" → "$cleanHeader"');

      // Map German headers to internal field names
      if (cleanHeader == 'vorname') {
        mapping['first_name'] = i;
      } else if (cleanHeader == 'nachname') {
        mapping['last_name'] = i;
      } else if (cleanHeader == 'geburtsdatum') {
        mapping['birth_date'] = i;
      } else if (cleanHeader == 'familien-nr') {
        mapping['family_number'] = i;
      } else if (cleanHeader == 'geschlecht') {
        mapping['gender'] = i;
      } else if (cleanHeader == 'e-mail') {
        mapping['email'] = i;
      } else if (cleanHeader == 'adresse') {
        mapping['address'] = i;
      } else if (cleanHeader == 'telefon') {
        mapping['phone'] = i;
      } else if (cleanHeader == 'notfallkontakt name') {
        mapping['emergency_contact_name'] = i;
      } else if (cleanHeader == 'notfallkontakt telefon') {
        mapping['emergency_contact_phone'] = i;
      } else if (cleanHeader == 'medikamente') {
        mapping['medications'] = i;
      } else if (cleanHeader == 'allergien') {
        mapping['allergies'] = i;
      } else if (cleanHeader == 'ernährung') {
        mapping['dietary_restrictions'] = i;
      } else if (cleanHeader == 'bildung & teilhabe') {
        mapping['bildung_und_teilhabe'] = i;
      }
    }

    AppLogger.info('[ParticipantExcelService] Column mapping complete: $mapping');
    return mapping;
  }

  /// Create families from Excel data based on Familien-Nr
  /// Returns a map of family_number → family_id
  Future<Map<String, int>> _createFamilies(
    List<List<Data?>> rows,
    Map<String, int> columnMapping,
    int eventId,
  ) async {
    AppLogger.info('[ParticipantExcelService] _createFamilies() - grouping families...');

    final familyNumberCol = columnMapping['family_number']!;
    final lastNameCol = columnMapping['last_name']!;

    // Group rows by family number
    final familyGroups = <String, List<int>>{};

    for (var i = 1; i < rows.length; i++) {  // Skip header row (index 0)
      final row = rows[i];
      final familyNumber = _getCellValue(row, familyNumberCol);

      // Only process rows with a family number
      if (familyNumber.isNotEmpty) {
        if (!familyGroups.containsKey(familyNumber)) {
          familyGroups[familyNumber] = [];
        }
        familyGroups[familyNumber]!.add(i);
      }
    }

    AppLogger.info('[ParticipantExcelService] Found ${familyGroups.length} family groups');

    // Create family records
    final familyMap = <String, int>{};

    for (final entry in familyGroups.entries) {
      final familyNumber = entry.key;
      final rowIndices = entry.value;

      if (rowIndices.isEmpty) continue;

      // Use first person's last name for family name
      final firstRowIndex = rowIndices.first;
      final firstRow = rows[firstRowIndex];
      final lastName = _getCellValue(firstRow, lastNameCol);

      final familyName = 'Familie $lastName';

      AppLogger.debug('[ParticipantExcelService] Creating family "$familyName" (Familien-Nr: $familyNumber, ${rowIndices.length} members)');

      try {
        // Create family in database
        final familyId = await _familyRepository.createFamily(
          eventId: eventId,
          familyName: familyName,
        );

        familyMap[familyNumber] = familyId;
        AppLogger.info('[ParticipantExcelService] ✓ Created family "$familyName" with ID: $familyId (Familien-Nr: $familyNumber)');
      } catch (e, stackTrace) {
        AppLogger.error('[ParticipantExcelService] Failed to create family "$familyName"', error: e, stackTrace: stackTrace);
      }
    }

    return familyMap;
  }

}

/// Import-Ergebnis
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final List<String> errors;

  ImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
    this.errors = const [],
  });
}
