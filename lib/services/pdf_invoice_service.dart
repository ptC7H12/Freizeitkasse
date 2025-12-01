import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:barcode/barcode.dart';
import '../data/database/app_database.dart';

/// Service für PDF-Rechnungsgenerierung
class PdfInvoiceService {
  /// Generiere Rechnung für einzelnen Teilnehmer
  Future<File> generateParticipantInvoice({
    required Participant participant,
    required Event event,
    required String organizationName,
    required String organizationAddress,
    required String iban,
    required String bic,
    List<Payment>? payments,
  }) async {
    final pdf = pw.Document();

    // Rechnungsnummer generieren
    final invoiceNumber = _generateInvoiceNumber(event.id, participant.id);

    // SEPA QR Code generieren
    final sepaQrCode = _generateSepaQrCode(
      recipientName: organizationName,
      iban: iban,
      bic: bic,
      amount: participant.calculatedPrice,
      reference: invoiceNumber,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildInvoiceHeader(organizationName, organizationAddress),
              pw.SizedBox(height: 20),

              // Empfänger
              _buildRecipient(participant),
              pw.SizedBox(height: 30),

              // Rechnungsnummer und Datum
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Rechnungsnummer:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(invoiceNumber),
                      pw.SizedBox(height: 10),
                      pw.Text('Datum:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(_formatDate(DateTime.now())),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Betreff
              pw.Text(
                'Rechnung für: ${event.name}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Teilnehmer-Info
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Teilnehmer', isHeader: true),
                      _buildTableCell('Preis', isHeader: true),
                    ],
                  ),
                  // Daten
                  pw.TableRow(
                    children: [
                      _buildTableCell('${participant.firstName} ${participant.lastName}'),
                      _buildTableCell('${participant.calculatedPrice.toStringAsFixed(2)} €'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Rabatte
              if (participant.discountPercent > 0) ...[
                pw.Text('Rabatt: ${participant.discountPercent.toStringAsFixed(0)}%'),
                if (participant.discountReason != null)
                  pw.Text('Grund: ${participant.discountReason}'),
                pw.SizedBox(height: 10),
              ],

              // Gesamt
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Gesamt: ${participant.calculatedPrice.toStringAsFixed(2)} €',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Zahlungsinformationen
              pw.Text('Zahlungsinformationen:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('IBAN: $iban'),
              pw.Text('BIC: $bic'),
              pw.Text('Verwendungszweck: $invoiceNumber'),
              pw.SizedBox(height: 20),

              // SEPA QR Code
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('SEPA-QR-Code:', style: pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.BarcodeWidget(
                        data: sepaQrCode,
                        barcode: Barcode.qrCode(),
                        width: 100,
                        height: 100,
                      ),
                      pw.Text('Mit Banking-App scannen', style: pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'Rechnung_${participant.lastName}_$invoiceNumber.pdf');
  }

  /// Generiere Familien-Sammelrechnung
  Future<File> generateFamilyInvoice({
    required Family family,
    required List<Participant> participants,
    required Event event,
    required String organizationName,
    required String organizationAddress,
    required String iban,
    required String bic,
  }) async {
    final pdf = pw.Document();

    // Gesamtpreis berechnen
    final totalAmount = participants.fold<double>(
      0.0,
      (sum, p) => sum + p.calculatedPrice,
    );

    // Rechnungsnummer generieren
    final invoiceNumber = _generateInvoiceNumber(event.id, family.id, isFamily: true);

    // SEPA QR Code generieren
    final sepaQrCode = _generateSepaQrCode(
      recipientName: organizationName,
      iban: iban,
      bic: bic,
      amount: totalAmount,
      reference: invoiceNumber,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildInvoiceHeader(organizationName, organizationAddress),
              pw.SizedBox(height: 20),

              // Empfänger (Familie)
              _buildFamilyRecipient(family),
              pw.SizedBox(height: 30),

              // Rechnungsnummer und Datum
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Rechnungsnummer:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(invoiceNumber),
                      pw.SizedBox(height: 10),
                      pw.Text('Datum:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(_formatDate(DateTime.now())),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Betreff
              pw.Text(
                'Sammelrechnung für: ${event.name}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Teilnehmer-Liste
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Teilnehmer', isHeader: true),
                      _buildTableCell('Geburtsdatum', isHeader: true),
                      _buildTableCell('Preis', isHeader: true),
                    ],
                  ),
                  // Daten
                  ...participants.map((p) => pw.TableRow(
                        children: [
                          _buildTableCell('${p.firstName} ${p.lastName}'),
                          _buildTableCell(_formatDate(p.birthDate)),
                          _buildTableCell('${p.calculatedPrice.toStringAsFixed(2)} €'),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 10),

              // Gesamt
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Gesamtbetrag: ${totalAmount.toStringAsFixed(2)} €',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Zahlungsinformationen
              pw.Text('Zahlungsinformationen:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('IBAN: $iban'),
              pw.Text('BIC: $bic'),
              pw.Text('Verwendungszweck: $invoiceNumber'),
              pw.SizedBox(height: 20),

              // SEPA QR Code
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('SEPA-QR-Code:', style: pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.BarcodeWidget(
                        data: sepaQrCode,
                        barcode: Barcode.qrCode(),
                        width: 100,
                        height: 100,
                      ),
                      pw.Text('Mit Banking-App scannen', style: pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return _savePdf(pdf, 'Familienrechnung_${family.familyName}_$invoiceNumber.pdf');
  }

  // ===== HELPER METHODS =====

  pw.Widget _buildInvoiceHeader(String organizationName, String address) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          organizationName,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(address, style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildRecipient(Participant participant) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('${participant.firstName} ${participant.lastName}'),
        if (participant.street != null) pw.Text('${participant.street}${participant.houseNumber != null ? " ${participant.houseNumber}" : ""}'),
        if (participant.postalCode != null && participant.city != null)
          pw.Text('${participant.postalCode} ${participant.city}'),
      ],
    );
  }

  pw.Widget _buildFamilyRecipient(Family family) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Familie ${family.familyName}'),
        if (family.contactPerson != null) pw.Text('z.Hd. ${family.contactPerson}'),
        if (family.street != null) pw.Text(family.street!),
        if (family.postalCode != null && family.city != null)
          pw.Text('${family.postalCode} ${family.city}'),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: isHeader ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Generiere Rechnungsnummer: R-EVENTID-ID-YEAR
  String _generateInvoiceNumber(int eventId, int id, {bool isFamily = false}) {
    final year = DateTime.now().year;
    final prefix = isFamily ? 'F' : 'P';
    return 'R-$eventId-$prefix$id-$year';
  }

  /// Generiere SEPA QR Code String (EPC069-12)
  String _generateSepaQrCode({
    required String recipientName,
    required String iban,
    required String bic,
    required double amount,
    required String reference,
  }) {
    final lines = [
      'BCD',                                    // Service Tag
      '002',                                    // Version
      '1',                                      // Character Set (UTF-8)
      'SCT',                                    // Identification
      bic,                                      // BIC
      recipientName,                            // Beneficiary Name
      iban.replaceAll(' ', ''),                // Beneficiary Account (IBAN)
      'EUR${amount.toStringAsFixed(2)}',       // Amount
      '',                                       // Purpose (leer)
      reference,                                // Structured Reference
      '',                                       // Remittance Information (leer)
      '',                                       // Beneficiary to originator information
    ];

    return lines.join('\n');
  }

  /// Speichere PDF
  Future<File> _savePdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory(path.join(dir.path, 'invoices'));

    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }

    final file = File(path.join(invoicesDir.path, fileName));
    await file.writeAsBytes(bytes);

    return file;
  }

  /// Öffne PDF (Preview/Share)
  Future<void> previewPdf(pw.Document pdf, {String? filename}) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: filename ?? 'invoice.pdf',
    );
  }
}
