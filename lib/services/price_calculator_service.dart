import '../utils/logger.dart';

/// Preisberechnungs-Service
///
/// Portiert von Python (app/services/price_calculator.py)
/// Berechnet Teilnehmerpreise basierend auf:
/// - Alter (age_groups)
/// - Rolle (role_discounts)
/// - Familie (family_discount)
class PriceCalculatorService {
  /// Berechnet den Preis für einen Teilnehmer basierend auf Regelwerk
  ///
  /// Args:
  ///   - age: Alter des Teilnehmers
  ///   - roleName: Optional Name der Rolle (z.B. "betreuer", "kind"). null = keine Rolle
  ///   - rulesetData: Regelwerk-Daten (age_groups, role_discounts, etc.)
  ///   - familyChildrenCount: Position in der Familie (1=erstes Kind, 2=zweites, etc.)
  ///
  /// Returns:
  ///   Berechneter Preis in Euro
  static double calculateParticipantPrice({
    required int age,
    String? roleName,
    required Map<String, dynamic> rulesetData,
    int familyChildrenCount = 1,
  }) {
    // Basispreis aus Altersgruppen ermitteln
    final basePrice = _getBasePriceByAge(
      age,
      rulesetData['age_groups'] as List? ?? [],
    );

    // Rollenrabatt ermitteln (nur wenn Rolle vorhanden)
    double roleDiscountPercent = 0.0;
    if (roleName != null) {
      roleDiscountPercent = _getRoleDiscount(
        roleName,
        rulesetData['role_discounts'] as Map<String, dynamic>? ?? {},
      );
    }

    // Familienrabatt ermitteln (nur für Kinder unter 18)
    final familyDiscountPercent = _getFamilyDiscount(
      age,
      familyChildrenCount,
      rulesetData['family_discount'] as Map<String, dynamic>? ?? {},
    );

    // Alle Rabatte vom Basispreis berechnen (nicht gestapelt!)
    // WICHTIG: Beide Rabatte werden vom Basispreis berechnet, nicht vom bereits
    // reduzierten Preis. Beispiel: Basispreis 100€, Rollenrabatt 50%, Familienrabatt 20%
    // → Endpreis = 100€ - 50€ - 20€ = 30€ (NICHT 100€ - 50€ - 10€ = 40€)
    final roleDiscountAmount = basePrice * (roleDiscountPercent / 100);
    final familyDiscountAmount = basePrice * (familyDiscountPercent / 100);

    // Endpreis = Basispreis - Summe aller Rabatte
    final finalPrice = basePrice - roleDiscountAmount - familyDiscountAmount;

    AppLogger.debug(
        '[PriceCalculation] calculateParticipantPrice:\n'
            '  age: $age\n'
            '  roleName: $roleName\n'
            '  familyChildrenCount: $familyChildrenCount\n'
            '  basePrice: $basePrice\n'
            '  roleDiscountPercent: $roleDiscountPercent\n'
            '  roleDiscountAmount: $roleDiscountAmount\n'
            '  familyDiscountPercent: $familyDiscountPercent\n'
            '  familyDiscountAmount: $familyDiscountAmount\n'
            '  finalPrice: ${finalPrice.toStringAsFixed(2)}\n'
    );

    return double.parse(finalPrice.toStringAsFixed(2));
  }

