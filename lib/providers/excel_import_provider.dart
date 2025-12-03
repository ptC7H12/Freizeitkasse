import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/excel_import_service.dart';
import 'participant_provider.dart';
import 'family_provider.dart';

/// Provider for ExcelImportService
final excelImportServiceProvider = Provider<ExcelImportService>((ref) {
  final participantRepository = ref.watch(participantRepositoryProvider);
  final familyRepository = ref.watch(familyRepositoryProvider);
  return ExcelImportService(participantRepository, familyRepository);
});
