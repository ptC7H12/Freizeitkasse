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
        title: currentEvent != null
            ? Row(
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
                  Text(
                    currentEvent.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            : null,
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
    return Container(
      width: 280,
      color: const Color(0xFF2196F3),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header mit Logo
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Row(
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: AppConstants.spacing),

          // VERWALTUNG Section
          _buildNavigationSectionHeader('VERWALTUNG'),
          _buildNavigationItem(
            context,
            Icons.dashboard,
            'Dashboard',
            selectedIndex == 0 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
            isSelected: selectedIndex == 0,
          ),
          _buildNavigationItem(
            context,
            Icons.people,
            'Teilnehmer & Familien',
            selectedIndex == 1 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ParticipantsListScreen()),
              );
            },
            isSelected: selectedIndex == 1,
          ),
          _buildNavigationItem(
            context,
            Icons.task_alt,
            'Aufgaben',
            selectedIndex == 9 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const TasksScreen()),
              );
            },
            isSelected: selectedIndex == 9,
          ),

          const SizedBox(height: AppConstants.spacingL),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: AppConstants.spacingL),

          // FINANZEN Section
          _buildNavigationSectionHeader('FINANZEN'),
          _buildNavigationItem(
            context,
            Icons.payment,
            'Zahlungseingänge',
            selectedIndex == 3 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const PaymentsListScreen()),
              );
            },
            isSelected: selectedIndex == 3,
          ),
          _buildNavigationItem(
            context,
            Icons.attach_money,
            'Sonstige Einnahmen',
            selectedIndex == 5 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const IncomesListScreen()),
              );
            },
            isSelected: selectedIndex == 5,
          ),
          _buildNavigationItem(
            context,
            Icons.shopping_cart,
            'Ausgaben',
            selectedIndex == 4 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ExpensesListScreen()),
              );
            },
            isSelected: selectedIndex == 4,
          ),
          _buildNavigationItem(
            context,
            Icons.receipt_long,
            'Kassenstand',
            selectedIndex == 6 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const CashStatusScreen()),
              );
            },
            isSelected: selectedIndex == 6,
          ),

          const SizedBox(height: AppConstants.spacingL),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: AppConstants.spacingL),

          // EINSTELLUNGEN Section
          _buildNavigationSectionHeader('EINSTELLUNGEN'),
          _buildNavigationItem(
            context,
            Icons.settings,
            'Einstellungen',
            selectedIndex == 10 ? null : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            isSelected: selectedIndex == 10,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback? onTap, {
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        hoverColor: Colors.white.withOpacity(0.1),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);

    return Drawer(
      child: Column(
        children: [
          // Header with logo and event name
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
          ),
          // Menu items
          Expanded(
            child: Container(
              color: const Color(0xFF2196F3),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // VERWALTUNG Section
                  _buildDrawerSectionHeader('VERWALTUNG'),
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
                  _buildDrawerItem(
                    context,
                    Icons.people,
                    'Teilnehmer & Familien',
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

                  const SizedBox(height: AppConstants.spacingM),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: AppConstants.spacingM),

                  // FINANZEN Section
                  _buildDrawerSectionHeader('FINANZEN'),
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

                  const SizedBox(height: AppConstants.spacingM),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: AppConstants.spacingM),

                  // EINSTELLUNGEN Section
                  _buildDrawerSectionHeader('EINSTELLUNGEN'),
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

                  const SizedBox(height: AppConstants.spacingXL),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: AppConstants.spacingM),

                  // Freizeit wechseln (special item)
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

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
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
