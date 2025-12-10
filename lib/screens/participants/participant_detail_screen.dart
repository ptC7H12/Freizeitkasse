import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:drift/drift.dart' show OrderingTerm;
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/pdf_export_provider.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';
import '../../extensions/context_extensions.dart';
import '../../utils/logger.dart';
import '../payments/payment_form_screen.dart';
import 'participant_form_screen.dart';

/// Participant Detail Screen
///
/// Zeigt alle Informationen eines Teilnehmers mit Zahlungsstatus und Aktionen
class ParticipantDetailScreen extends ConsumerStatefulWidget {
  final int participantId;

  const ParticipantDetailScreen({
    super.key,
    required this.participantId,
  });

  @override
  ConsumerState<ParticipantDetailScreen> createState() => _ParticipantDetailScreenState();
}

class _ParticipantDetailScreenState extends ConsumerState<ParticipantDetailScreen> {
  Participant? _participant;
  Family? _family;
  Role? _role;
  List<Payment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final database = ref.read(databaseProvider);

      // Lade Teilnehmer
      final participant = await (database.select(database.participants)
            ..where((tbl) => tbl.id.equals(widget.participantId)))
          .getSingleOrNull();

      if (participant == null) {
        if (mounted) {
          context.showError('Teilnehmer nicht gefunden');
          Navigator.of(context).pop();
        }
        return;
      }

      // Lade Familie (wenn vorhanden)
      Family? family;
      if (participant.familyId != null) {
        family = await (database.select(database.families)
              ..where((tbl) => tbl.id.equals(participant.familyId!)))
            .getSingleOrNull();
      }

      // Lade Rolle (wenn vorhanden)
      Role? role;
      if (participant.roleId != null) {
        role = await (database.select(database.roles)
              ..where((tbl) => tbl.id.equals(participant.roleId!)))
            .getSingleOrNull();
      }