  /// Ermittelt den Basispreis basierend auf dem Alter
  ///
  /// Args:
  ///   - age: Alter des Teilnehmers
  ///   - ageGroups: Liste der Altersgruppen mit base_price
  ///
  /// Returns:
  ///   Basispreis für die Altersgruppe
  static double _getBasePriceByAge(int age, List<dynamic> ageGroups) {
    AppLogger.debug(
      '[PriceCalculatorService] _getBasePriceByAge():\n'
      '  age: $age\n'
      '  ageGroups count: ${ageGroups.length}\n'
      '  ageGroups: $ageGroups',
    );

    if (ageGroups.isEmpty) {
      AppLogger.warning('[PriceCalculatorService] ageGroups ist leer! Keine Altersgruppen definiert.');
      return 0.0;
    }

    for (var i = 0; i < ageGroups.length; i++) {
      final group = ageGroups[i];
      final minAge = group['min_age'] as int? ?? 0;
      final maxAge = group['max_age'] as int? ?? 999;

      AppLogger.debug(
        '[PriceCalculatorService] Prüfe Gruppe $i:\n'
        '  min_age: $minAge\n'
        '  max_age: $maxAge\n'
        '  age in range: ${minAge <= age && age <= maxAge}\n'
        '  group: $group',
      );

      if (minAge <= age && age <= maxAge) {
        // Neues Format: base_price direkt aus age_group
        if (group.containsKey('base_price') == true) {
          final price = (group['base_price'] as num).toDouble();
          AppLogger.info(
            '[PriceCalculatorService] ✓ Basispreis gefunden:\n'
            '  Alter: $age\n'
            '  Preis: $price€\n'
            '  Gruppe: $minAge-$maxAge',
          );
          return price;
        }

        // Legacy Format: price als Fallback
        final price = (group['price'] as num?)?.toDouble() ?? 0.0;
        AppLogger.info(
          '[PriceCalculatorService] ✓ Basispreis gefunden (legacy format):\n'
          '  Alter: $age\n'
          '  Preis: $price€\n'
          '  Gruppe: $minAge-$maxAge',
        );
        return price;
      }
    }

    AppLogger.warning(
      '[PriceCalculatorService] ! Keine passende Altersgruppe für Alter $age gefunden!\n'
      '  Geprüfte Gruppen: ${ageGroups.length}\n'
      '  Rückgabe: 0.0',
    );
    return 0.0;
  }

  /// Ermittelt den Rollenrabatt in Prozent (case-insensitive)
  ///
  /// Args:
  ///   - roleName: Optional Name der Rolle
  ///   - roleDiscounts: Dictionary mit Rollenrabatten
  ///
  /// Returns:
  ///   Rabatt in Prozent (0.0 wenn keine Rolle oder kein Rabatt)
  static double _getRoleDiscount(
    String? roleName,
    Map<String, dynamic> roleDiscounts,
  ) {
    AppLogger.debug(
      '[PriceCalculatorService] _getRoleDiscount():\n'
      '  roleName: $roleName\n'
      '  roleDiscounts: $roleDiscounts',
    );

    if (roleName == null || roleName.isEmpty) {
      AppLogger.debug('[PriceCalculatorService] Keine Rolle angegeben → Rabatt: 0%');
      return 0.0;
    }

    if (roleDiscounts.isEmpty) {
      AppLogger.debug('[PriceCalculatorService] roleDiscounts ist leer → Rabatt: 0%');
      return 0.0;
    }

    // Case-insensitive Suche im roleDiscounts Dictionary
    final roleNameLower = roleName.toLowerCase();
    for (var entry in roleDiscounts.entries) {
      if (entry.key.toLowerCase() == roleNameLower) {
        final discount = entry.value as Map<String, dynamic>?;
        final discountPercent = (discount?['discount_percent'] as num?)?.toDouble() ?? 0.0;
        AppLogger.info(
          '[PriceCalculatorService] ✓ Rollenrabatt gefunden:\n'
          '  Rolle: $roleName\n'
          '  Rabatt: $discountPercent%',
        );
        return discountPercent;
      }
    }

    AppLogger.debug(
      '[PriceCalculatorService] Keine Rolle "$roleName" in roleDiscounts gefunden → Rabatt: 0%',
    );
    return 0.0;
  }

