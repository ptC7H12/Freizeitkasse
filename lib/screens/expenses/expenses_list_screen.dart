import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';
import '../../providers/expense_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/repositories/expense_repository.dart';
import 'expense_form_screen.dart';
import '../../utils/constants.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../widgets/adaptive_list_item.dart';
import '../../widgets/common/common_widgets.dart';
import '../../extensions/context_extensions.dart';
import '../../utils/logger.dart';

class ExpensesListScreen extends ConsumerWidget {
  const ExpensesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);
    final expensesAsync = ref.watch(expensesProvider);

    if (currentEvent == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ausgaben'),
        ),
        body: const Center(
          child: Text('Bitte wählen Sie zuerst eine Veranstaltung aus.'),
        ),
      );
    }

    return ResponsiveScaffold(
      title: 'Ausgaben',
      selectedIndex: 4,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<dynamic>(
              builder: (context) => const ExpenseFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Ausgabe'),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: AppConstants.spacing),
                  Text(
                    'Noch keine Ausgaben',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Fügen Sie die erste Ausgabe hinzu',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          // Berechne Statistiken
          final expensesByCategory = <String, List<Expense>>{};
          double gesamtbetrag = 0.0;
          double beglichene = 0.0;

          for (final expense in expenses) {
            expensesByCategory.putIfAbsent(expense.category, () => []).add(expense);
            gesamtbetrag += expense.amount;
            if (expense.reimbursed) {
              beglichene += expense.amount;
            }
          }

          final offeneAusgaben = gesamtbetrag - beglichene;

          return Column(
            children: [
              // Statistik-Header
              Container(
                padding: AppConstants.paddingAll16,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shopping_cart, color: Color(0xFFE91E63), size: 24),
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
                    // Erste Zeile: Zahlung gesamt, Gesamtbetrag
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Ausgaben gesamt',
                            value: expenses.length.toString(),
                            icon: Icons.receipt_long,
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing),
                        Expanded(
                          child: StatCard(
                            label: 'Gesamtbetrag',
                            value: NumberFormat.currency(locale: 'de_DE', symbol: '€').format(gesamtbetrag),
                            icon: Icons.euro,
                            color: const Color(0xFFE91E63),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacing),
                    // Zweite Zeile: Offene Ausgaben, Beglichen
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Offene Ausgaben',
                            value: NumberFormat.currency(locale: 'de_DE', symbol: '€').format(offeneAusgaben),
                            icon: Icons.hourglass_empty,
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing),
                        Expanded(
                          child: StatCard(
                            label: 'Beglichen',
                            value: NumberFormat.currency(locale: 'de_DE', symbol: '€').format(beglichene),
                            icon: Icons.check_circle,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Category filter chips
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: AppConstants.paddingH16,
                  children: [
                    Chip(
                      label: Text('Alle (${expenses.length})'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    ...expensesByCategory.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text('${entry.key} (${entry.value.length})'),
                          ),
                        )),
                  ],
                ),
              ),

              // Expenses list
              Expanded(
                child: ListView.builder(
                  padding: AppConstants.paddingAll16,
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return _ExpenseListItem(expense: expense, ref: ref);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Fehler beim Laden der Ausgaben: $error'),
        ),
      ),
    );
  }

}

class _ExpenseListItem extends ConsumerWidget {
  final Expense expense;
  final WidgetRef ref;

  const _ExpenseListItem({required this.expense, required this.ref});

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'verpflegung':
        return Icons.restaurant;
      case 'unterkunft':
        return Icons.hotel;
      case 'transport':
        return Icons.directions_bus;
      case 'material':
        return Icons.construction;
      case 'personal':
        return Icons.people;
      case 'versicherung':
        return Icons.shield;
      case 'sonstiges':
        return Icons.more_horiz;
      default:
        return Icons.receipt_long;
    }
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
      case 'sonstiges':
        return Colors.grey;
      default:
        return Colors.brown;
    }
  }

  /// Toggle Reimbursed Status
  Future<void> _toggleReimbursedStatus(WidgetRef ref) async {
    final database = ref.read(databaseProvider);
    final repository = ExpenseRepository(database);

    try {
      await repository.updateExpense(
        id: expense.id,
        reimbursed: !expense.reimbursed,
      );
    } catch (e) {
      // Fehlerbehandlung könnte hier verbessert werden
      AppLogger.debug('Fehler beim Aktualisieren des Status: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = _getCategoryColor(expense.category);
    final categoryIcon = _getCategoryIcon(expense.category);
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');

    return AdaptiveListItem(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          categoryIcon,
          color: categoryColor,
        ),
      ),
      title: Row(
        children: [
          Text(
            expense.category,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (expense.vendor != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '• ${expense.vendor}',
                style: TextStyle(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          Text(
            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(expense.amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
              fontSize: 16,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expense.description != null)
            Text(
              expense.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(expense.expenseDate),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: expense.reimbursed
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  expense.reimbursed ? 'Erstattet' : 'Offen',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: expense.reimbursed ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<dynamic>(
            builder: (context) => ExpenseFormScreen(expenseId: expense.id),
          ),
        );
      },
      onEdit: () {
        Navigator.push(
          context,
          MaterialPageRoute<dynamic>(
            builder: (context) => ExpenseFormScreen(expenseId: expense.id),
          ),
        );
      },
      onDelete: () async {
        final database = ref.read(databaseProvider);
        final repository = ExpenseRepository(database);
        await repository.deleteExpense(expense.id);
        if (context.mounted) {
          context.showSuccess('Ausgabe gelöscht');
        }
      },
      deleteConfirmMessage: 'Ausgabe "${expense.category}" (${NumberFormat.currency(locale: 'de_DE', symbol: '€').format(expense.amount)}) wirklich löschen?',
    );
  }
}
