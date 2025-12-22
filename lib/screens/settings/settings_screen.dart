import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/responsive_scaffold.dart';
import 'tabs/general_settings_tab.dart';
import 'tabs/ruleset_settings_tab.dart';
import 'tabs/categories_tab.dart';
import 'tabs/app_info_tab.dart';

/// Einstellungen-Screen mit Tabs
///
/// Tab 1: Allgemein (Organisation, Bankdaten, Verwendungszweck prefix, Fußzeile)
/// Tab 2: Regelwerk (GitHub-Verzeichnis, Import, Dokumentation-Link)
/// Tab 3: Kategorien (Ausgaben- und Einnahmen-Kategorien)
/// Tab 4: App-Infos (Version, Lizenzen)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Einstellungen',
      selectedIndex: 10,
      body: Column(
        children: [
          // TabBar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.business),
                text: 'Allgemein',
              ),
              Tab(
                icon: Icon(Icons.rule),
                text: 'Regelwerk',
              ),
              Tab(
                icon: Icon(Icons.category),
                text: 'Kategorien',
              ),
              Tab(
                icon: Icon(Icons.info),
                text: 'App-Info',
              ),
            ],
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Allgemein
                GeneralSettingsTab(),

                // Tab 2: Regelwerk
                RulesetSettingsTab(),

                // Tab 3: Kategorien
                CategoriesTab(),

                // Tab 4: App-Info
                AppInfoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