  /// Ermittelt den Familienrabatt in Prozent
  ///
  /// WICHTIG: Familienrabatte gelten nur für Kinder (unter 18 Jahre).
  /// Erwachsene (18+) erhalten KEINEN Familienrabatt.
  ///
  /// Unterstützt Rabatte für:
  /// - Erstes Kind (first_child_percent, optional, Standard: 0%)
  /// - Zweites Kind (second_child_percent)
  /// - Drittes und weitere Kinder (third_plus_child_percent)
  ///
  /// Beispiel: Bei 3 Kindern mit Rabatten [25%, 25%, 25%]:
  /// - Kind 1 (ältestes): 25% Rabatt
  /// - Kind 2: 25% Rabatt
  /// - Kind 3 (jüngstes): 25% Rabatt
  /// - Erwachsene: 0% Rabatt
  static double _getFamilyDiscount(
    int age,
    int childPosition,
    Map<String, dynamic> familyDiscountConfig,
  ) {
    AppLogger.debug(
      '[PriceCalculatorService] _getFamilyDiscount():\n'
      '  age: $age\n'
      '  childPosition: $childPosition\n'
      '  familyDiscountConfig: $familyDiscountConfig',
    );

    // Familienrabatte gelten NUR für Kinder (unter 18)
    if (age >= 18) {
      AppLogger.debug('[PriceCalculatorService] Alter >= 18 → Kein Familienrabatt');
      return 0.0;
    }

    final enabled = familyDiscountConfig['enabled'] as bool? ?? false;
    if (!enabled) {
      AppLogger.debug('[PriceCalculatorService] Familienrabatt nicht aktiviert → Rabatt: 0%');
      return 0.0;
    }

    double discount = 0.0;
    if (childPosition == 1) {
      // Erstes Kind (ältestes): Rabatt optional (Standard: 0%)
      discount = (familyDiscountConfig['first_child_percent'] as num?)?.toDouble() ?? 0.0;
    } else if (childPosition == 2) {
      // Zweites Kind
      discount = (familyDiscountConfig['second_child_percent'] as num?)?.toDouble() ?? 0.0;
    } else {
      // 3. Kind und weitere (jüngste Kinder)
      discount = (familyDiscountConfig['third_plus_child_percent'] as num?)?.toDouble() ?? 0.0;
    }

    AppLogger.info(
      '[PriceCalculatorService] ✓ Familienrabatt:\n'
      '  Position: $childPosition. Kind\n'
      '  Rabatt: $discount%',
    );
    return discount;
  }

