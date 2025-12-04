import 'dart:convert';
import '../data/database/app_database.dart';
import '../utils/logger.dart';

/// Zuschussberechnungs-Service
///
/// Portiert von Python (OLD Scripts/cash_status.py)
/// Berechnet erwartete Zuschüsse basierend auf:
/// - Rollenrabatte (nur subsidy_eligible=true)
/// - Familienrabatte (nur Kinder unter 18)
///
/// WICHTIG:
/// - NUR Teilnehmer OHNE manualPriceOverride werden berücksichtigt
/// - Bildung & Teilhabe (BUT) wird NICHT berücksichtigt (separate Abrechnung)
class SubsidyCalculatorService {
  /// Berechnet die gesamten erwarteten Zuschüsse für ein Event
  ///
  /// Args:
  ///   - event: Das Event (für Altersberechnung)
  ///   - ruleset: Aktives Regelwerk mit Rabatt-Konfigurationen
  ///   - participants: Alle aktiven Teilnehmer des Events
  ///   - roles: Alle Rollen des Events (für Zuordnung)
  ///
  /// Returns:
  ///   Gesamtsumme aller erwarteten Zuschüsse in Euro
  static double calculateExpectedSubsidies({
    required Event event,
    required Ruleset ruleset,
    required List<Participant> participants,
    required List<Role> roles,
  }) {
    AppLogger.debug(
      '[SubsidyCalculatorService] calculateExpectedSubsidies():\n'
      '  Event: ${event.name}\n'
      '  Ruleset: ${ruleset.name}\n'
      '  Participants: ${participants.length}\n'
      '  Roles: ${roles.length}',
    );

    double totalSubsidies = 0.0;

    // 1. Rollenbasierte Zuschüsse
    final roleSubsidies = calculateRoleSubsidies(
      event: event,
      ruleset: ruleset,
      participants: participants,
      roles: roles,
    );
    totalSubsidies += roleSubsidies;

    // 2. Familienrabatte als Zuschüsse
    final familySubsidies = calculateFamilySubsidies(
      event: event,
      ruleset: ruleset,
      participants: participants,
    );
    totalSubsidies += familySubsidies;

    AppLogger.info(
      '[SubsidyCalculatorService] ✓ Gesamte erwartete Zuschüsse:\n'
      '  Rollenbasiert: ${roleSubsidies.toStringAsFixed(2)} €\n'
      '  Familienrabatte: ${familySubsidies.toStringAsFixed(2)} €\n'
      '  GESAMT: ${totalSubsidies.toStringAsFixed(2)} €',
    );

    return double.parse(totalSubsidies.toStringAsFixed(2));
  }

