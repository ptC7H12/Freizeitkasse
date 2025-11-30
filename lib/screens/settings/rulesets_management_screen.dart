import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ruleset_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../data/database/app_database.dart';
import '../../utils/constants.dart';
import '../rulesets/ruleset_form_screen.dart';

/// Rulesets Management Screen (in Settings)
///
/// Verwaltet alle Regelwerke mit Tabs für Liste, Bearbeitung und Vorschau
class RulesetsManagementScreen extends ConsumerStatefulWidget {
  const RulesetsManagementScreen({super.key});

  @override
  ConsumerState<RulesetsManagementScreen> createState() =>
      _RulesetsManagementScreenState();
}

class _RulesetsManagementScreenState
    extends ConsumerState<RulesetsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Regelwerke verwalten'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.list),
              text: 'Übersicht',
            ),
            Tab(
              icon: Icon(Icons.info_outline),
              text: 'Info',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRulesetsListTab(),
          _buildInfoTab(),
        ],
      ),
    );
  }

  Widget _buildRulesetsListTab() {
    final rulesetsAsync = ref.watch(rulesetsProvider);

    return rulesetsAsync.when(
      data: (rulesets) {
        if (rulesets.isEmpty) {
          return _buildEmptyState();
        }

        // Sortiere nach validFrom (neueste zuerst)
        final sortedRulesets = List<Ruleset>.from(rulesets)
          ..sort((a, b) => b.validFrom.compareTo(a.validFrom));

        return ListView.builder(
          padding: AppConstants.paddingAll16,
          itemCount: sortedRulesets.length,
          itemBuilder: (context, index) {
            final ruleset = sortedRulesets[index];
            final isActive = ruleset.isActive;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: isActive ? 3 : 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive ? Colors.green : Colors.grey,
                  child: Icon(
                    isActive ? Icons.check_circle : Icons.rule,
                    color: Colors.white,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ruleset.name,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'AKTIV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Gültig ab: ${_formatDate(ruleset.validFrom)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (ruleset.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        ruleset.description!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => _showRulesetPreview(ruleset),
                      tooltip: 'Vorschau',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RulesetFormScreen(
                              rulesetId: ruleset.id,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Bearbeiten',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Fehler: $error')),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: AppConstants.paddingAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: AppConstants.spacingM),
                      Text(
                        'Was sind Regelwerke?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),
                  const Text(
                    'Regelwerke definieren die Preisstruktur für Ihre Veranstaltung. '
                    'Sie legen fest, wie viel Teilnehmer basierend auf Alter, Rolle und Familienzugehörigkeit zahlen.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing),
          Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, color: Colors.orange[700]),
                      const SizedBox(width: AppConstants.spacingM),
                      Text(
                        'Bestandteile eines Regelwerks',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),
                  _buildInfoItem(
                    '📊 Altersgruppen',
                    'Definieren Sie Preisspannen für verschiedene Altersgruppen (z.B. Kinder, Jugendliche, Erwachsene).',
                  ),
                  _buildInfoItem(
                    '💼 Rollenrabatte',
                    'Gewähren Sie Rabatte basierend auf Rollen wie Mitarbeiter oder Leitung.',
                  ),
                  _buildInfoItem(
                    '👨‍👩‍👧‍👦 Familienrabatte',
                    'Bieten Sie Ermäßigungen für Familien mit mehreren Kindern.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacing),
          Card(
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_download, color: Colors.green[700]),
                      const SizedBox(width: AppConstants.spacingM),
                      Text(
                        'GitHub-Import',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),
                  const Text(
                    'Regelwerke können automatisch von GitHub importiert werden. '
                    'Konfigurieren Sie den GitHub-Pfad in den Einstellungen unter "GitHub-Integration".',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Container(
                    padding: AppConstants.paddingAll12,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dateiname-Pattern:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '{Freizeittyp}_{Jahr}.yaml',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingM),
                        const Text(
                          'Beispiele:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('• Kinderfreizeit_2025.yaml'),
                        const Text('• Teeniefreizeit_2025.yaml'),
                        const Text('• Jugendfreizeit_2025.yaml'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.rule,
            size: 100,
            color: Colors.grey,
          ),
          const SizedBox(height: AppConstants.spacingL),
          const Text(
            'Noch keine Regelwerke',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingS),
          const Text(
            'Erstellen Sie Ihr erstes Regelwerk.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: AppConstants.spacingL),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RulesetFormScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Regelwerk erstellen'),
          ),
        ],
      ),
    );
  }

  void _showRulesetPreview(Ruleset ruleset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ruleset.name),
        content: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            padding: AppConstants.paddingAll12,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ruleset.yamlContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RulesetFormScreen(
                    rulesetId: ruleset.id,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Bearbeiten'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
