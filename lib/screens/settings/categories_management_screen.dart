import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/category_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../data/database/app_database.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/constants.dart';
/// import '../../extensions/context_extensions.dart';

/// Kategorien-Verwaltung für Ausgaben und Einnahmen
class CategoriesManagementScreen extends StatelessWidget {
  const CategoriesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategorien verwalten'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.shopping_cart),
                text: 'Ausgaben',
              ),
              Tab(
                icon: Icon(Icons.attach_money),
                text: 'Einnahmen',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ExpenseCategoriesTab(),
            _IncomeSourcesTab(),
          ],
        ),
      ),
    );
  }
}

// ===== AUSGABEN-KATEGORIEN TAB =====

class _ExpenseCategoriesTab extends ConsumerWidget {
  const _ExpenseCategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) => _buildCategoryList(
        context,
        ref,
        categories,
        isExpense: true,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Fehler: $error'),
      ),
    );
  }
}

// ===== EINNAHMEN-QUELLEN TAB =====

class _IncomeSourcesTab extends ConsumerWidget {
  const _IncomeSourcesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(incomeSourcesProvider);

    return sourcesAsync.when(
      data: (sources) => _buildCategoryList(
        context,
        ref,
        sources,
        isExpense: false,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Fehler: $error'),
      ),
    );
  }
}

// ===== GEMEINSAME LISTE =====

Widget _buildCategoryList(
  BuildContext context,
  WidgetRef ref,
  List<dynamic> items,
  {required bool isExpense}
) {
  return Column(
    children: [
      // Info-Karte
      Card(
        margin: AppConstants.paddingAll16,
        color: Colors.blue[50],
        child: Padding(
          padding: AppConstants.paddingAll16,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppConstants.infoColor),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Text(
                  isExpense
                      ? 'Verwalten Sie hier die Kategorien für Ausgaben. System-Kategorien (🔒) können nicht gelöscht werden.'
                      : 'Verwalten Sie hier die Quellen für Einnahmen. System-Quellen (🔒) können nicht gelöscht werden.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),

      // Liste
      Expanded(
        child: items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isExpense ? Icons.category_outlined : Icons.source_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: AppConstants.spacing),
                    Text(
                      isExpense ? 'Keine Kategorien' : 'Keine Quellen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            : ReorderableListView.builder(
                itemCount: items.length,
                onReorder: (oldIndex, newIndex) =>
                    _onReorder(ref, items, oldIndex, newIndex, isExpense),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildCategoryTile(
                    context,
                    ref,
                    item,
                    isExpense: isExpense,
                  );
                },
              ),
      ),

      // Add Button
      Container(
        padding: AppConstants.paddingAll16,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _showAddDialog(context, ref, isExpense),
            icon: const Icon(Icons.add),
            label: Text(isExpense ? 'Neue Kategorie' : 'Neue Quelle'),
          ),
        ),
      ),
    ],
  );
}

Widget _buildCategoryTile(
  BuildContext context,
  WidgetRef ref,
  dynamic item,
  {required bool isExpense}
) {
  final isSystem = isExpense
      ? (item as ExpenseCategory).isSystem
      : (item as IncomeSource).isSystem;
  final name = isExpense
      ? (item as ExpenseCategory).name
      : (item as IncomeSource).name;
  final description = isExpense
      ? (item as ExpenseCategory).description
      : (item as IncomeSource).description;

  return Card(
    key: ValueKey(isExpense
        ? (item as ExpenseCategory).id
        : (item as IncomeSource).id),
    margin: const EdgeInsets.symmetric(
      horizontal: AppConstants.spacing,
      vertical: AppConstants.spacingXS,
    ),
    child: ListTile(
      leading: Icon(
        isSystem ? Icons.lock : Icons.drag_handle,
        color: isSystem ? Colors.grey : null,
      ),
      title: Row(
        children: [
          Text(name),
          if (isSystem) ...[
            const SizedBox(width: AppConstants.spacingS),
            const Text(
              '🔒',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      subtitle: description != null && description.isNotEmpty
          ? Text(description)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context, ref, item, isExpense),
          ),
          if (!isSystem)
            IconButton(
              icon: const Icon(Icons.delete, color: AppConstants.errorColor),
              onPressed: () => _confirmDelete(context, ref, item, isExpense),
            ),
        ],
      ),
    ),
  );
}

// ===== DIALOGE =====

