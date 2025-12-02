import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:developer' as developer;
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/ruleset_provider.dart';
import '../../services/github_ruleset_service.dart';
//import '../../utils/route_helpers.dart';
import '../../utils/constants.dart';
import '../dashboard/dashboard_screen.dart';

/// Event Selection Screen
///
/// Startbildschirm mit zwei Bereichen:
/// - Links: Freizeit auswählen (Dropdown + Öffnen/Löschen Buttons)
/// - Rechts: Neue Freizeit erstellen (Formular)
class EventSelectionScreen extends ConsumerStatefulWidget {
  const EventSelectionScreen({super.key});

  @override
  ConsumerState<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends ConsumerState<EventSelectionScreen> {
  // Für Event-Auswahl (linke Seite)
  Event? _selectedEvent;

  // Für Event-Erstellung (rechte Seite)
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  String _selectedEventType = 'Kinderfreizeit';

  // Mobile: Welche Seite wird angezeigt?
  bool _showingCreateForm = false;

  final _eventTypes = [
    'Kinderfreizeit',
    'Teeniefreizeit',
    'Jugendfreizeit',
    'Familienfreizeit',
    'Sonstige',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MGB Freizeitplaner'),
        centerTitle: true,
        actions: [
          if (!isDesktop && !_showingCreateForm)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _showingCreateForm = true;
                });
              },
              tooltip: 'Neue Freizeit erstellen',
            ),
        ],
      ),
      body: StreamBuilder<List<Event>>(
        stream: database.select(database.events).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final events = snapshot.data ?? [];

          // Desktop: Beide Bereiche nebeneinander
          if (isDesktop) {
            return _buildDesktopLayout(events);
          }

          // Mobile: Entweder Auswahl oder Formular
          if (_showingCreateForm) {
            return _buildCreateEventForm(events);
          } else {
            return _buildEventSelection(events);
          }
        },
      ),
    );
  }

  // ========== DESKTOP LAYOUT ==========

  Widget _buildDesktopLayout(List<Event> events) {
    return Row(
      children: [
        // LINKE SEITE: Event-Auswahl
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: _buildEventSelection(events),
          ),
        ),

        // RECHTE SEITE: Event-Erstellung
        Expanded(
          flex: 1,
          child: _buildCreateEventForm(events),
        ),
      ],
    );
  }

  // ========== LINKE SEITE: EVENT-AUSWAHL ==========

  Widget _buildEventSelection(List<Event> events) {
    if (events.isEmpty) {
      return _buildEmptyState();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: AppConstants.paddingAll16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.event_available,
                size: 80,
                color: Color(0xFF2196F3),
              ),
              const SizedBox(height: AppConstants.spacingL),
              const Text(
                'Freizeit auswählen',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingS),
              const Text(
                'Wähle eine bestehende Freizeit aus',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXL),

              // DROPDOWN für Event-Auswahl
              DropdownButtonFormField<Event>(
                value: _selectedEvent,
                decoration: InputDecoration(
                  labelText: 'Freizeit',
                  prefixIcon: const Icon(Icons.event),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                hint: const Text('Bitte wählen...'),
                items: events.map((event) {
                  return DropdownMenuItem<Event>(
                    value: event,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (Event? value) {
                  setState(() {
                    _selectedEvent = value;
                  });
                },
              ),

              const SizedBox(height: AppConstants.spacingL),

              // BUTTONS: Öffnen und Löschen
              Row(
                children: [
                  // ÖFFNEN Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedEvent == null
                          ? null
                          : () => _openEvent(_selectedEvent!),
                      icon: const Icon(Icons.login),
                      label: const Text('Öffnen'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacing),

                  // LÖSCHEN Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectedEvent == null
                          ? null
                          : () => _showDeleteDialog(_selectedEvent!),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Löschen'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== RECHTE SEITE: EVENT-ERSTELLUNG ==========

  Widget _buildCreateEventForm(List<Event> events) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: AppConstants.paddingAll16,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.spacingL),
                const Icon(
                  Icons.add_circle_outline,
                  size: 80,
                  color: Color(0xFF2196F3),
                ),
                const SizedBox(height: AppConstants.spacingL),
                const Text(
                  'Neue Freizeit erstellen',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingS),
                const Text(
                  'Erstelle eine neue Freizeit',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXL),

                // FORMULAR
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: AppConstants.paddingAll16,
                    child: Column(
                      children: [
                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name der Freizeit *',
                            hintText: 'z.B. Sommerfreizeit 2025',
                            prefixIcon: Icon(Icons.text_fields),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Bitte Name eingeben';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppConstants.spacing),

                        // Freizeittyp
                        DropdownButtonFormField<String>(
                          value: _selectedEventType,
                          decoration: const InputDecoration(
                            labelText: 'Freizeittyp *',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items: _eventTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedEventType = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: AppConstants.spacing),

                        // Ort
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Ort',
                            hintText: 'z.B. Campingplatz Müggelsee',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacing),

                        // Startdatum
                        InkWell(
                          onTap: () => _selectStartDate(),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Startdatum *',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_formatDate(_startDate)),
                          ),
                        ),

                        const SizedBox(height: AppConstants.spacing),

                        // Enddatum
                        InkWell(
                          onTap: () => _selectEndDate(),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Enddatum *',
                              prefixIcon: Icon(Icons.event),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_formatDate(_endDate)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spacingL),

                // BESTÄTIGEN Button
                ElevatedButton.icon(
                  onPressed: () => _createEvent(),
                  icon: const Icon(Icons.check),
                  label: const Text('Bestätigen'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Mobile: Zurück-Button
                if (!isDesktop) ...[
                  const SizedBox(height: AppConstants.spacing),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showingCreateForm = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Zurück zur Auswahl'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== EMPTY STATE ==========

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_outlined,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: AppConstants.spacingL),
          const Text(
            'Noch keine Freizeiten vorhanden',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingS),
          const Text(
            'Erstelle deine erste Freizeit rechts →',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ========== ERROR STATE ==========

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: AppConstants.spacing),
          Text('Fehler: $error'),
        ],
      ),
    );
  }

  // ========== AKTIONEN ==========

  void _openEvent(Event event) {
    // Event in State speichern
    ref.read(currentEventProvider.notifier).selectEvent(event);

    // Zum Dashboard navigieren
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const DashboardScreen(),
      ),
    );
  }

  void _showDeleteDialog(Event event) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Freizeit löschen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Möchten Sie die Freizeit "${event.name}" wirklich löschen?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppConstants.spacing),
            const Text(
              'WARNUNG: Alle zugehörigen Daten werden ebenfalls gelöscht:',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppConstants.spacingS),
            const Text('• Teilnehmer'),
            const Text('• Familien'),
            const Text('• Zahlungen'),
            const Text('• Einnahmen'),
            const Text('• Ausgaben'),
            const Text('• Aufgaben'),
            const Text('• Regelwerke'),
            const SizedBox(height: AppConstants.spacing),
            const Text(
              'Diese Aktion kann nicht rückgängig gemacht werden!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final database = ref.read(databaseProvider);

              // Event löschen
              await (database.delete(database.events)
                    ..where((tbl) => tbl.id.equals(event.id)))
                  .go();

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();

                // Erfolgsmeldung
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Freizeit "${event.name}" wurde gelöscht'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                // Auswahl zurücksetzen
                setState(() {
                  _selectedEvent = null;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('de', 'DE'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 7));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      locale: const Locale('de', 'DE'),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final database = ref.read(databaseProvider);

    try {
      // Event erstellen
      final eventId = await database.into(database.events).insert(
            EventsCompanion.insert(
              name: _nameController.text,
              startDate: _startDate,
              endDate: _endDate,
              location: drift.Value(
                _locationController.text.isEmpty ? null : _locationController.text,
              ),
              eventType: drift.Value(_selectedEventType),
            ),
          );

      // Automatischer Ruleset-Import von GitHub
      await _importRulesetFromGitHub(
        eventId,
        _selectedEventType,
        _startDate.year,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Freizeit "${_nameController.text}" wurde erstellt'),
            backgroundColor: Colors.green,
          ),
        );

        // Formular zurücksetzen
        setState(() {
          _nameController.clear();
          _locationController.clear();
          _startDate = DateTime.now();
          _endDate = DateTime.now().add(const Duration(days: 7));
          _selectedEventType = 'Kinderfreizeit';

          // Mobile: Zurück zur Auswahl
          _showingCreateForm = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importRulesetFromGitHub(
    int eventId,
    String eventType,
    int year,
  ) async {
    // GitHub-Pfad aus Settings laden (vorerst hardcoded)
    const githubPath =
        'https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/rulesets';

    try {
      final yamlContent = await GitHubRulesetService.loadRulesetFromGitHub(
        githubBasePath: githubPath,
        eventType: eventType,
        year: year,
      );

      if (yamlContent != null) {
        final repository = ref.read(rulesetRepositoryProvider);

        await repository.createRuleset(
          eventId: eventId,
          name: '$eventType $year (GitHub)',
          yamlContent: yamlContent,
          validFrom: DateTime(year, 1, 1),
          description: 'Automatisch importiert von GitHub',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Regelwerk von GitHub geladen: $eventType'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      developer.log(
        'Fehler beim GitHub-Import: $e',
        name: 'EventSelectionScreen',
        level: 900,
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
