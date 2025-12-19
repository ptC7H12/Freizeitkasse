import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/subsidy_provider.dart';
/// import '../../providers/payment_provider.dart';
/// import '../../providers/participant_provider.dart';
import '../../providers/pdf_export_provider.dart';
import '../../data/database/app_database.dart' as db;
import '../../utils/constants.dart';
import '../../extensions/context_extensions.dart';
import '../../widgets/responsive_scaffold.dart';

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
      return const ResponsiveScaffold(
        title: 'Kassenstand',
        selectedIndex: 6,
        body: Center(
          child: Text('Bitte wählen Sie zuerst eine Veranstaltung aus.'),
        ),
      );
    }

    return ResponsiveScaffold(
      title: 'Kassenstand',
      selectedIndex: 6,
      body: Column(
        children: [
          // TabBar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.analytics), text: 'Übersicht'),
              Tab(icon: Icon(Icons.history), text: 'Transaktionen'),
              Tab(icon: Icon(Icons.card_giftcard), text: 'Zuschüsse'),
            ],
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportFinancialReportPDF(context, ref, database, currentEvent),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('PDF Export'),
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
            StreamBuilder<List<db.Payment>>(
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
                  error: (_, _) => const Center(child: Text('Fehler')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('Fehler')),
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
                error: (_, _) => const Center(child: Text('Fehler')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeBySourceChart(BuildContext context, WidgetRef ref, int eventId) {
    final incomesBySourceAsync = ref.watch(incomesByCategoryProvider);

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
                error: (_, _) => const Center(child: Text('Fehler')),
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
    db.AppDatabase database,
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
            _buildDetailedSection(context, ref, 'Einnahmen nach Kategorie', incomesByCategoryProvider),
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
          error: (_, _) => const Text('Fehler beim Laden'),
        ),
      ],
    );
  }

  // ========== TAB 1: ÜBERSICHT ==========
  Widget _buildOverviewTab(BuildContext context, WidgetRef ref, db.AppDatabase database, int eventId) {
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
  Widget _buildTransactionsTab(BuildContext context, WidgetRef ref, db.AppDatabase database, int eventId) {
    return StreamBuilder<List<db.Payment>>(
      stream: (database.select(database.payments)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .watch(),
      builder: (context, paymentSnapshot) {
        if (!paymentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<db.Income>>(
          stream: (database.select(database.incomes)
                ..where((tbl) => tbl.eventId.equals(eventId))
                ..where((tbl) => tbl.isActive.equals(true)))
              .watch(),
          builder: (context, incomeSnapshot) {
            if (!incomeSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<db.Expense>>(
              stream: (database.select(database.expenses)
                    ..where((tbl) => tbl.eventId.equals(eventId))
                    ..where((tbl) => tbl.isActive.equals(true)))
                  .watch(),
              builder: (context, expenseSnapshot) {
                if (!expenseSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<db.Participant>>(
                  stream: (database.select(database.participants)
                        ..where((tbl) => tbl.eventId.equals(eventId))
                        ..where((tbl) => tbl.isActive.equals(true)))
                      .watch(),
                  builder: (context, participantSnapshot) {
                    if (!participantSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return StreamBuilder<List<db.Family>>(
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
    List<db.Payment> payments,
    List<db.Income> incomes,
    List<db.Expense> expenses,
    List<db.Participant> participants,
    List<db.Family> families,
  ) {
    final List<Transaction> transactions = [];

    // Helper: Finde Teilnehmer-Name
    String? getParticipantName(int? participantId) {
      if (participantId == null) {
        return null;
      }
      try {
        final participant = participants.firstWhere((p) => p.id == participantId);
        return '${participant.firstName} ${participant.lastName}';
      } catch (e) {
        return null;
      }
    }

    // Helper: Finde Familien-Name
    String? getFamilyName(int? familyId) {
      if (familyId == null) {
        return null;
      }
      try {
        final family = families.firstWhere((f) => f.id == familyId);
        return family.familyName;
      } catch (e) {
        return null;
      }
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
    final isMobile = !context.isDesktop;

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
                      padding: AppConstants.paddingAll32,
                      child: Text(
                        'Keine Transaktionen gefunden',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else if (isMobile)
                  // Mobile: Card-basierte Ansicht
                  Column(
                    children: filteredTransactions.map((transaction) {
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

                      return Card(
                        margin: EdgeInsets.only(bottom: AppConstants.spacingS),
                        child: Padding(
                          padding: AppConstants.paddingAll12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kopfzeile: Datum + Typ
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(transaction.date),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      transaction.type,
                                      style: TextStyle(
                                        color: typeColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Beschreibung
                              Text(
                                transaction.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (transaction.participantOrFamily != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  transaction.participantOrFamily!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              if (transaction.reference != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Ref: ${transaction.reference}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                              const Divider(height: 16),
                              // Betrag + Saldo
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Betrag',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        NumberFormat.currency(locale: 'de_DE', symbol: '€')
                                            .format(transaction.amount),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: amountColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Saldo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        NumberFormat.currency(locale: 'de_DE', symbol: '€')
                                            .format(transaction.runningBalance),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: saldoColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  // Desktop: DataTable mit horizontalem Scroll
                  Container(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: context.screenWidth - 64,
                        ),
                        child: DataTable(
                          columnSpacing: 16,
                          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
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
                                      color: typeColor.withValues(alpha: 0.1),
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
  Widget _buildSubsidiesTab(BuildContext context, WidgetRef ref, db.AppDatabase database, int eventId) {
    final isMobile = !context.isDesktop;

    // Nutze SubsidyProvider für korrekte Berechnungen
    final subsidiesByRoleAsync = ref.watch(subsidiesByRoleProvider);
    final subsidiesByDiscountTypeAsync = ref.watch(subsidiesByDiscountTypeProvider);
    final expectedSubsidiesAsync = ref.watch(expectedSubsidiesProvider);

    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // Gesamtübersicht Card
        expectedSubsidiesAsync.when(
          data: (totalSubsidies) => Card(
            elevation: 2,
            color: const Color(0xFFF0F7FF),
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.euro, color: Color(0xFF2196F3), size: 24),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
                        'Erwartete Zuschüsse (Gesamt)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    NumberFormat.currency(locale: 'de_DE', symbol: '€').format(totalSubsidies),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Text('Fehler beim Laden der Zuschüsse: $error'),
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Zuschüsse nach Rolle
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

                subsidiesByRoleAsync.when(
                  data: (subsidiesByRole) {
                    if (subsidiesByRole.isEmpty) {
                      return const Text(
                        'Keine rollenbasierten Zuschüsse gefunden',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    if (isMobile) {
                      // Mobile: Card-basierte Ansicht
                      return Column(
                        children: subsidiesByRole.values.map((roleData) {
                          return Card(
                            margin: EdgeInsets.only(bottom: AppConstants.spacingS),
                            color: const Color(0xFFF8F9FA),
                            child: Padding(
                              padding: AppConstants.paddingAll12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    roleData.roleName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Rabatt',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${roleData.discountPercent.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Anzahl',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${roleData.participantCount}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Zuschuss (Soll)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            NumberFormat.currency(locale: 'de_DE', symbol: '€')
                                                .format(roleData.totalSubsidy),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4CAF50),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    } else {
                      // Desktop: DataTable mit horizontalem Scroll
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: context.screenWidth - 64,
                          ),
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                            columns: const [
                              DataColumn(label: Text('Rolle', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Rabatt', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Anzahl', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Zuschuss (Soll)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            ],
                            rows: subsidiesByRole.values.map((roleData) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(roleData.roleName)),
                                  DataCell(Text('${roleData.discountPercent.toStringAsFixed(0)}%')),
                                  DataCell(Text('${roleData.participantCount}')),
                                  DataCell(
                                    Text(
                                      NumberFormat.currency(locale: 'de_DE', symbol: '€').format(roleData.totalSubsidy),
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
                        ),
                      );
                    }
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text('Fehler: $error'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Zuschüsse nach Rabatttyp (OHNE BUT!)
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
                const Text(
                  'Bildung & Teilhabe (BuT) wird separat abgerechnet',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: AppConstants.spacing),

                subsidiesByDiscountTypeAsync.when(
                  data: (subsidiesByType) {
                    if (subsidiesByType.isEmpty) {
                      return const Text(
                        'Keine Zuschüsse gefunden',
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    if (isMobile) {
                      // Mobile: Card-basierte Ansicht
                      return Column(
                        children: subsidiesByType.values.map((typeData) {
                          return Card(
                            margin: EdgeInsets.only(bottom: AppConstants.spacingS),
                            color: const Color(0xFFFFF8E1),
                            child: Padding(
                              padding: AppConstants.paddingAll12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    typeData.discountType,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Anzahl',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${typeData.participantCount}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ø Rabatt',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${typeData.avgDiscountPercent.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Zuschuss (Soll)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            NumberFormat.currency(locale: 'de_DE', symbol: '€')
                                                .format(typeData.totalSubsidy),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4CAF50),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    } else {
                      // Desktop: DataTable mit horizontalem Scroll
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: context.screenWidth - 64,
                          ),
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                            columns: const [
                              DataColumn(label: Text('Rabatttyp', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Anzahl', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Ø Rabatt', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                              DataColumn(label: Text('Zuschuss (Soll)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            ],
                            rows: subsidiesByType.values.map((typeData) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(typeData.discountType)),
                                  DataCell(Text('${typeData.participantCount}')),
                                  DataCell(Text('${typeData.avgDiscountPercent.toStringAsFixed(1)}%')),
                                  DataCell(
                                    Text(
                                      NumberFormat.currency(locale: 'de_DE', symbol: '€').format(typeData.totalSubsidy),
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
                        ),
                      );
                    }
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Text('Fehler: $error'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Export-Buttons
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.file_download, color: Color(0xFF607D8B), size: 20),
                    SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Zuschussanträge exportieren',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                const Text(
                  'Erstelle Zuschussanträge für die Beantragung bei Förderstellen',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: AppConstants.spacing),

                // Export-Buttons
                Wrap(
                  spacing: AppConstants.spacingS,
                  runSpacing: AppConstants.spacingS,
                  children: [
                    // PDF Export (alle Rollen)
                    ElevatedButton.icon(
                      onPressed: () => _exportAllRoleSubsidiesPDF(context, ref),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Alle Rollen als PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                      ),
                    ),

                    // Excel Export (alle Rollen)
                    ElevatedButton.icon(
                      onPressed: () => _exportAllRoleSubsidiesExcel(context, ref),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Alle Rollen als Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppConstants.spacingS),
                const Text(
                  'Hinweis: Es wird für jede Rolle eine separate Datei erstellt',
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

  // ========== EXPORT-METHODEN ==========

  /// Exportiert den Finanzbericht als PDF
  Future<void> _exportFinancialReportPDF(
    BuildContext context,
    WidgetRef ref,
    db.AppDatabase database,
    db.Event currentEvent,
  ) async {
    try {
      final pdfService = ref.read(pdfExportServiceProvider);
      final payments = await (database.select(database.payments)
            ..where((t) => t.eventId.equals(currentEvent.id))
            ..where((t) => t.isActive.equals(true)))
          .get();
      final totalPayments = payments.fold<double>(0, (sum, p) => sum + p.amount);

      final totalIncomes = await ref.read(totalIncomesProvider.future);
      final totalExpenses = await ref.read(totalExpensesProvider.future);
      final expensesByCategory = await ref.read(expensesByCategoryProvider.future);
      final incomesBySource = await ref.read(incomesByCategoryProvider.future);

      final filePath = await pdfService.exportFinancialReport(
        eventName: currentEvent.name,
        totalIncomes: totalIncomes,
        totalExpenses: totalExpenses,
        totalPayments: totalPayments,
        expensesByCategory: expensesByCategory,
        incomesBySource: incomesBySource,
      );

      if (context.mounted) {
        context.showSuccess('PDF gespeichert: $filePath');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Fehler beim Export: $e');
      }
    }
  }

  /// Exportiert alle rollenbasierten Zuschüsse als PDF
  Future<void> _exportAllRoleSubsidiesPDF(BuildContext context, WidgetRef ref) async {
    try {
      final currentEvent = ref.read(currentEventProvider);
      if (currentEvent == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kein Event ausgewählt')),
          );
        }
        return;
      }

      // Zeige Loading-Dialog
      if (context.mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: AppConstants.paddingAll24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Erstelle PDF-Dateien...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Lade Zuschüsse nach Rollen
      final subsidiesByRole = await ref.read(subsidiesByRoleProvider.future);

      if (subsidiesByRole.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Schließe Loading-Dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine rollenbasierten Zuschüsse gefunden')),
          );
        }
        return;
      }

      // Exportiere PDFs
      final exportService = ref.read(subsidyExportServiceProvider);
      final filePaths = await exportService.exportAllRoleSubsidiesPDF(
        event: currentEvent,
        subsidiesByRole: subsidiesByRole,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Schließe Loading-Dialog

        // Extrahiere Speicherort
        final directory = filePaths.isNotEmpty
            ? filePaths.first.substring(0, filePaths.first.lastIndexOf('/'))
            : '';

        // Zeige Erfolgs-Dialog mit Details
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('PDF-Export erfolgreich'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${filePaths.length} PDF-Dateien wurden erfolgreich erstellt:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...filePaths.map((path) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${path.split('/').last}', style: const TextStyle(fontSize: 12)),
                )),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Speicherort:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  directory,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Schließe Loading-Dialog falls offen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Exportieren: $e')),
        );
      }
    }
  }

  /// Exportiert alle rollenbasierten Zuschüsse als Excel
  Future<void> _exportAllRoleSubsidiesExcel(BuildContext context, WidgetRef ref) async {
    try {
      final currentEvent = ref.read(currentEventProvider);
      if (currentEvent == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kein Event ausgewählt')),
          );
        }
        return;
      }

      // Zeige Loading-Dialog
      if (context.mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: AppConstants.paddingAll24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Erstelle Excel-Dateien...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Lade Zuschüsse nach Rollen
      final subsidiesByRole = await ref.read(subsidiesByRoleProvider.future);

      if (subsidiesByRole.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Schließe Loading-Dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine rollenbasierten Zuschüsse gefunden')),
          );
        }
        return;
      }

      // Exportiere Excel-Dateien
      final exportService = ref.read(subsidyExportServiceProvider);
      final filePaths = await exportService.exportAllRoleSubsidiesExcel(
        event: currentEvent,
        subsidiesByRole: subsidiesByRole,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Schließe Loading-Dialog

        // Extrahiere Speicherort
        final directory = filePaths.isNotEmpty
            ? filePaths.first.substring(0, filePaths.first.lastIndexOf('/'))
            : '';

        // Zeige Erfolgs-Dialog mit Details
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Excel-Export erfolgreich'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${filePaths.length} Excel-Dateien wurden erfolgreich erstellt:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...filePaths.map((path) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${path.split('/').last}', style: const TextStyle(fontSize: 12)),
                )),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Speicherort:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  directory,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Schließe Loading-Dialog falls offen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Exportieren: $e')),
        );
      }
    }
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

  Widget _buildSollSection(BuildContext context, WidgetRef ref, db.AppDatabase database, int eventId) {
    // Erwartete Zuschüsse aus SubsidyProvider
    final expectedSubsidiesAsync = ref.watch(expectedSubsidiesProvider);

    return StreamBuilder<List<db.Participant>>(
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

        return expectedSubsidiesAsync.when(
          data: (sonstigeEinnahmen) {
            // Sonstige Einnahmen = Erwartete Zuschüsse (SOLL)
            return StreamBuilder<List<db.Income>>(
              stream: (database.select(database.incomes)
                    ..where((tbl) => tbl.eventId.equals(eventId))
                    ..where((tbl) => tbl.isActive.equals(true)))
                  .watch(),
              builder: (context, incomeSnapshot) {
                // Incomes werden hier nicht mehr für SOLL benötigt,
                // sondern nur für IST-Werte (bereits erhaltene Zuschüsse)

            return StreamBuilder<List<db.Expense>>(
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            // Fehler beim Laden der erwarteten Zuschüsse - Fallback: 0.0
            const sonstigeEinnahmen = 0.0;

            return StreamBuilder<List<db.Expense>>(
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
                      'Zuschüsse (Fehler beim Laden)',
                      const Color(0xFFFF9800),
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

  Widget _buildIstSection(BuildContext context, WidgetRef ref, db.AppDatabase database, int eventId) {
    return StreamBuilder<List<db.Payment>>(
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

        return StreamBuilder<List<db.Income>>(
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

            return StreamBuilder<List<db.Expense>>(
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

  Widget _buildDifferenzenSection(BuildContext context, WidgetRef ref, db.AppDatabase database, int eventId) {
    return StreamBuilder<List<db.Participant>>(
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

        return StreamBuilder<List<db.Payment>>(
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

            return StreamBuilder<List<db.Income>>(
              stream: (database.select(database.incomes)
                    ..where((tbl) => tbl.eventId.equals(eventId))
                    ..where((tbl) => tbl.isActive.equals(true)))
                  .watch(),
              builder: (context, incomeSnapshot) {
                final incomes = incomeSnapshot.data ?? [];
                final sonstigeEinnahmen = incomes.fold<double>(0.0, (sum, income) => sum + income.amount);

                return StreamBuilder<List<db.Expense>>(
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
    final database = ref.watch(databaseProvider);
    final currentEvent = ref.watch(currentEventProvider);

    if (currentEvent == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.category, color: Color(0xFFE91E63), size: 24),
                SizedBox(width: AppConstants.spacingS),
                Text(
                  'Ausgaben nach Kategorie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            StreamBuilder<List<db.Expense>>(
              stream: (database.select(database.expenses)
                    ..where((tbl) => tbl.eventId.equals(currentEvent.id))
                    ..where((tbl) => tbl.isActive.equals(true)))
                  .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (snapshot.hasError) {
                  return const Text('Fehler beim Laden');
                }

                final expenses = snapshot.data ?? [];

                // Berechne Ausgaben nach Kategorie
                final Map<String, double> byCategory = {};
                final Map<String, int> countByCategory = {};

                for (final expense in expenses) {
                  byCategory[expense.category] = (byCategory[expense.category] ?? 0.0) + expense.amount;
                  countByCategory[expense.category] = (countByCategory[expense.category] ?? 0) + 1;
                }

                if (byCategory.isEmpty) {
                  return const Text(
                    'Keine Ausgaben vorhanden',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: context.isDesktop
                          ? context.screenWidth - 64
                          : context.screenWidth - 32,
                    ),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Kategorie', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Anzahl', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Betrag', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: byCategory.entries.map((entry) {
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
                          DataCell(Text('${countByCategory[entry.key]}')),
                          DataCell(Text(
                            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(entry.value),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
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
