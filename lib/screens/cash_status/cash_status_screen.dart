import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/participant_provider.dart';
import '../../providers/pdf_export_provider.dart';
import '../../data/database/app_database.dart';
import '../../utils/constants.dart';
import '../../extensions/context_extensions.dart';

class CashStatusScreen extends ConsumerStatefulWidget {
  const CashStatusScreen({super.key});

  @override
  ConsumerState<CashStatusScreen> createState() => _CashStatusScreenState();
}

class _CashStatusScreenState extends ConsumerState<CashStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEvent = ref.watch(currentEventProvider);
    final database = ref.watch(databaseProvider);

    if (currentEvent == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kassenstand'),
        ),
        body: const Center(
          child: Text('Bitte wählen Sie zuerst eine Veranstaltung aus.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kassenstand'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final pdfService = ref.read(pdfExportServiceProvider);
              final payments = await (database.select(database.payments)
                    ..where((t) => t.eventId.equals(currentEvent.id))
                    ..where((t) => t.isActive.equals(true)))
                  .get();
              final totalPayments = payments.fold<double>(0, (sum, p) => sum + p.amount);

              final totalIncomes = await ref.read(totalIncomesProvider.future);
              final totalExpenses = await ref.read(totalExpensesProvider.future);
              final expensesByCategory = await ref.read(expensesByCategoryProvider.future);
              final incomesBySource = await ref.read(incomesBySourceProvider.future);

              try {
                final filePath = await pdfService.exportFinancialReport(
                  eventName: currentEvent.name,
                  totalIncomes: totalIncomes,
                  totalExpenses: totalExpenses,
                  totalPayments: totalPayments,
                  expensesByCategory: expensesByCategory,
                  incomesBySource: incomesBySource,
                );

                if (context.mounted) {
                  context.showError('PDF gespeichert: $filePath');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showError('Fehler beim Export: $e');
                }
              }
            },
            tooltip: 'PDF Export',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Übersicht'),
            Tab(icon: Icon(Icons.history), text: 'Transaktionen'),
            Tab(icon: Icon(Icons.card_giftcard), text: 'Zuschüsse'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Übersicht
          _buildOverviewTab(context, ref, database, currentEvent.id),
          // Tab 2: Transaktionshistorie
          _buildTransactionsTab(context, ref, database, currentEvent.id),
          // Tab 3: Zuschüsse
          _buildSubsidiesTab(context, ref, database, currentEvent.id),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, WidgetRef ref, int eventId) {
    final totalIncomesAsync = ref.watch(totalIncomesProvider);
    final totalExpensesAsync = ref.watch(totalExpensesProvider);
    final database = ref.watch(databaseProvider);

    return Card(
      child: Padding(
        padding: AppConstants.paddingAll24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finanzübersicht',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Row(
              children: [
                Expanded(
                  child: totalIncomesAsync.when(
                    data: (totalIncomes) => _buildSummaryItem(
                      context,
                      'Einnahmen',
                      totalIncomes,
                      Colors.green,
                      Icons.trending_up,
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Fehler'),
                  ),
                ),
                const SizedBox(width: AppConstants.spacing),
                Expanded(
                  child: totalExpensesAsync.when(
                    data: (totalExpenses) => _buildSummaryItem(
                      context,
                      'Ausgaben',
                      totalExpenses,
                      Colors.red,
                      Icons.trending_down,
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Fehler'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            const Divider(),
            const SizedBox(height: AppConstants.spacing),
            StreamBuilder<List<Payment>>(
              stream: (database.select(database.payments)
                    ..where((tbl) => tbl.eventId.equals(eventId))
                    ..where((tbl) => tbl.isActive.equals(true)))
                  .watch(),
              builder: (context, snapshot) {
                final payments = snapshot.data ?? [];
                final totalPayments = payments.fold<double>(
                  0.0,
                  (sum, payment) => sum + payment.amount,
                );

                return totalIncomesAsync.when(
                  data: (totalIncomes) => totalExpensesAsync.when(
                    data: (totalExpenses) {
                      final balance = totalIncomes - totalExpenses;
                      final outstanding = totalPayments - totalIncomes;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  context,
                                  'Kassenstand',
                                  balance,
                                  balance >= 0 ? Colors.teal : Colors.deepOrange,
                                  Icons.account_balance_wallet,
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacing),
                              Expanded(
                                child: _buildSummaryItem(
                                  context,
                                  'Zahlungen',
                                  totalPayments,
                                  Colors.blue,
                                  Icons.payment,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacing),
                          if (outstanding > 0)
                            Container(
                              padding: AppConstants.paddingAll12,
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.orange[700]),
                                  const SizedBox(width: AppConstants.spacingM),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ausstehende Zahlungen',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange[900],
                                          ),
                                        ),
                                        Text(
                                          NumberFormat.currency(locale: 'de_DE', symbol: '€')
                                              .format(outstanding),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Fehler'),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, _) => const Text('Fehler'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    double value,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppConstants.spacingS),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          NumberFormat.currency(locale: 'de_DE', symbol: '€').format(value),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildIncomeExpenseChart(BuildContext context, WidgetRef ref, int eventId) {
    final totalIncomesAsync = ref.watch(totalIncomesProvider);
    final totalExpensesAsync = ref.watch(totalExpensesProvider);

    return Card(
      child: Padding(
        padding: AppConstants.paddingAll24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Einnahmen vs. Ausgaben',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: 200,
              child: totalIncomesAsync.when(
                data: (totalIncomes) => totalExpensesAsync.when(
                  data: (totalExpenses) {
                    if (totalIncomes == 0 && totalExpenses == 0) {
                      return Center(
                        child: Text(
                          'Noch keine Daten vorhanden',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    return BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (totalIncomes > totalExpenses ? totalIncomes : totalExpenses) * 1.2,
                        barTouchData: const BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                switch (value.toInt()) {
                                  case 0:
                                    return const Text('Einnahmen', style: TextStyle(fontSize: 12));
                                  case 1:
                                    return const Text('Ausgaben', style: TextStyle(fontSize: 12));
                                  default:
                                    return const Text('');
                                }
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}€',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: totalIncomes,
                                color: Colors.green,
                                width: 40,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: totalExpenses,
                                color: Colors.red,
                                width: 40,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Fehler')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Fehler')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseByCategoryChart(BuildContext context, WidgetRef ref, int eventId) {
    final expensesByCategoryAsync = ref.watch(expensesByCategoryProvider);

    return Card(
      child: Padding(
        padding: AppConstants.paddingAll24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ausgaben nach Kategorie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: 200,
              child: expensesByCategoryAsync.when(
                data: (byCategory) {
                  if (byCategory.isEmpty) {
                    return Center(
                      child: Text(
                        'Noch keine Ausgaben vorhanden',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  final total = byCategory.values.fold<double>(0, (sum, val) => sum + val);
                  final sections = byCategory.entries.map((entry) {
                    final percentage = (entry.value / total) * 100;
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: _getCategoryColor(entry.key),
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList();

                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: byCategory.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(entry.key),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spacingS),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Fehler')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeBySourceChart(BuildContext context, WidgetRef ref, int eventId) {
    final incomesBySourceAsync = ref.watch(incomesBySourceProvider);

    return Card(
      child: Padding(
        padding: AppConstants.paddingAll24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Einnahmen nach Quelle',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: 200,
              child: incomesBySourceAsync.when(
                data: (bySource) {
                  if (bySource.isEmpty) {
                    return Center(
                      child: Text(
                        'Noch keine Einnahmen vorhanden',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  final total = bySource.values.fold<double>(0, (sum, val) => sum + val);
                  final sections = bySource.entries.map((entry) {
                    final percentage = (entry.value / total) * 100;
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: _getSourceColor(entry.key),
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList();

                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: bySource.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getSourceColor(entry.key),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spacingS),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Fehler')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedBreakdown(
    BuildContext context,
    WidgetRef ref,
    AppDatabase database,
    int eventId,
  ) {
    return Card(
      child: Padding(
        padding: AppConstants.paddingAll24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detaillierte Aufschlüsselung',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppConstants.spacing),
            _buildDetailedSection(context, ref, 'Ausgaben nach Kategorie', expensesByCategoryProvider),
            const Divider(height: 32),
            _buildDetailedSection(context, ref, 'Einnahmen nach Quelle', incomesBySourceProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    ProviderListenable<AsyncValue<Map<String, double>>> provider,
  ) {
    final dataAsync = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        dataAsync.when(
          data: (data) {
            if (data.isEmpty) {
              return Text(
                'Keine Daten vorhanden',
                style: TextStyle(color: Colors.grey[600]),
              );
            }

            return Column(
              children: data.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(entry.key),
                      ),
                      Text(
                        NumberFormat.currency(locale: 'de_DE', symbol: '€').format(entry.value),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Fehler beim Laden'),
        ),
      ],
    );
  }

  // ========== TAB 1: ÜBERSICHT ==========
  Widget _buildOverviewTab(BuildContext context, WidgetRef ref, AppDatabase database, int eventId) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // Bereich 1: SOLL-Werte
        _buildSectionCard(
          context,
          'Zu erwartende Werte (SOLL)',
          Icons.request_quote,
          const Color(0xFF2196F3),
          _buildSollSection(context, ref, database, eventId),
        ),
        const SizedBox(height: AppConstants.spacing),

        // Bereich 2: IST-Werte
        _buildSectionCard(
          context,
          'Getätigte Zahlungen (IST) - Aktueller Stand',
          Icons.check_circle,
          const Color(0xFF4CAF50),
          _buildIstSection(context, ref, database, eventId),
        ),
        const SizedBox(height: AppConstants.spacing),

        // Bereich 3: DIFFERENZEN
        _buildSectionCard(
          context,
          'Differenzen (SOLL - IST)',
          Icons.compare_arrows,
          const Color(0xFFFF9800),
          _buildDifferenzenSection(context, ref, database, eventId),
        ),
        const SizedBox(height: AppConstants.spacing),

        // Bereich 4: Ausgaben nach Kategorie
        _buildExpensesByCategorySection(context, ref),
      ],
    );
  }

  // ========== TAB 2: TRANSAKTIONSHISTORIE ==========
  Widget _buildTransactionsTab(BuildContext context, WidgetRef ref, AppDatabase database, int eventId) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: const Color(0xFF2196F3), size: 24),
                    const SizedBox(width: AppConstants.spacingS),
                    const Text(
                      'Alle Transaktionen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                const Text('Transaktionshistorie wird in Kürze implementiert.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========== TAB 3: ZUSCHÜSSE ==========
  Widget _buildSubsidiesTab(BuildContext context, WidgetRef ref, AppDatabase database, int eventId) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.card_giftcard, color: const Color(0xFF4CAF50), size: 24),
                    const SizedBox(width: AppConstants.spacingS),
                    const Text(
                      'Zuschüsse nach Rolle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                const Text('Zuschüsse-Übersicht wird in Kürze implementiert.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========== HELPER METHODS ==========

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget child,
  ) {
    return Card(
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSollSection(BuildContext context, WidgetRef ref, AppDatabase database, int eventId) {
    return StreamBuilder<List<Participant>>(
      stream: (database.select(database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .watch(),
      builder: (context, participantSnapshot) {
        final participants = participantSnapshot.data ?? [];
        final einnahmenTeilnehmer = participants.fold<double>(
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
            final sonstigeEinnahmen = incomes.fold<double>(
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
                final ausgaben = expenses.fold<double>(
                  0.0,
                  (sum, expense) => sum + expense.amount,
                );

                final saldo = einnahmenTeilnehmer + sonstigeEinnahmen - ausgaben;

                return Column(
                  children: [
                    _buildStatRow(
                      context,
                      'Einnahmen (Teilnehmer)',
                      einnahmenTeilnehmer,
                      'Teilnahmegebühren',
                      const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                    _buildStatRow(
                      context,
                      'Sonstige Einnahmen',
                      sonstigeEinnahmen,
                      'Zuschüsse',
                      const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                    _buildStatRow(
                      context,
                      'Ausgaben',
                      ausgaben,
                      null,
                      const Color(0xFFE91E63),
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      context,
                      'Saldo',
                      saldo,
                      null,
                      saldo >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFE91E63),
                      isBold: true,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIstSection(BuildContext context, WidgetRef ref, AppDatabase database, int eventId) {
    return StreamBuilder<List<Payment>>(
      stream: (database.select(database.payments)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .watch(),
      builder: (context, paymentSnapshot) {
        final payments = paymentSnapshot.data ?? [];
        final einnahmenTeilnehmer = payments.fold<double>(
          0.0,
          (sum, payment) => sum + payment.amount,
        );

        return StreamBuilder<List<Income>>(
          stream: (database.select(database.incomes)
                ..where((tbl) => tbl.eventId.equals(eventId))
                ..where((tbl) => tbl.isActive.equals(true)))
              .watch(),
          builder: (context, incomeSnapshot) {
            final incomes = incomeSnapshot.data ?? [];
            final sonstigeEinnahmen = incomes.fold<double>(
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
                final beglicheneAusgaben = expenses
                    .where((e) => e.reimbursed)
                    .fold<double>(0.0, (sum, expense) => sum + expense.amount);

                final saldo = einnahmenTeilnehmer + sonstigeEinnahmen - beglicheneAusgaben;

                return Column(
                  children: [
                    _buildStatRow(
                      context,
                      'Einnahmen (Teilnehmer)',
                      einnahmenTeilnehmer,
                      null,
                      const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                    _buildStatRow(
                      context,
                      'Sonstige Einnahmen',
                      sonstigeEinnahmen,
                      null,
                      const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                    _buildStatRow(
                      context,
                      'Ausgaben (Beglichene)',
                      beglicheneAusgaben,
                      null,
                      const Color(0xFFE91E63),
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      context,
                      'Saldo',
                      saldo,
                      null,
                      saldo >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFE91E63),
                      isBold: true,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDifferenzenSection(BuildContext context, WidgetRef ref, AppDatabase database, int eventId) {
    return StreamBuilder<List<Participant>>(
      stream: (database.select(database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .watch(),
      builder: (context, participantSnapshot) {
        final participants = participantSnapshot.data ?? [];
        final sollEinnahmenTN = participants.fold<double>(
          0.0,
          (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
        );

        return StreamBuilder<List<Payment>>(
          stream: (database.select(database.payments)
                ..where((tbl) => tbl.eventId.equals(eventId))
                ..where((tbl) => tbl.isActive.equals(true)))
              .watch(),
          builder: (context, paymentSnapshot) {
            final payments = paymentSnapshot.data ?? [];
            final istEinnahmenTN = payments.fold<double>(
              0.0,
              (sum, payment) => sum + payment.amount,
            );

            return StreamBuilder<List<Income>>(
              stream: (database.select(database.incomes)
                    ..where((tbl) => tbl.eventId.equals(eventId))
                    ..where((tbl) => tbl.isActive.equals(true)))
                  .watch(),
              builder: (context, incomeSnapshot) {
                final incomes = incomeSnapshot.data ?? [];
                final sonstigeEinnahmen = incomes.fold<double>(0.0, (sum, income) => sum + income.amount);

                return StreamBuilder<List<Expense>>(
                  stream: (database.select(database.expenses)
                        ..where((tbl) => tbl.eventId.equals(eventId))
                        ..where((tbl) => tbl.isActive.equals(true)))
                      .watch(),
                  builder: (context, expenseSnapshot) {
                    final expenses = expenseSnapshot.data ?? [];
                    final sollAusgaben = expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
                    final beglicheneAusgaben = expenses
                        .where((e) => e.reimbursed)
                        .fold<double>(0.0, (sum, expense) => sum + expense.amount);

                    final einnahmenAusstehend = sollEinnahmenTN - istEinnahmenTN;
                    final ausgabenZuBegleichen = sollAusgaben - beglicheneAusgaben;
                    final sollSaldo = sollEinnahmenTN + sonstigeEinnahmen - sollAusgaben;
                    final istSaldo = istEinnahmenTN + sonstigeEinnahmen - beglicheneAusgaben;
                    final saldoDiff = sollSaldo - istSaldo;

                    return Column(
                      children: [
                        _buildStatRow(
                          context,
                          'Einnahmen (ausstehend)',
                          einnahmenAusstehend,
                          null,
                          einnahmenAusstehend > 0 ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        _buildStatRow(
                          context,
                          'Sonstige Einnahmen',
                          0.0,
                          'bereits vollständig',
                          const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        _buildStatRow(
                          context,
                          'Ausgaben (noch zu begleichen)',
                          ausgabenZuBegleichen,
                          null,
                          ausgabenZuBegleichen > 0 ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
                        ),
                        const Divider(height: 24),
                        _buildStatRow(
                          context,
                          'Saldo',
                          saldoDiff,
                          null,
                          saldoDiff >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                          isBold: true,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExpensesByCategorySection(BuildContext context, WidgetRef ref) {
    final expensesByCategoryAsync = ref.watch(expensesByCategoryProvider);

    return Card(
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: const Color(0xFFE91E63), size: 24),
                const SizedBox(width: AppConstants.spacingS),
                const Text(
                  'Ausgaben nach Kategorie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            expensesByCategoryAsync.when(
              data: (byCategory) {
                if (byCategory.isEmpty) {
                  return const Text(
                    'Keine Ausgaben vorhanden',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return DataTable(
                  columns: const [
                    DataColumn(label: Text('Kategorie', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Anzahl', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Betrag', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: byCategory.entries.map((entry) {
                    // Count basierend auf dem Betrag / durchschnittlicher Ausgabe - vereinfacht
                    return DataRow(cells: [
                      DataCell(Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(entry.key),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      )),
                      DataCell(Text('-')), // Anzahl könnte aus einer anderen Query kommen
                      DataCell(Text(
                        NumberFormat.currency(locale: 'de_DE', symbol: '€').format(entry.value),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                    ]);
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Fehler beim Laden'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    double value,
    String? subtitle,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isBold ? 16 : 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: Colors.grey[700],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          NumberFormat.currency(locale: 'de_DE', symbol: '€').format(value),
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'verpflegung':
        return Colors.orange;
      case 'unterkunft':
        return Colors.blue;
      case 'transport':
        return Colors.green;
      case 'material':
        return Colors.purple;
      case 'personal':
        return Colors.teal;
      case 'versicherung':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'teilnehmerbeitrag':
        return Colors.blue;
      case 'spende':
        return Colors.pink;
      case 'zuschuss':
        return Colors.green;
      case 'sponsoring':
        return Colors.purple;
      case 'merchandise':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }
}
