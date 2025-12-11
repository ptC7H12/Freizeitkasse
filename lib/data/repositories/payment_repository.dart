import 'dart:math';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../utils/logger.dart';

/// Repository für Zahlungen-CRUD-Operationen
class PaymentRepository {
  final AppDatabase _db;

  PaymentRepository(this._db);

  // READ
  Stream<List<Payment>> watchPaymentsByEvent(int eventId) {
    return (_db.select(_db.payments)
          ..where((tbl) => tbl.eventId.equals(eventId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.paymentDate)]))
        .watch();
  }

  Stream<List<Payment>> watchPaymentsByParticipant(int participantId) {
    return (_db.select(_db.payments)
          ..where((tbl) => tbl.participantId.equals(participantId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.paymentDate)]))
        .watch();
  }

  Stream<List<Payment>> watchPaymentsByFamily(int familyId) {
    return (_db.select(_db.payments)
          ..where((tbl) => tbl.familyId.equals(familyId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.paymentDate)]))
        .watch();
  }

  Future<Payment?> getPaymentById(int id) {
    return (_db.select(_db.payments)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // CREATE
  Future<int> createPayment({
    required int eventId,
    int? participantId,
    int? familyId,
    required double amount,
    required DateTime paymentDate,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) {
    return _db.into(_db.payments).insert(
          PaymentsCompanion.insert(
            eventId: eventId,
            participantId: Value(participantId),
            familyId: Value(familyId),
            amount: amount,
            paymentDate: paymentDate,
            paymentMethod: Value(paymentMethod),
            referenceNumber: Value(referenceNumber),
            notes: Value(notes),
          ),
        );
  }

  // UPDATE
  Future<bool> updatePayment({
    required int id,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) {
    return _db.update(_db.payments).replace(
          PaymentsCompanion(
            id: Value(id),
            amount: amount != null ? Value(amount) : const Value.absent(),
            paymentDate: paymentDate != null ? Value(paymentDate) : const Value.absent(),
            paymentMethod: paymentMethod != null ? Value(paymentMethod) : const Value.absent(),
            referenceNumber: referenceNumber != null ? Value(referenceNumber) : const Value.absent(),
            notes: notes != null ? Value(notes) : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  // DELETE
  Future<int> deletePayment(int id) {
    return (_db.delete(_db.payments)..where((tbl) => tbl.id.equals(id))).go();
  }

  // CALCULATIONS
  Future<double> getTotalPayments(int eventId) async {
    final payments = await (_db.select(_db.payments)
          ..where((tbl) => tbl.eventId.equals(eventId)))
        .get();

    return payments.fold<double>(0.0, (sum, p) => sum + p.amount);
  }

  Future<double> getTotalPaymentsForParticipant(int participantId) async {
    final payments = await (_db.select(_db.payments)
          ..where((tbl) => tbl.participantId.equals(participantId)))
        .get();

    return payments.fold<double>(0.0, (sum, p) => sum + p.amount);
  }

  Future<double> getTotalPaymentsForFamily(int familyId) async {
    final payments = await (_db.select(_db.payments)
          ..where((tbl) => tbl.familyId.equals(familyId)))
        .get();

    return payments.fold<double>(0.0, (sum, p) => sum + p.amount);
  }

  // Get outstanding amount for participant (OLD - doesn't include family payments)
  Future<double> getOutstandingAmount(int participantId) async {
    final participant = await (_db.select(_db.participants)
          ..where((tbl) => tbl.id.equals(participantId)))
        .getSingleOrNull();

    if (participant == null) {
      return 0.0;
    }

    final expectedPrice =
        participant.manualPriceOverride ?? participant.calculatedPrice;
    final totalPaid = await getTotalPaymentsForParticipant(participantId);

    return expectedPrice - totalPaid;
  }

  // ============================================================================
  // FAMILY PAYMENT LOGIC
  // ============================================================================

  /// Berechnet Gesamtzahlungen eines Teilnehmers inkl. anteiliger Familienzahlungen
  ///
  /// Verteilungslogik (SEQUENTIELL nach Geburtsdatum):
  /// 1. Direkte Zahlungen des Teilnehmers
  /// 2. Anteilige Verteilung von Familienzahlungen:
  ///    - Sortiere Familienmitglieder nach Geburtsdatum (jüngste zuerst)
  ///    - Verteile sequentiell: Fülle jeden vollständig auf, bevor zum nächsten übergegangen wird
  ///
  /// Beispiel:
  /// - Familie mit 2 Personen: P1 (146,25€, jünger), P2 (112,50€, älter)
  /// - Familie zahlt 200€ -> Sequentielle Verteilung nach Geburtsdatum:
  ///   - P1 (jüngstes Kind): 146,25€ (vollständig bezahlt)
  ///   - P2: 200€ - 146,25€ = 53,75€ (Rest)
  ///   - Ergebnis: P1 bezahlt 146,25€, P2 bezahlt 53,75€
  Future<double> getTotalPaymentsWithFamilyShare(int participantId) async {
    final participant = await (_db.select(_db.participants)
          ..where((tbl) => tbl.id.equals(participantId)))
        .getSingleOrNull();

    if (participant == null) {
      AppLogger.warning('Participant not found for payment calculation', {'participantId': participantId});
      return 0.0;
    }

    // Direkte Zahlungen des Teilnehmers
    final directPayments = await getTotalPaymentsForParticipant(participantId);

    // Anteilige Familienzahlungen
    final familyShare = await _calculateFamilyPaymentShare(participant);

    final total = directPayments + familyShare;

    AppLogger.debug('Payment calculation for participant ${participant.id}', {
      'directPayments': directPayments,
      'familyShare': familyShare,
      'total': total,
    });

    return total;
  }

  /// Berechnet den Anteil eines Teilnehmers an Familienzahlungen
  ///
  /// Verteilungslogik (SEQUENTIELL):
  /// 1. Sortiere Familienmitglieder nach Geburtsdatum (jüngste zuerst)
  /// 2. Verteile Familienzahlung sequentiell: Fülle jeden Teilnehmer vollständig auf,
  ///    bevor zum nächsten übergegangen wird
  /// 3. Fallback: Wenn alles bezahlt, verteile proportional zum Sollpreis
  Future<double> _calculateFamilyPaymentShare(Participant participant) async {
    if (participant.familyId == null) {
      return 0.0;
    }

    // Alle aktiven Familienmitglieder laden
    final familyMembers = await (_db.select(_db.participants)
          ..where((tbl) => tbl.familyId.equals(participant.familyId!))
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();

    if (familyMembers.isEmpty) {
      AppLogger.warning('No family members found', {'familyId': participant.familyId});
      return 0.0;
    }

    // Gesamte Familienzahlungen
    final familyPayments = await getTotalPaymentsForFamily(participant.familyId!);

    if (familyPayments == 0) {
      return 0.0; // Keine Familienzahlungen vorhanden
    }

    // Sortiere Mitglieder nach Geburtsdatum (jüngste zuerst)
    familyMembers.sort((a, b) => b.birthDate.compareTo(a.birthDate));

    // Berechne für jedes Mitglied den offenen Betrag
    final membersData = <Map<String, dynamic>>[];
    double totalOutstanding = 0.0;
    double totalPrice = 0.0;

    for (final member in familyMembers) {
      final memberPrice = member.manualPriceOverride ?? member.calculatedPrice;
      final directPayments = await getTotalPaymentsForParticipant(member.id);
      final memberOutstanding = max(0.0, memberPrice - directPayments);

      membersData.add({
        'id': member.id,
        'participant': member,
        'price': memberPrice,
        'directPayments': directPayments,
        'outstanding': memberOutstanding,
      });

      totalOutstanding += memberOutstanding;
      totalPrice += memberPrice;
    }

    double share = 0.0;

    // FALL 1: Es gibt offene Beträge -> Sequentielle Verteilung
    if (totalOutstanding > 0) {
      double remainingPayment = familyPayments;

      // Verteile sequentiell nach Geburtsdatum (jüngste zuerst)
      for (final memberData in membersData) {
        final memberId = memberData['id'] as int;
        final memberOutstanding = memberData['outstanding'] as double;

        // Berechne wie viel dieser Teilnehmer erhält
        final allocation = min(memberOutstanding, remainingPayment);

        if (memberId == participant.id) {
          share = allocation;

          AppLogger.debug('Family payment distribution (sequential)', {
            'participantId': participant.id,
            'memberOutstanding': memberOutstanding,
            'totalOutstanding': totalOutstanding,
            'familyPayments': familyPayments,
            'remainingPayment': remainingPayment,
            'allocation': allocation,
          });

          break;
        }

        // Reduziere verbleibendes Budget
        remainingPayment -= allocation;

        // Wenn nichts mehr übrig ist, können weitere Teilnehmer nichts mehr bekommen
        if (remainingPayment <= 0) {
          break;
        }
      }
    }
    // FALL 2: Alles bezahlt, aber noch Familienzahlungen vorhanden
    // -> Verteile proportional zum Sollpreis
    else if (totalPrice > 0) {
      // Finde Daten des aktuellen Teilnehmers
      final memberData = membersData.firstWhere(
        (m) => m['id'] == participant.id,
        orElse: () => {'id': participant.id, 'outstanding': 0.0, 'price': 0.0},
      );

      final memberPrice = memberData['price'] as double;
      share = (memberPrice / totalPrice) * familyPayments;

      AppLogger.debug('Family payment distribution (proportional - all paid)', {
        'participantId': participant.id,
        'memberPrice': memberPrice,
        'totalPrice': totalPrice,
        'familyPayments': familyPayments,
        'share': share,
      });
    }

    return share;
  }

  /// Berechnet offenen Betrag inkl. Familienzahlungen
  Future<double> getOutstandingAmountWithFamilyShare(int participantId) async {
    final participant = await (_db.select(_db.participants)
          ..where((tbl) => tbl.id.equals(participantId)))
        .getSingleOrNull();

    if (participant == null) {
      return 0.0;
    }

    final expectedPrice = participant.manualPriceOverride ?? participant.calculatedPrice;
    final totalPaid = await getTotalPaymentsWithFamilyShare(participantId);

    return max(0.0, expectedPrice - totalPaid);
  }

  /// Gibt detaillierte Zahlungsinformationen für einen Teilnehmer zurück
  ///
  /// Rückgabe: Map mit:
  /// - 'directPayments': Direkte Zahlungen des Teilnehmers
  /// - 'familyShare': Anteil an Familienzahlungen
  /// - 'totalPaid': Gesamt bezahlt (direkt + Familie)
  /// - 'expectedPrice': Sollpreis
  /// - 'outstanding': Offener Betrag
  Future<Map<String, double>> getPaymentBreakdown(int participantId) async {
    final participant = await (_db.select(_db.participants)
          ..where((tbl) => tbl.id.equals(participantId)))
        .getSingleOrNull();

    if (participant == null) {
      return {
        'directPayments': 0.0,
        'familyShare': 0.0,
        'totalPaid': 0.0,
        'expectedPrice': 0.0,
        'outstanding': 0.0,
      };
    }

    final expectedPrice = participant.manualPriceOverride ?? participant.calculatedPrice;
    final directPayments = await getTotalPaymentsForParticipant(participantId);
    final familyShare = await _calculateFamilyPaymentShare(participant);
    final totalPaid = directPayments + familyShare;
    final outstanding = max(0.0, expectedPrice - totalPaid);

    return {
      'directPayments': directPayments,
      'familyShare': familyShare,
      'totalPaid': totalPaid,
      'expectedPrice': expectedPrice,
      'outstanding': outstanding,
    };
  }
}
