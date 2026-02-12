import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/role_provider.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/repositories/role_repository.dart';
import 'role_form_screen.dart';
import '../../utils/constants.dart';
import '../../extensions/context_extensions.dart';
import '../../widgets/responsive_scaffold.dart';
import '../../widgets/adaptive_list_item.dart';

class RolesListScreen extends ConsumerWidget {
  const RolesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);
    final rolesWithCountsAsync = ref.watch(rolesWithCountsProvider);

    if (currentEvent == null) {
      return const ResponsiveScaffold(
        title: 'Rollen',
        selectedIndex: 8,
        body: Center(
          child: Text('Bitte wählen Sie zuerst eine Veranstaltung aus.'),
        ),
      );
    }

    return ResponsiveScaffold(
      title: 'Rollen',
      selectedIndex: 8,
      body: rolesWithCountsAsync.when(
        data: (rolesWithCounts) {
          if (rolesWithCounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: AppConstants.spacing),
                  Text(
                    'Noch keine Rollen',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Rollen wie "Mitarbeiter" oder "Leitung"\nfür Teilnehmer-Rabatte erstellen',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  FilledButton.icon(
                    onPressed: () {
                      context.pushScreen(const RoleFormScreen());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Rolle erstellen'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: AppConstants.paddingAll16,
            children: [
              // Info Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: AppConstants.paddingAll16,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: Text(
                          'Rollen werden in Regelwerken für Rabatte verwendet',
                          style: TextStyle(color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacing),

              // Roles List
              ...rolesWithCounts.map((data) {
                final role = data['role'];
                final count = data['participantCount'] as int;
                return _RoleListItem(role: role, participantCount: count);
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Fehler beim Laden der Rollen: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.pushScreen(const RoleFormScreen());
        },
        icon: const Icon(Icons.add),
        label: const Text('Rolle'),
      ),
    );
  }
}

class _RoleListItem extends ConsumerWidget {
  final dynamic role;
  final int participantCount;

  const _RoleListItem({
    required this.role,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptiveListItem(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.purple[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.badge,
          color: Colors.purple,
        ),
      ),
      title: Text(
        (role.name as String?) ?? '',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (role.description != null) ...[
            const SizedBox(height: 4),
            Text(
              (role.description as String?) ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppConstants.spacingS),
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '$participantCount Teilnehmer',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        context.pushScreen(RoleFormScreen(roleId: role.id as int?));
      },
      onEdit: () {
        context.pushScreen(RoleFormScreen(roleId: role.id as int?));
      },
      onDelete: () async {
        final database = ref.read(databaseProvider);
        final repository = RoleRepository(database);
        await repository.deleteRole(role.id as int);
      },
      deleteConfirmMessage: 'Rolle "${(role.name as String?) ?? ''}" wirklich löschen?',
    );
  }
}
