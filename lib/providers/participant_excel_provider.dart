import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/participant_excel_service.dart';
import 'participant_provider.dart';

/// Provider für Participant Excel Service
final participantExcelServiceProvider = Provider<ParticipantExcelService>((ref) {
  final repository = ref.watch(participantRepositoryProvider);
  return ParticipantExcelService(repository);
});
