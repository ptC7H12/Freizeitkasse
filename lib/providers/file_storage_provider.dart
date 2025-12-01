import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_storage_service.dart';

/// Provider für File Storage Service
final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});
