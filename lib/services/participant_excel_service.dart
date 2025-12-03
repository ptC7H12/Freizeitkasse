import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/database/app_database.dart';
import '../data/repositories/participant_repository.dart';
import '../utils/logger.dart';

/// Service für Excel-Import/Export von Teilnehmern
class ParticipantExcelService {
  final ParticipantRepository _repository;

  ParticipantExcelService(this._repository);

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
      'Straße und Hausnummer',
      'PLZ',
      'Ort',
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

      final rowData = [
        participant.id.toString(),
        participant.firstName,
        participant.lastName,
        _formatDate(participant.birthDate),
        participant.gender ?? '',
        participant.street ?? '',
        participant.postalCode ?? '',
        participant.city ?? '',
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

      // Header-Zeile überspringen (Index 0)
      var imported = 0;
      var errors = <String>[];

      AppLogger.info('[ParticipantExcelService] Starting import of ${rows.length - 1} rows (excluding header)...');

      for (var i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];

          AppLogger.debug('[ParticipantExcelService] Processing row ${i + 1}: ${row.length} columns');

          // Mindestens Vorname und Nachname müssen vorhanden sein
          if (row.length < 3) {
            final error = 'Zeile ${i + 1}: Zu wenige Spalten (${row.length} statt mind. 3)';
            AppLogger.warning('[ParticipantExcelService] $error');
            errors.add(error);
            continue;
          }

          final firstName = _getCellValue(row, 0);
          final lastName = _getCellValue(row, 1);
          final birthDateStr = _getCellValue(row, 2);

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

          AppLogger.debug('[ParticipantExcelService] Creating participant: $firstName $lastName, born: $birthDate');

          // Teilnehmer erstellen
          await _repository.createParticipant(
            eventId: eventId,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            gender: _getCellValue(row, 3).isNotEmpty ? _getCellValue(row, 4) : null,
            street: _getCellValue(row, 6).isNotEmpty ? _getCellValue(row, 5) : null,
            //postalCode: _getCellValue(row, 6).isNotEmpty ? _getCellValue(row, 6) : null,
            city: _getCellValue(row, 7).isNotEmpty ? _getCellValue(row, 7) : null,
            phone: _getCellValue(row, 5).isNotEmpty ? _getCellValue(row, 8) : null,
            email: _getCellValue(row, 4).isNotEmpty ? _getCellValue(row, 9) : null,
            //emergencyContactName: _getCellValue(row, 10).isNotEmpty ? _getCellValue(row, 10) : null,
            //emergencyContactPhone: _getCellValue(row, 11).isNotEmpty ? _getCellValue(row, 11) : null,
            //medications: _getCellValue(row, 12).isNotEmpty ? _getCellValue(row, 12) : null,
            //allergies: _getCellValue(row, 13).isNotEmpty ? _getCellValue(row, 13) : null,
            //dietaryRestrictions: _getCellValue(row, 14).isNotEmpty ? _getCellValue(row, 14) : null,
            //swimAbility: _getCellValue(row, 15).isNotEmpty ? _getCellValue(row, 15) : null,
            //notes: _getCellValue(row, 16).isNotEmpty ? _getCellValue(row, 16) : null,
            //bildungUndTeilhabe: _getCellValue(row, 17).toLowerCase() == 'ja',
          );

          imported++;
          AppLogger.info('[ParticipantExcelService] ✓ Row ${i + 1}: Created participant $firstName $lastName');
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

    // Header-Zeile (gleich wie Export, aber ohne ID)
    final headers = [
      'ID (leer lassen)',
      'Vorname *',
      'Nachname *',
      'Geburtsdatum * (TT.MM.JJJJ)',
      'Geschlecht',
      'Straße und Hausnummer',
      'PLZ',
      'Ort',
      'Telefon',
      'E-Mail',
      'Notfallkontakt Name',
      'Notfallkontakt Telefon',
      'Medikamente',
      'Allergien',
      'Ernährungseinschränkungen',
      'Notizen',
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

    // Beispiel-Zeile
    final example = [
      '',
      'Max',
      'Mustermann',
      '01.01.2010',
      'Männlich',
      'Musterstraße 123',
      '12345',
      'Musterstadt',
      '0123456789',
      'max@example.com',
      'Maria Mustermann',
      '0123456789',
      '',
      'Keine',
      'Vegetarisch',
      'Bronze',
      'Beispiel-Notiz',
      'Nein',
    ];

    for (var i = 0; i < example.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(example[i]);
      cell.cellStyle = CellStyle(
        italic: true,
        fontColorHex: ExcelColor.fromHexString('#808080'),
      );
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
