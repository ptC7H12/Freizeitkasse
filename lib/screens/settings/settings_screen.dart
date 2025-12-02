import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/constants.dart';
import '../../providers/settings_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../extensions/context_extensions.dart';
import 'categories_management_screen.dart';
import 'rulesets_management_screen.dart';

/// Einstellungen-Screen mit Tabs
///
/// Tab 1: Allgemein (Organisation, Bankdaten, Betreff, Fußzeile)
/// Tab 2: Regelwerk (GitHub-Verzeichnis, Import, Dokumentation-Link)
/// Tab 3: Kategorien (Ausgaben- und Einnahmen-Kategorien)
/// Tab 4: App-Infos (Version, Lizenzen)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.business),
              text: 'Allgemein',
            ),
            Tab(
              icon: Icon(Icons.rule),
              text: 'Regelwerk',
            ),
            Tab(
              icon: Icon(Icons.category),
              text: 'Kategorien',
            ),
            Tab(
              icon: Icon(Icons.info),
              text: 'App-Info',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Allgemein
          _GeneralSettingsTab(),

          // Tab 2: Regelwerk
          _RulesetSettingsTab(),

          // Tab 3: Kategorien
          const _CategoriesTab(),

          // Tab 4: App-Info
          const _AppInfoTab(),
        ],
      ),
    );
  }
}

// ========== TAB 1: ALLGEMEIN ==========
class _GeneralSettingsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends ConsumerState<_GeneralSettingsTab> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _organizationController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _ibanController = TextEditingController();
  final _bicController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _subjectController = TextEditingController();
  final _footerController = TextEditingController();

  @override
  void dispose() {
    _organizationController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _accountHolderController.dispose();
    _subjectController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // Organisation Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business, color: Color(0xFF2196F3)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Organisation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                TextFormField(
                  controller: _organizationController,
                  decoration: const InputDecoration(
                    labelText: 'Organisationsname',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Kontaktdaten (E-Mail, Telefon)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_mail),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Bankdaten Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF4CAF50)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Bankdaten',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                TextFormField(
                  controller: _ibanController,
                  decoration: const InputDecoration(
                    labelText: 'IBAN',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _bicController,
                  decoration: const InputDecoration(
                    labelText: 'BIC',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _accountHolderController,
                  decoration: const InputDecoration(
                    labelText: 'Kontoinhaber',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Dokumente Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description, color: Color(0xFFFF9800)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Dokumente',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Betreff für Rechnungen',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.subject),
                    hintText: 'z.B. Rechnung Sommerfreizeit 2024',
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                TextFormField(
                  controller: _footerController,
                  decoration: const InputDecoration(
                    labelText: 'Fußzeile für Dokumente',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.text_fields),
                    hintText: 'z.B. Mit freundlichen Grüßen...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Speichern Button
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement save functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Speichern-Funktion wird noch implementiert'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text('Speichern'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

// ========== TAB 2: REGELWERK ==========
class _RulesetSettingsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RulesetSettingsTab> createState() => _RulesetSettingsTabState();
}

class _RulesetSettingsTabState extends ConsumerState<_RulesetSettingsTab> {
  final _githubPathController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _githubPathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) return;

    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.getOrCreateSettings(currentEvent.id);

    if (mounted) {
      setState(() {
        _githubPathController.text = settings.githubRulesetPath ?? '';
      });
    }
  }

  Future<void> _saveSettings() async {
    final currentEvent = ref.read(currentEventProvider);
    if (currentEvent == null) {
      if (mounted) {
        context.showError('Kein Event ausgewählt');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(settingsRepositoryProvider);
      await repository.updateSettings(
        eventId: currentEvent.id,
        githubRulesetPath: _githubPathController.text.trim().isEmpty
            ? null
            : _githubPathController.text.trim(),
      );

      if (mounted) {
        context.showSuccess('Einstellungen gespeichert');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Fehler beim Speichern: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // GitHub-Integration Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_open, color: Color(0xFF2196F3)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'GitHub-Verzeichnis',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                TextFormField(
                  controller: _githubPathController,
                  decoration: const InputDecoration(
                    labelText: 'Pfad zum Regelwerk',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://github.com/ptC7H12/MGBFreizeitplaner/tree/main/rulesets/valid',
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Geben Sie den Pfad zum GitHub-Verzeichnis an, in dem Ihre Regelwerk-Dateien gespeichert sind.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: AppConstants.spacing),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveSettings,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Wird gespeichert...' : 'Speichern'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Import Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.upload_file, color: Color(0xFF4CAF50)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Regelwerk importieren',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RulesetsManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rule),
                  label: const Text('Regelwerk-Verwaltung öffnen'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Importieren Sie Regelwerk-Dateien (YAML) zur Preisberechnung.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Dokumentation Card
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book, color: Color(0xFFFF9800)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Dokumentation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Regelwerk-Dokumentation'),
                  subtitle: const Text('Wie erstelle ich Regelwerk-Dateien?'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    // TODO: Open documentation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dokumentation wird geöffnet...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ========== TAB 3: KATEGORIEN ==========
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        Card(
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category, color: Color(0xFF2196F3)),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Kategorien verwalten',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing),
                const Text(
                  'Verwalten Sie Ausgaben- und Einnahmen-Kategorien für eine bessere Organisation Ihrer Finanzen.',
                ),
                const SizedBox(height: AppConstants.spacing),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CategoriesManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Kategorien bearbeiten'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Info Card
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Hinweis',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                const Text(
                  'Kategorien helfen Ihnen, Ihre Einnahmen und Ausgaben zu organisieren und auszuwerten. '
                  'Sie können beliebig viele Kategorien erstellen und anpassen.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ========== TAB 4: APP-INFO ==========
class _AppInfoTab extends StatelessWidget {
  const _AppInfoTab();

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
          const Icon(Icons.check, size: 20, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Expanded(child: Text(feature)),
        ],
      ),
    );
  }
}
