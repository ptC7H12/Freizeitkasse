import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/subsidy_provider.dart';
import '../../data/database/app_database.dart';
import '../../utils/constants.dart';
import '../../widgets/responsive_scaffold.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return SingleChildScrollView(
      padding: AppConstants.paddingAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== FINANZÜBERSICHT ==========
          _buildSectionHeader(context, Icons.account_balance_wallet, 'Finanzübersicht'),
          const SizedBox(height: AppConstants.spacing),

          Card(
            elevation: 2,
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === EINNAHMEN ===
                  const Row(
                    children: [
                      Icon(Icons.trending_up, color: Color(0xFF4CAF50), size: 24),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
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
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Soll Einnahmen (Gesamt)',
                                            sollEinnahmenGesamt,
                                            null,
                                            const Color(0xFF4CAF50),
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Soll Zahlungseingänge',
                                            sollEinnahmenTeilnehmer,
                                            'durch Teilnahmegebühren',
                                            const Color(0xFF2196F3),
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Soll Sonstige Einnahmen',
                                            sollSonstigeEinnahmen,
                                            'durch Zuschüsse',
                                            const Color(0xFF2196F3),
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Ist Einnahmen (Gesamt)',
                                            istEinnahmenGesamt,
                                            'durch Zahlungen + Sonstige',
                                            const Color(0xFF4CAF50),
                                            isBold: true,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _buildFinanceDetailCard(
                                          context,
                                          'Soll Einnahmen (Gesamt)',
                                          sollEinnahmenGesamt,
                                          null,
                                          const Color(0xFF4CAF50),
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        _buildFinanceDetailCard(
                                          context,
                                          'Soll Zahlungseingänge',
                                          sollEinnahmenTeilnehmer,
                                          'durch Teilnahmegebühren',
                                          const Color(0xFF2196F3),
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        _buildFinanceDetailCard(
                                          context,
                                          'Soll Sonstige Einnahmen',
                                          sollSonstigeEinnahmen,
                                          'durch Zuschüsse',
                                          const Color(0xFF2196F3),
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        _buildFinanceDetailCard(
                                          context,
                                          'Ist Einnahmen (Gesamt)',
                                          istEinnahmenGesamt,
                                          'durch Zahlungen + Sonstige',
                                          const Color(0xFF4CAF50),
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
                  const Row(
                    children: [
                      Icon(Icons.trending_down, color: Color(0xFFE91E63), size: 24),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
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
                                  child: _buildFinanceDetailCard(
                                    context,
                                    'Soll Ausgaben (Gesamt)',
                                    sollAusgabenGesamt,
                                    null,
                                    const Color(0xFFE91E63),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacing),
                                Expanded(
                                  child: _buildFinanceDetailCard(
                                    context,
                                    'Beglichene Ausgaben',
                                    beglicheneAusgaben,
                                    null,
                                    const Color(0xFFE91E63),
                                    isBold: true,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildFinanceDetailCard(
                                  context,
                                  'Soll Ausgaben (Gesamt)',
                                  sollAusgabenGesamt,
                                  null,
                                  const Color(0xFFE91E63),
                                ),
                                const SizedBox(height: AppConstants.spacingS),
                                _buildFinanceDetailCard(
                                  context,
                                  'Beglichene Ausgaben',
                                  beglicheneAusgaben,
                                  null,
                                  const Color(0xFFE91E63),
                                  isBold: true,
                                ),
                              ],
                            );
                    },
                  ),

                  const Divider(height: 32),

                  // === SALDO ===
                  const Row(
                    children: [
                      Icon(Icons.account_balance, color: Color(0xFFFF9800), size: 24),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
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

  /// Section Header Widget
  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: AppConstants.paddingAll8,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: AppConstants.borderRadius8,
          ),
          child: Icon(icon, color: AppConstants.primaryColor, size: 24),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Finance Detail Card (for income/expense details)
  Widget _buildFinanceDetailCard(
    BuildContext context,
    String label,
    double amount,
    String? subtitle,
    Color color, {
    bool isBold = false,
  }) {
    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppConstants.borderRadius8,
        border: isBold ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(amount),
            style: TextStyle(
              fontSize: isBold ? 24 : 20,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
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
    final color = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE91E63);

    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
                    color: Colors.grey[600],
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