  /// Berechnet rollenbasierte Zuschüsse
  ///
  /// WICHTIG:
  /// - Nur Rollen mit subsidy_eligible=true
  /// - Nur Teilnehmer ohne manualPriceOverride
  /// - Bildung & Teilhabe (bildungUndTeilhabe) wird NICHT berücksichtigt
  ///
  /// Args:
  ///   - event: Das Event (für Altersberechnung)
  ///   - ruleset: Aktives Regelwerk
  ///   - participants: Alle aktiven Teilnehmer
  ///   - roles: Alle Rollen
  ///
  /// Returns:
  ///   Summe aller rollenbasierten Zuschüsse
  static double calculateRoleSubsidies({
    required Event event,
    required Ruleset ruleset,
    required List<Participant> participants,
    required List<Role> roles,
  }) {
    AppLogger.debug('[SubsidyCalculatorService] calculateRoleSubsidies()');

    if (ruleset.roleDiscounts == null || ruleset.roleDiscounts!.isEmpty) {
      AppLogger.debug('  → Keine Rollenrabatte im Ruleset definiert');
      return 0.0;
    }

    // Parse JSON string to Map
    final roleDiscountsMap = jsonDecode(ruleset.roleDiscounts!) as Map<String, dynamic>;

    if (roleDiscountsMap.isEmpty) {
      AppLogger.debug('  → Keine Rollenrabatte im Ruleset definiert');
      return 0.0;
    }

    double totalRoleSubsidies = 0.0;

    // Iteriere über alle Rollenrabatte im Ruleset
    for (final roleEntry in roleDiscountsMap.entries) {
      final roleName = roleEntry.key;
      final roleConfig = roleEntry.value as Map<String, dynamic>;

      // Prüfe ob Rolle zuschussberechtigt ist (Standard: true)
      final subsidyEligible = roleConfig['subsidy_eligible'] as bool? ?? true;

      if (!subsidyEligible) {
        AppLogger.debug('  → Rolle "$roleName" ist nicht zuschussberechtigt (subsidy_eligible=false)');
        continue;
      }

      final discountPercent = (roleConfig['discount_percent'] as num?)?.toDouble() ?? 0.0;
      if (discountPercent <= 0) {
        AppLogger.debug('  → Rolle "$roleName" hat keinen Rabatt');
        continue;
      }

      // Finde die entsprechende Rolle in der Datenbank
      final role = roles.where((r) => r.name.toLowerCase() == roleName.toLowerCase()).firstOrNull;
      if (role == null) {
        AppLogger.warning('  → Rolle "$roleName" nicht in Datenbank gefunden');
        continue;
      }

      // Finde alle Teilnehmer mit dieser Rolle (ohne manualPriceOverride)
      final roleParticipants = participants.where((p) =>
          p.roleId == role.id &&
          p.manualPriceOverride == null).toList();

      AppLogger.debug(
        '  → Rolle: $roleName\n'
        '    Rabatt: $discountPercent%\n'
        '    Teilnehmer: ${roleParticipants.length}',
      );

      // Berechne Zuschuss für jeden Teilnehmer
      final ageGroupsList = ruleset.ageGroups != null && ruleset.ageGroups!.isNotEmpty
          ? jsonDecode(ruleset.ageGroups!) as List<dynamic>
          : <dynamic>[];

      for (final participant in roleParticipants) {
        final age = _calculateAge(participant.birthDate, event.startDate);
        final basePrice = _getBasePriceByAge(age, ageGroupsList);
        final subsidyAmount = basePrice * (discountPercent / 100);

        totalRoleSubsidies += subsidyAmount;

        AppLogger.debug(
          '    - ${participant.firstName} ${participant.lastName}:\n'
          '      Alter: $age, Basispreis: ${basePrice.toStringAsFixed(2)} €,\n'
          '      Zuschuss: ${subsidyAmount.toStringAsFixed(2)} €',
        );
      }
    }

    AppLogger.info('  → Rollenbasierte Zuschüsse gesamt: ${totalRoleSubsidies.toStringAsFixed(2)} €');
    return double.parse(totalRoleSubsidies.toStringAsFixed(2));
  }

