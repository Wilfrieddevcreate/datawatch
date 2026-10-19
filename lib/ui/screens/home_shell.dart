import 'package:flutter/material.dart';

import 'apps_screen.dart';
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onOpenPlan: () => _goTo(_plan), onOpenApps: () => _goTo(_apps)),
            const AppsScreen(),
            PlanScreen(onSaved: () => _goTo(_dashboard)),
            const TipsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Applis'),
          NavigationDestination(icon: Icon(Icons.sim_card_outlined), selectedIcon: Icon(Icons.sim_card_rounded), label: 'Forfait'),
          NavigationDestination(icon: Icon(Icons.lightbulb_outline_rounded), selectedIcon: Icon(Icons.lightbulb_rounded), label: 'Conseils'),
        ],
      ),
    );
  }
}