void _showAddDialog(
  BuildContext context,
  WidgetRef ref,
  bool isExpense,
) {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isExpense ? 'Neue Kategorie' : 'Neue Quelle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: isExpense ? 'Kategorie-Name *' : 'Quellen-Name *',
              hintText: isExpense ? 'z.B. Dekoration' : 'z.B. Verkauf',
            ),
            autofocus: true,
          ),
          const SizedBox(height: AppConstants.spacing),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              hintText: 'Optional',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              UIHelpers.showErrorSnackbar(
                context,
                'Bitte Namen eingeben',
              );
              return;
            }

            try {
              final repository = ref.read(categoryRepositoryProvider);
              final eventId = ref.read(currentEventIdProvider);

              if (eventId == null) {
                throw Exception('Kein Event ausgewählt');
              }

              if (isExpense) {
                await repository.createExpenseCategory(
                  eventId: eventId,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );
              } else {
                await repository.createIncomeSource(
                  eventId: eventId,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
                UIHelpers.showSuccessSnackbar(
                  context,
                  isExpense ? 'Kategorie erstellt' : 'Quelle erstellt',
                );
              }
            } catch (e) {
              if (context.mounted) {
                UIHelpers.showErrorSnackbar(context, 'Fehler: $e');
              }
            }
          },
          child: const Text('Erstellen'),
        ),
      ],
    ),
  );
}

void _showEditDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic item,
  bool isExpense,
) {
  final nameController = TextEditingController(
    text: isExpense
        ? (item as ExpenseCategory).name
        : (item as IncomeSource).name,
  );
  final descriptionController = TextEditingController(
    text: isExpense
        ? (item as ExpenseCategory).description ?? ''
        : (item as IncomeSource).description ?? '',
  );

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isExpense ? 'Kategorie bearbeiten' : 'Quelle bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
            ),
            autofocus: true,
          ),
          const SizedBox(height: AppConstants.spacing),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              UIHelpers.showErrorSnackbar(
                context,
                'Bitte Namen eingeben',
              );
              return;
            }

            try {
              final repository = ref.read(categoryRepositoryProvider);
              final id = isExpense
                  ? (item as ExpenseCategory).id
                  : (item as IncomeSource).id;

              if (isExpense) {
                await repository.updateExpenseCategory(
                  id: id,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );
              } else {
                await repository.updateIncomeSource(
                  id: id,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
                UIHelpers.showSuccessSnackbar(
                  context,
                  isExpense ? 'Kategorie aktualisiert' : 'Quelle aktualisiert',
                );
              }
            } catch (e) {
              if (context.mounted) {
                UIHelpers.showErrorSnackbar(context, 'Fehler: $e');
              }
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
}

void _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  dynamic item,
  bool isExpense,
) async {
  final name = isExpense
      ? (item as ExpenseCategory).name
      : (item as IncomeSource).name;

  final confirmed = await UIHelpers.showDeleteConfirmDialog(
    context: context,
    itemName: isExpense ? 'Kategorie "$name"' : 'Quelle "$name"',
  );

  if (confirmed && context.mounted) {
    try {
      final repository = ref.read(categoryRepositoryProvider);
      final id =
          isExpense ? (item as ExpenseCategory).id : (item as IncomeSource).id;

      if (isExpense) {
        await repository.deleteExpenseCategory(id);
      } else {
        await repository.deleteIncomeSource(id);
      }

      if (context.mounted) {
        UIHelpers.showSuccessSnackbar(
          context,
          isExpense ? 'Kategorie gelöscht' : 'Quelle gelöscht',
        );
      }
    } catch (e) {
      if (context.mounted) {
        UIHelpers.showErrorSnackbar(context, 'Fehler: $e');
      }
    }
  }
}

void _onReorder(
  WidgetRef ref,
  List<dynamic> items,
  int oldIndex,
  int newIndex,
  bool isExpense,
) async {
  if (oldIndex < newIndex) {
    newIndex -= 1;
  }

  // Reorder local list
  final item = items.removeAt(oldIndex);
  items.insert(newIndex, item);

  // Update sort orders in database
  try {
    final repository = ref.read(categoryRepositoryProvider);

    for (var i = 0; i < items.length; i++) {
      final id = isExpense
          ? (items[i] as ExpenseCategory).id
          : (items[i] as IncomeSource).id;

      if (isExpense) {
        await repository.updateExpenseCategory(
          id: id,
          sortOrder: i,
        );
      } else {
        await repository.updateIncomeSource(
          id: id,
          sortOrder: i,
        );
      }
    }
  } catch (e) {
    // Error handling
  }
}
