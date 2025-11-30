import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/category_repository.dart';
import 'database_provider.dart';
import 'current_event_provider.dart';

/// Provider für Category Repository
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CategoryRepository(database);
});

/// Provider für Ausgaben-Kategorien (aktuelles Event)
final expenseCategoriesProvider =
    StreamProvider.autoDispose<List<ExpenseCategory>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  final eventId = ref.watch(currentEventIdProvider);

  if (eventId == null) {
    return Stream.value([]);
  }

  return repository.watchExpenseCategories(eventId);
});

/// Provider für Einnahmen-Quellen (aktuelles Event)
final incomeSourcesProvider =
    StreamProvider.autoDispose<List<IncomeSource>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  final eventId = ref.watch(currentEventIdProvider);

  if (eventId == null) {
    return Stream.value([]);
  }

  return repository.watchIncomeSources(eventId);
});

/// Provider für einzelne Ausgaben-Kategorie
final expenseCategoryByIdProvider =
    FutureProvider.family<ExpenseCategory?, int>((ref, id) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getExpenseCategoryById(id);
});

/// Provider für einzelne Einnahmen-Quelle
final incomeSourceByIdProvider =
    FutureProvider.family<IncomeSource?, int>((ref, id) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getIncomeSourceById(id);
});
