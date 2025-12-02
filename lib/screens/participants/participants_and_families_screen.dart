import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/constants.dart';
import 'participants_list_screen.dart';
import '../families/families_list_screen.dart';

/// Participants and Families Screen with Tabs
///
/// Kombiniert Teilnehmer und Familien in einem Tab-basierten Screen
class ParticipantsAndFamiliesScreen extends ConsumerStatefulWidget {
  const ParticipantsAndFamiliesScreen({super.key});

  @override
  ConsumerState<ParticipantsAndFamiliesScreen> createState() => _ParticipantsAndFamiliesScreenState();
}

class _ParticipantsAndFamiliesScreenState extends ConsumerState<ParticipantsAndFamiliesScreen>
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
        title: const Text('Teilnehmer & Familien'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: 'Teilnehmer',
            ),
            Tab(
              icon: Icon(Icons.family_restroom),
              text: 'Familien',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Tab 1: Teilnehmer
          _ParticipantsTabContent(),

          // Tab 2: Familien
          _FamiliesTabContent(),
        ],
      ),
    );
  }
}

/// Tab 1 Content: Teilnehmer
class _ParticipantsTabContent extends StatelessWidget {
  const _ParticipantsTabContent();

  @override
  Widget build(BuildContext context) {
    // Verwende den existierenden ParticipantsListScreen, aber ohne AppBar
    return const ParticipantsListScreen(embedded: true);
  }
}

/// Tab 2 Content: Familien
class _FamiliesTabContent extends StatelessWidget {
  const _FamiliesTabContent();

  @override
  Widget build(BuildContext context) {
    // Verwende den existierenden FamiliesListScreen, aber ohne AppBar
    return const FamiliesListScreen(embedded: true);
  }
}
