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

// Unified Transaction class für Transaktionshistorie
class Transaction {
  final int id;
  final DateTime date;
  final String type; // 'Zahlung', 'Einnahme', 'Ausgabe'
  final String? reference;
  final String description;
  final String? participantOrFamily;
  final double amount; // Positive für Einnahmen, Negativ für Ausgaben
  final double runningBalance; // Laufender Saldo

  Transaction({
    required this.id,
    required this.date,
    required this.type,
    this.reference,
    required this.description,
    this.participantOrFamily,
    required this.amount,
    required this.runningBalance,
  });
}

class CashStatusScreen extends ConsumerStatefulWidget {
  const CashStatusScreen({super.key});

  @override
  ConsumerState<CashStatusScreen> createState() => _CashStatusScreenState();
}

class _CashStatusScreenState extends ConsumerState<CashStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filter für Transaktionshistorie
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    return StreamBuilder<List<Payment>>(
      stream: (database.select(database.payments)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .watch(),
      builder: (context, paymentSnapshot) {
        if (!paymentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<Income>>(
          stream: (database.select(database.incomes)
                ..where((tbl) => tbl.eventId.equals(eventId))
                ..where((tbl) => tbl.isActive.equals(true)))
              .watch(),
          builder: (context, incomeSnapshot) {
            if (!incomeSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<Expense>>(
              stream: (database.select(database.expenses)
                    ..where((tbl) => tbl.eventId.equals(eventId))
                    ..where((tbl) => tbl.isActive.equals(true)))
                  .watch(),
              builder: (context, expenseSnapshot) {
                if (!expenseSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<Participant>>(
                  stream: (database.select(database.participants)
                        ..where((tbl) => tbl.eventId.equals(eventId))
                        ..where((tbl) => tbl.isActive.equals(true)))
                      .watch(),
                  builder: (context, participantSnapshot) {
                    if (!participantSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return StreamBuilder<List<Family>>(
                      stream: (database.select(database.families)
                            ..where((tbl) => tbl.eventId.equals(eventId)))
                          .watch(),
                      builder: (context, familySnapshot) {
                        if (!familySnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        // Daten zusammenführen und Transaction-Objekte erstellen
                        final transactions = _buildTransactionList(
                          paymentSnapshot.data!,
                          incomeSnapshot.data!,
                          expenseSnapshot.data!,
                          participantSnapshot.data!,
                          familySnapshot.data!,
                        );

                        return _buildTransactionHistoryContent(context, transactions);
                      },
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

  List<Transaction> _buildTransactionList(
    List<Payment> payments,
    List<Income> incomes,
    List<Expense> expenses,
    List<Participant> participants,
    List<Family> families,
  ) {
    final List<Transaction> transactions = [];

    // Helper: Finde Teilnehmer-Name
    String? getParticipantName(int? participantId) {
      if (participantId == null) return null;
      final participant = participants.firstWhere(
        (p) => p.id == participantId,
        orElse: () => participants.first,
      );
      return '${participant.firstName} ${participant.lastName}';
    }

    // Helper: Finde Familien-Name
    String? getFamilyName(int? familyId) {
      if (familyId == null) return null;
      final family = families.firstWhere(
        (f) => f.id == familyId,
        orElse: () => families.first,
      );
      return family.familyName;
    }

    // 1. Zahlungseingänge hinzufügen (positive Beträge)
    for (final payment in payments) {
      String? participantOrFamily;
      if (payment.participantId != null) {
        participantOrFamily = getParticipantName(payment.participantId);
      } else if (payment.familyId != null) {
        participantOrFamily = 'Familie ${getFamilyName(payment.familyId)}';
      }

      transactions.add(Transaction(
        id: payment.id,
        date: payment.paymentDate,
        type: 'Zahlung',
        reference: payment.referenceNumber,
        description: payment.notes ?? payment.paymentMethod ?? 'Zahlung',
        participantOrFamily: participantOrFamily,
        amount: payment.amount,
        runningBalance: 0, // Wird später berechnet
      ));
    }

    // 2. Sonstige Einnahmen hinzufügen (positive Beträge)
    for (final income in incomes) {
      transactions.add(Transaction(
        id: income.id,
        date: income.incomeDate,
        type: 'Einnahme',
        reference: income.referenceNumber,
        description: income.description ?? income.category,
        participantOrFamily: income.source,
        amount: income.amount,
        runningBalance: 0, // Wird später berechnet
      ));
    }

    // 3. Ausgaben hinzufügen (negative Beträge)
    for (final expense in expenses) {
      transactions.add(Transaction(
        id: expense.id,
        date: expense.expenseDate,
        type: 'Ausgabe',
        reference: expense.receiptNumber ?? expense.referenceNumber,
        description: expense.description ?? expense.category,
        participantOrFamily: expense.vendor ?? expense.paidBy,
        amount: -expense.amount, // Negativ!
        runningBalance: 0, // Wird später berechnet
      ));
    }

    // Nach Datum sortieren
    transactions.sort((a, b) => a.date.compareTo(b.date));

    // Laufenden Saldo berechnen
    double runningBalance = 0;
    final List<Transaction> transactionsWithBalance = [];
    for (final transaction in transactions) {
      runningBalance += transaction.amount;
      transactionsWithBalance.add(Transaction(
        id: transaction.id,
        date: transaction.date,
        type: transaction.type,
        reference: transaction.reference,
        description: transaction.description,
        participantOrFamily: transaction.participantOrFamily,
        amount: transaction.amount,
        runningBalance: runningBalance,
      ));
    }

    return transactionsWithBalance;
  }

  Widget _buildTransactionHistoryContent(BuildContext context, List<Transaction> allTransactions) {
    // Filter anwenden
    List<Transaction> filteredTransactions = allTransactions;

    // Datumsfilter
    if (_startDateFilter != null) {
      filteredTransactions = filteredTransactions
          .where((t) => t.date.isAfter(_startDateFilter!) || t.date.isAtSameMomentAs(_startDateFilter!))
          .toList();
    }
    if (_endDateFilter != null) {
      filteredTransactions = filteredTransactions
          .where((t) => t.date.isBefore(_endDateFilter!) || t.date.isAtSameMomentAs(_endDateFilter!))
          .toList();
    }

    // Suchfilter
    if (_searchText.isNotEmpty) {
      filteredTransactions = filteredTransactions.where((t) {
        final searchLower = _searchText.toLowerCase();
        return t.type.toLowerCase().contains(searchLower) ||
            (t.reference?.toLowerCase().contains(searchLower) ?? false) ||
            t.description.toLowerCase().contains(searchLower) ||
            (t.participantOrFamily?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // Filter-Bereich
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.filter_list, color: Color(0xFF2196F3), size: 20),
                    SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),

                // Suchfeld
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Suchen...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),

                // Datumsfilter
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _startDateFilter ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            locale: const Locale('de', 'DE'),
                          );
                          if (picked != null) {
                            setState(() {
                              _startDateFilter = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _startDateFilter != null
                              ? 'Von: ${DateFormat('dd.MM.yyyy').format(_startDateFilter!)}'
                              : 'Von Datum',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _endDateFilter ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            locale: const Locale('de', 'DE'),
                          );
                          if (picked != null) {
                            setState(() {
                              _endDateFilter = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _endDateFilter != null
                              ? 'Bis: ${DateFormat('dd.MM.yyyy').format(_endDateFilter!)}'
                              : 'Bis Datum',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),

                // Filter zurücksetzen
                if (_startDateFilter != null || _endDateFilter != null || _searchText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppConstants.spacingS),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _startDateFilter = null;
                          _endDateFilter = null;
                          _searchController.clear();
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Alle Filter zurücksetzen'),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Transaktionsliste
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: Color(0xFF2196F3), size: 20),
                    const SizedBox(width: AppConstants.spacingS),
                    const Text(
                      'Alle Transaktionen',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filteredTransactions.length} Transaktionen',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),

                if (filteredTransactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Keine Transaktionen gefunden',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                      columns: const [
                        DataColumn(label: Text('Datum', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Typ', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Referenz', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Beschreibung', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Teilnehmer/Familie', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Betrag', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: filteredTransactions.map((transaction) {
                        final Color typeColor = transaction.type == 'Zahlung'
                            ? const Color(0xFF2196F3)
                            : transaction.type == 'Einnahme'
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE91E63);

                        final Color amountColor = transaction.amount >= 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE91E63);

                        final Color saldoColor = transaction.runningBalance >= 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE91E63);

                        return DataRow(
                          cells: [
                            DataCell(Text(DateFormat('dd.MM.yyyy').format(transaction.date))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  transaction.type,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(transaction.reference ?? '-')),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Text(
                                  transaction.description,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(Text(transaction.participantOrFamily ?? '-')),
                            DataCell(
                              Text(
                                NumberFormat.currency(locale: 'de_DE', symbol: '€').format(transaction.amount),
                                style: TextStyle(
                                  color: amountColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat.currency(locale: 'de_DE', symbol: '€').format(transaction.runningBalance),
                                style: TextStyle(
                                  color: saldoColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========== TAB 3: ZUSCHÜSSE ==========
  Widget _buildSubsidiesTab(BuildContext context, WidgetRef ref, AppDatabase database, int eventId) {
    return StreamBuilder<List<Participant>>(
      stream: (database.select(database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .watch(),
      builder: (context, participantSnapshot) {
        if (!participantSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<Role>>(
          stream: (database.select(database.roles)
                ..where((tbl) => tbl.eventId.equals(eventId)))
              .watch(),
          builder: (context, roleSnapshot) {
            if (!roleSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final participants = participantSnapshot.data!;
            final roles = roleSnapshot.data!;

            // Nur Teilnehmer OHNE manualPriceOverride (regelwerk-basierte Preise)
            final rulesetParticipants = participants
                .where((p) => p.manualPriceOverride == null && p.discountPercent > 0)
                .toList();

            return _buildSubsidiesContent(context, rulesetParticipants, roles);
          },
        );
      },
    );
  }

  Widget _buildSubsidiesContent(BuildContext context, List<Participant> participants, List<Role> roles) {
    // Helper: Berechne Zuschuss-Betrag
    double calculateSubsidy(Participant p) {
      if (p.discountPercent <= 0) return 0;
      // Subsidy = calculatedPrice * (discountPercent / (100 - discountPercent))
      return p.calculatedPrice * (p.discountPercent / (100 - p.discountPercent));
    }

    // Bereich 1: Zuschüsse nach Rolle
    final Map<int?, List<Participant>> byRole = {};
    for (final p in participants) {
      if (!byRole.containsKey(p.roleId)) {
        byRole[p.roleId] = [];
      }
      byRole[p.roleId]!.add(p);
    }

    // Bereich 2: Zuschüsse nach Rabatttyp
    final Map<String, List<Participant>> byDiscountType = {};
    for (final p in participants) {
      String discountType = 'Sonstige';

      if (p.bildungUndTeilhabe) {
        discountType = 'Bildung & Teilhabe';
      } else if (p.discountReason != null && p.discountReason!.isNotEmpty) {
        discountType = p.discountReason!;
      }

      if (!byDiscountType.containsKey(discountType)) {
        byDiscountType[discountType] = [];
      }
      byDiscountType[discountType]!.add(p);
    }

    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // Bereich 1: Zuschüsse nach Rolle
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.groups, color: Color(0xFF2196F3), size: 20),
                    SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Zuschüsse nach Rolle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),

                if (byRole.isEmpty)
                  const Text(
                    'Keine Zuschüsse nach Rolle gefunden',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  DataTable(
                    columnSpacing: 24,
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columns: const [
                      DataColumn(label: Text('Rolle', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Anzahl', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('Gesamtrabatt', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: byRole.entries.map((entry) {
                      final roleId = entry.key;
                      final roleParticipants = entry.value;

                      String roleName = 'Teilnehmer (keine Rolle)';
                      if (roleId != null) {
                        final role = roles.firstWhere(
                          (r) => r.id == roleId,
                          orElse: () => roles.first,
                        );
                        roleName = role.displayName;
                      }

                      final totalSubsidy = roleParticipants.fold<double>(
                        0.0,
                        (sum, p) => sum + calculateSubsidy(p),
                      );

                      return DataRow(
                        cells: [
                          DataCell(Text(roleName)),
                          DataCell(Text('${roleParticipants.length}')),
                          DataCell(
                            Text(
                              NumberFormat.currency(locale: 'de_DE', symbol: '€').format(totalSubsidy),
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Bereich 2: Zuschüsse nach Rabatttyp
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.discount, color: Color(0xFFFF9800), size: 20),
                    SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Zuschüsse nach Rabatttyp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),

                if (byDiscountType.isEmpty)
                  const Text(
                    'Keine Zuschüsse nach Rabatttyp gefunden',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  DataTable(
                    columnSpacing: 24,
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columns: const [
                      DataColumn(label: Text('Rabatttyp', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Anzahl', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('Durchschn. Rabatt', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('Gesamtrabatt', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: byDiscountType.entries.map((entry) {
                      final discountType = entry.key;
                      final discountParticipants = entry.value;

                      final totalSubsidy = discountParticipants.fold<double>(
                        0.0,
                        (sum, p) => sum + calculateSubsidy(p),
                      );

                      final avgDiscountPercent = discountParticipants.fold<double>(
                        0.0,
                        (sum, p) => sum + p.discountPercent,
                      ) / discountParticipants.length;

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 150,
                              child: Text(
                                discountType,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text('${discountParticipants.length}')),
                          DataCell(Text('${avgDiscountPercent.toStringAsFixed(1)}%')),
                          DataCell(
                            Text(
                              NumberFormat.currency(locale: 'de_DE', symbol: '€').format(totalSubsidy),
                              style: const TextStyle(
                                color: Color(0xFFFF9800),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Zusammenfassung
        Card(
          color: const Color(0xFFF5F5F5),
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.summarize, color: Color(0xFF607D8B), size: 20),
                    SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Zusammenfassung',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gesamt-Teilnehmer mit Zuschuss:',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      '${participants.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gesamt-Zuschüsse:',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'de_DE', symbol: '€').format(
                        participants.fold<double>(0.0, (sum, p) => sum + calculateSubsidy(p)),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                const Divider(),
                const SizedBox(height: AppConstants.spacingXs),
                const Text(
                  'Hinweis: Nur regelwerk-basierte Zuschüsse werden angezeigt. Manuelle Preisüberschreibungen sind ausgeschlossen.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
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
