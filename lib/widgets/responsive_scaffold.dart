import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/database/app_database.dart';
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
    final currentEvent = ref.watch(currentEventProvider);

    return Container(
      width: 280,
      color: const Color(0xFF2196F3),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Event Header (nur wenn Event ausgewählt)
            if (currentEvent != null) _buildEventHeader(currentEvent),

            // VERWALTUNG Section
            _buildNavigationSectionHeader('VERWALTUNG'),
          _buildNavigationItem(
            context,
            Icons.dashboard,
            'Dashboard',
            selectedIndex == 0 ? null : () {
              _navigateWithoutAnimation(context, const DashboardScreen());
            },
            isSelected: selectedIndex == 0,
          ),
          _buildNavigationItem(
            context,
            Icons.people,
            'Teilnehmer & Familien',
            selectedIndex == 1 ? null : () {
              _navigateWithoutAnimation(context, const ParticipantsListScreen());
            },
            isSelected: selectedIndex == 1,
          ),
          _buildNavigationItem(
            context,
            Icons.task_alt,
            'Aufgaben',
            selectedIndex == 9 ? null : () {
              _navigateWithoutAnimation(context, const TasksScreen());
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
              _navigateWithoutAnimation(context, const PaymentsListScreen());
            },
            isSelected: selectedIndex == 3,
          ),
          _buildNavigationItem(
            context,
            Icons.attach_money,
            'Sonstige Einnahmen',
            selectedIndex == 5 ? null : () {
              _navigateWithoutAnimation(context, const IncomesListScreen());
            },
            isSelected: selectedIndex == 5,
          ),
          _buildNavigationItem(
            context,
            Icons.shopping_cart,
            'Ausgaben',
            selectedIndex == 4 ? null : () {
              _navigateWithoutAnimation(context, const ExpensesListScreen());
            },
            isSelected: selectedIndex == 4,
          ),
          _buildNavigationItem(
            context,
            Icons.receipt_long,
            'Kassenstand',
            selectedIndex == 6 ? null : () {
              _navigateWithoutAnimation(context, const CashStatusScreen());
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
              _navigateWithoutAnimation(context, const SettingsScreen());
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
              child: _buildNavigationItem(
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
    ));
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

  /// Navigate without animation (für bessere UX beim Menü-Wechsel)
  void _navigateWithoutAnimation(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);

    return Drawer(
      child: Container(
        color: const Color(0xFF2196F3),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Event Header (nur wenn Event ausgewählt)
              if (currentEvent != null) _buildEventHeader(currentEvent),

              // VERWALTUNG Section
              _buildDrawerSectionHeader('VERWALTUNG'),
              _buildDrawerItem(
                context,
                Icons.dashboard,
                'Dashboard',
                () {
                  Navigator.of(context).pop();
                  if (selectedIndex != 0) {
                    _navigateWithoutAnimation(context, const DashboardScreen());
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
                    _navigateWithoutAnimation(context, const ParticipantsListScreen());
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
                    _navigateWithoutAnimation(context, const TasksScreen());
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
                    _navigateWithoutAnimation(context, const PaymentsListScreen());
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
                    _navigateWithoutAnimation(context, const IncomesListScreen());
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
                    _navigateWithoutAnimation(context, const ExpensesListScreen());
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
                    _navigateWithoutAnimation(context, const CashStatusScreen());
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
                    _navigateWithoutAnimation(context, const SettingsScreen());
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
    );
  }

  Widget _buildEventHeader(Event currentEvent) {
    final dateFormat = DateFormat('dd.MM.yyyy', 'de_DE');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Icon + Name
          Row(
            children: [
              const Icon(Icons.event, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentEvent.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Type
          if (currentEvent.eventType != null)
            Text(
              currentEvent.eventType!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 4),
          // Date Range
          Text(
            '${dateFormat.format(currentEvent.startDate)} - ${dateFormat.format(currentEvent.endDate)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
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