      // Lade alle Zahlungen für diesen Teilnehmer
      final payments = await (database.select(database.payments)
            ..where((tbl) => tbl.participantId.equals(widget.participantId))
            ..where((tbl) => tbl.isActive.equals(true))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.paymentDate)]))
          .get();

      setState(() {
        _participant = participant;
        _family = family;
        _role = role;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e, stack) {
      AppLogger.error('Fehler beim Laden der Teilnehmerdaten', error: e, stackTrace: stack);
      if (mounted) {
        context.showError('Fehler beim Laden der Daten');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadInvoice() async {
    if (_participant == null) return;

    try {
      final pdfService = ref.read(pdfExportServiceProvider);
      final currentEvent = ref.read(currentEventProvider);
      final database = ref.read(databaseProvider);

      // Lade Settings
      Setting? settings;
      if (currentEvent != null) {
        settings = await (database.select(database.settings)
              ..where((tbl) => tbl.eventId.equals(currentEvent.id)))
            .getSingleOrNull();
      }

      // Wenn Teilnehmer zu Familie gehört, Familienrechnung erstellen
      if (_family != null) {
        // Lade alle Familienmitglieder
        final familyMembers = await (database.select(database.participants)
              ..where((tbl) => tbl.familyId.equals(_family!.id))
              ..where((tbl) => tbl.isActive.equals(true)))
            .get();

        // Lade alle Zahlungen für die Familie (sowohl direkte als auch von Mitgliedern)
        final familyPayments = await (database.select(database.payments)
              ..where((tbl) => tbl.familyId.equals(_family!.id))
              ..where((tbl) => tbl.isActive.equals(true)))
            .get();

        // Lade auch Zahlungen der einzelnen Mitglieder
        final memberPayments = await (database.select(database.payments)
              ..where((tbl) => tbl.participantId.isIn(familyMembers.map((m) => m.id).toList()))
              ..where((tbl) => tbl.isActive.equals(true)))
            .get();

        // Kombiniere beide Zahlungslisten
        final allPayments = [...familyPayments, ...memberPayments];

        final filePath = await pdfService.generateFamilyInvoice(
          family: _family!,
          eventName: currentEvent?.name ?? 'Veranstaltung',
          familyMembers: familyMembers,
          familyPayments: allPayments,
          settings: settings,
          verwendungszweckPrefix: settings?.verwendungszweckPrefix,
        );
        if (mounted) {
          context.showSuccess('Familienrechnung erstellt: $filePath');
        }
      } else {
        // Einzelrechnung erstellen
        final filePath = await pdfService.generateParticipantInvoice(
          participant: _participant!,
          eventName: currentEvent?.name ?? 'Veranstaltung',
          payments: _payments,
          settings: settings,
          verwendungszweckPrefix: settings?.verwendungszweckPrefix,
        );
        if (mounted) {
          context.showSuccess('Rechnung erstellt: $filePath');
        }
      }
    } catch (e, stack) {
      AppLogger.error('Fehler beim Erstellen der Rechnung', error: e, stackTrace: stack);
      if (mounted) {
        context.showError('Fehler beim Erstellen der Rechnung: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Teilnehmer-Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_participant == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Teilnehmer-Details'),
        ),
        body: const Center(child: Text('Teilnehmer nicht gefunden')),
      );
    }

    final totalPrice = _participant!.manualPriceOverride ?? _participant!.calculatedPrice;
    final totalPaid = _payments.fold<double>(0, (sum, payment) => sum + payment.amount);
    final outstanding = totalPrice - totalPaid;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_participant!.firstName} ${_participant!.lastName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ParticipantFormScreen(
                    participantId: widget.participantId,
                  ),
                ),
              );
              if (result == true) {
                _loadData(); // Daten neu laden nach Bearbeitung
              }
            },
            tooltip: 'Bearbeiten',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aktions-Buttons
            _buildActionButtons(context, outstanding),
            const SizedBox(height: AppConstants.spacing),

            // Zahlungsstatus Card
            _buildPaymentStatusCard(totalPrice, totalPaid, outstanding),
            const SizedBox(height: AppConstants.spacing),

            // Persönliche Daten
            _buildSectionCard(
              'Persönliche Daten',
              Icons.person,
              [
                _buildInfoRow('Vorname', _participant!.firstName),
                _buildInfoRow('Nachname', _participant!.lastName),
                _buildInfoRow(
                  'Geburtsdatum',
                  '${AppDateUtils.formatGerman(_participant!.birthDate)} (${AppDateUtils.calculateAge(_participant!.birthDate)} Jahre)',
                ),
                if (_participant!.gender != null)
                  _buildInfoRow('Geschlecht', _participant!.gender!),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),

            // Familie & Rolle
            if (_family != null || _role != null)
              _buildSectionCard(
                'Zuordnung',
                Icons.group,
                [
                  if (_family != null) _buildInfoRow('Familie', _family!.familyName),
                  if (_role != null) _buildInfoRow('Rolle', _role!.name),
                ],
              ),
            if (_family != null || _role != null) const SizedBox(height: AppConstants.spacing),

            // Adresse
            if (_participant!.street != null || _participant!.city != null)
              _buildSectionCard(
                'Adresse',
                Icons.home,
                [
                  if (_participant!.street != null) _buildInfoRow('Straße', _participant!.street!),
                  if (_participant!.postalCode != null || _participant!.city != null)
                    _buildInfoRow(
                      'Ort',
                      '${_participant!.postalCode ?? ''} ${_participant!.city ?? ''}'.trim(),
                    ),
                ],
              ),
            if (_participant!.street != null || _participant!.city != null)
              const SizedBox(height: AppConstants.spacing),

            // Kontakt
            if (_participant!.email != null || _participant!.phone != null)
              _buildSectionCard(
                'Kontakt',
                Icons.contact_mail,
                [
                  if (_participant!.email != null) _buildInfoRow('E-Mail', _participant!.email!),
                  if (_participant!.phone != null) _buildInfoRow('Telefon', _participant!.phone!),
                ],
              ),
            if (_participant!.email != null || _participant!.phone != null)
              const SizedBox(height: AppConstants.spacing),

            // Notfallkontakt
            if (_participant!.emergencyContactName != null ||
                _participant!.emergencyContactPhone != null)
              _buildSectionCard(
                'Notfallkontakt',
                Icons.emergency,
                [
                  if (_participant!.emergencyContactName != null)
                    _buildInfoRow('Name', _participant!.emergencyContactName!),
                  if (_participant!.emergencyContactPhone != null)
                    _buildInfoRow('Telefon', _participant!.emergencyContactPhone!),
                ],
              ),
            if (_participant!.emergencyContactName != null ||
                _participant!.emergencyContactPhone != null)
              const SizedBox(height: AppConstants.spacing),

            // Preisinformationen
            _buildPriceCard(totalPrice),
            const SizedBox(height: AppConstants.spacing),

            // Zahlungen
            _buildPaymentsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, double outstanding) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PaymentFormScreen(
                        preselectedParticipantId: widget.participantId,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadData(); // Daten neu laden nach Zahlung
                  }
                },
                icon: const Icon(Icons.payments),
                label: const Text('Zahlung erfassen'),
              ),
            ),
            const SizedBox(width: AppConstants.spacing),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _downloadInvoice,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(_family != null ? 'Familienrechnung' : 'Rechnung'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusCard(double totalPrice, double totalPaid, double outstanding) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (outstanding <= 0) {
      statusColor = Colors.green;
      statusText = 'Vollständig bezahlt';
      statusIcon = Icons.check_circle;
    } else if (totalPaid > 0) {
      statusColor = Colors.orange;
      statusText = 'Teilweise bezahlt';
      statusIcon = Icons.schedule;
    } else {
      statusColor = Colors.red;
      statusText = 'Noch nicht bezahlt';
      statusIcon = Icons.error_outline;
    }

    return Card(
      elevation: 2,
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: AppConstants.spacing),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildPaymentRow('Gesamtpreis', totalPrice, fontWeight: FontWeight.bold),
            const SizedBox(height: 8),
            _buildPaymentRow('Bereits bezahlt', totalPaid, color: Colors.green),
            const SizedBox(height: 8),
            _buildPaymentRow(
              'Offener Betrag',
              outstanding,
              color: outstanding > 0 ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(
    String label,
    double amount, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: fontWeight,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} €',
          style: TextStyle(
            fontSize: 14,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppConstants.primaryColor),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(double totalPrice) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.euro, color: AppConstants.primaryColor),
                const SizedBox(width: AppConstants.spacingS),
                const Text(
                  'Preisinformationen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow(
              'Berechneter Preis',
              '${_participant!.calculatedPrice.toStringAsFixed(2)} €',
            ),
            if (_participant!.manualPriceOverride != null) ...[
              _buildInfoRow(
                'Manueller Preis',
                '${_participant!.manualPriceOverride!.toStringAsFixed(2)} €',
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Preis wurde manuell überschrieben',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: AppConstants.primaryColor),
                const SizedBox(width: AppConstants.spacingS),
                const Text(
                  'Zahlungen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            if (_payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Noch keine Zahlungen erfasst',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payments.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final payment = _payments[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      child: const Icon(Icons.check, color: Colors.green, size: 20),
                    ),
                    title: Text(
                      '${payment.amount.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      AppDateUtils.formatGerman(payment.paymentDate),
                    ),
                    trailing: payment.paymentMethod != null
                        ? Chip(
                            label: Text(
                              payment.paymentMethod!,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
