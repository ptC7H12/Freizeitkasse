import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/constants.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../utils/logger.dart';
import '../../extensions/context_extensions.dart';
import '../../providers/participant_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/pdf_export_provider.dart';
import '../../providers/participant_excel_provider.dart';
import 'participants_list_screen.dart';
import 'participant_form_screen.dart';
import '../families/families_list_screen.dart';
import '../families/family_form_screen.dart';

/// Participants and Families Screen with Tabs
///
/// Kombiniert Teilnehmer und Familien in einem Tab-basierten Screen
class ParticipantsAndFamiliesScreen extends ConsumerStatefulWidget {
  const ParticipantsAndFamiliesScreen({super.key});

  @override
  ConsumerState<ParticipantsAndFamiliesScreen> createState() => _ParticipantsAndFamiliesScreenState();
}

class _ParticipantsAndFamiliesScreenState extends ConsumerState<ParticipantsAndFamiliesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  /// Exportiert Teilnehmerliste als PDF
  Future<void> _exportParticipantsToPdf() async {
    try {
      final participantsValue = ref.read(participantsProvider).value;
      final currentEvent = ref.read(currentEventProvider);

      if (participantsValue == null || participantsValue.isEmpty) {
        if (context.mounted) {
          context.showError('Keine Teilnehmer zum Exportieren');
        }
        return;
      }

      final pdfService = ref.read(pdfExportServiceProvider);
      final filePath = await pdfService.exportParticipantsList(
        participants: participantsValue,
        eventName: currentEvent?.name ?? 'Veranstaltung',
      );

      if (context.mounted) {
        context.showSuccess('PDF gespeichert: $filePath');
      }

      AppLogger.info('Exported participants to PDF', {'path': filePath});
    } catch (e, stack) {
      AppLogger.error('Failed to export participants to PDF', error: e, stackTrace: stack);
      if (context.mounted) {
        context.showError('Fehler beim PDF-Export: $e');
      }
    }
  }

  /// Exportiert Teilnehmerliste als Excel
  Future<void> _exportParticipantsToExcel() async {
    try {
      final participantsValue = ref.read(participantsProvider).value;
      final currentEvent = ref.read(currentEventProvider);

      if (participantsValue == null || participantsValue.isEmpty) {
        if (context.mounted) {
          context.showError('Keine Teilnehmer zum Exportieren');
        }
        return;
      }

      final excelService = ref.read(participantExcelServiceProvider);
      final file = await excelService.exportParticipants(
        participants: participantsValue,
        eventName: currentEvent?.name ?? 'Veranstaltung',
      );

      if (context.mounted) {
        context.showSuccess('Excel exportiert: ${file.path}');
      }

      AppLogger.info('Exported participants to Excel', {'path': file.path});
    } catch (e, stack) {
      AppLogger.error('Failed to export participants to Excel', error: e, stackTrace: stack);
      if (context.mounted) {
        context.showError('Fehler beim Excel-Export: $e');
      }
    }
  }

  /// Importiert Teilnehmer aus Excel
  Future<void> _importParticipantsFromExcel() async {
    try {
      final currentEvent = ref.read(currentEventProvider);
      if (currentEvent == null) {
        if (context.mounted) {
          context.showError('Kein Event ausgewählt');
        }
        return;
      }

      final excelService = ref.read(participantExcelServiceProvider);
      final result = await excelService.importParticipants(
        eventId: currentEvent.id,
      );

      if (context.mounted) {
        if (result.success) {
          context.showSuccess(result.message);

          // Zeige Fehler-Details falls vorhanden
          if (result.errors.isNotEmpty) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Import-Fehler'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.errors.map((e) => Text('• $e')).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          context.showError(result.message);
        }
      }

      AppLogger.info('Imported participants from Excel', {'success': result.success});
    } catch (e, stack) {
      AppLogger.error('Failed to import participants from Excel', error: e, stackTrace: stack);
      if (context.mounted) {
        context.showError('Fehler beim Importieren: $e');
      }
    }
  }

  /// Lädt Excel-Import-Vorlage herunter
  Future<void> _downloadImportTemplate() async {
    try {
      final excelService = ref.read(participantExcelServiceProvider);
      final file = await excelService.createImportTemplate();

      if (context.mounted) {
        context.showSuccess('Vorlage erstellt: ${file.path}');
      }

      AppLogger.info('Created import template', {'path': file.path});
    } catch (e, stack) {
      AppLogger.error('Failed to create import template', error: e, stackTrace: stack);
      if (context.mounted) {
        context.showError('Fehler beim Erstellen der Vorlage: $e');
      }
    }
  }

  /// Zeigt Export/Import-Optionen Dialog
  void _showExportImportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppConstants.paddingAll16,
              child: Text(
                'Export & Import',
                style: context.textTheme.titleLarge,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF exportieren'),
              subtitle: const Text('Teilnehmerliste als PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportParticipantsToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Excel exportieren'),
              subtitle: const Text('Teilnehmerliste als Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportParticipantsToExcel();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Excel importieren'),
              subtitle: const Text('Teilnehmer aus Excel-Datei importieren'),
              onTap: () {
                Navigator.pop(context);
                _importParticipantsFromExcel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.orange),
              title: const Text('Import-Vorlage herunterladen'),
              subtitle: const Text('Excel-Vorlage zum Ausfüllen'),
              onTap: () {
                Navigator.pop(context);
                _downloadImportTemplate();
              },
            ),
            SizedBox(height: AppConstants.spacingS),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Teilnehmer & Familien',
      selectedIndex: 1,
      body: Column(
        children: [
          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.person),
                text: 'Teilnehmer',
              ),
              Tab(
                icon: Icon(Icons.family_restroom),
                text: 'Familien',
              ),
            ],
          ),
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                // Tab 1: Teilnehmer
                _ParticipantsTabContent(),
                // Tab 2: Familien
                _FamiliesTabContent(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  /// Erstellt die FABs basierend auf dem aktiven Tab
  Widget _buildFloatingActionButtons() {
    // Tab 0: Teilnehmer - Haupt-FAB (Hinzufügen) + Extended FAB (Export/Import)
    if (_currentTabIndex == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Extended FAB für Export/Import
          FloatingActionButton.extended(
            heroTag: 'export_import_participants',
            onPressed: _showExportImportOptions,
            icon: const Icon(Icons.import_export),
            label: const Text('Export/Import'),
            tooltip: 'Teilnehmer exportieren oder importieren',
          ),
          SizedBox(height: AppConstants.spacingS),
          // Haupt-FAB für Hinzufügen
          FloatingActionButton.extended(
            heroTag: 'add_participant',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ParticipantFormScreen(),
                ),
              );
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Teilnehmer'),
            tooltip: 'Teilnehmer hinzufügen',
          ),
        ],
      );
    }

    // Tab 1: Familien - Nur Haupt-FAB (Hinzufügen)
    else {
      return FloatingActionButton.extended(
        heroTag: 'add_family',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FamilyFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Familie'),
        tooltip: 'Familie hinzufügen',
      );
    }
  }
}

/// Tab 1 Content: Teilnehmer
class _ParticipantsTabContent extends StatelessWidget {
  const _ParticipantsTabContent();

  @override
  Widget build(BuildContext context) {
    // Verwende den existierenden ParticipantsListScreen, aber ohne AppBar
    return const ParticipantsListScreen(embedded: true);
  }
}

/// Tab 2 Content: Familien
class _FamiliesTabContent extends StatelessWidget {
  const _FamiliesTabContent();

  @override
  Widget build(BuildContext context) {
    // Verwende den existierenden FamiliesListScreen, aber ohne AppBar
    return const FamiliesListScreen(embedded: true);
  }
}
