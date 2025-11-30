import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:developer' as developer;
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/ruleset_provider.dart';
import '../../services/github_ruleset_service.dart';
import '../../utils/route_helpers.dart';
import '../../utils/constants.dart';
import '../dashboard/dashboard_screen.dart';

/// Event Selection Screen
///
/// Entspricht der Landing Page / Event-Auswahl in der Web-App
/// Nutzer wählt hier das Event aus, an dem er arbeiten möchte
class EventSelectionScreen extends ConsumerWidget {
  const EventSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MGB Freizeitplaner'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Event>>(
        stream: database.select(database.events).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: AppConstants.spacing),
                  Text('Fehler: ${snapshot.error}'),
                ],
              ),
            );
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return _buildEmptyState(context, database);
          }

          return _buildEventList(context, ref, events);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEventDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Neues Event'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppDatabase database) {
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
            'Noch keine Events vorhanden',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingS),
          const Text(
            'Erstelle dein erstes Event, um zu beginnen.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: AppConstants.spacingL),
          ElevatedButton.icon(
            onPressed: () => _showCreateEventDialog(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Erstes Event erstellen'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(
    BuildContext context,
    WidgetRef ref,
    List<Event> events,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppConstants.spacingL),
              const Text(
                'Wähle ein Event aus',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingS),
              const Text(
                'Mit welchem Event möchtest du arbeiten?',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: AppConstants.paddingAll16,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(Icons.event, color: Colors.white),
                        ),
                        title: Text(
                          event.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppConstants.spacingS),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                                ),
                              ],
                            ),
                            if (event.location != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  Text(event.location!),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _selectEvent(context, ref, event),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectEvent(BuildContext context, WidgetRef ref, Event event) {
    // Event in State speichern
    ref.read(currentEventProvider.notifier).selectEvent(event);

    // Zum Dashboard navigieren
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const DashboardScreen(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _showCreateEventDialog(BuildContext context, WidgetRef? ref) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    String selectedEventType = 'Kinderfreizeit';

    final eventTypes = [
      'Kinderfreizeit',
      'Teeniefreizeit',
      'Jugendfreizeit',
      'Familienfreizeit',
      'Sonstige',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Neues Event erstellen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Event-Name *',
                    hintText: 'z.B. Sommerfreizeit 2025',
                  ),
                ),
                const SizedBox(height: AppConstants.spacing),
                DropdownButtonFormField<String>(
                  initialValue: selectedEventType,
                  decoration: const InputDecoration(
                    labelText: 'Freizeittyp *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: eventTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedEventType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppConstants.spacing),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Ort',
                    hintText: 'z.B. Campingplatz Müggelsee',
                  ),
                ),
                const SizedBox(height: AppConstants.spacing),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('de', 'DE'),
                    );
                    if (picked != null) {
                      setState(() {
                        startDate = picked;
                        if (endDate.isBefore(startDate)) {
                          endDate = startDate.add(const Duration(days: 7));
                        }
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Startdatum *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_formatDate(startDate)),
                  ),
                ),
                const SizedBox(height: AppConstants.spacing),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime(2100),
                      locale: const Locale('de', 'DE'),
                    );
                    if (picked != null) {
                      setState(() {
                        endDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Enddatum *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_formatDate(endDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => RouteHelpers.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bitte Event-Name eingeben'),
                    ),
                  );
                  return;
                }

                // Event erstellen
                final database = ref?.read(databaseProvider);
                if (database != null) {
                  final eventId = await database.into(database.events).insert(
                        EventsCompanion.insert(
                          name: nameController.text,
                          startDate: startDate,
                          endDate: endDate,
                          location: drift.Value(locationController.text.isEmpty
                              ? null
                              : locationController.text),
                          eventType: drift.Value(selectedEventType),
                        ),
                      );

                  // Automatischer Ruleset-Import von GitHub
                  if (ref != null) {
                    await _importRulesetFromGitHub(
                      context,
                      ref,
                      eventId,
                      selectedEventType,
                      startDate.year,
                    );
                  }
                }

                if (context.mounted) {
                  RouteHelpers.pop(context);
                }
              },
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importRulesetFromGitHub(
    BuildContext context,
    WidgetRef ref,
    int eventId,
    String eventType,
    int year,
  ) async {
    // GitHub-Pfad aus Settings laden (vorerst hardcoded)
    // TODO: Aus Settings-Tabelle laden
    const githubPath = 'https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/rulesets';

    // Versuche Ruleset von GitHub zu laden
    try {
      final yamlContent = await GitHubRulesetService.loadRulesetFromGitHub(
        githubBasePath: githubPath,
        eventType: eventType,
        year: year,
      );

      if (yamlContent != null) {
        // Ruleset erfolgreich geladen - speichern
        //final database = ref.read(databaseProvider);
        final repository = ref.read(rulesetRepositoryProvider);

        await repository.createRuleset(
          eventId: eventId,
          name: '$eventType $year (GitHub)',
          yamlContent: yamlContent,
          validFrom: DateTime(year, 1, 1),
          description: 'Automatisch importiert von GitHub',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Regelwerk von GitHub geladen: $eventType'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Fallback auf lokales Template
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GitHub-Regelwerk nicht gefunden - verwende Standard-Template'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Fehler beim Laden - stilles Fallback
      developer.log(
        'Fehler beim GitHub-Import: $e',
        name: 'EventSelectionScreen',
        level: 900,
      );
    }
  }
}