  /// Berechnet Familienrabatte als Zuschüsse
  ///
  /// WICHTIG:
  /// - Nur Kinder unter 18 Jahren
  /// - Nur Teilnehmer ohne manualPriceOverride
  /// - Position in Familie wird berücksichtigt (1. Kind, 2. Kind, 3.+ Kind)
  ///
  /// Args:
  ///   - event: Das Event (für Altersberechnung)
  ///   - ruleset: Aktives Regelwerk
  ///   - participants: Alle aktiven Teilnehmer
  ///
  /// Returns:
  ///   Summe aller Familienrabatte
  static double calculateFamilySubsidies({
    required Event event,
    required Ruleset ruleset,
    required List<Participant> participants,
  }) {
    AppLogger.debug('[SubsidyCalculatorService] calculateFamilySubsidies()');

    if (ruleset.familyDiscount == null || ruleset.familyDiscount!.isEmpty) {
      AppLogger.debug('  → Familienrabatt nicht definiert');
      return 0.0;
    }

    // Parse JSON string to Map
    final familyDiscountMap = jsonDecode(ruleset.familyDiscount!) as Map<String, dynamic>;

    if (familyDiscountMap['enabled'] != true) {
      AppLogger.debug('  → Familienrabatt nicht aktiviert');
      return 0.0;
    }

    double totalFamilySubsidies = 0.0;

    // Finde alle Teilnehmer mit Familie (ohne manualPriceOverride)
    final familyParticipants = participants.where((p) =>
        p.familyId != null &&
        p.manualPriceOverride == null).toList();

    AppLogger.debug('  → Teilnehmer mit Familie: ${familyParticipants.length}');

    // Parse JSON string to Map
    final ageGroupsList = ruleset.ageGroups != null && ruleset.ageGroups!.isNotEmpty
        ? jsonDecode(ruleset.ageGroups!) as List<dynamic>
        : <dynamic>[];

    for (final participant in familyParticipants) {
      final age = _calculateAge(participant.birthDate, event.startDate);

      // Nur Kinder unter 18
      if (age >= 18) {
        AppLogger.debug(
          '    - ${participant.firstName} ${participant.lastName}: '
          'Alter $age >= 18 → Kein Familienrabatt',
        );
        continue;
      }

      final basePrice = _getBasePriceByAge(age, ageGroupsList);

      // Position in Familie ermitteln (sortiert nach Geburtsdatum, ältestes = 1)
      final siblings = participants
          .where((p) => p.familyId == participant.familyId && p.isActive)
          .toList()
        ..sort((a, b) => a.birthDate.compareTo(b.birthDate));

      int childPosition = 1;
      for (var i = 0; i < siblings.length; i++) {
        if (siblings[i].id == participant.id) {
          childPosition = i + 1;
          break;
        }
      }

      // Familienrabatt berechnen
      final familyDiscountPercent = _getFamilyDiscountPercent(
        age,
        childPosition,
        familyDiscountMap,
      );

      if (familyDiscountPercent <= 0) {
        continue;
      }

      final subsidyAmount = basePrice * (familyDiscountPercent / 100);
      totalFamilySubsidies += subsidyAmount;

      AppLogger.debug(
        '    - ${participant.firstName} ${participant.lastName}:\n'
        '      Alter: $age, Position: $childPosition. Kind,\n'
        '      Basispreis: ${basePrice.toStringAsFixed(2)} €,\n'
        '      Rabatt: $familyDiscountPercent%,\n'
        '      Zuschuss: ${subsidyAmount.toStringAsFixed(2)} €',
      );
    }

    AppLogger.info('  → Familienrabatte gesamt: ${totalFamilySubsidies.toStringAsFixed(2)} €');
    return double.parse(totalFamilySubsidies.toStringAsFixed(2));
  }

  /// Berechnet Zuschüsse aufgeschlüsselt nach Rollen
  ///
  /// Returns:
  ///   Map mit Rollen-IDs als Key und Zuschuss-Summe als Value
  static Map<int, SubsidyByRole> getSubsidiesByRole({
    required Event event,
    required Ruleset ruleset,
    required List<Participant> participants,
    required List<Role> roles,
  }) {
    AppLogger.debug('[SubsidyCalculatorService] getSubsidiesByRole()');

    final Map<int, SubsidyByRole> subsidiesByRole = {};

    if (ruleset.roleDiscounts == null || ruleset.roleDiscounts!.isEmpty) {
      return subsidiesByRole;
    }

    // Parse JSON string to Map
    final roleDiscountsMap = jsonDecode(ruleset.roleDiscounts!) as Map<String, dynamic>;

    // Iteriere über alle Rollenrabatte
    for (final roleEntry in roleDiscountsMap.entries) {
      final roleName = roleEntry.key;
      final roleConfig = roleEntry.value as Map<String, dynamic>;

      // Nur zuschussberechtigte Rollen
      final subsidyEligible = roleConfig['subsidy_eligible'] as bool? ?? true;
      if (!subsidyEligible) continue;

      final discountPercent = (roleConfig['discount_percent'] as num?)?.toDouble() ?? 0.0;
      if (discountPercent <= 0) continue;

      // Finde die Rolle
      final role = roles.where((r) => r.name.toLowerCase() == roleName.toLowerCase()).firstOrNull;
      if (role == null) continue;

      // Finde Teilnehmer mit dieser Rolle
      final roleParticipants = participants.where((p) =>
          p.roleId == role.id &&
          p.manualPriceOverride == null).toList();

      if (roleParticipants.isEmpty) continue;

      // Berechne Zuschüsse
      double totalSubsidy = 0.0;
      final List<SubsidyParticipant> participantDetails = [];

      final ageGroupsList = ruleset.ageGroups != null && ruleset.ageGroups!.isNotEmpty
          ? jsonDecode(ruleset.ageGroups!) as List<dynamic>
          : <dynamic>[];

      for (final participant in roleParticipants) {
        final age = _calculateAge(participant.birthDate, event.startDate);
        final basePrice = _getBasePriceByAge(age, ageGroupsList);
        final subsidyAmount = basePrice * (discountPercent / 100);

        totalSubsidy += subsidyAmount;

        participantDetails.add(SubsidyParticipant(
          participantId: participant.id,
          name: '${participant.firstName} ${participant.lastName}',
          birthDate: participant.birthDate,
          basePrice: basePrice,
          subsidyAmount: subsidyAmount,
          discountPercent: discountPercent,
        ));
      }

      subsidiesByRole[role.id] = SubsidyByRole(
        roleId: role.id,
        roleName: role.displayName,
        participantCount: roleParticipants.length,
        totalSubsidy: double.parse(totalSubsidy.toStringAsFixed(2)),
        discountPercent: discountPercent,
        participants: participantDetails,
      );
    }

    return subsidiesByRole;
  }

