import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../data/database/app_database.dart';
import '../utils/date_utils.dart';

class PdfExportService {
  /// Export participants list to PDF
  Future<String> exportParticipantsList({
    required List<Participant> participants,
    required String eventName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(
              'Teilnehmerliste - $eventName',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Text(
            'Erstellt am: ${DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(DateTime.now())}',
            style: const pw.TextStyle(color: PdfColors.grey600),
          ),
          pw.Text(
            'Anzahl Teilnehmer: ${participants.length}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),

          // Participants Table
          pw.Table.fromTextArray(
            context: context,
            headers: ['Nr', 'Name', 'Geburtsdatum', 'Alter', 'Preis (EUR)'],
            data: participants.asMap().entries.map((entry) {
              final index = entry.key;
              final p = entry.value;
              final age = AppDateUtils.calculateAge(p.birthDate);
              final price = p.manualPriceOverride ?? p.calculatedPrice;
              return [
                '${index + 1}',
                '${p.firstName} ${p.lastName}',
                AppDateUtils.formatGerman(p.birthDate),
                '$age',
                '${price.toStringAsFixed(2)} EUR',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 30,
          ),

          pw.SizedBox(height: 20),

          // Total Price
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Gesamtpreis: ${participants.fold<double>(0, (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice)).toStringAsFixed(2)} EUR',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'teilnehmerliste_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Export participant details to PDF
  Future<String> exportParticipantDetails({
    required Participant participant,
    String? eventName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Teilnehmer-Details',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),

            _buildSection('Persönliche Daten', [
              _buildField('Vorname', participant.firstName),
              _buildField('Nachname', participant.lastName),
              _buildField('Geburtsdatum', AppDateUtils.formatGerman(participant.birthDate)),
              _buildField('Alter', '${AppDateUtils.calculateAge(participant.birthDate)} Jahre'),
              if (participant.gender != null) _buildField('Geschlecht', participant.gender!),
            ]),

            pw.SizedBox(height: 15),

            _buildSection('Adresse', [
              if (participant.street != null)
                _buildField('Straße', participant.street!),
              if (participant.postalCode != null && participant.city != null)
                _buildField('Ort', '${participant.postalCode} ${participant.city}'),
            ]),

            pw.SizedBox(height: 15),

            _buildSection('Kontakt', [
              if (participant.email != null) _buildField('E-Mail', participant.email!),
              if (participant.phone != null) _buildField('Telefon', participant.phone!),
            ]),

            pw.SizedBox(height: 15),

            _buildSection('Notfallkontakt', [
              if (participant.emergencyContactName != null)
                _buildField('Name', participant.emergencyContactName!),
              if (participant.emergencyContactPhone != null)
                _buildField('Telefon', participant.emergencyContactPhone!),
            ]),

            pw.SizedBox(height: 15),

            _buildSection('Preis', [
              _buildField(
                'Berechneter Preis',
                '${participant.calculatedPrice.toStringAsFixed(2)} EUR',
              ),
              if (participant.manualPriceOverride != null)
                _buildField(
                  'Manueller Preis',
                  '${participant.manualPriceOverride!.toStringAsFixed(2)} EUR',
                ),
            ]),
          ],
        ),
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'teilnehmer_${participant.firstName}_${participant.lastName}_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Export financial report to PDF
  Future<String> exportFinancialReport({
    required String eventName,
    required double totalIncomes,
    required double totalExpenses,
    required double totalPayments,
    required Map<String, double> expensesByCategory,
    required Map<String, double> incomesBySource,
  }) async {
    final pdf = pw.Document();
    final balance = totalIncomes - totalExpenses;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Title
          pw.Header(
            level: 0,
            child: pw.Text(
              'Finanzbericht - $eventName',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Erstellt am: ${DateFormat('dd.MM.yyyy HH:mm', 'de_DE').format(DateTime.now())}',
            style: const pw.TextStyle(color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 20),

          // Summary
          _buildFinancialSummary(totalIncomes, totalExpenses, totalPayments, balance),
          pw.SizedBox(height: 20),

          // Expenses by Category
          if (expensesByCategory.isNotEmpty) ...[
            pw.Text(
              'Ausgaben nach Kategorie',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildCategoryTable(expensesByCategory),
            pw.SizedBox(height: 20),
          ],

          // Incomes by Source
          if (incomesBySource.isNotEmpty) ...[
            pw.Text(
              'Einnahmen nach Quelle',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildCategoryTable(incomesBySource),
          ],
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'finanzbericht_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  pw.Widget _buildSection(String title, List<pw.Widget> fields) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        ...fields,
      ],
    );
  }

  pw.Widget _buildField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildFinancialSummary(
    double totalIncomes,
    double totalExpenses,
    double totalPayments,
    double balance,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        children: [
          _buildSummaryRow('Einnahmen', totalIncomes, PdfColors.green),
          pw.Divider(),
          _buildSummaryRow('Ausgaben', totalExpenses, PdfColors.red),
          pw.Divider(),
          _buildSummaryRow('Zahlungen', totalPayments, PdfColors.blue),
          pw.Divider(thickness: 2),
          _buildSummaryRow(
            'Kassenstand',
            balance,
            balance >= 0 ? PdfColors.teal : PdfColors.orange,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, double amount, PdfColor color) {
    final formatter = NumberFormat.currency(locale: 'de_DE', symbol: 'EUR');
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 12, color: color)),
        pw.Text(
          formatter.format(amount),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCategoryTable(Map<String, double> data) {
    final formatter = NumberFormat.currency(locale: 'de_DE', symbol: 'EUR');
    return pw.Table.fromTextArray(
      headers: ['Kategorie', 'Betrag'],
      data: data.entries.map((e) => [e.key, formatter.format(e.value)]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  /// Generate a participant invoice as PDF
  Future<String> generateParticipantInvoice({
    required Participant participant,
    required String eventName,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final invoiceNumber = 'R-${participant.id.toString().padLeft(6, '0')}-${now.year}';
    final invoiceDate = DateFormat('dd.MM.yyyy', 'de_DE').format(now);

    // Load payments for this participant
    final totalPrice = participant.manualPriceOverride ?? participant.calculatedPrice;
    // Note: We would need to pass payments as parameter or load them here
    // For now, using placeholder
    final totalPaid = 0.0; // TODO: Load actual payments
    final outstanding = totalPrice - totalPaid;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Text(
              'Rechnung',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // Invoice Info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Rechnungsnummer: $invoiceNumber',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Rechnungsdatum: $invoiceDate'),
                  pw.SizedBox(height: 5),
                  pw.Text('Teilnehmer-ID: ${participant.id}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Recipient
          pw.Text(
            'Rechnung für:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text('${participant.firstName} ${participant.lastName}'),
          if (participant.street != null) pw.Text(participant.street!),
          if (participant.postalCode != null && participant.city != null)
            pw.Text('${participant.postalCode} ${participant.city}'),
          pw.SizedBox(height: 20),

          // Subject
          pw.Text(
            'Teilnahme an: $eventName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),

          // Positions Table
          pw.Table.fromTextArray(
            context: context,
            headers: ['Pos.', 'Beschreibung', 'Betrag'],
            data: [
              [
                '1',
                'Teilnahmegebühr $eventName\n'
                    'Teilnehmer: ${participant.firstName} ${participant.lastName}\n'
                    'Alter: ${AppDateUtils.calculateAge(participant.birthDate)} Jahre',
                '${totalPrice.toStringAsFixed(2)} €',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 40,
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 150,
                      child: pw.Text('Zwischensumme:'),
                    ),
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text(
                        '${totalPrice.toStringAsFixed(2)} €',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 150,
                      child: pw.Text('Bereits bezahlt:'),
                    ),
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text(
                        '${totalPaid.toStringAsFixed(2)} €',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.SizedBox(
                      width: 150,
                      child: pw.Text(
                        'Offener Betrag:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text(
                        '${outstanding.toStringAsFixed(2)} €',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 40),

          // Payment Information
          if (outstanding > 0) ...[
            pw.Text(
              'Zahlungsinformationen:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Bitte überweisen Sie den offenen Betrag unter Angabe der Rechnungsnummer.\n\n'
              'Vielen Dank für Ihre Zahlung!',
            ),
          ] else ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.green100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(
                'Status: Vollständig bezahlt',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'rechnung_${participant.firstName}_${participant.lastName}_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Generate a family invoice as PDF
  Future<String> generateFamilyInvoice({
    required Family family,
    required String eventName,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final invoiceNumber = 'RF-${family.id.toString().padLeft(6, '0')}-${now.year}';
    final invoiceDate = DateFormat('dd.MM.yyyy', 'de_DE').format(now);

    // Note: We would need to pass family members and payments as parameters
    // For now, using placeholder values
    final totalPrice = 0.0; // TODO: Calculate from family members
    final totalPaid = 0.0; // TODO: Load actual payments
    final outstanding = totalPrice - totalPaid;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Text(
              'Familienrechnung',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // Invoice Info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Rechnungsnummer: $invoiceNumber',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Rechnungsdatum: $invoiceDate'),
                  pw.SizedBox(height: 5),
                  pw.Text('Familien-ID: ${family.id}'),
                  pw.SizedBox(height: 5),
                  pw.Text('Art: Sammelrechnung'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Recipient
          pw.Text(
            'Sammelrechnung für Familie:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            family.familyName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          if (family.contactPerson != null) pw.Text('Ansprechpartner: ${family.contactPerson}'),
          if (family.street != null) pw.Text(family.street!),
          if (family.postalCode != null && family.city != null)
            pw.Text('${family.postalCode} ${family.city}'),
          pw.SizedBox(height: 20),

          // Note about family members
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Text(
              'Diese Rechnung umfasst alle Familienmitglieder für die Veranstaltung "$eventName".\n'
              'Bitte laden Sie die Detailansicht der Familie, um alle Teilnehmer zu sehen.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Gesamtsumme:'),
                    pw.Text('${totalPrice.toStringAsFixed(2)} €'),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Bereits bezahlt:'),
                    pw.Text('${totalPaid.toStringAsFixed(2)} €'),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Offener Betrag:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${outstanding.toStringAsFixed(2)} €',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 40),

          // Payment Information
          if (outstanding > 0) ...[
            pw.Text(
              'Zahlungsinformationen:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Bitte überweisen Sie den offenen Betrag unter Angabe der Rechnungsnummer.\n\n'
              'Vielen Dank für Ihre Zahlung!',
            ),
          ] else ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.green100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(
                'Status: Vollständig bezahlt',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'familienrechnung_${family.familyName.replaceAll(' ', '_')}_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }
}
