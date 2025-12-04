import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../services/ruleset_parser_service.dart';
import '../../utils/logger.dart';
import 'participant_repository.dart';

class RulesetRepository {
  final AppDatabase _database;
  final ParticipantRepository? _participantRepository;

  RulesetRepository(this._database, [this._participantRepository]);

  /// Get all rulesets for a specific event
  Stream<List<Ruleset>> watchRulesetsByEvent(int eventId) {
    return (_database.select(_database.rulesets)
          ..where((t) => t.eventId.equals(eventId) & t.isActive.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.validFrom, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get a single ruleset by ID
  Future<Ruleset?> getRulesetById(int id) async {
    return await (_database.select(_database.rulesets)
          ..where((t) => t.id.equals(id) & t.isActive.equals(true)))
        .getSingleOrNull();
  }

  /// Get all rulesets for an event (one-time fetch)
  Future<List<Ruleset>> getRulesetsByEvent(int eventId) async {
    return await (_database.select(_database.rulesets)
          ..where((t) => t.eventId.equals(eventId) & t.isActive.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.validFrom, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get the active ruleset for a given date
  Future<Ruleset?> getActiveRuleset(int eventId, DateTime date) async {
    final rulesets = await (_database.select(_database.rulesets)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.isActive.equals(true) &
              t.validFrom.isSmallerOrEqualValue(date))
          ..orderBy([
            (t) => OrderingTerm(expression: t.validFrom, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .get();

    return rulesets.isEmpty ? null : rulesets.first;
  }

  /// Get the current active ruleset for an event
  Future<Ruleset?> getCurrentRuleset(int eventId) async {
    return getActiveRuleset(eventId, DateTime.now());
  }

  /// Create a new ruleset
  Future<int> createRuleset({
    required int eventId,
    required String name,
    required String yamlContent,
    required DateTime validFrom,
    DateTime? validUntil,
    String? description,
  }) async {
    // Validate and parse YAML content
    Map<String, dynamic> parsedData;
    try {
      parsedData = RulesetParserService.parseRuleset(yamlContent);
    } catch (e) {
      throw Exception('Ungültiger YAML-Inhalt: $e');
    }

    // Convert parsed data to JSON strings for storage
    final ageGroupsJson = jsonEncode(parsedData['age_groups']);
    final roleDiscountsJson = jsonEncode(parsedData['role_discounts']);
    final familyDiscountJson = jsonEncode(parsedData['family_discount']);

    final companion = RulesetsCompanion(
      eventId: Value(eventId),
      name: Value(name),
      yamlContent: Value(yamlContent),
      ageGroups: Value(ageGroupsJson),
      roleDiscounts: Value(roleDiscountsJson),
      familyDiscount: Value(familyDiscountJson),
      validFrom: Value(validFrom),
      validUntil: Value(validUntil),
      description: Value(description),
      isActive: const Value(true),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    final id = await _database.into(_database.rulesets).insert(companion);
    AppLogger.info('[RulesetRepository] Created ruleset $id with parsed JSON fields');
    return id;
  }

  /// Update an existing ruleset
  Future<bool> updateRuleset({
    required int id,
    String? name,
    String? yamlContent,
    DateTime? validFrom,
    String? description,
  }) async {
    final existing = await getRulesetById(id);
    if (existing == null) {
      return false;
    }

    // If YAML content is being updated, validate and parse it
    String? ageGroupsJson;
    String? roleDiscountsJson;
    String? familyDiscountJson;

    if (yamlContent != null) {
      try {
        final parsedData = RulesetParserService.parseRuleset(yamlContent);
        ageGroupsJson = jsonEncode(parsedData['age_groups']);
        roleDiscountsJson = jsonEncode(parsedData['role_discounts']);
        familyDiscountJson = jsonEncode(parsedData['family_discount']);
      } catch (e) {
        throw Exception('Ungültiger YAML-Inhalt: $e');
      }
    }

    final companion = RulesetsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      yamlContent: yamlContent != null ? Value(yamlContent) : const Value.absent(),
      ageGroups: ageGroupsJson != null ? Value(ageGroupsJson) : const Value.absent(),
      roleDiscounts: roleDiscountsJson != null ? Value(roleDiscountsJson) : const Value.absent(),
      familyDiscount: familyDiscountJson != null ? Value(familyDiscountJson) : const Value.absent(),
      validFrom: validFrom != null ? Value(validFrom) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    final rowsAffected = await (_database.update(_database.rulesets)
          ..where((t) => t.id.equals(id)))
        .write(companion);

    if (rowsAffected > 0) {
      AppLogger.info('[RulesetRepository] Updated ruleset $id with parsed JSON fields');
    }
    return rowsAffected > 0;
  }

  /// Soft delete a ruleset
  Future<bool> deleteRuleset(int id) async {
    final existing = await getRulesetById(id);
    if (existing == null) {
      return false;
    }

    return await (_database.update(_database.rulesets)
          ..where((t) => t.id.equals(id)))
        .write(
      RulesetsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    ) >
        0;
  }

  /// Permanently delete a ruleset (hard delete)
  Future<bool> permanentlyDeleteRuleset(int id) async {
    return await (_database.delete(_database.rulesets)
          ..where((t) => t.id.equals(id)))
        .go() >
        0;
  }

  /// Parse and validate a ruleset's YAML content
  Map<String, dynamic> parseRulesetYaml(String yamlContent) {
    return RulesetParserService.parseRuleset(yamlContent);
  }

  /// Get a ruleset with parsed data
  Future<Map<String, dynamic>?> getRulesetWithParsedData(int id) async {
    final ruleset = await getRulesetById(id);
    if (ruleset == null) {
      return null;
    }

    try {
      final parsedData = RulesetParserService.parseRuleset(ruleset.yamlContent);
      return {
        'ruleset': ruleset,
        'parsed': parsedData,
      };
    } catch (e) {
      return {
        'ruleset': ruleset,
        'error': e.toString(),
      };
    }
  }

  /// Clone a ruleset with a new valid_from date
  Future<int> cloneRuleset({
    required int sourceId,
    required DateTime newValidFrom,
    String? newName,
  }) async {
    final source = await getRulesetById(sourceId);
    if (source == null) {
      throw Exception('Quell-Regelwerk nicht gefunden');
    }

    final name = newName ?? '${source.name} (Kopie)';

    return createRuleset(
      eventId: source.eventId,
      name: name,
      yamlContent: source.yamlContent,
      validFrom: newValidFrom,
      description: source.description,
    );
  }

  /// Get ruleset statistics
  Future<Map<String, dynamic>> getRulesetStatistics(int rulesetId) async {
    final ruleset = await getRulesetById(rulesetId);
    if (ruleset == null) {
      return {
        'error': 'Regelwerk nicht gefunden',
      };
    }

    try {
      final parsed = RulesetParserService.parseRuleset(ruleset.yamlContent);

      return {
        'name': ruleset.name,
        'validFrom': ruleset.validFrom,
        'ageGroupCount': (parsed['age_groups'] as List).length,
        'roleDiscountCount': (parsed['role_discounts'] as Map<String, dynamic>).length,
        'hasFamilyDiscount': parsed['family_discount'] != null,
        'parsed': parsed,
      };
    } catch (e) {
      return {
        'error': 'Fehler beim Parsen: $e',
      };
    }
  }

  /// Create a default ruleset template
  String getDefaultRulesetTemplate() {
    return '''name: "Neues Regelwerk"
valid_from: ${DateTime.now().toIso8601String().split('T')[0]}

age_groups:
  - name: "Kinder"
    min_age: 0
    max_age: 12
    base_price: 150.00
  - name: "Jugendliche"
    min_age: 13
    max_age: 17
    base_price: 180.00
  - name: "Erwachsene"
    min_age: 18
    max_age: 999
    base_price: 200.00

role_discounts:
  - role_name: "Mitarbeiter"
    discount_percent: 50.0
  - role_name: "Leitung"
    discount_percent: 100.0

family_discount:
  min_children: 2
  discount_percent_per_child:
    - children_count: 2
      discount_percent: 10.0
    - children_count: 3
      discount_percent: 15.0
    - children_count: 4
      discount_percent: 20.0
''';
  }

  /// Activate a ruleset and deactivate all others for the same event
  ///
  /// This will:
  /// 1. Deactivate all other rulesets for the event
  /// 2. Activate the selected ruleset
  /// 3. Recalculate all participant prices with the new ruleset
  Future<void> activateRuleset(int rulesetId) async {
    AppLogger.info('[RulesetRepository] Activating ruleset $rulesetId');

    // Get the ruleset to activate
    final ruleset = await (_database.select(_database.rulesets)
          ..where((t) => t.id.equals(rulesetId)))
        .getSingleOrNull();

    if (ruleset == null) {
      throw Exception('Ruleset $rulesetId not found');
    }

    final eventId = ruleset.eventId;

    // Step 1: Deactivate all rulesets for this event
    await (_database.update(_database.rulesets)
          ..where((t) => t.eventId.equals(eventId)))
        .write(
      RulesetsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );

    AppLogger.info('[RulesetRepository] Deactivated all rulesets for event $eventId');

    // Step 2: Activate the selected ruleset
    await (_database.update(_database.rulesets)
          ..where((t) => t.id.equals(rulesetId)))
        .write(
      RulesetsCompanion(
        isActive: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );

    AppLogger.info('[RulesetRepository] Activated ruleset $rulesetId');

    // Step 3: Recalculate all participant prices
    if (_participantRepository != null) {
      await _recalculateAllParticipantPrices(eventId);
      AppLogger.info('[RulesetRepository] Recalculated all participant prices for event $eventId');
    } else {
      AppLogger.warning('[RulesetRepository] ParticipantRepository not provided, skipping price recalculation');
    }
  }

  /// Recalculate prices for all participants in an event
  Future<void> _recalculateAllParticipantPrices(int eventId) async {
    if (_participantRepository == null) return;

    AppLogger.info('[RulesetRepository] Recalculating all participant prices for event $eventId');

    // Get all active participants for the event
    final participants = await (_database.select(_database.participants)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();

    AppLogger.info('[RulesetRepository] Found ${participants.length} participants to recalculate');

    int recalculatedCount = 0;
    int skippedCount = 0;

    for (var participant in participants) {
      // Skip participants with manual price override
      if (participant.manualPriceOverride != null) {
        AppLogger.debug('[RulesetRepository] Skipping ${participant.firstName} ${participant.lastName} (manual price override)');
        skippedCount++;
        continue;
      }

      try {
        // Use the updateParticipant method to recalculate price
        await _participantRepository.updateParticipant(
          id: participant.id,
          recalculatePrice: true,
        );
        recalculatedCount++;
      } catch (e) {
        AppLogger.error('[RulesetRepository] Failed to recalculate price for participant ${participant.id}', error: e);
      }
    }

    AppLogger.info('[RulesetRepository] Price recalculation complete: $recalculatedCount recalculated, $skippedCount skipped');
  }
}
