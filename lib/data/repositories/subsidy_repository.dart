import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../services/subsidy_calculator_service.dart';
import '../../utils/logger.dart';
import '../../utils/exceptions.dart';

/// Repository für Zuschuss-Berechnungen
///
/// Bietet Methoden zur Berechnung und Abfrage von erwarteten Zuschüssen
class SubsidyRepository {
  final AppDatabase _database;

  SubsidyRepository(this._database);

  /// Berechnet die gesamten erwarteten Zuschüsse für ein Event
  ///
  /// Args:
  ///   - eventId: ID des Events
  ///
  /// Returns:
  ///   Gesamtsumme der erwarteten Zuschüsse in Euro
  Future<double> getExpectedSubsidies(int eventId) async {
    try {
      AppLogger.debug('[SubsidyRepository] getExpectedSubsidies() für Event $eventId');

      // Event laden
      final event = await (_database.select(_database.events)
            ..where((tbl) => tbl.id.equals(eventId)))
          .getSingleOrNull();

      if (event == null) {
        throw NotFoundException('Event', eventId);
      }

      // Aktives Ruleset laden
      final ruleset = await _getActiveRuleset(eventId, event.startDate);
      if (ruleset == null) {
        AppLogger.warning('[SubsidyRepository] Kein aktives Ruleset für Event $eventId gefunden');
        return 0.0;
      }

      // Aktive Teilnehmer laden
      final participants = await (_database.select(_database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .get();

      // Alle Rollen laden
      final roles = await (_database.select(_database.roles)
            ..where((tbl) => tbl.eventId.equals(eventId)))
          .get();

      // Zuschüsse berechnen
      final totalSubsidies = SubsidyCalculatorService.calculateExpectedSubsidies(
        event: event,
        ruleset: ruleset,
        participants: participants,
        roles: roles,
      );

      AppLogger.info(
        '[SubsidyRepository] ✓ Erwartete Zuschüsse für Event "$eventId": '
        '${totalSubsidies.toStringAsFixed(2)} €',
      );

      return totalSubsidies;
    } catch (e, stack) {
      AppLogger.error(
        '[SubsidyRepository] Fehler beim Berechnen der erwarteten Zuschüsse',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Stream für erwartete Zuschüsse (reaktiv)
  ///
  /// Aktualisiert sich automatisch bei Änderungen an Teilnehmern, Rollen oder Rulesets
  Stream<double> watchExpectedSubsidies(int eventId) async* {
    AppLogger.debug('[SubsidyRepository] watchExpectedSubsidies() für Event $eventId');

    // Kombiniere Streams für automatische Updates
    await for (final _ in _database.select(_database.participants).watch()) {
      try {
        final subsidies = await getExpectedSubsidies(eventId);
        yield subsidies;
      } catch (e) {
        AppLogger.error('[SubsidyRepository] Fehler beim Berechnen der Zuschüsse', error: e);
        yield 0.0;
      }
    }
  }

  /// Berechnet Zuschüsse aufgeschlüsselt nach Rollen
  ///
  /// Args:
  ///   - eventId: ID des Events
  ///
  /// Returns:
  ///   Map mit Rollen-IDs als Key und Zuschuss-Details als Value
  Future<Map<int, SubsidyByRole>> getSubsidiesByRole(int eventId) async {
    try {
      AppLogger.debug('[SubsidyRepository] getSubsidiesByRole() für Event $eventId');

      // Event laden
      final event = await (_database.select(_database.events)
            ..where((tbl) => tbl.id.equals(eventId)))
          .getSingleOrNull();

      if (event == null) {
        throw NotFoundException('Event', eventId);
      }

      // Aktives Ruleset laden
      final ruleset = await _getActiveRuleset(eventId, event.startDate);
      if (ruleset == null) {
        AppLogger.warning('[SubsidyRepository] Kein aktives Ruleset für Event $eventId');
        return {};
      }

      // Aktive Teilnehmer laden
      final participants = await (_database.select(_database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .get();

      // Alle Rollen laden
      final roles = await (_database.select(_database.roles)
            ..where((tbl) => tbl.eventId.equals(eventId)))
          .get();

      // Zuschüsse nach Rollen berechnen
      final subsidiesByRole = SubsidyCalculatorService.getSubsidiesByRole(
        event: event,
        ruleset: ruleset,
        participants: participants,
        roles: roles,
      );

      AppLogger.info(
        '[SubsidyRepository] ✓ Zuschüsse nach Rollen: ${subsidiesByRole.length} Rollen',
      );

      return subsidiesByRole;
    } catch (e, stack) {
      AppLogger.error(
        '[SubsidyRepository] Fehler beim Berechnen der Zuschüsse nach Rollen',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Berechnet Zuschüsse aufgeschlüsselt nach Rabatttyp
  ///
  /// Args:
  ///   - eventId: ID des Events
  ///
  /// Returns:
  ///   Map mit Rabatttyp als Key und Zuschuss-Details als Value
  Future<Map<String, SubsidyByDiscountType>> getSubsidiesByDiscountType(int eventId) async {
    try {
      AppLogger.debug('[SubsidyRepository] getSubsidiesByDiscountType() für Event $eventId');

      // Event laden
      final event = await (_database.select(_database.events)
            ..where((tbl) => tbl.id.equals(eventId)))
          .getSingleOrNull();

      if (event == null) {
        throw NotFoundException('Event', eventId);
      }

      // Aktives Ruleset laden
      final ruleset = await _getActiveRuleset(eventId, event.startDate);
      if (ruleset == null) {
        AppLogger.warning('[SubsidyRepository] Kein aktives Ruleset für Event $eventId');
        return {};
      }

      // Aktive Teilnehmer laden
      final participants = await (_database.select(_database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true)))
          .get();

      // Zuschüsse nach Rabatttyp berechnen
      final subsidiesByType = SubsidyCalculatorService.getSubsidiesByDiscountType(
        event: event,
        ruleset: ruleset,
        participants: participants,
      );

      AppLogger.info(
        '[SubsidyRepository] ✓ Zuschüsse nach Rabatttyp: ${subsidiesByType.length} Typen',
      );

      return subsidiesByType;
    } catch (e, stack) {
      AppLogger.error(
        '[SubsidyRepository] Fehler beim Berechnen der Zuschüsse nach Rabatttyp',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Lädt alle Teilnehmer mit Zuschüssen für ein Event
  ///
  /// WICHTIG: Nur Teilnehmer OHNE manualPriceOverride und MIT Rabatten
  ///
  /// Args:
  ///   - eventId: ID des Events
  ///
  /// Returns:
  ///   Liste aller Teilnehmer mit Zuschüssen
  Future<List<Participant>> getParticipantsWithSubsidies(int eventId) async {
    try {
      AppLogger.debug('[SubsidyRepository] getParticipantsWithSubsidies() für Event $eventId');

      final participants = await (_database.select(_database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true))
            ..where((tbl) => tbl.manualPriceOverride.isNull())
            ..where((tbl) => tbl.discountPercent.isBiggerThanValue(0)))
          .get();

      // BUT-Teilnehmer ausfiltern (werden separat abgerechnet)
      final subsidyParticipants = participants
          .where((p) => !p.bildungUndTeilhabe)
          .toList();

      AppLogger.info(
        '[SubsidyRepository] ✓ Teilnehmer mit Zuschüssen: ${subsidyParticipants.length}',
      );

      return subsidyParticipants;
    } catch (e, stack) {
      AppLogger.error(
        '[SubsidyRepository] Fehler beim Laden der Teilnehmer mit Zuschüssen',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Lädt Teilnehmer für eine bestimmte Rolle mit Zuschüssen
  ///
  /// Args:
  ///   - eventId: ID des Events
  ///   - roleId: ID der Rolle
  ///
  /// Returns:
  ///   Liste der Teilnehmer mit Zuschüssen für diese Rolle
  Future<List<SubsidyParticipant>> getParticipantsByRole(int eventId, int roleId) async {
    try {
      AppLogger.debug(
        '[SubsidyRepository] getParticipantsByRole() für Event $eventId, Rolle $roleId',
      );

      // Event laden
      final event = await (_database.select(_database.events)
            ..where((tbl) => tbl.id.equals(eventId)))
          .getSingleOrNull();

      if (event == null) {
        throw NotFoundException('Event', eventId);
      }

      // Ruleset laden
      final ruleset = await _getActiveRuleset(eventId, event.startDate);
      if (ruleset == null) {
        throw const BusinessRuleException('Kein aktives Ruleset für Event gefunden');
      }

      // Rolle laden
      final role = await (_database.select(_database.roles)
            ..where((tbl) => tbl.id.equals(roleId)))
          .getSingleOrNull();

      if (role == null) {
        throw NotFoundException('Role', roleId);
      }

      // Teilnehmer mit dieser Rolle laden
      final participants = await (_database.select(_database.participants)
            ..where((tbl) => tbl.eventId.equals(eventId))
            ..where((tbl) => tbl.isActive.equals(true))
            ..where((tbl) => tbl.roleId.equals(roleId))
            ..where((tbl) => tbl.manualPriceOverride.isNull()))
          .get();

      // Rollenconfig aus Ruleset holen (JSON parsen)
      if (ruleset.roleDiscounts == null || ruleset.roleDiscounts!.isEmpty) {
        AppLogger.warning('[SubsidyRepository] Keine Rollenrabatte im Ruleset');
        return [];
      }

      final roleDiscountsMap = jsonDecode(ruleset.roleDiscounts!) as Map<String, dynamic>;
      final roleConfig = roleDiscountsMap[role.name.toLowerCase()] as Map<String, dynamic>?;
      if (roleConfig == null) {
        AppLogger.warning('[SubsidyRepository] Keine Rollenkonfiguration für ${role.name}');
        return [];
      }

      final discountPercent = (roleConfig['discount_percent'] as num?)?.toDouble() ?? 0.0;

      // Parse ageGroups JSON
      final ageGroupsList = ruleset.ageGroups != null && ruleset.ageGroups!.isNotEmpty
          ? jsonDecode(ruleset.ageGroups!) as List<dynamic>
          : <dynamic>[];

      // SubsidyParticipant-Objekte erstellen
      final subsidyParticipants = <SubsidyParticipant>[];
      for (final participant in participants) {
        final age = SubsidyCalculatorService.calculateAge(participant.birthDate, event.startDate);
        final basePrice = SubsidyCalculatorService.getBasePriceByAge(
          age,
          ageGroupsList,
        );
        final subsidyAmount = basePrice * (discountPercent / 100);

        subsidyParticipants.add(SubsidyParticipant(
          participantId: participant.id,
          name: '${participant.firstName} ${participant.lastName}',
          birthDate: participant.birthDate,
          basePrice: basePrice,
          subsidyAmount: subsidyAmount,
          discountPercent: discountPercent,
        ));
      }

      AppLogger.info(
        '[SubsidyRepository] ✓ Teilnehmer mit Zuschüssen für Rolle "${role.displayName}": '
        '${subsidyParticipants.length}',
      );

      return subsidyParticipants;
    } catch (e, stack) {
      AppLogger.error(
        '[SubsidyRepository] Fehler beim Laden der Teilnehmer für Rolle',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

  /// Lädt das aktive Ruleset für ein Event
  ///
  /// Das aktive Ruleset ist dasjenige, dessen valid_from <= eventStartDate ist
  /// und das am nächsten an eventStartDate liegt
  Future<Ruleset?> _getActiveRuleset(int eventId, DateTime eventStartDate) async {
    final rulesets = await (_database.select(_database.rulesets)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..where((tbl) => tbl.validFrom.isSmallerOrEqualValue(eventStartDate))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.validFrom)]))
        .get();

    if (rulesets.isEmpty) {
      return null;
    }

    return rulesets.first;
  }
}
