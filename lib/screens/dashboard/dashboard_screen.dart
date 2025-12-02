import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/current_event_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/database/app_database.dart';
import '../participants/participants_families_screen.dart';
import '../payments/payments_list_screen.dart';
import '../expenses/expenses_list_screen.dart';
import '../incomes/incomes_list_screen.dart';
import '../cash_status/cash_status_screen.dart';
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
    return Container(
      width: 280,
      color: const Color(0xFF2196F3),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header mit Logo
          Container(
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
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: AppConstants.spacing),

          // VERWALTUNG Section
          _buildNavigationSectionHeader('VERWALTUNG'),
          _buildNavigationItem(
            context,
            Icons.dashboard,
            'Dashboard',
            () => null, // Already on dashboard
            isSelected: true,
          ),
          _buildNavigationItem(
            context,
            Icons.people,
            'Teilnehmer & Familien',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ParticipantsFamiliesScreen(),
              ),
            ),
          ),
          _buildNavigationItem(
            context,
            Icons.task_alt,
            'Aufgaben',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TasksScreen(),
              ),
            ),
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
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PaymentsListScreen(),
              ),
            ),
          ),
          _buildNavigationItem(
            context,
            Icons.attach_money,
            'Sonstige Einnahmen',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const IncomesListScreen(),
              ),
            ),
          ),
          _buildNavigationItem(
            context,
            Icons.shopping_cart,
            'Ausgaben',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ExpensesListScreen(),
              ),
            ),
          ),
          _buildNavigationItem(
            context,
            Icons.receipt_long,
            'Kassenstand',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CashStatusScreen(),
              ),
            ),
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
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            ),
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
          // Blauer Header-Bereich mit Logo und Event
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
                        Text(
                          currentEvent.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
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
                  // VERWALTUNG Section
                  _buildDrawerSectionHeader('VERWALTUNG'),
                  _buildDrawerItem(
                    context,
                    Icons.dashboard,
                    'Dashboard',
                    () => Navigator.of(context).pop(),
                  ),
                  _buildDrawerItem(
                    context,
                    Icons.people,
                    'Teilnehmer & Familien',
                    () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ParticipantsFamiliesScreen(),
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
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
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

    // Responsive Layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return SingleChildScrollView(
      padding: AppConstants.paddingAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== BEREICH 1: TEILNEHMER ==========
          _buildSectionHeader(context, Icons.people, 'Teilnehmer'),
          const SizedBox(height: AppConstants.spacing),

          StreamBuilder<int>(
            stream: (database.select(database.participants)
                  ..where((tbl) => tbl.eventId.equals(eventId))
                  ..where((tbl) => tbl.isActive.equals(true)))
                .watch()
                .map((list) => list.length),
            builder: (context, snapshot) {
              final participantCount = snapshot.data ?? 0;

              return StreamBuilder<int>(
                stream: (database.select(database.families)
                      ..where((tbl) => tbl.eventId.equals(eventId)))
                    .watch()
                    .map((list) => list.length),
                builder: (context, familySnapshot) {
                  final familyCount = familySnapshot.data ?? 0;

                  return Card(
                    elevation: 2,
                    child: Padding(
                      padding: AppConstants.paddingAll16,
                      child: isDesktop
                          ? Row(
                              children: [
                                Expanded(
                                  child: _buildParticipantStat(
                                    context,
                                    'Anzahl Teilnehmer',
                                    participantCount.toString(),
                                    Icons.people,
                                    const Color(0xFF2196F3),
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const ParticipantsFamiliesScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                                const VerticalDivider(width: 32),
                                Expanded(
                                  child: _buildParticipantStat(
                                    context,
                                    'Anzahl Familien',
                                    familyCount.toString(),
                                    Icons.family_restroom,
                                    const Color(0xFF4CAF50),
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const ParticipantsFamiliesScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildParticipantStat(
                                  context,
                                  'Anzahl Teilnehmer',
                                  participantCount.toString(),
                                  Icons.people,
                                  const Color(0xFF2196F3),
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const ParticipantsFamiliesScreen(),
                                    ),
                                  ),
                                ),
                                const Divider(height: 24),
                                _buildParticipantStat(
                                  context,
                                  'Anzahl Familien',
                                  familyCount.toString(),
                                  Icons.family_restroom,
                                  const Color(0xFF4CAF50),
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const ParticipantsFamiliesScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: AppConstants.spacingXL),

          // ========== BEREICH 2: FINANZÜBERSICHT ==========
          _buildSectionHeader(context, Icons.account_balance_wallet, 'Finanzübersicht'),
          const SizedBox(height: AppConstants.spacing),

          Card(
            elevation: 2,
            child: Padding(
              padding: AppConstants.paddingAll16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === EINNAHMEN ===
                  const Row(
                    children: [
                      Icon(Icons.trending_up, color: Color(0xFF4CAF50), size: 24),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
                        'Einnahmen',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  StreamBuilder<List<Participant>>(
                    stream: (database.select(database.participants)
                          ..where((tbl) => tbl.eventId.equals(eventId))
                          ..where((tbl) => tbl.isActive.equals(true)))
                        .watch(),
                    builder: (context, participantSnapshot) {
                      final participants = participantSnapshot.data ?? [];
                      final sollEinnahmenTeilnehmer = participants.fold<double>(
                        0.0,
                        (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
                      );

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
                              final istEinnahmenZahlungen = payments.fold<double>(
                                0.0,
                                (sum, payment) => sum + payment.amount,
                              );

                              final sollEinnahmenGesamt = sollEinnahmenTeilnehmer + sollSonstigeEinnahmen;
                              final istEinnahmenGesamt = istEinnahmenZahlungen + sollSonstigeEinnahmen;

                              return isDesktop
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Soll Einnahmen (Gesamt)',
                                            sollEinnahmenGesamt,
                                            null,
                                            const Color(0xFF4CAF50),
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Soll Zahlungseingänge',
                                            sollEinnahmenTeilnehmer,
                                            'durch Teilnahmegebühren',
                                            const Color(0xFF2196F3),
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Soll Sonstige Einnahmen',
                                            sollSonstigeEinnahmen,
                                            'durch Zuschüsse',
                                            const Color(0xFF2196F3),
                                          ),
                                        ),
                                        const SizedBox(width: AppConstants.spacing),
                                        Expanded(
                                          child: _buildFinanceDetailCard(
                                            context,
                                            'Ist Einnahmen (Gesamt)',
                                            istEinnahmenGesamt,
                                            'durch Zahlungen + Sonstige',
                                            const Color(0xFF4CAF50),
                                            isBold: true,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _buildFinanceDetailCard(
                                          context,
                                          'Soll Einnahmen (Gesamt)',
                                          sollEinnahmenGesamt,
                                          null,
                                          const Color(0xFF4CAF50),
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        _buildFinanceDetailCard(
                                          context,
                                          'Soll Zahlungseingänge',
                                          sollEinnahmenTeilnehmer,
                                          'durch Teilnahmegebühren',
                                          const Color(0xFF2196F3),
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        _buildFinanceDetailCard(
                                          context,
                                          'Soll Sonstige Einnahmen',
                                          sollSonstigeEinnahmen,
                                          'durch Zuschüsse',
                                          const Color(0xFF2196F3),
                                        ),
                                        const SizedBox(height: AppConstants.spacingS),
                                        _buildFinanceDetailCard(
                                          context,
                                          'Ist Einnahmen (Gesamt)',
                                          istEinnahmenGesamt,
                                          'durch Zahlungen + Sonstige',
                                          const Color(0xFF4CAF50),
                                          isBold: true,
                                        ),
                                      ],
                                    );
                            },
                          );
                        },
                      );
                    },
                  ),

                  const Divider(height: 32),

                  // === AUSGABEN ===
                  const Row(
                    children: [
                      Icon(Icons.trending_down, color: Color(0xFFE91E63), size: 24),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
                        'Ausgaben',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),

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
                      // TODO: Später mit Status-Feld erweitern
                      final beglicheneAusgaben = sollAusgabenGesamt;

                      return isDesktop
                          ? Row(
                              children: [
                                Expanded(
                                  child: _buildFinanceDetailCard(
                                    context,
                                    'Soll Ausgaben (Gesamt)',
                                    sollAusgabenGesamt,
                                    null,
                                    const Color(0xFFE91E63),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacing),
                                Expanded(
                                  child: _buildFinanceDetailCard(
                                    context,
                                    'Beglichene Ausgaben',
                                    beglicheneAusgaben,
                                    null,
                                    const Color(0xFFE91E63),
                                    isBold: true,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildFinanceDetailCard(
                                  context,
                                  'Soll Ausgaben (Gesamt)',
                                  sollAusgabenGesamt,
                                  null,
                                  const Color(0xFFE91E63),
                                ),
                                const SizedBox(height: AppConstants.spacingS),
                                _buildFinanceDetailCard(
                                  context,
                                  'Beglichene Ausgaben',
                                  beglicheneAusgaben,
                                  null,
                                  const Color(0xFFE91E63),
                                  isBold: true,
                                ),
                              ],
                            );
                    },
                  ),

                  const Divider(height: 32),

                  // === SALDO ===
                  const Row(
                    children: [
                      Icon(Icons.account_balance, color: Color(0xFFFF9800), size: 24),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
                        'Saldo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacing),

                  StreamBuilder<List<Participant>>(
                    stream: (database.select(database.participants)
                          ..where((tbl) => tbl.eventId.equals(eventId))
                          ..where((tbl) => tbl.isActive.equals(true)))
                        .watch(),
                    builder: (context, participantSnapshot) {
                      final participants = participantSnapshot.data ?? [];
                      final sollEinnahmenTeilnehmer = participants.fold<double>(
                        0.0,
                        (sum, p) => sum + (p.manualPriceOverride ?? p.calculatedPrice),
                      );

                      return StreamBuilder<List<Income>>(
                        stream: (database.select(database.incomes)
                              ..where((tbl) => tbl.eventId.equals(eventId))
                              ..where((tbl) => tbl.isActive.equals(true)))
                            .watch(),
                        builder: (context, incomeSnapshot) {
                          final incomes = incomeSnapshot.data ?? [];
                          final istSonstigeEinnahmen = incomes.fold<double>(
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
                              final sollAusgabenGesamt = expenses.fold<double>(
                                0.0,
                                (sum, expense) => sum + expense.amount,
                              );

                              // Formel: Soll Einnahmen (Gesamt) + Ist Einnahmen Sonstige - Soll Ausgaben (Gesamt)
                              final sollEinnahmenGesamt = sollEinnahmenTeilnehmer + istSonstigeEinnahmen;
                              final saldo = sollEinnahmenGesamt + istSonstigeEinnahmen - sollAusgabenGesamt;

                              return _buildSaldoCard(
                                context,
                                saldo,
                                'Soll Einnahmen (Gesamt) + Ist Sonstige Einnahmen - Soll Ausgaben (Gesamt)',
                              );
                            },
                          );
                        },
                      );
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

  /// Section Header Widget
  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: AppConstants.paddingAll8,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: AppConstants.borderRadius8,
          ),
          child: Icon(icon, color: AppConstants.primaryColor, size: 24),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Participant/Family Stat Widget with Quicklink
  Widget _buildParticipantStat(
    BuildContext context,
    String label,
    String count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppConstants.borderRadius8,
      child: Padding(
        padding: AppConstants.paddingAll8,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: AppConstants.borderRadius8,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: AppConstants.spacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  /// Finance Detail Card (for income/expense details)
  Widget _buildFinanceDetailCard(
    BuildContext context,
    String label,
    double amount,
    String? subtitle,
    Color color, {
    bool isBold = false,
  }) {
    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppConstants.borderRadius8,
        border: isBold ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.currency(locale: 'de_DE', symbol: '€').format(amount),
            style: TextStyle(
              fontSize: isBold ? 24 : 20,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Saldo Card (highlighted)
  Widget _buildSaldoCard(
    BuildContext context,
    double saldo,
    String formula,
  ) {
    final isPositive = saldo >= 0;
    final color = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE91E63);

    return Container(
      padding: AppConstants.paddingAll16,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppConstants.borderRadius12,
        border: Border.all(color: color, width: 3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo (Gesamt)',
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(locale: 'de_DE', symbol: '€').format(saldo),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formula,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 48,
          ),
        ],
      ),
    );
  }
}
