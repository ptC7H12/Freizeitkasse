import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/database/app_database.dart';
import '../data/repositories/participant_repository.dart';

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
      'Straße',
      'Hausnummer',
      'PLZ',
      'Ort',
      'Land',
      'Telefon',
      'Mobil',
      'E-Mail',
      'Notfallkontakt Name',
      'Notfallkontakt Telefon',
      'Med. Informationen',
      'Med. Hinweise',
      'Medikamente',
      'Allergien',
      'Ernährungseinschränkungen',
      'Schwimmfähigkeit',
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
        backgroundColorHex: ExcelColor.gray25,
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
        participant.houseNumber ?? '',
        participant.postalCode ?? '',
        participant.city ?? '',
        participant.country ?? '',
        participant.phone ?? '',
        participant.mobile ?? '',
        participant.email ?? '',
        participant.emergencyContactName ?? '',
        participant.emergencyContactPhone ?? '',
        participant.medicalInfo ?? '',
        participant.medicalNotes ?? '',
        participant.medications ?? '',
        participant.allergies ?? '',
        participant.dietaryRestrictions ?? '',
        participant.swimAbility ?? '',
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
    try {
      // File Picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: false,
          message: 'Keine Datei ausgewählt',
        );
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        return ImportResult(
          success: false,
          message: 'Excel-Datei enthält keine Tabellen',
        );
      }

      // Erste Tabelle verwenden
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        return ImportResult(
          success: false,
          message: 'Tabelle ist leer',
        );
      }

      final rows = sheet.rows;

      // Header-Zeile überspringen (Index 0)
      var imported = 0;
      var errors = <String>[];

      for (var i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];

          // Mindestens Vorname und Nachname müssen vorhanden sein
          if (row.length < 3) {
            errors.add('Zeile ${i + 1}: Zu wenige Spalten');
            continue;
          }

          final firstName = _getCellValue(row, 1); // Spalte B
          final lastName = _getCellValue(row, 2); // Spalte C
          final birthDateStr = _getCellValue(row, 3); // Spalte D

          if (firstName.isEmpty || lastName.isEmpty) {
            errors.add('Zeile ${i + 1}: Vorname oder Nachname fehlt');
            continue;
          }

          if (birthDateStr.isEmpty) {
            errors.add('Zeile ${i + 1}: Geburtsdatum fehlt');
            continue;
          }

          final birthDate = _parseDate(birthDateStr);
          if (birthDate == null) {
            errors.add('Zeile ${i + 1}: Ungültiges Geburtsdatum: $birthDateStr');
            continue;
          }

          // Teilnehmer erstellen
          await _repository.createParticipant(
            eventId: eventId,
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            gender: _getCellValue(row, 4).isNotEmpty ? _getCellValue(row, 4) : null,
            street: _getCellValue(row, 5).isNotEmpty ? _getCellValue(row, 5) : null,
            houseNumber: _getCellValue(row, 6).isNotEmpty ? _getCellValue(row, 6) : null,
            postalCode: _getCellValue(row, 7).isNotEmpty ? _getCellValue(row, 7) : null,
            city: _getCellValue(row, 8).isNotEmpty ? _getCellValue(row, 8) : null,
            country: _getCellValue(row, 9).isNotEmpty ? _getCellValue(row, 9) : null,
            phone: _getCellValue(row, 10).isNotEmpty ? _getCellValue(row, 10) : null,
            mobile: _getCellValue(row, 11).isNotEmpty ? _getCellValue(row, 11) : null,
            email: _getCellValue(row, 12).isNotEmpty ? _getCellValue(row, 12) : null,
            emergencyContactName: _getCellValue(row, 13).isNotEmpty ? _getCellValue(row, 13) : null,
            emergencyContactPhone: _getCellValue(row, 14).isNotEmpty ? _getCellValue(row, 14) : null,
            medicalInfo: _getCellValue(row, 15).isNotEmpty ? _getCellValue(row, 15) : null,
            medicalNotes: _getCellValue(row, 16).isNotEmpty ? _getCellValue(row, 16) : null,
            medications: _getCellValue(row, 17).isNotEmpty ? _getCellValue(row, 17) : null,
            allergies: _getCellValue(row, 18).isNotEmpty ? _getCellValue(row, 18) : null,
            dietaryRestrictions: _getCellValue(row, 19).isNotEmpty ? _getCellValue(row, 19) : null,
            swimAbility: _getCellValue(row, 20).isNotEmpty ? _getCellValue(row, 20) : null,
            notes: _getCellValue(row, 21).isNotEmpty ? _getCellValue(row, 21) : null,
            bildungUndTeilhabe: _getCellValue(row, 22).toLowerCase() == 'ja',
          );

          imported++;
        } catch (e) {
          errors.add('Zeile ${i + 1}: Fehler beim Importieren - $e');
        }
      }

      return ImportResult(
        success: true,
        message: '$imported Teilnehmer importiert${errors.isNotEmpty ? ', ${errors.length} Fehler' : ''}',
        importedCount: imported,
        errors: errors,
      );
    } catch (e) {
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
      'Straße',
      'Hausnummer',
      'PLZ',
      'Ort',
      'Land',
      'Telefon',
      'Mobil',
      'E-Mail',
      'Notfallkontakt Name',
      'Notfallkontakt Telefon',
      'Med. Informationen',
      'Med. Hinweise',
      'Medikamente',
      'Allergien',
      'Ernährungseinschränkungen',
      'Schwimmfähigkeit',
      'Notizen',
      'Bildung & Teilhabe (Ja/Nein)',
    ];

    // Header schreiben
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
      );
    }

    // Beispiel-Zeile
    final example = [
      '',
      'Max',
      'Mustermann',
      '01.01.2010',
      'Männlich',
      'Musterstraße',
      '123',
      '12345',
      'Musterstadt',
      'Deutschland',
      '0123456789',
      '0987654321',
      'max@example.com',
      'Maria Mustermann',
      '0123456789',
      '',
      'Keine',
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
        fontColorHex: ExcelColor.gray50,
      );
    }

    // Auto-fit columns
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 20.0);
    }

    // Datei speichern
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'Teilnehmer_Import_Vorlage.xlsx';
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
      // Format: DD.MM.YYYY oder DD/MM/YYYY
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
