import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../utils/logger.dart';

/// Repository für Familien-CRUD-Operationen
class FamilyRepository {
  final AppDatabase _db;

  FamilyRepository(this._db);

  // READ
  Stream<List<Family>> watchFamiliesByEvent(int eventId) {
    return (_db.select(_db.families)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.familyName)]))
        .watch();
  }

  Future<Family?> getFamilyById(int id) {
    return (_db.select(_db.families)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> getFamilyCount(int eventId) async {
    final query = _db.selectOnly(_db.families)
      ..addColumns([_db.families.id.count()])
      ..where(_db.families.eventId.equals(eventId));

    final result = await query.getSingle();
    return result.read(_db.families.id.count()) ?? 0;
  }

  // CREATE
  Future<int> createFamily({
    required int eventId,
    required String familyName,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      AppLogger.debug('Creating family', {
        'eventId': eventId,
        'familyName': familyName,
      });

      final id = await _db.into(_db.families).insert(
            FamiliesCompanion.insert(
              eventId: eventId,
              familyName: familyName,
              contactPerson: Value(contactPerson),
              phone: Value(phone),
              email: Value(email),
              address: Value(address),
            ),
          );

      AppLogger.info('Family created successfully', {
        'id': id,
        'familyName': familyName,
      });

      return id;
    } catch (e, stack) {
      AppLogger.error('Failed to create family', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // UPDATE
  Future<bool> updateFamily({
    required int id,
    String? familyName,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      AppLogger.debug('Updating family', {'id': id});

      final success = await (_db.update(_db.families)
            ..where((t) => t.id.equals(id)))
          .write(
            FamiliesCompanion(
              familyName:
                  familyName != null ? Value(familyName) : const Value.absent(),
              contactPerson:
                  contactPerson != null ? Value(contactPerson) : const Value.absent(),
              phone: phone != null ? Value(phone) : const Value.absent(),
              email: email != null ? Value(email) : const Value.absent(),
              address: address != null ? Value(address) : const Value.absent(),
              updatedAt: Value(DateTime.now()),
            ),
          ) >
          0;

      if (success) {
        AppLogger.info('Family updated successfully', {'id': id});
      } else {
        AppLogger.warning('Family not found for update', {'id': id});
      }

      return success;
    } catch (e, stack) {
      AppLogger.error('Failed to update family', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // DELETE
  Future<int> deleteFamily(int id) async {
    try {
      AppLogger.debug('Deleting family', {'id': id});

      final rowsDeleted = await (_db.delete(_db.families)..where((tbl) => tbl.id.equals(id))).go();

      if (rowsDeleted > 0) {
        AppLogger.info('Family deleted successfully', {'id': id, 'rowsDeleted': rowsDeleted});
      } else {
        AppLogger.warning('Family not found for deletion', {'id': id});
      }

      return rowsDeleted;
    } catch (e, stack) {
      AppLogger.error('Failed to delete family', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // Get members of family
  Future<List<Participant>> getFamilyMembers(int familyId) {
    return (_db.select(_db.participants)
          ..where((tbl) => tbl.familyId.equals(familyId))
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();
  }

  // Calculate total family price
  Future<double> getFamilyTotalPrice(int familyId) async {
    try {
      AppLogger.debug('Calculating family total price', {'familyId': familyId});

      final members = await getFamilyMembers(familyId);
      final totalPrice = members.fold<double>(
        0.0,
        (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
      );

      AppLogger.info('Family total price calculated', {
        'familyId': familyId,
        'memberCount': members.length,
        'totalPrice': totalPrice,
      });

      return totalPrice;
    } catch (e, stack) {
      AppLogger.error('Failed to calculate family total price', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