  /// Berechnet Zuschüsse aufgeschlüsselt nach Rabatttyp
  ///
  /// WICHTIG: Bildung & Teilhabe (BUT) wird NICHT berücksichtigt!
  ///
  /// Returns:
  ///   Map mit Rabatttyp als Key und Details als Value
  static Map<String, SubsidyByDiscountType> getSubsidiesByDiscountType({
    required Event event,
    required Ruleset ruleset,
    required List<Participant> participants,
  }) {
    AppLogger.debug('[SubsidyCalculatorService] getSubsidiesByDiscountType()');

    final Map<String, SubsidyByDiscountType> subsidiesByType = {};

    // Nur Teilnehmer ohne manualPriceOverride und MIT Rabatten
    final discountedParticipants = participants.where((p) =>
        p.manualPriceOverride == null &&
        p.discountPercent > 0).toList();

    AppLogger.debug('  → Teilnehmer mit Rabatten: ${discountedParticipants.length}');

    final ageGroupsList = ruleset.ageGroups != null && ruleset.ageGroups!.isNotEmpty
        ? jsonDecode(ruleset.ageGroups!) as List<dynamic>
        : <dynamic>[];

    for (final participant in discountedParticipants) {
      // WICHTIG: Bildung & Teilhabe überspringen!
      if (participant.bildungUndTeilhabe) {
        AppLogger.debug(
          '    - ${participant.firstName} ${participant.lastName}: '
          'Bildung & Teilhabe → Übersprungen (separate Abrechnung)',
        );
        continue;
      }

      // Rabatttyp ermitteln
      String discountType = 'Sonstige';

      if (participant.discountReason != null && participant.discountReason!.isNotEmpty) {
        discountType = participant.discountReason!;
      } else if (participant.familyId != null) {
        // Familienrabatt
        final age = _calculateAge(participant.birthDate, event.startDate);
        if (age < 18) {
          discountType = 'Familienrabatt';
        }
      } else if (participant.roleId != null) {
        // Rollenrabatt
        discountType = 'Rollenrabatt';
      }

      // Zuschuss berechnen
      final age = _calculateAge(participant.birthDate, event.startDate);
      final basePrice = _getBasePriceByAge(age, ageGroupsList);
      final subsidyAmount = basePrice * (participant.discountPercent / 100);

      // Zu Typ hinzufügen
      if (!subsidiesByType.containsKey(discountType)) {
        subsidiesByType[discountType] = SubsidyByDiscountType(
          discountType: discountType,
          participantCount: 0,
          totalSubsidy: 0.0,
          avgDiscountPercent: 0.0,
          participants: [],
        );
      }

      final typeData = subsidiesByType[discountType]!;
      subsidiesByType[discountType] = SubsidyByDiscountType(
        discountType: discountType,
        participantCount: typeData.participantCount + 1,
        totalSubsidy: typeData.totalSubsidy + subsidyAmount,
        avgDiscountPercent: 0.0, // Wird später berechnet
        participants: [
          ...typeData.participants,
          SubsidyParticipant(
            participantId: participant.id,
            name: '${participant.firstName} ${participant.lastName}',
            birthDate: participant.birthDate,
            basePrice: basePrice,
            subsidyAmount: subsidyAmount,
            discountPercent: participant.discountPercent,
          ),
        ],
      );
    }

    // Durchschnittliche Rabattprozente berechnen
    for (final entry in subsidiesByType.entries) {
      final avgPercent = entry.value.participants.fold<double>(
            0.0,
                (sum, p) => sum + p.discountPercent,
          ) /
          entry.value.participants.length;

      subsidiesByType[entry.key] = SubsidyByDiscountType(
        discountType: entry.value.discountType,
        participantCount: entry.value.participantCount,
        totalSubsidy: double.parse(entry.value.totalSubsidy.toStringAsFixed(2)),
        avgDiscountPercent: double.parse(avgPercent.toStringAsFixed(1)),
        participants: entry.value.participants,
      );
    }

    return subsidiesByType;
  }

