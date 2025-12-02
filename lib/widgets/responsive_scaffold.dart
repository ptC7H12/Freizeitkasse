import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/current_event_provider.dart';
import '../utils/constants.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/participants/participants_list_screen.dart';
import '../screens/families/families_list_screen.dart';
import '../screens/payments/payments_list_screen.dart';
import '../screens/expenses/expenses_list_screen.dart';
import '../screens/incomes/incomes_list_screen.dart';
import '../screens/cash_status/cash_status_screen.dart';
import '../screens/rulesets/rulesets_list_screen.dart';
import '../screens/roles/roles_list_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/settings/settings_screen.dart';

/// Responsive Scaffold Widget
///
/// Provides a responsive layout that shows:
/// - Mobile (<800px): Drawer that can be swiped in
/// - Desktop (>=800px): Permanent NavigationRail on the left
class ResponsiveScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final int selectedIndex;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.selectedIndex = -1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          return _buildDesktopLayout(context, ref);
        } else {
          return _buildMobileLayout(context, ref);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      drawer: _buildDrawer(context, ref),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: AppConstants.paddingAll8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event, size: 24),
            ),
            const SizedBox(width: AppConstants.spacingM),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (currentEvent != null)
                  Text(
                    currentEvent.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                  ),
              ],
            ),
          ],
        ),
        actions: actions,
      ),
      body: Row(
        children: [
          _buildNavigationRail(context, ref),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNavigationRail(BuildContext context, WidgetRef ref) {
    return NavigationRail(
      extended: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people),
          label: Text('Teilnehmer'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.family_restroom),
          label: Text('Familien'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.payment),
          label: Text('Zahlungen'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.shopping_cart),
          label: Text('Ausgaben'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.attach_money),
          label: Text('Einnahmen'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long),
          label: Text('Kassenstand'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.rule),
          label: Text('Regelwerke'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.badge),
          label: Text('Rollen'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.task_alt),
          label: Text('Aufgaben'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('Einstellungen'),
        ),
      ],
      onDestinationSelected: (index) {
        // Avoid navigating if already on the selected screen
        if (index == selectedIndex) return;

        Widget screen;
        switch (index) {
          case 0:
            screen = const DashboardScreen();
            break;
          case 1:
            screen = const ParticipantsListScreen();
            break;
          case 2:
            screen = const FamiliesListScreen();
            break;
          case 3:
            screen = const PaymentsListScreen();
            break;
          case 4:
            screen = const ExpensesListScreen();
            break;
          case 5:
            screen = const IncomesListScreen();
            break;
          case 6:
            screen = const CashStatusScreen();
            break;
          case 7:
            screen = const RulesetsListScreen();
            break;
          case 8:
            screen = const RolesListScreen();
            break;
          case 9:
            screen = const TasksScreen();
            break;
          case 10:
            screen = const SettingsScreen();
            break;
          default:
            return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => screen),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);

    return Drawer(
      child: Column(
        children: [
          // Header with logo and event name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF2196F3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: AppConstants.paddingAll8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 28,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    const Text(
                      'Freizeitkasse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (currentEvent != null) ...[
                  const SizedBox(height: AppConstants.spacing),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            currentEvent.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Menu items
          Expanded(
            child: Container(
              color: const Color(0xFF2196F3),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    Icons.dashboard,
                    'Dashboard',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 0) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const DashboardScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 0,
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.people,
                    'Teilnehmer',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 1) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const ParticipantsListScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 1,
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.family_restroom,
                    'Familien',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 2) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const FamiliesListScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 2,
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.payment,
                    'Zahlungseingänge',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 3) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const PaymentsListScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 3,
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.shopping_cart,
                    'Ausgaben',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 4) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const ExpensesListScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 4,
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.attach_money,
                    'Sonstige Einnahmen',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 5) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const IncomesListScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 5,
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.receipt_long,
                    'Kassenstand',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 6) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const CashStatusScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 6,
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.rule,
                    'Regelwerke',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 7) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const RulesetsListScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 7,
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.badge,
                    'Rollen',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 8) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const RolesListScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 8,
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.task_alt,
                    'Aufgaben',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 9) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const TasksScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 9,
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.settings,
                    'Einstellungen',
                    () {
                      Navigator.of(context).pop();
                      if (selectedIndex != 10) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      }
                    },
                    isSelected: selectedIndex == 10,
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: AppConstants.spacingM),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: _buildDrawerItem(
                        context,
                        Icons.swap_horiz,
                        'Freizeit wechseln',
                        () {
                          ref.read(currentEventProvider.notifier).clearEvent();
                          Navigator.of(context).pushReplacementNamed('/');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.2),
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.1),
      dense: true,
    );
  }
}
