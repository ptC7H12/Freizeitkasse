import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/constants.dart';
import '../../providers/database_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../data/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'categories_management_screen.dart';
import 'rulesets_management_screen.dart';

/// Einstellungen-Screen
///
/// Zeigt App-Informationen und zukünftige Einstellungsoptionen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const appVersion = '1.0.0';
    const buildNumber = '1';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        children: [
          // App Information Section
          _buildSectionHeader(context, 'App-Informationen'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: 'App-Name',
                  subtitle: 'MGB Freizeitplaner',
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.tag,
                  title: 'Version',
                  subtitle: appVersion,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.code,
                  title: 'Build-Nummer',
                  subtitle: buildNumber,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacing),

          // Appearance Section (Future)
          _buildSectionHeader(context, 'Darstellung'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Design-Modus'),
                  subtitle: const Text('Hell'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement theme switching
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dark Mode kommt bald!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacing),

          // Categories Section
          _buildSectionHeader(context, 'Kategorien'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Kategorien verwalten'),
                  subtitle: const Text('Ausgaben- und Einnahmen-Kategorien'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CategoriesManagementScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacing),

          // Rulesets Management Section
          _buildSectionHeader(context, 'Regelwerke'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rule),
                  title: const Text('Regelwerke verwalten'),
                  subtitle: const Text('Preisstrukturen und Rabatte konfigurieren'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RulesetsManagementScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacing),

          // GitHub Integration Section
          _buildSectionHeader(context, 'GitHub-Integration'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('GitHub Ruleset-Pfad'),
                  subtitle: const Text('URL zu GitHub-Repository mit Regelwerk-Templates'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showGitHubPathDialog(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacing),

          // Data Section
          _buildSectionHeader(context, 'Daten'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Datenbank sichern'),
                  subtitle: const Text('Export der Datenbank'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement database backup
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backup-Funktion kommt bald!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Datenbank wiederherstellen'),
                  subtitle: const Text('Import einer Sicherung'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implement database restore
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Wiederherstellungs-Funktion kommt bald!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacing),

          // About Section
          _buildSectionHeader(context, 'Über'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Lizenzen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'MGB Freizeitplaner',
                      applicationVersion: appVersion,
                      applicationIcon: Padding(
                        padding: AppConstants.paddingAll16,
                        child: Container(
                          padding: AppConstants.paddingAll16,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.event,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.group_outlined,
                  title: 'Entwickelt für',
                  subtitle: 'MGB Jugendfreizeiten',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  void _showGitHubPathDialog(BuildContext context, WidgetRef ref) async {
    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein Event ausgewählt')),
      );
      return;
    }

    final database = ref.read(databaseProvider);

    // Lade aktuelle Settings
    final settings = await (database.select(database.settings)
          ..where((tbl) => tbl.eventId.equals(currentEvent.id)))
        .getSingleOrNull();

    final controller = TextEditingController(
      text: settings?.githubRulesetPath ?? '',
    );

    if (!context.mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub Ruleset-Pfad konfigurieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basis-URL zu Ihrem GitHub-Repository mit Regelwerk-Templates.\n\n'
              'Beispiel:\n'
              'https://raw.githubusercontent.com/user/repo/main/rulesets\n\n'
              'Pattern: {Freizeittyp}_{Jahr}.yaml',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: AppConstants.spacing),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'GitHub-Pfad',
                hintText: 'https://raw.githubusercontent.com/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Container(
              padding: AppConstants.paddingAll12,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erwartete Dateinamen:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text('• Kinderfreizeit_2025.yaml', style: TextStyle(fontSize: 11)),
                  Text('• Teeniefreizeit_2025.yaml', style: TextStyle(fontSize: 11)),
                  Text('• Jugendfreizeit_2025.yaml', style: TextStyle(fontSize: 11)),
                  Text('• Familienfreizeit_2025.yaml', style: TextStyle(fontSize: 11)),
                  Text('• Sonstige_2025.yaml', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final path = controller.text.trim();

              if (settings == null) {
                // Settings noch nicht vorhanden - erstellen
                await database.into(database.settings).insert(
                  SettingsCompanion.insert(
                    eventId: currentEvent.id,
                    githubRulesetPath: drift.Value(path.isEmpty ? null : path),
                  ),
                );
              } else {
                // Settings aktualisieren
                await (database.update(database.settings)
                      ..where((tbl) => tbl.id.equals(settings.id)))
                    .write(
                  SettingsCompanion(
                    githubRulesetPath: drift.Value(path.isEmpty ? null : path),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('GitHub-Pfad gespeichert'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
