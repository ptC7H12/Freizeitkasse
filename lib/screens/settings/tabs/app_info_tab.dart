import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

/// Tab 4: App-Informationen
///
/// Version, Lizenzen, Features
class AppInfoTab extends StatelessWidget {
  const AppInfoTab({super.key});

  @override
  Widget build(BuildContext context) {
    const appVersion = '1.0.0';
    const buildNumber = '1';

    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // App Info Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              children: [
                const Icon(
                  Icons.event_available,
                  size: 80,
                  color: Color(0xFF2196F3),
                ),
                const SizedBox(height: AppConstants.spacing),
                const Text(
                  'MGB Freizeitplaner',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Version $appVersion (Build $buildNumber)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Funktionen Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Funktionen',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                _buildFeatureTile('Teilnehmerverwaltung mit Familienrabatt'),
                _buildFeatureTile('Zahlungsverfolgung'),
                _buildFeatureTile('Ausgaben- und Einnahmenverwaltung'),
                _buildFeatureTile('Kassenstand-Übersicht'),
                _buildFeatureTile('PDF-Export für Teilnehmerlisten'),
                _buildFeatureTile('Excel Import/Export'),
                _buildFeatureTile('Flexibles Regelwerk-System'),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Lizenzen Card
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Open Source Lizenzen'),
                subtitle: const Text('Verwendete Bibliotheken anzeigen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'MGB Freizeitplaner',
                    applicationVersion: appVersion,
                    applicationIcon: const Icon(
                      Icons.event_available,
                      size: 48,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Copyright
        Center(
          child: Text(
            '© 2024 MGB Freizeitplaner\nAlle Rechte vorbehalten',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTile(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Text(feature),
          ),
        ],
      ),
    );
  }
}
