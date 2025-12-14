import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';
import '../../providers/ruleset_provider.dart';
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
                    if (!isActive)
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline, size: 20),
                        onPressed: () => _activateRuleset(ruleset),
                        tooltip: 'Aktivieren',
                        color: Colors.green,
                      ),
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

  Future<void> _activateRuleset(Ruleset ruleset) async {
    // Confirm activation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regelwerk aktivieren?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie das Regelwerk "${ruleset.name}" aktivieren?'),
            const SizedBox(height: 16),
            const Text(
              'Dies wird:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Alle anderen Regelwerke deaktivieren'),
            const Text('• Alle Teilnehmerpreise neu berechnen'),
            const SizedBox(height: 16),
            const Text(
              'Hinweis: Teilnehmer mit manuellen Preisen werden übersprungen.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aktivieren'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(rulesetRepositoryProvider);

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Regelwerk wird aktiviert...'),
                    Text('Preise werden neu berechnet...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      await repository.activateRuleset(ruleset.id);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Regelwerk "${ruleset.name}" wurde aktiviert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Aktivieren: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRulesetPreview(Ruleset ruleset) {
    // Parse YAML
    Map<String, dynamic>? parsedYaml;
    try {
      final yamlDoc = loadYaml(ruleset.yamlContent);
      parsedYaml = Map<String, dynamic>.from(yamlDoc as Map);
    } catch (e) {
      // If parsing fails, show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fehler'),
          content: Text('YAML konnte nicht geparst werden: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ruleset.name),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Altersgruppen
                if (parsedYaml?['age_groups'] != null)
                  _buildPreviewAgeGroups(parsedYaml!['age_groups']),

                const SizedBox(height: AppConstants.spacing),

                // Rollenrabatte
                if (parsedYaml?['role_discounts'] != null)
                  _buildPreviewRoleDiscounts(parsedYaml!['role_discounts']),

                const SizedBox(height: AppConstants.spacing),

                // Familienrabatte
                if (parsedYaml?['family_discount'] != null)
                  _buildPreviewFamilyDiscount(parsedYaml!['family_discount']),
              ],
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

  Widget _buildPreviewAgeGroups(dynamic ageGroups) {
    // Handle both List and Map structures
    final groupsList = ageGroups is List ? ageGroups : [];

    return Card(
      elevation: 0,
      color: Colors.green[50],
      child: Padding(
        padding: AppConstants.paddingAll12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cake, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Altersgruppen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...groupsList.map((group) {
              final groupMap = Map<String, dynamic>.from(group as Map);
              final name = (groupMap['name'] ?? 'Unbenannt') as String;
              final minAge = groupMap['min_age'] ?? 0;
              final maxAge = groupMap['max_age'] ?? 999;
              final price = groupMap['base_price'] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '$minAge - $maxAge Jahre',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(price as num).toStringAsFixed(2)} €',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRoleDiscounts(dynamic roleDiscounts) {
    // Handle both List and Map structures
    List<MapEntry<String, dynamic>> discountEntries = [];

    if (roleDiscounts is Map) {
      // Map structure: role_name -> {discount_percent, ...}
      discountEntries = roleDiscounts.entries
          .map((e) => MapEntry<String, dynamic>(e.key.toString(), e.value))
          .toList();
    } else if (roleDiscounts is List) {
      // List structure: [{role_name: ..., discount_percent: ...}]
      discountEntries = roleDiscounts.map((item) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        final roleName = itemMap['role_name'] ?? 'Unbenannt';
        return MapEntry<String, dynamic>(roleName.toString(), itemMap);
      }).toList();
    }

    return Card(
      elevation: 0,
      color: Colors.blue[50],
      child: Padding(
        padding: AppConstants.paddingAll12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Rollenrabatte',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...discountEntries.map((entry) {
              final discountData = entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : <String, dynamic>{'discount_percent': entry.value};
              final roleName = entry.key;
              final discountPercent = discountData['discount_percent'] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        roleName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.discount, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${(discountPercent as num).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewFamilyDiscount(dynamic familyDiscount) {
    if (familyDiscount is! Map) {
      return const SizedBox.shrink();
    }

    final discountMap = Map<String, dynamic>.from(familyDiscount as Map);

    // Check if it's the new structure with first_child_percent, etc.
    final hasDirectPercentages = discountMap.containsKey('first_child_percent');

    // For old structure
    final minChildren = discountMap['min_children'] ?? 0;
    final discountPerChild = discountMap['discount_percent_per_child'];

    return Card(
      elevation: 0,
      color: Colors.pink[50],
      child: Padding(
        padding: AppConstants.paddingAll12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.family_restroom, color: Colors.pink[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Familienrabatte',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.pink[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (hasDirectPercentages) ...[
              // New structure: first_child_percent, second_child_percent, etc.
              if (discountMap['first_child_percent'] != null)
                _buildFamilyDiscountItem(
                  '1. Kind',
                  discountMap['first_child_percent'] as num,
                ),
              if (discountMap['second_child_percent'] != null)
                _buildFamilyDiscountItem(
                  '2. Kind',
                  discountMap['second_child_percent'] as num,
                ),
              if (discountMap['third_plus_child_percent'] != null)
                _buildFamilyDiscountItem(
                  '3+ Kind',
                  discountMap['third_plus_child_percent'] as num,
                ),
            ] else ...[
              // Old structure: min_children + discount_percent_per_child list
              if (minChildren > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Ab $minChildren Kindern',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),

              if (discountPerChild is List)
                ...discountPerChild.map((item) {
                  final itemMap = Map<String, dynamic>.from(item as Map);
                  final childrenCount = itemMap['children_count'] ?? 0;
                  final discountPercent = itemMap['discount_percent'] ?? 0.0;
                  return _buildFamilyDiscountItem(
                    '$childrenCount. Kind',
                    discountPercent as num,
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyDiscountItem(String label, num discountPercent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.pink[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.discount, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '${discountPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
