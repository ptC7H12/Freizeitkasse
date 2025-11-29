import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

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
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
}
