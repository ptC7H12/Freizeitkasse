import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../utils/logger.dart';

class SettingsRepository {
  final AppDatabase _database;

  SettingsRepository(this._database);

  /// Get settings for an event
  Future<Setting?> getSettingsByEventId(int eventId) async {
    try {
      final setting = await (_database.select(_database.settings)
            ..where((tbl) => tbl.eventId.equals(eventId)))
          .getSingleOrNull();

      AppLogger.debug('Settings loaded for event $eventId', setting);
      return setting;
    } catch (e, stack) {
      AppLogger.error('Failed to load settings for event $eventId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Create default settings for an event
  Future<int> createDefaultSettings({required int eventId}) async {
    try {
      final id = await _database.into(_database.settings).insert(
        SettingsCompanion.insert(
          eventId: eventId,
          organizationName: const Value(null),
          organizationStreet: const Value(null),
          organizationPostalCode: const Value(null),
          organizationCity: const Value(null),
          bankName: const Value(null),
          iban: const Value(null),
          bic: const Value(null),
          invoiceFooter: const Value(null),
          // Default GitHub ruleset path
          githubRulesetPath: const Value('https://raw.githubusercontent.com/ptC7H12/Freizeitkasse/master/rulesets/valid'),
        ),
      );

      AppLogger.info('Default settings created for event $eventId', id);
      return id;
    } catch (e, stack) {
      AppLogger.error('Failed to create default settings', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update settings
  Future<bool> updateSettings({
    required int eventId,
    String? organizationName,
    String? organizationStreet,
    String? organizationPostalCode,
    String? organizationCity,
    String? bankName,
    String? iban,
    String? bic,
    String? invoiceFooter,
    String? githubRulesetPath,
  }) async {
    try {
      // Check if settings exist
      final existing = await getSettingsByEventId(eventId);

      if (existing == null) {
        // Create new settings
        await _database.into(_database.settings).insert(
          SettingsCompanion.insert(
            eventId: eventId,
            organizationName: Value(organizationName),
            organizationStreet: Value(organizationStreet),
            organizationPostalCode: Value(organizationPostalCode),
            organizationCity: Value(organizationCity),
            bankName: Value(bankName),
            iban: Value(iban),
            bic: Value(bic),
            invoiceFooter: Value(invoiceFooter),
            githubRulesetPath: Value(githubRulesetPath),
          ),
        );
      } else {
        // Update existing settings
        await (_database.update(_database.settings)
              ..where((tbl) => tbl.eventId.equals(eventId)))
            .write(
          SettingsCompanion(
            organizationName: Value(organizationName),
            organizationStreet: Value(organizationStreet),
            organizationPostalCode: Value(organizationPostalCode),
            organizationCity: Value(organizationCity),
            bankName: Value(bankName),
            iban: Value(iban),
            bic: Value(bic),
            invoiceFooter: Value(invoiceFooter),
            githubRulesetPath: Value(githubRulesetPath),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      AppLogger.info('Settings updated for event $eventId');
      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to update settings', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Get or create settings for an event
  Future<Setting> getOrCreateSettings(int eventId) async {
    try {
      var setting = await getSettingsByEventId(eventId);

      if (setting == null) {
        final id = await createDefaultSettings(eventId: eventId);
        setting = await (_database.select(_database.settings)
              ..where((tbl) => tbl.id.equals(id)))
            .getSingle();
      }

      return setting;
    } catch (e, stack) {
      AppLogger.error('Failed to get or create settings', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Watch settings for an event (reactive)
  Stream<Setting?> watchSettingsByEventId(int eventId) {
    return (_database.select(_database.settings)
          ..where((tbl) => tbl.eventId.equals(eventId)))
        .watchSingleOrNull();
  }
}