  /// Berechnet den Preis mit detaillierter Aufschlüsselung
  ///
  /// Args:
  ///   - age: Alter des Teilnehmers
  ///   - roleName: Name der Rolle (z.B. "betreuer", "kind")
  ///   - roleDisplayName: Anzeigename der Rolle (z.B. "Betreuer", "Kind")
  ///   - rulesetData: Regelwerk-Daten (age_groups, role_discounts, etc.)
  ///   - familyChildrenCount: Position in der Familie (1=erstes Kind, 2=zweites, etc.)
  ///   - discountPercent: Zusätzlicher manueller Rabatt in Prozent
  ///   - discountReason: Grund für den manuellen Rabatt
  ///   - manualPriceOverride: Manuell gesetzter Preis (überschreibt Berechnung)
  ///
  /// Returns:
  ///   Map mit detaillierter Preisaufschlüsselung
  static Map<String, dynamic> calculateParticipantPriceWithBreakdown({
    required int age,
    required String roleName,
    required String roleDisplayName,
    required Map<String, dynamic> rulesetData,
    int familyChildrenCount = 1,
    double discountPercent = 0.0,
    String? discountReason,
    double? manualPriceOverride,
  }) {
    final breakdown = <String, dynamic>{
      'base_price': 0.0,
      'role_discount_percent': 0.0,
      'role_discount_amount': 0.0,
      'price_after_role_discount': 0.0,
      'family_discount_percent': 0.0,
      'family_discount_amount': 0.0,
      'price_after_family_discount': 0.0,
      'manual_discount_percent': discountPercent,
      'manual_discount_amount': 0.0,
      'manual_price_override': manualPriceOverride,
      'final_price': 0.0,
      'has_discounts': false,
      'discount_reasons': <String>[],
    };

    // Wenn manueller Preis gesetzt ist, überschreibt dieser alles
    if (manualPriceOverride != null) {
      breakdown['final_price'] = manualPriceOverride;
      breakdown['has_discounts'] = true;
      breakdown['discount_reasons'].add(
        'Manueller Preis: ${manualPriceOverride.toStringAsFixed(2)} €',
      );
      if (discountReason != null && discountReason.isNotEmpty) {
        breakdown['discount_reasons'].add('Grund: $discountReason');
      }
      return breakdown;
    }

    // Basispreis ermitteln
    breakdown['base_price'] = _getBasePriceByAge(
      age,
      rulesetData['age_groups'] as List? ?? [],
    );

    // Rollenrabatt ermitteln (vom Basispreis!)
    breakdown['role_discount_percent'] = _getRoleDiscount(
      roleName,
      rulesetData['role_discounts'] as Map<String, dynamic>? ?? {},
    );
    breakdown['role_discount_amount'] =
        breakdown['base_price'] * (breakdown['role_discount_percent'] / 100);

    if ((breakdown['role_discount_percent'] as num) > 0) {
      breakdown['has_discounts'] = true;
      breakdown['discount_reasons'].add(
        'Rollenrabatt ($roleDisplayName): ${breakdown['role_discount_percent'].toStringAsFixed(0)}%',
      );
    }

    // Familienrabatt ermitteln (vom Basispreis, NICHT gestapelt!)
    // Nur für Kinder unter 18
    breakdown['family_discount_percent'] = _getFamilyDiscount(
      age,
      familyChildrenCount,
      rulesetData['family_discount'] as Map<String, dynamic>? ?? {},
    );
    breakdown['family_discount_amount'] =
        breakdown['base_price'] * (breakdown['family_discount_percent'] / 100);

    if ((breakdown['family_discount_percent'] as num) > 0) {
      breakdown['has_discounts'] = true;
      breakdown['discount_reasons'].add(
        'Kinderzuschuss durch MGB ($familyChildrenCount. Kind): ${breakdown['family_discount_percent'].toStringAsFixed(0)}%',
      );
    }

    // Preis nach automatischen Rabatten (für Display-Zwecke)
    breakdown['price_after_role_discount'] =
        breakdown['base_price'] - breakdown['role_discount_amount'];
    breakdown['price_after_family_discount'] = breakdown['base_price'] -
        breakdown['role_discount_amount'] -
        breakdown['family_discount_amount'];

    // Manueller Rabatt (zusätzlich, vom bereits reduzierten Preis)
    if (discountPercent > 0) {
      breakdown['manual_discount_amount'] =
          breakdown['price_after_family_discount'] * (discountPercent / 100);
      breakdown['has_discounts'] = true;

      var reason = 'Zusätzlicher Rabatt: ${discountPercent.toStringAsFixed(0)}%';
      if (discountReason != null && discountReason.isNotEmpty) {
        reason += ' ($discountReason)';
      }
      breakdown['discount_reasons'].add(reason);
    }

    // Endpreis berechnen
    final finalPrice = breakdown['price_after_family_discount'] -
        breakdown['manual_discount_amount'];
    breakdown['final_price'] = double.parse((finalPrice as num).toStringAsFixed(2));

    AppLogger.debug(
        '[PriceCalculation] Breakdown:\n'
            '  base_price: ${breakdown['base_price']}\n'
            '  role_discount_percent: ${breakdown['role_discount_percent']}\n'
            '  role_discount_amount: ${breakdown['role_discount_amount']}\n'
            '  price_after_role_discount: ${breakdown['price_after_role_discount']}\n'
            '  family_discount_percent: ${breakdown['family_discount_percent']}\n'
            '  family_discount_amount: ${breakdown['family_discount_amount']}\n'
            '  price_after_family_discount: ${breakdown['price_after_family_discount']}\n'
            '  manual_discount_percent: ${breakdown['manual_discount_percent']}\n'
            '  manual_discount_amount: ${breakdown['manual_discount_amount']}\n'
            '  manual_price_override: ${breakdown['manual_price_override']}\n'
            '  final_price: ${breakdown['final_price']}\n'
            '  has_discounts: ${breakdown['has_discounts']}\n'
            '  discount_reasons: ${breakdown['discount_reasons']}\n'
    );

    return breakdown;
  }
}
