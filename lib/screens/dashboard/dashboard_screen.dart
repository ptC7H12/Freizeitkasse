import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/subsidy_provider.dart';
import '../../data/database/app_database.dart';
import '../../utils/constants.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../widgets/common/common_widgets.dart';
import '../../extensions/context_extensions.dart';

/// Dashboard Screen
///
/// Hauptübersicht mit Statistiken und Schnellzugriff auf alle Funktionen
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);

    if (currentEvent == null) {
      // Sollte nicht passieren, aber als Fallback
      return const Scaffold(
        body: Center(
          child: Text('Kein Event ausgewählt'),
        ),
      );
    }

    return ResponsiveScaffold(
      title: 'Dashboard',
      selectedIndex: 0,
      body: _buildDashboardContent(context, ref, currentEvent),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    Event currentEvent,
  ) {
    final database = ref.watch(databaseProvider);
    final eventId = currentEvent.id;

    // Responsive Layout
    final isDesktop = context.isDesktop;

    return SingleChildScrollView(
      padding: AppConstants.paddingAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== FINANZÜBERSICHT ==========
          SectionHeader.large(
            title: 'Finanzübersicht',
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: AppConstants.spacing),

          Card(
            elevation: 2,
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === EINNAHMEN ===
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: AppConstants.successColor, size: 24),
                      const SizedBox(width: AppConstants.spacingS),
                      const Text(
                        'Einnahmen',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  // === EINNAHMEN-ÜBERSICHT ===
                  Consumer(
                    builder: (context, ref, child) {
                      final expectedSubsidiesAsync = ref.watch(expectedSubsidiesProvider);

                      return StreamBuilder<List<Participant>>(
                        stream: (database.select(database.participants)
                              ..where((tbl) => tbl.eventId.equals(eventId))
                              ..where((tbl) => tbl.isActive.equals(true)))
                            .watch(),
                        builder: (context, participantSnapshot) {
                          final participants = participantSnapshot.data ?? [];
                          final sollEinnahmenTeilnehmer = participants.fold<double>(
                            0.0,
                            (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
                          );

                          return expectedSubsidiesAsync.when(
                            data: (sollSonstigeEinnahmen) {
                              return StreamBuilder<List<Income>>(
                                stream: (database.select(database.incomes)
                                      ..where((tbl) => tbl.eventId.equals(eventId))
                                      ..where((tbl) => tbl.isActive.equals(true)))
                                    .watch(),
                                builder: (context, incomeSnapshot) {
                                  return StreamBuilder<List<Payment>>(
                            stream: (database.select(database.payments)
                                  ..where((tbl) => tbl.eventId.equals(eventId))
                                  ..where((tbl) => tbl.isActive.equals(true)))
                                .watch(),
                            builder: (context, paymentSnapshot) {
                              final payments = paymentSnapshot.data ?? [];
                              final istEinnahmenZahlungen = payments.fold<double>(
                                0.0,
                                (sum, payment) => sum + payment.amount,
                              );

                              final sollEinnahmenGesamt = sollEinnahmenTeilnehmer + sollSonstigeEinnahmen;
                              final istEinnahmenGesamt = istEinnahmenZahlungen + sollSonstigeEinnahmen;

                              return isDesktop
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: FinanceCard(
                                            label: 'Soll Einnahmen (Gesamt)',
                                            amount: sollEinnahmenGesamt,
                                            color: AppConstants.successColor,
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: FinanceCard(
                                            label: 'Soll Zahlungseingänge',
                                            amount: sollEinnahmenTeilnehmer,
                                            subtitle: 'durch Teilnahmegebühren',
                                            color: AppConstants.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: FinanceCard(
                                            label: 'Soll Sonstige Einnahmen',
                                            amount: sollSonstigeEinnahmen,
                                            subtitle: 'durch Zuschüsse',
                                            color: AppConstants.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: FinanceCard(
                                            label: 'Ist Einnahmen (Gesamt)',
                                            amount: istEinnahmenGesamt,
                                            subtitle: 'durch Zahlungen + Sonstige',
                                            color: AppConstants.successColor,
                                            isBold: true,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        FinanceCard(
                                          label: 'Soll Einnahmen (Gesamt)',
                                          amount: sollEinnahmenGesamt,
                                          color: AppConstants.successColor,
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        FinanceCard(
                                          label: 'Soll Zahlungseingänge',
                                          amount: sollEinnahmenTeilnehmer,
                                          subtitle: 'durch Teilnahmegebühren',
                                          color: AppConstants.primaryColor,
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        FinanceCard(
                                          label: 'Soll Sonstige Einnahmen',
                                          amount: sollSonstigeEinnahmen,
                                          subtitle: 'durch Zuschüsse',
                                          color: AppConstants.primaryColor,
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        FinanceCard(
                                          label: 'Ist Einnahmen (Gesamt)',
                                          amount: istEinnahmenGesamt,
                                          subtitle: 'durch Zahlungen + Sonstige',
                                          color: AppConstants.successColor,
                                          isBold: true,
                                        ),
                                      ],
                                    );
                                      },
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (error, stack) {
                                // Fehler beim Laden der erwarteten Zuschüsse
                                // Fallback: 0.0
                                const sollSonstigeEinnahmen = 0.0;

                                return StreamBuilder<List<Income>>(
                                  stream: (database.select(database.incomes)
                                        ..where((tbl) => tbl.eventId.equals(eventId))
                                        ..where((tbl) => tbl.isActive.equals(true)))
                                      .watch(),
                                  builder: (context, incomeSnapshot) {
                                    return StreamBuilder<List<Payment>>(
                                      stream: (database.select(database.payments)
                                            ..where((tbl) => tbl.eventId.equals(eventId))
                                            ..where((tbl) => tbl.isActive.equals(true)))
                                          .watch(),
                                      builder: (context, paymentSnapshot) {
                                        final payments = paymentSnapshot.data ?? [];
                                        final istEinnahmenZahlungen = payments.fold<double>(
                                          0.0,
                                          (sum, payment) => sum + payment.amount,
                                        );

                                        final sollEinnahmenGesamt = sollEinnahmenTeilnehmer + sollSonstigeEinnahmen;
                                        final istEinnahmenGesamt = istEinnahmenZahlungen + sollSonstigeEinnahmen;

                                        return const Text('Fehler beim Laden der Zuschüsse');
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                  const Divider(height: 32),

                  // === AUSGABEN ===
                  Row(
                    children: [
                      Icon(Icons.trending_down, color: AppConstants.dangerColor, size: 24),
                      const SizedBox(width: AppConstants.spacingS),
                      const Text(
                        'Ausgaben',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  StreamBuilder<List<Expense>>(
                    stream: (database.select(database.expenses)
                          ..where((tbl) => tbl.eventId.equals(eventId))
                          ..where((tbl) => tbl.isActive.equals(true)))
                        .watch(),
                    builder: (context, expenseSnapshot) {
                      final expenses = expenseSnapshot.data ?? [];
                      final sollAusgabenGesamt = expenses.fold<double>(
                        0.0,
                        (sum, expense) => sum + expense.amount,
                      );
                      // TODO: Später mit Status-Feld erweitern
                      final beglicheneAusgaben = sollAusgabenGesamt;

                      return isDesktop
                          ? Row(
                              children: [
                                Expanded(
                                  child: FinanceCard(
                                    label: 'Soll Ausgaben (Gesamt)',
                                    amount: sollAusgabenGesamt,
                                    color: AppConstants.dangerColor,
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacing),
                                Expanded(
                                  child: FinanceCard(
                                    label: 'Beglichene Ausgaben',
                                    amount: beglicheneAusgaben,
                                    color: AppConstants.dangerColor,
                                    isBold: true,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                FinanceCard(
                                  label: 'Soll Ausgaben (Gesamt)',
                                  amount: sollAusgabenGesamt,
                                  color: AppConstants.dangerColor,
                                ),
                                const SizedBox(height: AppConstants.spacingS),
                                FinanceCard(
                                  label: 'Beglichene Ausgaben',
                                  amount: beglicheneAusgaben,
                                  color: AppConstants.dangerColor,
                                  isBold: true,
                                ),
                              ],
                            );
                    },
                  ),

                  const Divider(height: 32),

                  // === SALDO ===
                  Row(
                    children: [
                      Icon(Icons.account_balance, color: AppConstants.warningColor, size: 24),
                      const SizedBox(width: AppConstants.spacingS),
                      const Text(
                        'Saldo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  StreamBuilder<List<Participant>>(
                    stream: (database.select(database.participants)
                          ..where((tbl) => tbl.eventId.equals(eventId))
                          ..where((tbl) => tbl.isActive.equals(true)))
                        .watch(),
                    builder: (context, participantSnapshot) {
                      final participants = participantSnapshot.data ?? [];
                      final sollEinnahmenTeilnehmer = participants.fold<double>(
                        0.0,
                        (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
                      );

                      return StreamBuilder<List<Income>>(
                        stream: (database.select(database.incomes)
                              ..where((tbl) => tbl.eventId.equals(eventId))
                              ..where((tbl) => tbl.isActive.equals(true)))
                            .watch(),
                        builder: (context, incomeSnapshot) {
                          final incomes = incomeSnapshot.data ?? [];
                          final istSonstigeEinnahmen = incomes.fold<double>(
                            0.0,
                            (sum, income) => sum + income.amount,
                          );

                          return StreamBuilder<List<Expense>>(
                            stream: (database.select(database.expenses)
                                  ..where((tbl) => tbl.eventId.equals(eventId))
                                  ..where((tbl) => tbl.isActive.equals(true)))
                                .watch(),
                            builder: (context, expenseSnapshot) {
                              final expenses = expenseSnapshot.data ?? [];
                              final sollAusgabenGesamt = expenses.fold<double>(
                                0.0,
                                (sum, expense) => sum + expense.amount,
                              );

                              // Formel: Soll Einnahmen (Gesamt) + Ist Einnahmen Sonstige - Soll Ausgaben (Gesamt)
                              final sollEinnahmenGesamt = sollEinnahmenTeilnehmer + istSonstigeEinnahmen;
                              final saldo = sollEinnahmenGesamt + istSonstigeEinnahmen - sollAusgabenGesamt;

                              return _buildSaldoCard(
                                context,
                                saldo,
                                'Soll Einnahmen (Gesamt) + Ist Sonstige Einnahmen - Soll Ausgaben (Gesamt)',
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// Saldo Card (highlighted)
  Widget _buildSaldoCard(
    BuildContext context,
    double saldo,
    String formula,
  ) {
    final isPositive = saldo >= 0;
    final color = isPositive ? AppConstants.successColor : AppConstants.dangerColor;

    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppConstants.borderRadius12,
        border: Border.all(color: color, width: 3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo (Gesamt)',
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(locale: 'de_DE', symbol: '€').format(saldo),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formula,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 48,
          ),
        ],
      ),
    );
  }
}
