import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';
import '../participants/participants_families_screen.dart';
import '../participants/participants_list_screen.dart';
import '../families/families_list_screen.dart';
import '../rulesets/rulesets_list_screen.dart';
import '../payments/payments_list_screen.dart';
import '../expenses/expenses_list_screen.dart';
import '../incomes/incomes_list_screen.dart';
import '../cash_status/cash_status_screen.dart';
import '../roles/roles_list_screen.dart';
import '../tasks/tasks_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/constants.dart';

/// Dashboard Screen
///
/// Hauptübersicht mit Statistiken und Schnellzugriff auf alle Funktionen
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);

    if (currentEvent == null) {
      // Sollte nicht passieren, aber als Fallback
      return const Scaffold(
        body: Center(
          child: Text('Kein Event ausgewählt'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive Breakpoint: > 800px = Desktop
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // Desktop-Layout: NavigationRail (immer sichtbar)
          return _buildDesktopLayout(context, ref, currentEvent);
        } else {
          // Mobile-Layout: Drawer (Swipe)
          return _buildMobileLayout(context, ref, currentEvent);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref, Event currentEvent) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text(
              currentEvent.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref),
      body: _buildDashboardContent(context, ref, currentEvent),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref, Event currentEvent) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Kein Hamburger-Icon
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
                const Text('Dashboard'),
                Text(
                  currentEvent.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // NavigationRail (immer sichtbar)
          _buildNavigationRail(context, ref),
          // Vertikaler Separator
          const VerticalDivider(thickness: 1, width: 1),
          // Dashboard Content
          Expanded(
            child: _buildDashboardContent(context, ref, currentEvent),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context, WidgetRef ref) {
    return NavigationRail(
      extended: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedIndex: 0, // Dashboard ist immer selected
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people),
          label: Text('Teilnehmer & Familien'),
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
          icon: Icon(Icons.badge),
          label: Text('Rollen'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.task_alt),
          label: Text('Aufgaben'),
        ),
      ],
      onDestinationSelected: (index) {
        // Navigation basierend auf Index
        switch (index) {
          case 0:
            // Dashboard - bereits da
            break;
          case 1:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ParticipantsFamiliesScreen(),
              ),
            );
            break;
          case 2:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PaymentsListScreen(),
              ),
            );
            break;
          case 3:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ExpensesListScreen(),
              ),
            );
            break;
          case 4:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const IncomesListScreen(),
              ),
            );
            break;
          case 5:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CashStatusScreen(),
              ),
            );
            break;
          case 6:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RolesListScreen(),
              ),
            );
            break;
          case 7:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TasksScreen(),
              ),
            );
            break;
        }
      },
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final currentEvent = ref.watch(currentEventProvider);

    return Drawer(
      child: Column(
        children: [
          // Weißer Header-Bereich
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: AppConstants.paddingAll8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.event,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    const Text(
                      'Freizeitkasse',
                      style: TextStyle(
                        color: Color(0xFF2196F3),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (currentEvent != null) ...[
                  const SizedBox(height: AppConstants.spacingM),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentEvent.name,
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Blauer Menü-Bereich
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
                    () => Navigator.of(context).pop(),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.people,
                    'Teilnehmer',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ParticipantsListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.family_restroom,
                    'Familien',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FamiliesListScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.payment,
                    'Zahlungseingänge',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PaymentsListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.attach_money,
                    'Sonstige Einnahmen',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const IncomesListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.shopping_cart,
                    'Ausgaben',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ExpensesListScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.receipt_long,
                    'Kassenstand',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CashStatusScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.rule,
                    'Regelwerke',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RulesetsListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.badge,
                    'Rollen',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RolesListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.task_alt,
                    'Aufgaben',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const TasksScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  _buildDrawerItem(
                    context,
                    Icons.settings,
                    'Einstellungen',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  _buildDrawerItem(
                    context,
                    Icons.event_note,
                    'Freizeit wechseln',
                    () {
                      ref.read(currentEventProvider.notifier).clearEvent();
                      Navigator.of(context).pushReplacementNamed('/');
                    },
                  ),
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
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.1),
      dense: true,
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    Event currentEvent,
  ) {
    final database = ref.watch(databaseProvider);
    final eventId = currentEvent.id;

    return SingleChildScrollView(
      padding: AppConstants.paddingAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teilnehmer und Familien Karten
          StreamBuilder<int>(
            stream: (database.select(database.participants)
                  ..where((tbl) => tbl.eventId.equals(eventId))
                  ..where((tbl) => tbl.isActive.equals(true)))
                .watch()
                .map((list) => list.length),
            builder: (context, snapshot) {
              final participantCount = snapshot.data ?? 0;

              return Row(
                children: [
                  Expanded(
                    child: _buildOverviewCard(
                      context,
                      'Teilnehmer',
                      participantCount.toString(),
                      Icons.people,
                      const Color(0xFF2196F3), // Blau
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ParticipantsListScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacing),
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: (database.select(database.families)
                            ..where((tbl) => tbl.eventId.equals(eventId)))
                          .watch()
                          .map((list) => list.length),
                      builder: (context, snapshot) {
                        final familyCount = snapshot.data ?? 0;
                        return _buildOverviewCard(
                          context,
                          'Familien',
                          familyCount.toString(),
                          Icons.family_restroom,
                          const Color(0xFF4CAF50), // Grün
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const FamiliesListScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppConstants.spacingL),

          // Finanzübersicht
          const Text(
            'Finanzübersicht',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacing),

          // Einnahmen Sektion
          const Text(
            'Einnahmen',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingM),

          StreamBuilder<List<Participant>>(
            stream: (database.select(database.participants)
                  ..where((tbl) => tbl.eventId.equals(eventId))
                  ..where((tbl) => tbl.isActive.equals(true)))
                .watch(),
            builder: (context, participantSnapshot) {
              final participants = participantSnapshot.data ?? [];
              final sollEinnahmenGesamt = participants.fold<double>(
                0.0,
                (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
              );

              final sollZahlungseingaenge = sollEinnahmenGesamt; // Teilnahmegebühren

              return StreamBuilder<List<Income>>(
                stream: (database.select(database.incomes)
                      ..where((tbl) => tbl.eventId.equals(eventId))
                      ..where((tbl) => tbl.isActive.equals(true)))
                    .watch(),
                builder: (context, incomeSnapshot) {
                  final incomes = incomeSnapshot.data ?? [];
                  final sollSonstigeEinnahmen = incomes.fold<double>(
                    0.0,
                    (sum, income) => sum + income.amount,
                  );

                  return StreamBuilder<List<Payment>>(
                    stream: (database.select(database.payments)
                          ..where((tbl) => tbl.eventId.equals(eventId))
                          ..where((tbl) => tbl.isActive.equals(true)))
                        .watch(),
                    builder: (context, paymentSnapshot) {
                      final payments = paymentSnapshot.data ?? [];
                      final istEinnahmenGesamt = payments.fold<double>(
                        0.0,
                        (sum, payment) => sum + payment.amount,
                      ) + sollSonstigeEinnahmen;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildFinanceCard(
                                  context,
                                  'Soll Einnahmen (Gesamt)',
                                  NumberFormat.currency(locale: 'de_DE', symbol: '€').format(sollEinnahmenGesamt + sollSonstigeEinnahmen),
                                  null,
                                  backgroundColor: const Color(0xFFE8F5E9), // Hellgrün
                                  textColor: const Color(0xFF2E7D32), // Dunkelgrün
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacing),
                              Expanded(
                                child: _buildFinanceCard(
                                  context,
                                  'Soll Zahlungseingänge',
                                  NumberFormat.currency(locale: 'de_DE', symbol: '€').format(sollZahlungseingaenge),
                                  'Teilnahmegebühren',
                                  backgroundColor: const Color(0xFFE3F2FD), // Hellblau
                                  textColor: const Color(0xFF1976D2), // Blau
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spacing),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFinanceCard(
                                  context,
                                  'Soll Sonstige Einnahmen',
                                  NumberFormat.currency(locale: 'de_DE', symbol: '€').format(sollSonstigeEinnahmen),
                                  'Zuschüsse',
                                  backgroundColor: const Color(0xFFE3F2FD), // Hellblau
                                  textColor: const Color(0xFF1976D2), // Blau
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacing),
                              Expanded(
                                child: _buildFinanceCard(
                                  context,
                                  'Ist Einnahmen (Gesamt)',
                                  NumberFormat.currency(locale: 'de_DE', symbol: '€').format(istEinnahmenGesamt),
                                  'Zahlungen + Sonstige',
                                  borderColor: const Color(0xFF4CAF50), // Grün
                                  textColor: const Color(0xFF2E7D32), // Dunkelgrün
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: AppConstants.spacingL),

          // Ausgaben Sektion
          const Text(
            'Ausgaben',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingM),

          StreamBuilder<List<Expense>>(
            stream: (database.select(database.expenses)
                  ..where((tbl) => tbl.eventId.equals(eventId))
                  ..where((tbl) => tbl.isActive.equals(true)))
                .watch(),
            builder: (context, expenseSnapshot) {
              final expenses = expenseSnapshot.data ?? [];
              final sollAusgabenGesamt = expenses.fold<double>(
                0.0,
                (sum, expense) => sum + expense.amount,
              );
              final beglicheneAusgaben = sollAusgabenGesamt; // Tatsächlich gezahlt (hier gleich)

              return Row(
                children: [
                  Expanded(
                    child: _buildFinanceCard(
                      context,
                      'Soll Ausgaben (Gesamt)',
                      NumberFormat.currency(locale: 'de_DE', symbol: '€').format(sollAusgabenGesamt),
                      null,
                      backgroundColor: const Color(0xFFFCE4EC), // Hellrosa
                      textColor: const Color(0xFFC2185B), // Pink
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacing),
                  Expanded(
                    child: _buildFinanceCard(
                      context,
                      'Beglichene Ausgaben',
                      NumberFormat.currency(locale: 'de_DE', symbol: '€').format(beglicheneAusgaben),
                      'Tatsächlich gezahlt',
                      borderColor: const Color(0xFFE91E63), // Pink
                      textColor: const Color(0xFFC2185B), // Pink
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppConstants.spacingL),

          // Saldo Sektion
          const Text(
            'Saldo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingM),

          StreamBuilder<List<Payment>>(
            stream: (database.select(database.payments)
                  ..where((tbl) => tbl.eventId.equals(eventId))
                  ..where((tbl) => tbl.isActive.equals(true)))
                .watch(),
            builder: (context, paymentSnapshot) {
              final payments = paymentSnapshot.data ?? [];
              final totalPayments = payments.fold<double>(
                0.0,
                (sum, payment) => sum + payment.amount,
              );

              return StreamBuilder<List<Income>>(
                stream: (database.select(database.incomes)
                      ..where((tbl) => tbl.eventId.equals(eventId))
                      ..where((tbl) => tbl.isActive.equals(true)))
                    .watch(),
                builder: (context, incomeSnapshot) {
                  final incomes = incomeSnapshot.data ?? [];
                  final totalIncomes = incomes.fold<double>(
                    0.0,
                    (sum, income) => sum + income.amount,
                  );

                  return StreamBuilder<List<Expense>>(
                    stream: (database.select(database.expenses)
                          ..where((tbl) => tbl.eventId.equals(eventId))
                          ..where((tbl) => tbl.isActive.equals(true)))
                        .watch(),
                    builder: (context, expenseSnapshot) {
                      final expenses = expenseSnapshot.data ?? [];
                      final totalExpenses = expenses.fold<double>(
                        0.0,
                        (sum, expense) => sum + expense.amount,
                      );
                      final saldo = totalPayments + totalIncomes - totalExpenses;

                      return _buildFinanceCard(
                        context,
                        'Saldo (Gesamt)',
                        NumberFormat.currency(locale: 'de_DE', symbol: '€').format(saldo),
                        'Einnahmen - Ausgaben',
                        backgroundColor: const Color(0xFFE8F5E9), // Hellgrün
                        textColor: const Color(0xFF2E7D32), // Dunkelgrün
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppConstants.paddingAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              const Row(
                children: [
                  Text(
                    'Zur Übersicht →',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceCard(
    BuildContext context,
    String title,
    String value,
    String? subtitle, {
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return Card(
      elevation: 2,
      color: backgroundColor ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != null
            ? BorderSide(color: borderColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: AppConstants.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: textColor ?? Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor ?? Colors.black,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor?.withOpacity(0.7) ?? Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
