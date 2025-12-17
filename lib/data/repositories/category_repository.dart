import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../utils/logger.dart';

/// Repository für Ausgaben-Kategorien und Einnahmen-Quellen
class CategoryRepository {
  final AppDatabase _db;

  CategoryRepository(this._db);

  // ===== EXPENSE CATEGORIES =====

  /// Alle Ausgaben-Kategorien für ein Event
  Stream<List<ExpenseCategory>> watchExpenseCategories(int eventId) {
    return (_db.select(_db.expenseCategories)
          ..where((t) => t.eventId.equals(eventId))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  /// Alle Ausgaben-Kategorien für ein Event (nicht als Stream)
  Future<List<ExpenseCategory>> getExpenseCategories(int eventId) {
    return (_db.select(_db.expenseCategories)
          ..where((t) => t.eventId.equals(eventId))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  /// Einzelne Kategorie
  Future<ExpenseCategory?> getExpenseCategoryById(int id) {
    return (_db.select(_db.expenseCategories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Erstelle Ausgaben-Kategorie
  Future<ExpenseCategory> createExpenseCategory({
    required int eventId,
    required String name,
    String? description,
    int sortOrder = 0,
    bool isSystem = false,
  }) async {
    try {
      AppLogger.debug('Creating expense category', {
        'eventId': eventId,
        'name': name,
        'isSystem': isSystem,
      });

      final id = await _db.into(_db.expenseCategories).insert(
            ExpenseCategoriesCompanion.insert(
              eventId: eventId,
              name: name,
              description: Value(description),
              sortOrder: Value(sortOrder),
              isSystem: Value(isSystem),
            ),
          );

      AppLogger.info('Expense category created successfully', {
        'id': id,
        'name': name,
      });

      return (await getExpenseCategoryById(id))!;
    } catch (e, stack) {
      AppLogger.error('Failed to create expense category', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update Ausgaben-Kategorie
  Future<void> updateExpenseCategory({
    required int id,
    String? name,
    String? description,
    int? sortOrder,
  }) async {
    try {
      AppLogger.debug('Updating expense category', {'id': id});

      await (_db.update(_db.expenseCategories)
            ..where((t) => t.id.equals(id)))
          .write(
        ExpenseCategoriesCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          description: Value(description),
          sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      AppLogger.info('Expense category updated successfully', {'id': id});
    } catch (e, stack) {
      AppLogger.error('Failed to update expense category', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Lösche Ausgaben-Kategorie (soft delete)
  Future<void> deleteExpenseCategory(int id) async {
    try {
      AppLogger.debug('Deleting expense category', {'id': id});

      // System-Kategorien dürfen nicht gelöscht werden
      final category = await getExpenseCategoryById(id);
      if (category?.isSystem == true) {
        AppLogger.warning('Cannot delete system expense category', {'id': id});
        throw Exception('System-Kategorien können nicht gelöscht werden');
      }

      await (_db.update(_db.expenseCategories)
            ..where((t) => t.id.equals(id)))
          .write(
        ExpenseCategoriesCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      AppLogger.info('Expense category soft deleted successfully', {'id': id});
    } catch (e, stack) {
      AppLogger.error('Failed to delete expense category', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Initialisiere Standard-Kategorien für ein neues Event
  Future<void> initializeDefaultExpenseCategories(int eventId) async {
    final defaultCategories = [
      ('Verpflegung', 'Essen und Getränke', 1),
      ('Unterkunft', 'Hotel, Camping, etc.', 2),
      ('Transport', 'Bus, Bahn, Benzin', 3),
      ('Material', 'Bastelmaterial, Ausrüstung', 4),
      ('Personal', 'Honorare, Gehälter', 5),
      ('Versicherung', 'Versicherungen aller Art', 6),
      ('Sonstiges', 'Andere Ausgaben', 7),
    ];

    for (final (name, description, sortOrder) in defaultCategories) {
      await createExpenseCategory(
        eventId: eventId,
        name: name,
        description: description,
        sortOrder: sortOrder,
        isSystem: true,
      );
    }
  }

  // ===== INCOME SOURCES =====

  /// Alle Einnahmen-Quellen für ein Event
  Stream<List<IncomeSource>> watchIncomeSources(int eventId) {
    return (_db.select(_db.incomeSources)
          ..where((t) => t.eventId.equals(eventId))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  /// Alle Einnahmen-Quellen für ein Event (nicht als Stream)
  Future<List<IncomeSource>> getIncomeSources(int eventId) {
    return (_db.select(_db.incomeSources)
          ..where((t) => t.eventId.equals(eventId))
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  /// Einzelne Quelle
  Future<IncomeSource?> getIncomeSourceById(int id) {
    return (_db.select(_db.incomeSources)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Erstelle Einnahmen-Quelle
  Future<IncomeSource> createIncomeSource({
    required int eventId,
    required String name,
    String? description,
    int sortOrder = 0,
    bool isSystem = false,
  }) async {
    try {
      AppLogger.debug('Creating income source', {
        'eventId': eventId,
        'name': name,
        'isSystem': isSystem,
      });

      final id = await _db.into(_db.incomeSources).insert(
            IncomeSourcesCompanion.insert(
              eventId: eventId,
              name: name,
              description: Value(description),
              sortOrder: Value(sortOrder),
              isSystem: Value(isSystem),
            ),
          );

      AppLogger.info('Income source created successfully', {
        'id': id,
        'name': name,
      });

      return (await getIncomeSourceById(id))!;
    } catch (e, stack) {
      AppLogger.error('Failed to create income source', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update Einnahmen-Quelle
  Future<void> updateIncomeSource({
    required int id,
    String? name,
    String? description,
    int? sortOrder,
  }) async {
    try {
      AppLogger.debug('Updating income source', {'id': id});

      await (_db.update(_db.incomeSources)
            ..where((t) => t.id.equals(id)))
          .write(
        IncomeSourcesCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          description: Value(description),
          sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      AppLogger.info('Income source updated successfully', {'id': id});
    } catch (e, stack) {
      AppLogger.error('Failed to update income source', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Lösche Einnahmen-Quelle (soft delete)
  Future<void> deleteIncomeSource(int id) async {
    try {
      AppLogger.debug('Deleting income source', {'id': id});

      // System-Quellen dürfen nicht gelöscht werden
      final source = await getIncomeSourceById(id);
      if (source?.isSystem == true) {
        AppLogger.warning('Cannot delete system income source', {'id': id});
        throw Exception('System-Quellen können nicht gelöscht werden');
      }

      await (_db.update(_db.incomeSources)
            ..where((t) => t.id.equals(id)))
          .write(
        IncomeSourcesCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      AppLogger.info('Income source soft deleted successfully', {'id': id});
    } catch (e, stack) {
      AppLogger.error('Failed to delete income source', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Initialisiere Standard-Quellen für ein neues Event
  Future<void> initializeDefaultIncomeSources(int eventId) async {
    final defaultSources = [
      ('Teilnehmerbeitrag', 'Beiträge der Teilnehmer', 1),
      ('Spende', 'Geldspenden', 2),
      ('Zuschuss', 'Zuschüsse und Förderungen', 3),
      ('Sponsoring', 'Sponsoring-Einnahmen', 4),
      ('Merchandise', 'Verkauf von Merchandise', 5),
      ('Sonstiges', 'Andere Einnahmen', 6),
    ];

    for (final (name, description, sortOrder) in defaultSources) {
      await createIncomeSource(
        eventId: eventId,
        name: name,
        description: description,
        sortOrder: sortOrder,
        isSystem: true,
      );
    }
  }
}
