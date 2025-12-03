import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/excel_import_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../services/excel_import_service.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import '../../extensions/context_extensions.dart';

class ParticipantImportScreen extends ConsumerStatefulWidget {
  const ParticipantImportScreen({super.key});

  @override
  ConsumerState<ParticipantImportScreen> createState() => _ParticipantImportScreenState();
}

class _ParticipantImportScreenState extends ConsumerState<ParticipantImportScreen> {
  String? _selectedFilePath;
  bool _isImporting = false;
  ExcelImportResult? _importResult;

  Future<void> _pickFile() async {
    AppLogger.info('[ImportScreen] Opening file picker...');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      AppLogger.debug('[ImportScreen] File picker result: ${result != null ? "File selected" : "Cancelled"}');

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;

        AppLogger.info('[ImportScreen] File selected:');
        AppLogger.info('[ImportScreen]   Name: $fileName');
        AppLogger.info('[ImportScreen]   Path: $filePath');
        AppLogger.info('[ImportScreen]   Size: $fileSize bytes');

        // Check if file exists
        final file = File(filePath);
        if (!file.existsSync()) {
          AppLogger.error('[ImportScreen] File does not exist at path: $filePath');
          if (mounted) {
            context.showError('Datei nicht gefunden');
          }
          return;
        }

        AppLogger.info('[ImportScreen] File exists and is readable');

        setState(() {
          _selectedFilePath = filePath;
          _importResult = null; // Reset previous result
        });

        AppLogger.info('[ImportScreen] File path stored in state');
      } else {
        AppLogger.info('[ImportScreen] No file selected or path is null');
      }
    } catch (e, stackTrace) {
      AppLogger.error('[ImportScreen] Error in file picker', error: e, stackTrace: stackTrace);
      if (mounted) {
        context.showError('Fehler beim Auswählen der Datei: $e');
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/teilnehmer_vorlage.xlsx';

      final service = ref.read(excelImportServiceProvider);
      final path = await service.generateImportTemplate(outputPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vorlage gespeichert: $path'),
            action: SnackBarAction(
              label: 'Öffnen',
              onPressed: () {
                // TODO: Open file with default app
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen der Vorlage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importFile() async {
    AppLogger.info('[ImportScreen] ==================== IMPORT START ====================');
    AppLogger.info('[ImportScreen] _importFile() called');

    if (_selectedFilePath == null) {
      AppLogger.warning('[ImportScreen] No file selected');
      context.showError('Bitte wählen Sie zuerst eine Datei aus');
      return;
    }

    AppLogger.info('[ImportScreen] File path: $_selectedFilePath');

    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) {
      AppLogger.warning('[ImportScreen] No event selected');
      context.showError('Keine Veranstaltung ausgewählt');
      return;
    }

    AppLogger.info('[ImportScreen] Current event: ${currentEvent.name} (ID: ${currentEvent.id})');

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    AppLogger.info('[ImportScreen] State updated - import started');

    try {
      AppLogger.info('[ImportScreen] Getting excel import service from provider...');
      final service = ref.read(excelImportServiceProvider);
      AppLogger.info('[ImportScreen] Service obtained: ${service.runtimeType}');

      AppLogger.info('[ImportScreen] Calling importParticipantsFromExcel()...');
      AppLogger.info('[ImportScreen]   filePath: $_selectedFilePath');
      AppLogger.info('[ImportScreen]   eventId: ${currentEvent.id}');

      final result = await service.importParticipantsFromExcel(
        filePath: _selectedFilePath!,
        eventId: currentEvent.id,
      );

      AppLogger.info('[ImportScreen] Import completed!');
      AppLogger.info('[ImportScreen] Result: $result');

      setState(() {
        _importResult = result;
      });

      if (result.successCount > 0) {
        AppLogger.info('[ImportScreen] Showing success message: ${result.successCount} participants imported');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.successCount} Teilnehmer erfolgreich importiert'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (result.hasErrors) {
        AppLogger.warning('[ImportScreen] Import had ${result.errorCount} errors');
        AppLogger.warning('[ImportScreen] Errors: ${result.errors}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import abgeschlossen mit ${result.errorCount} Fehlern'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('[ImportScreen] FATAL ERROR during import', error: e, stackTrace: stackTrace);
      AppLogger.error('[ImportScreen] Error type: ${e.runtimeType}');
      AppLogger.error('[ImportScreen] Error message: $e');
      AppLogger.error('[ImportScreen] Stack trace:\n$stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      AppLogger.info('[ImportScreen] Cleaning up - setting _isImporting to false');
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
      AppLogger.info('[ImportScreen] ==================== IMPORT END ====================');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teilnehmer importieren'),
      ),
      body: ListView(
        padding: AppConstants.paddingAll16,
        children: [
          // Instructions Card
          Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(
                        'Anleitung',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  const Text(
                    '1. Laden Sie die Excel-Vorlage herunter\n'
                    '2. Füllen Sie die Teilnehmerdaten aus\n'
                    '3. Speichern Sie die Datei\n'
                    '4. Wählen Sie die Datei aus und starten Sie den Import\n\n'
                    'Pflichtfelder: Vorname, Nachname, Geburtsdatum',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing),

          // Download Template Button
          Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schritt 1: Vorlage herunterladen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  FilledButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('Excel-Vorlage herunterladen'),
                    style: FilledButton.styleFrom(
                      padding: AppConstants.paddingAll16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing),

          // File Selection
          Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schritt 2: Datei auswählen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  if (_selectedFilePath != null) ...[
                    Container(
                      padding: AppConstants.paddingAll12,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: AppConstants.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Datei ausgewählt',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _selectedFilePath!.split(Platform.pathSeparator).last,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedFilePath = null;
                                _importResult = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingM),
                  ],
                  FilledButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text(_selectedFilePath == null
                        ? 'Excel-Datei auswählen'
                        : 'Andere Datei auswählen'),
                    style: FilledButton.styleFrom(
                      padding: AppConstants.paddingAll16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing),

          // Import Button
          Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schritt 3: Import starten',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  FilledButton.icon(
                    onPressed: _isImporting || _selectedFilePath == null ? null : _importFile,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isImporting ? 'Importiere...' : 'Import starten'),
                    style: FilledButton.styleFrom(
                      padding: AppConstants.paddingAll16,
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Import Results
          if (_importResult != null) ...[
            const SizedBox(height: AppConstants.spacing),
            Card(
              color: _importResult!.hasErrors ? Colors.orange[50] : Colors.green[50],
              child: Padding(
                padding: AppConstants.paddingAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _importResult!.hasErrors ? Icons.warning_amber : Icons.check_circle,
                          color: _importResult!.hasErrors ? Colors.orange[700] : Colors.green[700],
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          'Import-Ergebnis',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _importResult!.hasErrors
                                    ? Colors.orange[900]
                                    : Colors.green[900],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingM),
                    Text('Gesamtzeilen: ${_importResult!.totalRows}'),
                    Text('Erfolgreich: ${_importResult!.successCount}'),
                    if (_importResult!.hasErrors)
                      Text('Fehler: ${_importResult!.errorCount}'),
                    if (_importResult!.hasErrors) ...[
                      const SizedBox(height: AppConstants.spacingM),
                      const Divider(),
                      const SizedBox(height: AppConstants.spacingM),
                      Text(
                        'Fehlerdetails:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      ..._importResult!.errors.take(10).map((error) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $error',
                              style: const TextStyle(fontSize: 12),
                            ),
                          )),
                      if (_importResult!.errors.length > 10)
                        Text(
                          '... und ${_importResult!.errors.length - 10} weitere Fehler',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
