import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/subsidy_repository.dart';
import '../services/subsidy_calculator_service.dart';
import '../services/subsidy_export_service.dart';
import 'database_provider.dart';
import 'current_event_provider.dart';
import '../utils/logger.dart';

// ========== REPOSITORY & SERVICE PROVIDERS ==========

/// Provider für SubsidyRepository
final subsidyRepositoryProvider = Provider<SubsidyRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SubsidyRepository(database);
});

/// Provider für SubsidyExportService
final subsidyExportServiceProvider = Provider<SubsidyExportService>((ref) {
  return SubsidyExportService();
});

// ========== SUBSIDY DATA PROVIDERS ==========

/// Provider für erwartete Gesamtzuschüsse (SOLL)
///
/// Liefert die Summe aller erwarteten Zuschüsse für das aktuelle Event.
/// Aktualisiert sich automatisch bei Änderungen an Teilnehmern, Rollen oder Rulesets.
final expectedSubsidiesProvider = StreamProvider<double>((ref) async* {
  final currentEvent = ref.watch(currentEventProvider);
  final repository = ref.watch(subsidyRepositoryProvider);

  if (currentEvent == null) {
    AppLogger.debug('[SubsidyProvider] Kein aktuelles Event → erwartete Zuschüsse = 0.0');
    yield 0.0;
    return;
  }

  AppLogger.debug('[SubsidyProvider] expectedSubsidiesProvider für Event ${currentEvent.id}');

  try {
    // Initiale Berechnung
    final initialSubsidies = await repository.getExpectedSubsidies(currentEvent.id);
    yield initialSubsidies;

    // Stream für reaktive Updates
    await for (final subsidies in repository.watchExpectedSubsidies(currentEvent.id)) {
      yield subsidies;
    }
  } catch (e, stack) {
    AppLogger.error(
      '[SubsidyProvider] Fehler beim Laden der erwarteten Zuschüsse',
      error: e,
      stackTrace: stack,
    );
    yield 0.0;
  }
});

/// Provider für Zuschüsse aufgeschlüsselt nach Rollen
///
/// Liefert eine Map mit Rollen-IDs als Key und Zuschuss-Details als Value.
final subsidiesByRoleProvider = FutureProvider<Map<int, SubsidyByRole>>((ref) async {
  final currentEvent = ref.watch(currentEventProvider);
  final repository = ref.watch(subsidyRepositoryProvider);

  if (currentEvent == null) {
    AppLogger.debug('[SubsidyProvider] Kein aktuelles Event → subsidiesByRole = {}');
    return {};
  }

  AppLogger.debug('[SubsidyProvider] subsidiesByRoleProvider für Event ${currentEvent.id}');

  try {
    return await repository.getSubsidiesByRole(currentEvent.id);
  } catch (e, stack) {
    AppLogger.error(
      '[SubsidyProvider] Fehler beim Laden der Zuschüsse nach Rollen',
      error: e,
      stackTrace: stack,
    );
    return {};
  }
});

/// Provider für Zuschüsse aufgeschlüsselt nach Rabatttyp
///
/// Liefert eine Map mit Rabatttyp als Key und Zuschuss-Details als Value.
/// WICHTIG: Bildung & Teilhabe (BUT) wird NICHT berücksichtigt!
final subsidiesByDiscountTypeProvider = FutureProvider<Map<String, SubsidyByDiscountType>>((ref) async {
  final currentEvent = ref.watch(currentEventProvider);
  final repository = ref.watch(subsidyRepositoryProvider);

  if (currentEvent == null) {
    AppLogger.debug('[SubsidyProvider] Kein aktuelles Event → subsidiesByDiscountType = {}');
    return {};
  }

  AppLogger.debug('[SubsidyProvider] subsidiesByDiscountTypeProvider für Event ${currentEvent.id}');

  try {
    return await repository.getSubsidiesByDiscountType(currentEvent.id);
  } catch (e, stack) {
    AppLogger.error(
      '[SubsidyProvider] Fehler beim Laden der Zuschüsse nach Rabatttyp',
      error: e,
      stackTrace: stack,
    );
    return {};
  }
});

/// Provider für Teilnehmer mit Zuschüssen
///
/// Liefert eine Liste aller Teilnehmer, die Zuschüsse erhalten
/// (ohne manualPriceOverride, mit Rabatten, ohne BUT).
final participantsWithSubsidiesProvider = FutureProvider<List<SubsidyParticipant>>((ref) async {
  final currentEvent = ref.watch(currentEventProvider);
  final repository = ref.watch(subsidyRepositoryProvider);

  if (currentEvent == null) {
    AppLogger.debug('[SubsidyProvider] Kein aktuelles Event → participantsWithSubsidies = []');
    return [];
  }

  AppLogger.debug('[SubsidyProvider] participantsWithSubsidiesProvider für Event ${currentEvent.id}');

  try {
    // Zuschüsse nach Rabatttyp holen (enthält alle relevanten Teilnehmer)
    final subsidiesByType = await repository.getSubsidiesByDiscountType(currentEvent.id);

    // Alle Teilnehmer aus allen Rabatttypen sammeln
    final allParticipants = <SubsidyParticipant>[];
    for (final typeData in subsidiesByType.values) {
      allParticipants.addAll(typeData.participants);
    }

    return allParticipants;
  } catch (e, stack) {
    AppLogger.error(
      '[SubsidyProvider] Fehler beim Laden der Teilnehmer mit Zuschüssen',
      error: e,
      stackTrace: stack,
    );
    return [];
  }
});

/// Provider für Teilnehmer einer bestimmten Rolle mit Zuschüssen
///
/// Args:
///   - roleId: ID der Rolle
///
/// Liefert eine Liste der Teilnehmer mit Zuschüssen für diese Rolle.
final participantsByRoleProvider = FutureProvider.family<List<SubsidyParticipant>, int>((ref, roleId) async {
  final currentEvent = ref.watch(currentEventProvider);
  final repository = ref.watch(subsidyRepositoryProvider);

  if (currentEvent == null) {
    AppLogger.debug('[SubsidyProvider] Kein aktuelles Event → participantsByRole = []');
    return [];
  }

  AppLogger.debug('[SubsidyProvider] participantsByRoleProvider für Event ${currentEvent.id}, Rolle $roleId');

  try {
    return await repository.getParticipantsByRole(currentEvent.id, roleId);
  } catch (e, stack) {
    AppLogger.error(
      '[SubsidyProvider] Fehler beim Laden der Teilnehmer für Rolle $roleId',
      error: e,
      stackTrace: stack,
    );
    return [];
  }
});
