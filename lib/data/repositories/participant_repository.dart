import 'dart:convert';
import 'package:drift/drift.dart';
import '../../utils/logger.dart';
import '../database/app_database.dart';
import '../../services/price_calculator_service.dart';
import '../../utils/date_utils.dart';

/// Repository für Teilnehmer-CRUD-Operationen
///
/// Kapselt alle Datenbank-Zugriffe für Participants
class ParticipantRepository {
  final AppDatabase _db;

  ParticipantRepository(this._db);

  // ============================================================================
  // READ OPERATIONS
  // ============================================================================

  /// Alle aktiven Teilnehmer eines Events
  Stream<List<Participant>> watchParticipantsByEvent(int eventId) {
    return (_db.select(_db.participants)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.lastName)]))
        .watch();
  }

  /// Einzelner Teilnehmer nach ID
  Future<Participant?> getParticipantById(int id) {
    return (_db.select(_db.participants)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Stream für einzelnen Teilnehmer (reaktiv)
  Stream<Participant?> watchParticipantById(int id) {
    return (_db.select(_db.participants)..where((tbl) => tbl.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Alle Teilnehmer einer Familie
  Future<List<Participant>> getParticipantsByFamily(int familyId) {
    return (_db.select(_db.participants)
          ..where((tbl) => tbl.familyId.equals(familyId))
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.birthDate)]))
        .get();
  }

  /// Anzahl aktiver Teilnehmer eines Events
  Future<int> getParticipantCount(int eventId) async {
    final query = _db.selectOnly(_db.participants)
      ..addColumns([_db.participants.id.count()])
      ..where(_db.participants.eventId.equals(eventId))
      ..where(_db.participants.isActive.equals(true));

    final result = await query.getSingle();
    return result.read(_db.participants.id.count()) ?? 0;
  }

  /// Suche Teilnehmer nach Name
  Stream<List<Participant>> searchParticipants(int eventId, String query) {
    final searchLower = query.toLowerCase();
    return (_db.select(_db.participants)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..where((tbl) => tbl.isActive.equals(true))
          ..where(
            (tbl) =>
                tbl.firstName.lower().like('%$searchLower%') |
                tbl.lastName.lower().like('%$searchLower%'),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.lastName)]))
        .watch();
  }

  // ============================================================================
  // CREATE OPERATION
  // ============================================================================

  /// Erstelle neuen Teilnehmer
  ///
  /// Berechnet automatisch den Preis basierend auf Event und Regelwerk
  Future<int> createParticipant({
    required int eventId,
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    String? gender,
    String? street,
    String? postalCode,
    String? city,
    String? phone,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? medications,
    String? allergies,
    String? dietaryRestrictions,
    String? notes,
    bool bildungUndTeilhabe = false,
    int? roleId,
    int? familyId,
    double? manualPriceOverride,
    double discountPercent = 0.0,
    String? discountReason,
  }) async {
    // Preis berechnen
    final calculatedPrice = await _calculatePrice(
      eventId: eventId,
      birthDate: birthDate,
      roleId: roleId,
      familyId: familyId,
    );

    final companion = ParticipantsCompanion.insert(
      eventId: eventId,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      gender: Value(gender),
      street: Value(street),
      postalCode: Value(postalCode),
      city: Value(city),
      phone: Value(phone),
      email: Value(email),
      emergencyContactName: Value(emergencyContactName),
      emergencyContactPhone: Value(emergencyContactPhone),
      medications: Value(medications),
      allergies: Value(allergies),
      dietaryRestrictions: Value(dietaryRestrictions),
      notes: Value(notes),
      bildungUndTeilhabe: Value(bildungUndTeilhabe),
      calculatedPrice: Value(calculatedPrice),
      manualPriceOverride: Value(manualPriceOverride),
      discountPercent: Value(discountPercent),
      discountReason: Value(discountReason),
      roleId: Value(roleId),
      familyId: Value(familyId),
    );

    final participantId = await _db.into(_db.participants).insert(companion);

    // Preise aller Familienmitglieder neu berechnen (da sich Anzahl ändert)
    if (familyId != null) {
      await recalculateFamilyPrices(familyId);
    }

    return participantId;
  }

  // ============================================================================
  // UPDATE OPERATION
  // ============================================================================

  /// Aktualisiere Teilnehmer
  ///
  /// Berechnet Preis neu wenn sich relevante Felder ändern
  Future<bool> updateParticipant({
    required int id,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? gender,
    String? street,
    String? postalCode,
    String? city,
    String? phone,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? medications,
    String? allergies,
    String? dietaryRestrictions,
    String? notes,
    bool? bildungUndTeilhabe,
    int? roleId,
    int? familyId,
    double? manualPriceOverride,
    double? discountPercent,
    String? discountReason,
    bool recalculatePrice = true,
  }) async {
    final existing = await getParticipantById(id);
    if (existing == null) {
      return false;
    }

    double? newCalculatedPrice;

    // Preis neu berechnen wenn sich relevante Felder ändern
    if (recalculatePrice &&
        manualPriceOverride == null &&
        (birthDate != null ||
            roleId != null ||
            familyId != null ||
            roleId != existing.roleId ||
            familyId != existing.familyId)) {
      newCalculatedPrice = await _calculatePrice(
        eventId: existing.eventId,
        birthDate: birthDate ?? existing.birthDate,
        roleId: roleId ?? existing.roleId,
        familyId: familyId ?? existing.familyId,
      );
    }

    final companion = ParticipantsCompanion(
      id: Value(id),
      firstName: firstName != null ? Value(firstName) : const Value.absent(),
      lastName: lastName != null ? Value(lastName) : const Value.absent(),
      birthDate: birthDate != null ? Value(birthDate) : const Value.absent(),
      gender: gender != null ? Value(gender) : const Value.absent(),
      street: street != null ? Value(street) : const Value.absent(),
      postalCode: postalCode != null ? Value(postalCode) : const Value.absent(),
      city: city != null ? Value(city) : const Value.absent(),
      phone: phone != null ? Value(phone) : const Value.absent(),
      email: email != null ? Value(email) : const Value.absent(),
      emergencyContactName:
          emergencyContactName != null ? Value(emergencyContactName) : const Value.absent(),
      emergencyContactPhone:
          emergencyContactPhone != null ? Value(emergencyContactPhone) : const Value.absent(),
      medications:
          medications != null ? Value(medications) : const Value.absent(),
      allergies: allergies != null ? Value(allergies) : const Value.absent(),
      dietaryRestrictions: dietaryRestrictions != null
          ? Value(dietaryRestrictions)
          : const Value.absent(),
      notes:
          notes != null ? Value(notes) : const Value.absent(),
      bildungUndTeilhabe: bildungUndTeilhabe != null
          ? Value(bildungUndTeilhabe)
          : const Value.absent(),
      roleId: Value(roleId),
      familyId: Value(familyId),
      manualPriceOverride: Value(manualPriceOverride),
      discountPercent:
          discountPercent != null ? Value(discountPercent) : const Value.absent(),
      discountReason:
          discountReason != null ? Value(discountReason) : const Value.absent(),
      calculatedPrice:
          newCalculatedPrice != null ? Value(newCalculatedPrice) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    final success = await _db.update(_db.participants).replace(companion);

    // Preise aller Familienmitglieder neu berechnen wenn Familie geändert wurde
    if (success) {
      // Alte Familie neu berechnen (wenn vorhanden)
      if (existing.familyId != null && existing.familyId != familyId) {
        await recalculateFamilyPrices(existing.familyId!);
      }

      // Neue Familie neu berechnen (wenn vorhanden)
      if (familyId != null) {
        await recalculateFamilyPrices(familyId);
      }
    }

    return success;
  }

  // ============================================================================
  // DELETE OPERATION (Soft Delete)
  // ============================================================================

  /// Soft-Delete: Setzt isActive=false und deletedAt
  Future<bool> deleteParticipant(int id) async {
    try {
      // Teilnehmer laden um familyId zu bekommen
      final participant = await getParticipantById(id);

      final rowsAffected = await (_db.update(_db.participants)
            ..where((tbl) => tbl.id.equals(id)))
          .write(
        const ParticipantsCompanion(
          isActive: Value(false),
          deletedAt: Value.absentIfNull(null), // Will be set by trigger or default
          updatedAt: Value.absentIfNull(null), // Will be set by trigger or default
        ).copyWith(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      AppLogger.info('Soft-deleted participant', {'id': id, 'rowsAffected': rowsAffected});

      // Preise der verbleibenden Familienmitglieder neu berechnen
      if (rowsAffected > 0 && participant?.familyId != null) {
        await recalculateFamilyPrices(participant!.familyId!);
      }

      return rowsAffected > 0;
    } catch (e, stack) {
      AppLogger.error('Failed to delete participant', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Hard-Delete: Löscht tatsächlich aus DB (nur für Tests!)
  Future<int> hardDeleteParticipant(int id) {
    return (_db.delete(_db.participants)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Reaktiviere gelöschten Teilnehmer
  Future<bool> restoreParticipant(int id) async {
    final companion = ParticipantsCompanion(
      id: Value(id),
      isActive: const Value(true),
      deletedAt: const Value(null),
      updatedAt: Value(DateTime.now()),
    );

    return await _db.update(_db.participants).replace(companion);
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Berechnet Preis für Teilnehmer
  Future<double> _calculatePrice({
    required int eventId,
    required DateTime birthDate,
    int? roleId,
    int? familyId,
  }) async {
    // Event laden
    final event = await (_db.select(_db.events)
          ..where((tbl) => tbl.id.equals(eventId)))
        .getSingleOrNull();

    if (event == null) {
      return 0.0;
    }

    // Aktives Regelwerk für Event finden
    final ruleset = await (_db.select(_db.rulesets)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..where((tbl) => tbl.isActive.equals(true))
          ..where((tbl) => tbl.validFrom.isSmallerOrEqualValue(event.startDate))
          ..where((tbl) =>
              tbl.validUntil.isNull() |
              tbl.validUntil.isBiggerOrEqualValue(event.startDate)))
        .getSingleOrNull();

    if (ruleset == null) {
      AppLogger.error('[ParticipantRepository] Kein aktives Regelwerk gefunden für Event $eventId (startDate: ${event.startDate})');

      // Debug: Alle Rulesets für Event anzeigen
      final allRulesets = await (_db.select(_db.rulesets)
            ..where((tbl) => tbl.eventId.equals(eventId)))
          .get();
      AppLogger.debug('[ParticipantRepository] Verfügbare Rulesets: ${allRulesets.length}');
      for (var r in allRulesets) {
        AppLogger.debug('[ParticipantRepository] - ${r.name}: isActive=${r.isActive}, validFrom=${r.validFrom}, validUntil=${r.validUntil}');
      }

      return 0.0;
    }

    // Alter zum Event-Start berechnen
    final age = AppDateUtils.calculateAgeAtEventStart(birthDate, event.startDate);

    // Rolle laden (falls vorhanden)
    String? roleName;
    if (roleId != null) {
      final role = await (_db.select(_db.roles)
            ..where((tbl) => tbl.id.equals(roleId)))
          .getSingleOrNull();
      roleName = role?.name.toLowerCase();
    }

    // Position in Familie ermitteln (basierend auf Geburtsdatum)
    int familyChildrenCount = 1;
    if (familyId != null) {
      // Alle Geschwister inkl. neuem Teilnehmer laden und nach Geburtsdatum sortieren
      final siblings = await (_db.select(_db.participants)
            ..where((tbl) => tbl.familyId.equals(familyId))
            ..where((tbl) => tbl.isActive.equals(true))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.birthDate)]))
          .get();

      // Position des Kindes in sortierter Liste finden
      // Kinder mit gleichem oder früherem Geburtsdatum zählen
      familyChildrenCount = 1;
      for (var sibling in siblings) {
        if (sibling.birthDate.isBefore(birthDate) ||
            sibling.birthDate.isAtSameMomentAs(birthDate)) {
          familyChildrenCount++;
        }
      }
    }

    // Preis berechnen mit PriceCalculatorService
    final rulesetData = {
      'age_groups': _parseJsonField(ruleset.ageGroups),
      'role_discounts': _parseJsonField(ruleset.roleDiscounts),
      'family_discount': _parseJsonField(ruleset.familyDiscount),
    };

    return PriceCalculatorService.calculateParticipantPrice(
      age: age,
      roleName: roleName,
      rulesetData: rulesetData,
      familyChildrenCount: familyChildrenCount,
    );
  }

  /// Parse JSON-String zu Map/List (Drift speichert JSON als TEXT)
  dynamic _parseJsonField(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty || jsonString == 'null') {
      return <String, dynamic>{};
    }

    try {
      final parsed = jsonDecode(jsonString);
      return parsed;
    } catch (e) {
      AppLogger.error('[ParticipantRepository] Failed to parse JSON field', error: e);
      return <String, dynamic>{};
    }
  }

  /// Gibt den finalen Anzeigepreis zurück (manualPriceOverride oder calculatedPrice)
  double getDisplayPrice(Participant participant) {
    return participant.manualPriceOverride ?? participant.calculatedPrice;
  }

  /// Berechnet Preise aller Familienmitglieder neu
  ///
  /// Sollte aufgerufen werden wenn:
  /// - Ein neues Familienmitglied hinzugefügt wird
  /// - Ein Familienmitglied entfernt wird
  /// - Die Familie eines Teilnehmers geändert wird
  ///
  /// Ignoriert Teilnehmer mit manual_price_override
  Future<void> recalculateFamilyPrices(int familyId) async {
    AppLogger.info('[ParticipantRepository] Recalculating prices for family $familyId');

    // Alle aktiven Familienmitglieder laden
    final members = await (_db.select(_db.participants)
          ..where((tbl) => tbl.familyId.equals(familyId))
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();

    if (members.isEmpty) {
      AppLogger.info('[ParticipantRepository] No family members found for family $familyId');
      return;
    }

    // Event-ID vom ersten Mitglied nehmen (alle sollten gleich sein)
    final eventId = members.first.eventId;

    for (var member in members) {
      // Nur Teilnehmer ohne manuelle Preisanpassung neu berechnen
      if (member.manualPriceOverride != null) {
        AppLogger.debug('[ParticipantRepository] Skipping ${member.firstName} ${member.lastName} (manual price override)');
        continue;
      }

      // Preis neu berechnen
      final newPrice = await _calculatePrice(
        eventId: eventId,
        birthDate: member.birthDate,
        roleId: member.roleId,
        familyId: familyId,
      );

      // Preis aktualisieren
      await (_db.update(_db.participants)..where((tbl) => tbl.id.equals(member.id))).write(
        ParticipantsCompanion(
          calculatedPrice: Value(newPrice),
          updatedAt: Value(DateTime.now()),
        ),
      );

      AppLogger.debug('[ParticipantRepository] Updated price for ${member.firstName} ${member.lastName}: $newPrice€');
    }

    AppLogger.info('[ParticipantRepository] Recalculated prices for ${members.length} family members');
  }

  /// Berechnet Gesamtsumme aller Teilnehmerpreise eines Events
  Future<double> getTotalRevenue(int eventId) async {
    final participants = await (_db.select(_db.participants)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();

    return participants.fold<double>(
      0.0,
      (sum, p) => sum + getDisplayPrice(p),
    );
  }
}
