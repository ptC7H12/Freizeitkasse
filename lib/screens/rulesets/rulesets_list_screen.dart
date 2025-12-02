import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';
import '../../providers/ruleset_provider.dart';
import '../../providers/current_event_provider.dart';
import 'ruleset_form_screen.dart';
import '../../utils/constants.dart';
import '../../widgets/responsive_scaffold.dart';

class RulesetsListScreen extends ConsumerWidget {
  const RulesetsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);
    final rulesetsAsync = ref.watch(rulesetsProvider);
    final currentRulesetAsync = ref.watch(currentRulesetProvider);

    if (currentEvent == null) {
      return ResponsiveScaffold(
        title: 'Regelwerke',
        selectedIndex: 7,
        body: const Center(
          child: Text('Bitte wählen Sie zuerst eine Veranstaltung aus.'),
        ),
      );
    }

    return ResponsiveScaffold(
      title: 'Regelwerke',
      selectedIndex: 7,
      body: rulesetsAsync.when(
        data: (rulesets) {
          if (rulesets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rule_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: AppConstants.spacing),
                  Text(
                    'Noch keine Regelwerke',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Regelwerke definieren Preise und Rabatte',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
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

          return ListView(
            padding: AppConstants.paddingAll16,
            children: [
              // Current Active Ruleset Card
              currentRulesetAsync.when(
                data: (currentRuleset) {
                  if (currentRuleset != null) {
                    return Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: AppConstants.paddingAll16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppConstants.spacingS),
                                Text(
                                  'Aktuell aktives Regelwerk',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingM),
                            Text(
                              currentRuleset.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: AppConstants.spacingS),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Gültig ab: ${DateFormat('dd.MM.yyyy', 'de_DE').format(currentRuleset.validFrom)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            if (currentRuleset.description != null) ...[
                              const SizedBox(height: AppConstants.spacingS),
                              Text(
                                currentRuleset.description!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // All Rulesets List
              Text(
                'Alle Regelwerke',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppConstants.spacing),

              ...rulesets.map((ruleset) {
                final isCurrent = currentRulesetAsync.value?.id == ruleset.id;
                return _RulesetListItem(
                  ruleset: ruleset,
                  isCurrent: isCurrent,
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Fehler beim Laden der Regelwerke: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RulesetFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Regelwerk'),
      ),
    );
  }
}

class _RulesetListItem extends ConsumerWidget {
  final Ruleset ruleset;
  final bool isCurrent;

  const _RulesetListItem({
    required this.ruleset,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');
    final statisticsAsync = ref.watch(rulesetStatisticsProvider(ruleset.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RulesetFormScreen(rulesetId: ruleset.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppConstants.paddingAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                ruleset.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: AppConstants.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'AKTIV',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Gültig ab: ${dateFormat.format(ruleset.validFrom)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              if (ruleset.description != null) ...[
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  ruleset.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppConstants.spacingM),
              statisticsAsync.when(
                data: (stats) {
                  if (stats.containsKey('error')) {
                    return Container(
                      padding: AppConstants.paddingAll8,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Colors.red),
                          const SizedBox(width: AppConstants.spacingS),
                          Expanded(
                            child: Text(
                              stats['error'] as String? ?? '',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildStatChip(
                        context,
                        Icons.people_outline,
                        '${stats['ageGroupCount']} Altersgruppen',
                      ),
                      _buildStatChip(
                        context,
                        Icons.discount,
                        '${stats['roleDiscountCount']} Rollenrabatte',
                      ),
                      if (stats['hasFamilyDiscount'] as bool? ?? false)
                        _buildStatChip(
                          context,
                          Icons.family_restroom,
                          'Familienrabatt',
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
