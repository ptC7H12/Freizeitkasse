import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart' as db;
import '../../utils/constants.dart';

/// Regelwerk-Übersicht Screen
///
/// Zeigt eine grafische Übersicht des aktiven Regelwerks:
/// - Altersgruppen mit Basispreisen
/// - Rollenrabatte
/// - Familienrabatte
class RulesetOverviewScreen extends ConsumerWidget {
  const RulesetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);
    final database = ref.watch(databaseProvider);

    if (currentEvent == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Regelwerk'),
        ),
        body: const Center(
          child: Text('Kein Event ausgewählt'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regelwerk'),
      ),
      body: StreamBuilder<List<db.Ruleset>>(
        stream: (database.select(database.rulesets)
              ..where((tbl) => tbl.eventId.equals(currentEvent.id))
              ..where((tbl) => tbl.isActive.equals(true)))
            .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(context);
          }

          final ruleset = snapshot.data!.first;

          // Parse JSON data
          Map<String, dynamic> ageGroups = {};
          Map<String, dynamic> roleDiscounts = {};
          Map<String, dynamic> familyDiscount = {};

          try {
            if (ruleset.ageGroups != null && ruleset.ageGroups!.isNotEmpty) {
              ageGroups = jsonDecode(ruleset.ageGroups!) as Map<String, dynamic>;
            }
            if (ruleset.roleDiscounts != null && ruleset.roleDiscounts!.isNotEmpty) {
              roleDiscounts = jsonDecode(ruleset.roleDiscounts!) as Map<String, dynamic>;
            }
            if (ruleset.familyDiscount != null && ruleset.familyDiscount!.isNotEmpty) {
              familyDiscount = jsonDecode(ruleset.familyDiscount!) as Map<String, dynamic>;
            }
          } catch (e) {
            return Center(
              child: Text('Fehler beim Parsen des Regelwerks: $e'),
            );
          }

          return _buildContent(context, ruleset, ageGroups, roleDiscounts, familyDiscount);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rule,
            size: 100,
            color: Colors.grey,
          ),
          SizedBox(height: AppConstants.spacing),
          Text(
            'Kein aktives Regelwerk',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppConstants.spacingS),
          Text(
            'Importieren Sie ein Regelwerk in den Einstellungen',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    db.Ruleset ruleset,
    Map<String, dynamic> ageGroups,
    Map<String, dynamic> roleDiscounts,
    Map<String, dynamic> familyDiscount,
  ) {
    return ListView(
      padding: AppConstants.paddingAll16,
      children: [
        // Header Card
        Card(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          child: Padding(
            padding: AppConstants.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rule, color: Color(0xFF2196F3), size: 32),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ruleset.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (ruleset.description != null)
                            Text(
                              ruleset.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Gültig ab ${_formatDate(ruleset.validFrom)}${ruleset.validUntil != null ? ' bis ${_formatDate(ruleset.validUntil!)}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.spacing),

        // Altersgruppen
        _buildAgeGroupsSection(context, ageGroups),

        const SizedBox(height: AppConstants.spacing),

        // Rollenrabatte
        _buildRoleDiscountsSection(context, roleDiscounts),

        const SizedBox(height: AppConstants.spacing),

        // Familienrabatte
        _buildFamilyDiscountSection(context, familyDiscount),
      ],
    );
  }

  Widget _buildAgeGroupsSection(BuildContext context, Map<String, dynamic> ageGroups) {
    return Card(
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cake, color: Color(0xFF4CAF50)),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Altersgruppen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            const Text(
              'Basispreise nach Alter des Teilnehmers',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: AppConstants.spacing),

            if (ageGroups.isEmpty)
              const Text(
                'Keine Altersgruppen definiert',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              ...ageGroups.entries.map((entry) {
                final groupData = entry.value as Map<String, dynamic>;
                final minAge = groupData['min_age'] ?? 0;
                final maxAge = groupData['max_age'] ?? 999;
                final price = groupData['price'] ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                      child: Text(
                        '$minAge-$maxAge',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$minAge bis $maxAge Jahre'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${price.toStringAsFixed(2)} €',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleDiscountsSection(BuildContext context, Map<String, dynamic> roleDiscounts) {
    return Card(
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: Color(0xFF2196F3)),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Rollenrabatte',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            const Text(
              'Rabatte für spezielle Rollen (z.B. Betreuer, Küche)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: AppConstants.spacing),

            if (roleDiscounts.isEmpty)
              const Text(
                'Keine Rollenrabatte definiert',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              ...roleDiscounts.entries.map((entry) {
                final discount = entry.value as num;
                final isPercentage = discount <= 1.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.discount, size: 16, color: Color(0xFFFF9800)),
                          const SizedBox(width: 4),
                          Text(
                            isPercentage
                                ? '${(discount * 100).toStringAsFixed(0)}%'
                                : '${discount.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyDiscountSection(BuildContext context, Map<String, dynamic> familyDiscount) {
    return Card(
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, color: Color(0xFFE91E63)),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Familienrabatte',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing),
            const Text(
              'Rabatte für mehrere Kinder aus einer Familie',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: AppConstants.spacing),

            if (familyDiscount.isEmpty)
              const Text(
                'Keine Familienrabatte definiert',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              Column(
                children: [
                  // Zweites Kind
                  if (familyDiscount.containsKey('second_child'))
                    _buildFamilyDiscountRow(
                      '2. Kind',
                      familyDiscount['second_child'] as num,
                      Icons.looks_two,
                    ),

                  // Drittes Kind
                  if (familyDiscount.containsKey('third_child'))
                    _buildFamilyDiscountRow(
                      '3. Kind',
                      familyDiscount['third_child'] as num,
                      Icons.looks_3,
                    ),

                  // Viertes Kind
                  if (familyDiscount.containsKey('fourth_child'))
                    _buildFamilyDiscountRow(
                      '4. Kind',
                      familyDiscount['fourth_child'] as num,
                      Icons.looks_4,
                    ),

                  // Weitere Kinder
                  if (familyDiscount.containsKey('additional_children'))
                    _buildFamilyDiscountRow(
                      'Jedes weitere Kind',
                      familyDiscount['additional_children'] as num,
                      Icons.more_horiz,
                    ),
                ],
              ),

            // Info-Box
            const SizedBox(height: AppConstants.spacing),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.pink[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Familienrabatte werden automatisch beim Hinzufügen von Kindern zur gleichen Familie berechnet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.pink[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyDiscountRow(String label, num discount, IconData icon) {
    final isPercentage = discount <= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE91E63).withValues(alpha: 0.2),
          child: Icon(
            icon,
            color: const Color(0xFFE91E63),
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.discount, size: 16, color: Color(0xFFE91E63)),
              const SizedBox(width: 4),
              Text(
                isPercentage
                    ? '${(discount * 100).toStringAsFixed(0)}%'
                    : '${discount.toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
