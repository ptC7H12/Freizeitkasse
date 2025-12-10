import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/participant_excel_service.dart';
import 'participant_provider.dart';
import 'family_provider.dart';
import 'payment_provider.dart';

/// Provider für Participant Excel Service
final participantExcelServiceProvider = Provider<ParticipantExcelService>((ref) {
  final participantRepository = ref.watch(participantRepositoryProvider);
  final familyRepository = ref.watch(familyRepositoryProvider);
  final paymentRepository = ref.watch(paymentRepositoryProvider);
  return ParticipantExcelService(
    participantRepository,
    familyRepository,
    paymentRepository,
  );
});
