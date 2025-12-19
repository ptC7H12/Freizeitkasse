import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/payment_provider.dart';
import '../../providers/participant_provider.dart';
import '../../providers/family_provider.dart';
import '../../utils/date_utils.dart';
import 'payment_form_screen.dart';
import '../../utils/constants.dart';
import '../../widgets/responsive_scaffold.dart';

/// Payments List Screen
class PaymentsListScreen extends ConsumerWidget {
  const PaymentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider);
    final participantsAsync = ref.watch(participantsProvider);
    final familiesAsync = ref.watch(familiesProvider);

    return ResponsiveScaffold(
      title: 'Zahlungseingänge',
      selectedIndex: 3,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.pushScreen(const PaymentFormScreen());
        },
        icon: const Icon(Icons.add),
        label: const Text('Zahlung'),
      ),
      body: paymentsAsync.when(
        data: (payments) {
          // Berechne Statistiken
          final zahlungGesamt = payments.length;
          final gesamtbetrag = payments.fold<double>(
            0.0,
            (sum, payment) => sum + payment.amount,
          );

          return Column(
            children: [
              // Statistik-Header
              participantsAsync.when(
                data: (participants) {
                  final erwarteteEinnahme = participants.fold<double>(
                    0.0,
                    (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
                  );
                  final ausstehend = erwarteteEinnahme - gesamtbetrag;

                  return _buildStatsHeader(
                    context,
                    zahlungGesamt,
                    gesamtbetrag,
                    erwarteteEinnahme,
                    ausstehend,
                  );
                },
                loading: () => _buildStatsHeaderLoading(context, zahlungGesamt, gesamtbetrag),
                error: (_, _) => _buildStatsHeaderLoading(context, zahlungGesamt, gesamtbetrag),
              ),

              // Zahlungsliste
              Expanded(
                child: payments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 100, color: Colors.grey),
                            SizedBox(height: 24),
                            Text(
                              'Noch keine Zahlungen',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Erfasse die erste Zahlung.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : participantsAsync.when(
                        data: (participants) => familiesAsync.when(
                          data: (families) => ListView.builder(
                            padding: AppConstants.paddingAll16,
                            itemCount: payments.length,
                            itemBuilder: (context, index) {
                              final payment = payments[index];

                              // Bestimme, wer gezahlt hat (Teilnehmer oder Familie)
                              String payerName = 'Unbekannt';
                              IconData payerIcon = Icons.person;
                              Color payerColor = Colors.grey;

                              if (payment.participantId != null) {
                                // Zahlung von Einzelperson
                                try {
                                  final participant = participants.firstWhere(
                                    (p) => p.id == payment.participantId,
                                  );
                                  payerName = '${participant.firstName} ${participant.lastName}';
                                  payerIcon = Icons.person;
                                  payerColor = Colors.blue;
                                } catch (e) {
                                  payerName = 'Teilnehmer (ID: ${payment.participantId})';
                                }
                              } else if (payment.familyId != null) {
                                // Zahlung von Familie
                                try {
                                  final family = families.firstWhere(
                                    (f) => f.id == payment.familyId,
                                  );
                                  payerName = family.familyName;
                                  payerIcon = Icons.family_restroom;
                                  payerColor = Colors.purple;
                                } catch (e) {
                                  payerName = 'Familie (ID: ${payment.familyId})';
                                  payerIcon = Icons.family_restroom;
                                  payerColor = Colors.purple;
                                }
                              }

                              return Card(
                                margin: EdgeInsets.only(bottom: AppConstants.spacingM),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: Icon(Icons.euro, color: Colors.green.shade700),
                                  ),
                                  title: Text(
                                    '${payment.amount.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(payerIcon, size: 14, color: payerColor),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              payerName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: payerColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(AppDateUtils.formatGerman(payment.paymentDate)),
                                      if (payment.paymentMethod != null)
                                        Text('Methode: ${payment.paymentMethod}'),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    context.pushScreen(
                                      PaymentFormScreen(
                                        paymentId: payment.id,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, _) => const Center(child: Text('Fehler beim Laden der Familien')),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, _) => const Center(child: Text('Fehler beim Laden der Teilnehmer')),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Fehler: $error')),
      ),
    );
  }

  /// Statistik-Header mit allen Informationen
  Widget _buildStatsHeader(
    BuildContext context,
    int zahlungGesamt,
    double gesamtbetrag,
    double erwarteteEinnahme,
    double ausstehend,
  ) {
    final currencyFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');

    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments, color: Color(0xFF2196F3), size: 24),
              SizedBox(width: AppConstants.spacingS),
              Text(
                'Übersicht',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing),
          Row(
            children: [
              // Zahlung gesamt
              Expanded(
                child: _buildStatCard(
                  context,
                  'Zahlungen gesamt',
                  zahlungGesamt.toString(),
                  Icons.receipt_long,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: AppConstants.spacing),
              // Gesamtbetrag
              Expanded(
                child: _buildStatCard(
                  context,
                  'Gesamtbetrag',
                  currencyFormat.format(gesamtbetrag),
                  Icons.euro,
                  const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing),
          // Erwartete Einnahme mit Info
          _buildExpectedIncomeCard(
            context,
            erwarteteEinnahme,
            ausstehend,
          ),
        ],
      ),
    );
  }

  /// Statistik-Header während des Ladens (ohne erwartete Einnahme)
  Widget _buildStatsHeaderLoading(
    BuildContext context,
    int zahlungGesamt,
    double gesamtbetrag,
  ) {
    final currencyFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');

    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments, color: Color(0xFF2196F3), size: 24),
              SizedBox(width: AppConstants.spacingS),
              Text(
                'Übersicht',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Zahlungen gesamt',
                  zahlungGesamt.toString(),
                  Icons.receipt_long,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: AppConstants.spacing),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Gesamtbetrag',
                  currencyFormat.format(gesamtbetrag),
                  Icons.euro,
                  const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kleine Statistik-Karte
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppConstants.borderRadius8,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Erwartete Einnahme Karte mit Ausstehend-Info
  Widget _buildExpectedIncomeCard(
    BuildContext context,
    double erwarteteEinnahme,
    double ausstehend,
  ) {
    final currencyFormat = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final isComplete = ausstehend <= 0;

    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppConstants.borderRadius8,
        border: Border.all(
          color: isComplete
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : const Color(0xFFFF9800).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: isComplete ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                      size: 20,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    const Text(
                      'Erwartete Einnahme',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  currencyFormat.format(erwarteteEinnahme),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacing),
          // Ausstehend Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                  : const Color(0xFFFF9800).withValues(alpha: 0.1),
              borderRadius: AppConstants.borderRadius8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isComplete ? 'Vollständig' : 'Ausstehend',
                  style: TextStyle(
                    fontSize: 10,
                    color: isComplete ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat.format(ausstehend.abs()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
