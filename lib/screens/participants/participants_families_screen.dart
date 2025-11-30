import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/constants.dart';
import 'participants_list_screen.dart';
import '../families/families_list_screen.dart';

/// Combined Participants and Families Screen with Tabs
///
/// Zeigt Teilnehmer und Familien in separaten Tabs
class ParticipantsFamiliesScreen extends ConsumerStatefulWidget {
  const ParticipantsFamiliesScreen({super.key});

  @override
  ConsumerState<ParticipantsFamiliesScreen> createState() =>
      _ParticipantsFamiliesScreenState();
}

class _ParticipantsFamiliesScreenState
    extends ConsumerState<ParticipantsFamiliesScreen>
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
              icon: Icon(Icons.people),
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
          // Participants Tab
          ParticipantsListScreen(),
          // Families Tab
          FamiliesListScreen(),
        ],
      ),
    );
  }
}
