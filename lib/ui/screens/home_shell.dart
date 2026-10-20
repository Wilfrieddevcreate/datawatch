import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/data_plan.dart';
import '../theme/tokens.dart';
import '../widgets/page_header.dart';
import 'apps_screen.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart';
import 'plan_screen.dart';
import 'tips_screen.dart';

/// Les quatre onglets de la barre de navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _dashboard = 0;
  static const _apps = 1;
  static const _plan = 2;

  int _index = _dashboard;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final level = AppScope.of(context).planUsage?.level;
    final alerts = DwHeaderButton(
      icon: Icons.notifications_none_rounded,
      tooltip: 'Seuils d’alerte',
      onPressed: () => _goTo(_plan),
      badgeColor: switch (level) {
        UsageLevel.exhausted => c.critical,
        UsageLevel.warning => c.warning,
        _ => null,
      },
    );
    final settings = DwHeaderButton(
      icon: Icons.settings_outlined,
      tooltip: 'Paramètres',
      onPressed: () => Navigator.of(
        context,
      ).push(SettingsScreen.route(onOpenPlan: () => _goTo(_plan))),
    );
    final actions = [alerts, settings];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            actions: actions,
            onOpenPlan: () => _goTo(_plan),
            onOpenApps: () => _goTo(_apps),
          ),
          AppsScreen(actions: actions),
          PlanScreen(actions: actions, onSaved: () => _goTo(_dashboard)),
          TipsScreen(actions: actions),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Applis',
          ),
          NavigationDestination(
            icon: Icon(Icons.sim_card_outlined),
            selectedIcon: Icon(Icons.sim_card_rounded),
            label: 'Forfait',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline_rounded),
            selectedIcon: Icon(Icons.lightbulb_rounded),
            label: 'Conseils',
          ),
        ],
      ),
    );
  }
}
