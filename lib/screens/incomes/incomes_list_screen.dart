import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';
import '../../providers/income_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/repositories/income_repository.dart';
import 'income_form_screen.dart';
import '../../utils/constants.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../widgets/adaptive_list_item.dart';
import '../../extensions/context_extensions.dart';

class IncomesListScreen extends ConsumerWidget {
  const IncomesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);
    final incomesAsync = ref.watch(incomesProvider);

    if (currentEvent == null) {
      return const ResponsiveScaffold(
        title: 'Sonstige Einnahmen',
        selectedIndex: 5,
        body: Center(
          child: Text('Bitte wählen Sie zuerst eine Veranstaltung aus.'),
        ),
      );
    }

    return ResponsiveScaffold(
      title: 'Sonstige Einnahmen',
      selectedIndex: 5,
      body: incomesAsync.when(
        data: (incomes) {
          if (incomes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: AppConstants.spacing),
                  Text(
                    'Noch keine Einnahmen',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Fügen Sie die erste Einnahme hinzu',
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
                          builder: (context) => const IncomeFormScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Einnahme hinzufügen'),
                  ),
                ],
              ),
            );
          }

          // Group incomes by source
          final incomesBySource = <String, List<Income>>{};
          double total = 0.0;

          for (final income in incomes) {
            incomesBySource.putIfAbsent(income.source ?? 'Sonstige', () => []).add(income);
            total += income.amount;
          }

          return Column(
            children: [
              // Statistik-Header
              Container(
                padding: AppConstants.paddingAll16,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Color(0xFF4CAF50), size: 24),
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
                        // Gesamteinnahmen
                        Expanded(
                          child: Container(
                            padding: AppConstants.paddingAll16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppConstants.borderRadius8,
                              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.euro, color: Color(0xFF4CAF50), size: 20),
                                    SizedBox(width: AppConstants.spacingS),
                                    Text(
                                      'Gesamteinnahmen',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppConstants.spacingS),
                                Text(
                                  NumberFormat.currency(locale: 'de_DE', symbol: '€').format(total),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacing),
                        // Anzahl Einnahmen
                        Expanded(
                          child: Container(
                            padding: AppConstants.paddingAll16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppConstants.borderRadius8,
                              border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.receipt_long, color: Color(0xFF2196F3), size: 20),
                                    SizedBox(width: AppConstants.spacingS),
                                    Text(
                                      'Anzahl Einnahmen',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppConstants.spacingS),
                                Text(
                                  incomes.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Source filter chips
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Chip(
                      label: Text('Alle (${incomes.length})'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    ...incomesBySource.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text('${entry.key} (${entry.value.length})'),
                          ),
                        )),
                  ],
                ),
              ),

              // Incomes list
              Expanded(
                child: ListView.builder(
                  padding: AppConstants.paddingAll16,
                  itemCount: incomes.length,
                  itemBuilder: (context, index) {
                    final income = incomes[index];
                    return _IncomeListItem(income: income, ref: ref);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Fehler beim Laden der Einnahmen: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const IncomeFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Einnahme'),
      ),
    );
  }
}

class _IncomeListItem extends ConsumerWidget {
  final Income income;
  final WidgetRef ref;

  const _IncomeListItem({required this.income, required this.ref});

  IconData _getSourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'teilnehmerbeitrag':
        return Icons.person;
      case 'spende':
        return Icons.favorite;
      case 'zuschuss':
        return Icons.account_balance;
      case 'sponsoring':
        return Icons.business;
      case 'merchandise':
        return Icons.shopping_bag;
      case 'sonstiges':
        return Icons.more_horiz;
      default:
        return Icons.account_balance_wallet;
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
      case 'sonstiges':
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceColor = _getSourceColor(income.source ?? 'Sonstige');
    final sourceIcon = _getSourceIcon(income.source ?? 'Sonstige');
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');

    return AdaptiveListItem(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: sourceColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          sourceIcon,
          color: sourceColor,
        ),
      ),
      title: Row(
        children: [
          Text(
            income.source ?? 'Sonstige',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(income.amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
              fontSize: 16,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (income.description != null)
            Text(
              income.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(income.incomeDate),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IncomeFormScreen(incomeId: income.id),
          ),
        );
      },
      onEdit: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IncomeFormScreen(incomeId: income.id),
          ),
        );
      },
      onDelete: () async {
        final database = ref.read(databaseProvider);
        final repository = IncomeRepository(database);
        await repository.deleteIncome(income.id);
        if (context.mounted) {
          context.showSuccess('Einnahme gelöscht');
        }
      },
      deleteConfirmMessage: 'Einnahme "${income.source ?? 'Sonstige'}" (${NumberFormat.currency(locale: 'de_DE', symbol: '€').format(income.amount)}) wirklich löschen?',
    );
  }
}
