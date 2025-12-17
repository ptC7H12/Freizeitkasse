import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../utils/logger.dart';

/// Service für File Storage (Belege, Dokumente)
class FileStorageService {
  /// Hole das App-Dokumente-Verzeichnis
  Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Erstelle Unterverzeichnis für Belege
  Future<Directory> getReceiptsDirectory(int eventId) async {
    final appDir = await getAppDocumentsDirectory();
    final receiptsDir = Directory(path.join(appDir.path, 'receipts', eventId.toString()));

    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    return receiptsDir;
  }

  /// Beleg hochladen
  Future<String?> uploadReceipt({
    required int eventId,
    required int expenseId,
  }) async {
    try {
      // File Picker öffnen
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = File(result.files.single.path!);

      // Zielverzeichnis
      final receiptsDir = await getReceiptsDirectory(eventId);

      // Dateiname: expense_ID_timestamp.extension
      final extension = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'expense_${expenseId}_$timestamp$extension';

      // Datei kopieren
      final targetPath = path.join(receiptsDir.path, fileName);
      await file.copy(targetPath);

      return targetPath;
    } catch (e) {
      AppLogger.debug('Error uploading receipt: $e');
      return null;
    }
  }

  /// Beleg löschen
  Future<bool> deleteReceipt(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.debug('Error deleting receipt: $e');
      return false;
    }
  }

  /// Prüfe, ob Datei existiert
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Hole Datei-Info
  FileInfo? getFileInfo(String? filePath) {
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    final file = File(filePath);
    final fileName = path.basename(filePath);
    final extension = path.extension(filePath).toLowerCase();

    ReceiptFileType fileType;
    if (extension == '.pdf') {
      fileType = ReceiptFileType.pdf;
    } else if (['.jpg', '.jpeg', '.png'].contains(extension)) {
      fileType = ReceiptFileType.image;
    } else {
      fileType = ReceiptFileType.unknown;
    }

    return FileInfo(
      path: filePath,
      name: fileName,
      type: fileType,
      file: file,
    );
  }

  /// Teile/Exportiere Datei
  Future<void> shareFile(String filePath) async {
    // TODO: Implement sharing (requires share_plus package)
    // Für jetzt nur als Platzhalter
    AppLogger.debug('Sharing file: $filePath');
  }
}

/// File Info Datenklasse
class FileInfo {
  final String path;
  final String name;
  final ReceiptFileType type;
  final File file;

  FileInfo({
    required this.path,
    required this.name,
    required this.type,
    required this.file,
  });
}

enum ReceiptFileType {
  image,
  pdf,
  unknown,
}
