import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../utils/logger.dart';
import '../../utils/exceptions.dart';

class RoleRepository {
  final AppDatabase _database;

  RoleRepository(this._database);

  /// Get all roles for a specific event
  Stream<List<Role>> watchRolesByEvent(int eventId) {
    return (_database.select(_database.roles)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// Get a single role by ID
  Future<Role?> getRoleById(int id) async {
    return await (_database.select(_database.roles)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get all roles for an event (one-time fetch)
  Future<List<Role>> getRolesByEvent(int eventId) async {
    return await (_database.select(_database.roles)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Get role by name
  Future<Role?> getRoleByName(int eventId, String name) async {
    return await (_database.select(_database.roles)
          ..where((t) => t.eventId.equals(eventId) & t.name.equals(name)))
        .getSingleOrNull();
  }

  /// Create a new role
  Future<int> createRole({
    required int eventId,
    required String name,
    String? displayName,
    String? description,
  }) async {
    try {
      AppLogger.debug('Creating role', {
        'eventId': eventId,
        'name': name,
      });

      // Check if role with same name already exists
      final existing = await getRoleByName(eventId, name);
      if (existing != null) {
        AppLogger.warning('Role with same name already exists', {
          'eventId': eventId,
          'name': name,
        });
        throw ValidationException('Eine Rolle mit diesem Namen existiert bereits');
      }

      final companion = RolesCompanion(
        eventId: Value(eventId),
        name: Value(name),
        displayName: Value(displayName ?? name), // Use name if displayName not provided
        description: Value(description),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );

      final id = await _database.into(_database.roles).insert(companion);

      AppLogger.info('Role created successfully', {
        'id': id,
        'name': name,
      });

      return id;
    } catch (e, stack) {
      AppLogger.error('Failed to create role', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update an existing role
  Future<bool> updateRole({
    required int id,
    String? name,
    String? displayName,
    String? description,
  }) async {
    try {
      AppLogger.debug('Updating role', {'id': id});

      final existing = await getRoleById(id);
      if (existing == null) {
        AppLogger.warning('Role not found for update', {'id': id});
        return false;
      }

      // Check if new name conflicts with another role
      if (name != null && name != existing.name) {
        final conflict = await getRoleByName(existing.eventId, name);
        if (conflict != null && conflict.id != id) {
          AppLogger.warning('Role name conflict during update', {
            'id': id,
            'name': name,
            'conflictId': conflict.id,
          });
          throw ValidationException('Eine Rolle mit diesem Namen existiert bereits');
        }
      }

      final companion = RolesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        displayName: displayName != null ? Value(displayName) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      );

      final success = await (_database.update(_database.roles)
            ..where((t) => t.id.equals(id)))
          .write(companion) >
          0;

      if (success) {
        AppLogger.info('Role updated successfully', {'id': id});
      }

      return success;
    } catch (e, stack) {
      AppLogger.error('Failed to update role', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete a role
  Future<bool> deleteRole(int id) async {
    try {
      AppLogger.debug('Deleting role', {'id': id});

      // Check if role is in use by any participants
      final participantsWithRole = await (_database.select(_database.participants)
            ..where((t) => t.roleId.equals(id)))
          .get();

      if (participantsWithRole.isNotEmpty) {
        AppLogger.warning('Cannot delete role - in use by participants', {
          'id': id,
          'participantCount': participantsWithRole.length,
        });
        throw BusinessRuleException(
          'Diese Rolle kann nicht gelöscht werden, da sie von ${participantsWithRole.length} Teilnehmer(n) verwendet wird',
        );
      }

      final success = await (_database.delete(_database.roles)
            ..where((t) => t.id.equals(id)))
          .go() >
          0;

      if (success) {
        AppLogger.info('Role deleted successfully', {'id': id});
      } else {
        AppLogger.warning('Role not found for deletion', {'id': id});
      }

      return success;
    } catch (e, stack) {
      AppLogger.error('Failed to delete role', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get role statistics
  Future<Map<String, dynamic>> getRoleStatistics(int roleId) async {
    try {
      AppLogger.debug('Getting role statistics', {'roleId': roleId});

      final role = await getRoleById(roleId);
      if (role == null) {
        AppLogger.warning('Role not found for statistics', {'roleId': roleId});
        return {'error': 'Rolle nicht gefunden'};
      }

      // Count participants with this role
      final participants = await (_database.select(_database.participants)
            ..where((t) => t.roleId.equals(roleId) & t.isActive.equals(true)))
          .get();

      final stats = {
        'role': role,
        'participantCount': participants.length,
      };

      AppLogger.info('Role statistics calculated', {
        'roleId': roleId,
        'participantCount': participants.length,
      });

      return stats;
    } catch (e, stack) {
      AppLogger.error('Failed to get role statistics', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get all roles with participant counts
  Future<List<Map<String, dynamic>>> getRolesWithCounts(int eventId) async {
    final roles = await getRolesByEvent(eventId);
    final result = <Map<String, dynamic>>[];

    for (final role in roles) {
      final count = await (_database.select(_database.participants)
            ..where((t) => t.roleId.equals(role.id) & t.isActive.equals(true)))
          .get()
          .then((list) => list.length);

      result.add({
        'role': role,
        'participantCount': count,
      });
    }

    return result;
  }
}
