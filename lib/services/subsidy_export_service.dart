import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../data/database/app_database.dart';
import '../services/subsidy_calculator_service.dart';
import '../utils/date_utils.dart';
import '../utils/logger.dart';

/// Service für den Export von Zuschusslisten (PDF & Excel)
///
/// Portiert von Python (OLD Scripts/cash_status.py)
/// - export_subsidy_excel() / _create_subsidy_excel()
/// - export_subsidy_pdf() / _create_subsidy_pdf()
class SubsidyExportService {
  /// Exportiert Zuschussliste als PDF
  ///
  /// Args:
  ///   - event: Das Event
  ///   - subsidyType: Art des Zuschusses (z.B. "Rollenzuschuss: Betreuer")
  ///   - participants: Liste mit Teilnehmer-Details
  ///
  /// Returns:
  ///   Dateipfad zur erstellten PDF-Datei
  Future<String> exportSubsidyPDF({
    required Event event,
    required String subsidyType,
    required List<SubsidyParticipant> participants,
  }) async {
    try {
      AppLogger.info('[SubsidyExport] Erstelle PDF für: $subsidyType');

      final pdf = pw.Document();

      // Berechnungen
      final totalSubsidy = participants.fold<double>(
        0.0,
        (sum, p) => sum + p.subsidyAmount,
      );
      final totalBasePrice = participants.fold<double>(
        0.0,
        (sum, p) => sum + p.basePrice,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // === HEADER ===
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  event.name,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1e40af'),
                  ),
                ),
                pw.Text(
                  'Beantragungsdatum: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Zeitraum
            pw.Text(
              'Zeitraum: ${AppDateUtils.formatGerman(event.startDate)} - ${AppDateUtils.formatGerman(event.endDate)}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 16),

            // Art des Zuschusses
            pw.Text(
              'Art des Zuschusses: $subsidyType',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1e40af'),
              ),
            ),
            pw.SizedBox(height: 16),

            // === TEILNEHMER-TABELLE ===
            pw.Table.fromTextArray(
              context: context,
              headers: ['Name', 'Geburtsdatum', 'Regulärer Preis', 'Zuschuss'],
              data: participants.map((p) {
                return [
                  p.name,
                  AppDateUtils.formatGerman(p.birthDate),
                  '${p.basePrice.toStringAsFixed(2)} €',
                  '${p.subsidyAmount.toStringAsFixed(2)} €',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1e40af'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
            ),

            pw.SizedBox(height: 16),

            // === SUMME ===
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Gesamtsumme der Zuschüsse: ${totalSubsidy.toStringAsFixed(2)} €',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#4CAF50'),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 32),

            // === UNTERSCHRIFT ===
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Unterschrift:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: 300,
                  height: 1,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      // Datei speichern
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sanitizedType = subsidyType.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = 'zuschuss_${sanitizedType}_$timestamp.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      AppLogger.info('[SubsidyExport] PDF erstellt: ${file.path}');
      return file.path;
    } catch (e, stack) {
      AppLogger.error(
        '[SubsidyExport] Fehler beim Erstellen der PDF',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Exportiert Zuschussliste als Excel
  ///
  /// Args:
  ///   - event: Das Event
  ///   - subsidyType: Art des Zuschusses (z.B. "Rollenzuschuss: Betreuer")
  ///   - participants: Liste mit Teilnehmer-Details
  ///
  /// Returns:
  ///   Dateipfad zur erstellten Excel-Datei
  Future<String> exportSubsidyExcel({
    required Event event,
    required String subsidyType,
    required List<SubsidyParticipant> participants,
  }) async {
    try {
      AppLogger.info('[SubsidyExport] Erstelle Excel für: $subsidyType');

      final excel = Excel.createExcel();
      final sheet = excel['Zuschussliste'];

      // Berechnungen
      final totalSubsidy = participants.fold<double>(
        0.0,
        (sum, p) => sum + p.subsidyAmount,
      );
      final totalBasePrice = participants.fold<double>(
        0.0,
        (sum, p) => sum + p.basePrice,
      );

      // === HEADER-INFORMATIONEN ===
      final today = DateTime.now();

      // Zeile 1: Event-Name (links) & Beantragungsdatum (rechts)
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(event.name);
      sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
        fontSize: 16,
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#1e40af'),
      );

      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue(
        'Beantragungsdatum: ${DateFormat('dd.MM.yyyy').format(today)}',
      );
      sheet.cell(CellIndex.indexByString('E1')).cellStyle = CellStyle(
        fontSize: 10,
        horizontalAlign: HorizontalAlign.Right,
      );

      // Zeile 2: Zeitraum
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Zeitraum: ${AppDateUtils.formatGerman(event.startDate)} - ${AppDateUtils.formatGerman(event.endDate)}',
      );
      sheet.cell(CellIndex.indexByString('A2')).cellStyle = CellStyle(fontSize: 10);

      // Zeile 3: Art des Zuschusses
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Art des Zuschusses: $subsidyType',
      );
      sheet.cell(CellIndex.indexByString('A3')).cellStyle = CellStyle(
        fontSize: 12,
        bold: true,
        fontColorHex: ExcelColor.fromHexString('#1e40af'),
      );

      // === TABELLEN-HEADER (Zeile 5) ===
      final headers = ['Name', 'Geburtsdatum', 'Regulärer Preis (€)', 'Zuschuss (€)'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#1e40af'),
          fontColorHex: ExcelColor.white,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // === DATEN-ZEILEN ===
      var rowIndex = 5; // Start bei Zeile 6 (0-indexed: 5)
      for (final participant in participants) {
        // Name
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
            TextCellValue(participant.name);

        // Geburtsdatum
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
            TextCellValue(AppDateUtils.formatGerman(participant.birthDate));

        // Regulärer Preis
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
            DoubleCellValue(participant.basePrice);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle =
            CellStyle(numberFormat: NumFormat.defaultNumeric);

        // Zuschuss
        final subsidyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
        subsidyCell.value = DoubleCellValue(participant.subsidyAmount);
        subsidyCell.cellStyle = CellStyle(
          numberFormat: NumFormat.defaultNumeric,
          fontColorHex: ExcelColor.fromHexString('#4CAF50'),
          bold: true,
        );

        rowIndex++;
      }

      // === SUMMENZEILE ===
      rowIndex++; // Leerzeile
      final summaryRow = rowIndex;

      // "Gesamt" Label
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow)).value =
          TextCellValue('Gesamt');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow)).cellStyle =
          CellStyle(bold: true);