  // ========== HELPER METHODS ==========

  /// Berechnet das Alter eines Teilnehmers am Startdatum des Events
  static int _calculateAge(DateTime birthDate, DateTime eventStartDate) {
    int age = eventStartDate.year - birthDate.year;
    if (eventStartDate.month < birthDate.month ||
        (eventStartDate.month == birthDate.month && eventStartDate.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Ermittelt den Basispreis basierend auf dem Alter
  static double _getBasePriceByAge(int age, List<dynamic> ageGroups) {
    if (ageGroups.isEmpty) {
      AppLogger.warning('[SubsidyCalculatorService] ageGroups ist leer!');
      return 0.0;
    }

    for (final group in ageGroups) {
      final minAge = group['min_age'] as int? ?? 0;
      final maxAge = group['max_age'] as int? ?? 999;

      if (minAge <= age && age <= maxAge) {
        return (group['base_price'] as num?)?.toDouble() ?? 0.0;
      }
    }

    AppLogger.warning('[SubsidyCalculatorService] Keine Altersgruppe für Alter $age gefunden!');
    return 0.0;
  }

  /// Ermittelt den Familienrabatt in Prozent
  static double _getFamilyDiscountPercent(
      int age,
      int childPosition,
      Map<String, dynamic> familyDiscountConfig,
      ) {
    // Familienrabatte gelten NUR für Kinder (unter 18)
    if (age >= 18) {
      return 0.0;
    }

    final enabled = familyDiscountConfig['enabled'] as bool? ?? false;
    if (!enabled) {
      return 0.0;
    }

    double discount = 0.0;
    if (childPosition == 1) {
      discount = (familyDiscountConfig['first_child_percent'] as num?)?.toDouble() ?? 0.0;
    } else if (childPosition == 2) {
      discount = (familyDiscountConfig['second_child_percent'] as num?)?.toDouble() ?? 0.0;
    } else {
      discount = (familyDiscountConfig['third_plus_child_percent'] as num?)?.toDouble() ?? 0.0;
    }

    return discount;
  }
}

// ========== DATA CLASSES ==========

/// Zuschuss-Daten pro Rolle
class SubsidyByRole {
  final int roleId;
  final String roleName;
  final int participantCount;
  final double totalSubsidy;
  final double discountPercent;
  final List<SubsidyParticipant> participants;

  SubsidyByRole({
    required this.roleId,
    required this.roleName,
    required this.participantCount,
    required this.totalSubsidy,
    required this.discountPercent,
    required this.participants,
  });
}

/// Zuschuss-Daten pro Rabatttyp
class SubsidyByDiscountType {
  final String discountType;
  final int participantCount;
  final double totalSubsidy;
  final double avgDiscountPercent;
  final List<SubsidyParticipant> participants;

  SubsidyByDiscountType({
    required this.discountType,
    required this.participantCount,
    required this.totalSubsidy,
    required this.avgDiscountPercent,
    required this.participants,
  });
}

/// Teilnehmer-Details für Zuschüsse
class SubsidyParticipant {
  final int participantId;
  final String name;
  final DateTime birthDate;
  final double basePrice;
  final double subsidyAmount;
  final double discountPercent;

  SubsidyParticipant({
    required this.participantId,
    required this.name,
    required this.birthDate,
    required this.basePrice,
    required this.subsidyAmount,
    required this.discountPercent,
  });
}
