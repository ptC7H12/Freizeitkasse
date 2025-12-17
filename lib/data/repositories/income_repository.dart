import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../utils/logger.dart';

class IncomeRepository {
  final AppDatabase _database;

  IncomeRepository(this._database);

  /// Get all incomes for a specific event
  Stream<List<Income>> watchIncomesByEvent(int eventId) {
    return (_database.select(_database.incomes)
          ..where((t) => t.eventId.equals(eventId) & t.isActive.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.incomeDate, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get a single income by ID
  Future<Income?> getIncomeById(int id) async {
    return await (_database.select(_database.incomes)
          ..where((t) => t.id.equals(id) & t.isActive.equals(true)))
        .getSingleOrNull();
  }

  /// Get all incomes for an event (one-time fetch)
  Future<List<Income>> getIncomesByEvent(int eventId) async {
    return await (_database.select(_database.incomes)
          ..where((t) => t.eventId.equals(eventId) & t.isActive.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.incomeDate, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get total incomes for an event
  Future<double> getTotalIncomes(int eventId) async {
    final result = await _database.customSelect(
      'SELECT COALESCE(SUM(amount), 0) as total FROM incomes WHERE event_id = ? AND is_active = 1',
      variables: [Variable.withInt(eventId)],
      readsFrom: {_database.incomes},
    ).getSingle();

    return result.read<double>('total');
  }

  /// Get incomes by category
  Future<Map<String, double>> getIncomesByCategory(int eventId) async {
    final results = await _database.customSelect(
      'SELECT category, SUM(amount) as total FROM incomes WHERE event_id = ? AND is_active = 1 GROUP BY category',
      variables: [Variable.withInt(eventId)],
      readsFrom: {_database.incomes},
    ).get();

    return {
      for (final row in results)
        row.read<String>('category'): row.read<double>('total')
    };
  }

  /// Get incomes within a date range
  Future<List<Income>> getIncomesByDateRange(
    int eventId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await (_database.select(_database.incomes)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.isActive.equals(true) &
              t.incomeDate.isBiggerOrEqualValue(startDate) &
              t.incomeDate.isSmallerOrEqualValue(endDate))
          ..orderBy([
            (t) => OrderingTerm(expression: t.incomeDate, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Create a new income
  Future<int> createIncome({
    required int eventId,
    required String category,
    required double amount,
    required DateTime incomeDate,
    String? description,
    String? source,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    try {
      AppLogger.debug('Creating income', {
        'eventId': eventId,
        'category': category,
        'amount': amount,
        'source': source,
      });

      final companion = IncomesCompanion(
        eventId: Value(eventId),
        category: Value(category),
        source: Value(source),
        amount: Value(amount),
        incomeDate: Value(incomeDate),
        description: Value(description),
        paymentMethod: Value(paymentMethod),
        referenceNumber: Value(referenceNumber),
        notes: Value(notes),
        isActive: const Value(true),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );

      final id = await _database.into(_database.incomes).insert(companion);

      AppLogger.info('Income created successfully', {'id': id, 'amount': amount});
      return id;
    } catch (e, stack) {
      AppLogger.error('Failed to create income', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update an existing income
  Future<bool> updateIncome({
    required int id,
    String? category,
    String? source,
    double? amount,
    DateTime? incomeDate,
    String? description,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    try {
      AppLogger.debug('Updating income', {'id': id});

      final existing = await getIncomeById(id);
      if (existing == null) {
        AppLogger.warning('Income not found for update', {'id': id});
        return false;
      }

      final companion = IncomesCompanion(
        category: category != null ? Value(category) : const Value.absent(),
        source: source != null ? Value(source) : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        incomeDate: incomeDate != null ? Value(incomeDate) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        paymentMethod: paymentMethod != null ? Value(paymentMethod) : const Value.absent(),
        referenceNumber: referenceNumber != null ? Value(referenceNumber) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      );

      final success = await (_database.update(_database.incomes)
            ..where((t) => t.id.equals(id)))
          .write(companion) >
          0;

      if (success) {
        AppLogger.info('Income updated successfully', {'id': id});
      }

      return success;
    } catch (e, stack) {
      AppLogger.error('Failed to update income', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Soft delete an income
  Future<bool> deleteIncome(int id) async {
    try {
      AppLogger.debug('Soft deleting income', {'id': id});

      final existing = await getIncomeById(id);
      if (existing == null) {
        AppLogger.warning('Income not found for deletion', {'id': id});
        return false;
      }

      final success = await (_database.update(_database.incomes)
            ..where((t) => t.id.equals(id)))
          .write(
        IncomesCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      ) >
          0;

      if (success) {
        AppLogger.info('Income soft deleted successfully', {'id': id});
      }

      return success;
    } catch (e, stack) {
      AppLogger.error('Failed to delete income', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Permanently delete an income (hard delete)
  Future<bool> permanentlyDeleteIncome(int id) async {
    return await (_database.delete(_database.incomes)
          ..where((t) => t.id.equals(id)))
        .go() >
        0;
  }

  /// Get income statistics for an event
  Future<Map<String, dynamic>> getIncomeStatistics(int eventId) async {
    try {
      AppLogger.debug('Calculating income statistics', {'eventId': eventId});

      final incomes = await getIncomesByEvent(eventId);
      final total = await getTotalIncomes(eventId);
      final byCategory = await getIncomesByCategory(eventId);

      // Find largest income category
      String? largestCategory;
      double maxCategoryAmount = 0;
      byCategory.forEach((category, amount) {
        if (amount > maxCategoryAmount) {
          maxCategoryAmount = amount;
          largestCategory = category;
        }
      });

      final stats = {
        'total': total,
        'count': incomes.length,
        'byCategory': byCategory,
        'largestCategory': largestCategory,
        'largestCategoryAmount': maxCategoryAmount,
        'averageIncome': incomes.isEmpty ? 0.0 : total / incomes.length,
      };

      AppLogger.info('Income statistics calculated', {
        'eventId': eventId,
        'total': total,
        'count': incomes.length,
      });

      return stats;
    } catch (e, stack) {
      AppLogger.error('Failed to calculate income statistics', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Search incomes by description, notes, or category
  Future<List<Income>> searchIncomes(int eventId, String query) async {
    final lowerQuery = query.toLowerCase();

    return await (_database.select(_database.incomes)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.isActive.equals(true) &
              (t.description.lower().like('%$lowerQuery%') |
               t.notes.lower().like('%$lowerQuery%') |
               t.category.lower().like('%$lowerQuery%'))))
        .get();
  }
}
