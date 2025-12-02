import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/settings_repository.dart';
import 'database_provider.dart';
import 'current_event_provider.dart';

/// Settings Repository Provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SettingsRepository(database);
});

/// Current Event Settings Provider (reactive)
final currentEventSettingsProvider = StreamProvider<Setting?>((ref) {
  final currentEvent = ref.watch(currentEventProvider);
  final repository = ref.watch(settingsRepositoryProvider);

  if (currentEvent == null) {
    return Stream.value(null);
  }

  return repository.watchSettingsByEventId(currentEvent.id);
});

/// Get or Create Settings for Current Event
final getOrCreateSettingsProvider = FutureProvider<Setting?>((ref) async {
  final currentEvent = ref.watch(currentEventProvider);
  final repository = ref.watch(settingsRepositoryProvider);

  if (currentEvent == null) {
    return null;
  }

  return repository.getOrCreateSettings(currentEvent.id);
});
