import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/data_plan.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import 'apps_screen.dart';
import 'dashboard_screen.dart';
import 'plan_screen.dart';
import 'settings_screen.dart';
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
    final badge = switch (level) {
      UsageLevel.exhausted => c.critical,
      UsageLevel.warning => c.warning,
      _ => null,
    };
    List<Widget> actions({Color? color, Color? badgeBorder}) => [
      DwHeaderButton(
        icon: Icons.notifications_none,
        tooltip: 'Seuils d’alerte',
        onPressed: () => _goTo(_plan),
        badgeColor: badge,
        color: color,
        badgeBorder: badgeBorder,
      ),
      DwHeaderButton(
        icon: Icons.settings_outlined,
        tooltip: 'Paramètres',
        onPressed: () => Navigator.of(
          context,
        ).push(SettingsScreen.route(onOpenPlan: () => _goTo(_plan))),
        color: color,
        badgeBorder: badgeBorder,
      ),
    ];
    final tabActions = actions();

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            actions: actions(color: c.heroText, badgeBorder: c.hero),
            onOpenPlan: () => _goTo(_plan),
            onOpenApps: () => _goTo(_apps),
          ),
          AppsScreen(actions: tabActions),
          PlanScreen(actions: tabActions, onSaved: () => _goTo(_dashboard)),
          TipsScreen(actions: tabActions),
        ],
      ),
      bottomNavigationBar: _TabBar(index: _index, onChanged: _goTo),
    );
  }
}

/// Barre d'onglets plate : un filet au-dessus, l'onglet courant souligné
/// d'un trait lime sous son icône.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _Tab(
                label: 'Accueil',
                selected: index == 0,
                onTap: () => onChanged(0),
                icon: const _TankIcon(),
              ),
              _Tab(
                label: 'Applis',
                selected: index == 1,
                onTap: () => onChanged(1),
                icon: const Icon(Icons.grid_view_rounded, size: 22),
              ),
              _Tab(
                label: 'Forfait',
                selected: index == 2,
                onTap: () => onChanged(2),
                icon: const Icon(Icons.sim_card_outlined, size: 22),
              ),
              _Tab(
                label: 'Conseils',
                selected: index == 3,
                onTap: () => onChanged(3),
                icon: const Icon(Icons.lightbulb_outline, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final color = selected ? c.text : c.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? c.accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: IconTheme(
                  data: IconThemeData(color: color, size: 22),
                  child: icon,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: DwFonts.style(
                  DwFonts.body,
                  12,
                  selected ? 600 : 500,
                ).copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'icône de l'accueil : le réservoir, dans la couleur de l'onglet.
class _TankIcon extends StatelessWidget {
  const _TankIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? context.dw.text;
    return Container(
      width: 13,
      height: 20,
      padding: const EdgeInsets.all(2.5),
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