      // Summe Regulärer Preis
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: summaryRow)).value =
          DoubleCellValue(totalBasePrice);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: summaryRow)).cellStyle =
          CellStyle(
        bold: true,
        numberFormat: NumFormat.defaultNumeric,
        backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
      );

      // Summe Zuschuss
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: summaryRow)).value =
          DoubleCellValue(totalSubsidy);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: summaryRow)).cellStyle =
          CellStyle(
        bold: true,
        numberFormat: NumFormat.defaultNumeric,
        fontColorHex: ExcelColor.fromHexString('#4CAF50'),
        backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
      );

      // === UNTERSCHRIFTENFELD ===
      rowIndex += 3;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
          TextCellValue('Unterschrift:');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle =
          CellStyle(bold: true);

      rowIndex++;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
          TextCellValue('_' * 50);

      // === SPALTENBREITEN ===
      sheet.setColWidth(0, 30); // Name
      sheet.setColWidth(1, 20); // Geburtsdatum
      sheet.setColWidth(2, 20); // Regulärer Preis
      sheet.setColWidth(3, 20); // Zuschuss

      // Datei speichern
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final sanitizedType = subsidyType.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = 'zuschuss_${sanitizedType}_$timestamp.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);

      AppLogger.info('[SubsidyExport] Excel erstellt: ${file.path}');
      return file.path;
    } catch (e, stack) {
      AppLogger.error(
        '[SubsidyExport] Fehler beim Erstellen der Excel-Datei',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Exportiert alle Zuschüsse nach Rollen (mehrere PDFs)
  ///
  /// Args:
  ///   - event: Das Event
  ///   - subsidiesByRole: Map mit Rollen-IDs und Zuschuss-Details
  ///
  /// Returns:
  ///   Liste der erstellten PDF-Dateipfade
  Future<List<String>> exportAllRoleSubsidiesPDF({
    required Event event,
    required Map<int, SubsidyByRole> subsidiesByRole,
  }) async {
    final filePaths = <String>[];

    for (final roleData in subsidiesByRole.values) {
      final subsidyType = 'Rollenzuschuss: ${roleData.roleName}';
      final filePath = await exportSubsidyPDF(
        event: event,
        subsidyType: subsidyType,
        participants: roleData.participants,
      );
      filePaths.add(filePath);
    }

    AppLogger.info('[SubsidyExport] ${filePaths.length} PDFs für Rollen erstellt');
    return filePaths;
  }

  /// Exportiert alle Zuschüsse nach Rollen (mehrere Excel-Dateien)
  ///
  /// Args:
  ///   - event: Das Event
  ///   - subsidiesByRole: Map mit Rollen-IDs und Zuschuss-Details
  ///
  /// Returns:
  ///   Liste der erstellten Excel-Dateipfade
  Future<List<String>> exportAllRoleSubsidiesExcel({
    required Event event,
    required Map<int, SubsidyByRole> subsidiesByRole,
  }) async {
    final filePaths = <String>[];

    for (final roleData in subsidiesByRole.values) {
      final subsidyType = 'Rollenzuschuss: ${roleData.roleName}';
      final filePath = await exportSubsidyExcel(
        event: event,
        subsidyType: subsidyType,
        participants: roleData.participants,
      );
      filePaths.add(filePath);
    }

    AppLogger.info('[SubsidyExport] ${filePaths.length} Excel-Dateien für Rollen erstellt');
    return filePaths;
  }
}
