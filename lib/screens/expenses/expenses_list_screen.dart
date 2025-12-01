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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ausgaben'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseFormScreen(),
                ),
              );
            },
            tooltip: 'Neue Ausgabe',
          ),
        ],
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
                  const SizedBox(height: AppConstants.spacingL),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExpenseFormScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ausgabe hinzufügen'),
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
                  color: const Color(0xFFE91E63).withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, color: const Color(0xFFE91E63), size: 24),
                        const SizedBox(width: AppConstants.spacingS),
                        const Text(
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
                          child: _buildStatCard(
                            context,
                            'Ausgaben gesamt',
                            expenses.length.toString(),
                            Icons.receipt_long,
                            const Color(0xFF2196F3),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Gesamtbetrag',
                            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(gesamtbetrag),
                            Icons.euro,
                            const Color(0xFFE91E63),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacing),
                    // Zweite Zeile: Offene Ausgaben, Beglichen
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Offene Ausgaben',
                            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(offeneAusgaben),
                            Icons.hourglass_empty,
                            const Color(0xFFFF9800),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Beglichen',
                            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(beglichene),
                            Icons.check_circle,
                            const Color(0xFF4CAF50),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    return _ExpenseListItem(expense: expense);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ExpenseFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
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
        border: Border.all(color: color.withOpacity(0.3)),
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseListItem extends ConsumerWidget {
  final Expense expense;

  const _ExpenseListItem({required this.expense});

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
      print('Fehler beim Aktualisieren des Status: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = _getCategoryColor(expense.category);
    final categoryIcon = _getCategoryIcon(expense.category);
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseFormScreen(expenseId: expense.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppConstants.paddingAll16,
          child: Row(
            children: [
              // Category icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryIcon,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: AppConstants.spacing),

              // Expense details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          expense.category,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (expense.vendor != null) ...[
                          const SizedBox(width: AppConstants.spacingS),
                          Flexible(
                            child: Text(
                              '• ${expense.vendor}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (expense.description != null)
                      Text(
                        expense.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(expense.expenseDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        if (expense.paymentMethod != null) ...[
                          const SizedBox(width: AppConstants.spacingM),
                          Icon(
                            Icons.payment,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            expense.paymentMethod!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Amount and Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(locale: 'de_DE', symbol: '€').format(expense.amount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  // Status-Chip (klickbar zum Togglen)
                  InkWell(
                    onTap: () => _toggleReimbursedStatus(ref),
                    borderRadius: AppConstants.borderRadius8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: expense.reimbursed
                            ? const Color(0xFF4CAF50).withOpacity(0.1)
                            : const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: AppConstants.borderRadius8,
                        border: Border.all(
                          color: expense.reimbursed
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            expense.reimbursed ? Icons.check_circle : Icons.hourglass_empty,
                            size: 16,
                            color: expense.reimbursed
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF9800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            expense.reimbursed ? 'Erstattet' : 'Offen',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: expense.reimbursed
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expense.receiptNumber != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Beleg: ${expense.receiptNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
