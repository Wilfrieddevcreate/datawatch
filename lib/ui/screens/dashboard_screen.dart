import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../../data/usage_source.dart';
import '../period_text.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/plan_hero_card.dart';
import '../widgets/segmented.dart';
import '../widgets/usage_row.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenPlan, required this.onOpenApps});

  final VoidCallback onOpenPlan;
  final VoidCallback onOpenApps;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final snapshot = controller.snapshot;
    final periods = controller.plan == null
        ? const [UsagePeriod.today, UsagePeriod.week, UsagePeriod.month]
        : UsagePeriod.values;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Header(onAlerts: onOpenPlan),
          const SizedBox(height: 16),
          PlanHeroCard(
            plan: controller.plan,
            usage: controller.planUsage,
            now: snapshot?.fetchedAt ?? controller.now(),
            onEditPlan: onOpenPlan,
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text('Consommation', style: t.titleLarge)),
              if (controller.loading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (snapshot != null)
                Text('Mis à jour à ${formatTime(snapshot.fetchedAt)}', style: t.bodySmall!.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          DwSegmented<UsagePeriod>(
            values: periods,
            selected: controller.effectivePeriod,
            labelOf: (p) => p.label,
            onChanged: controller.setPeriod,
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 10),
            Text(
              periodCaption(snapshot.period, snapshot.range),
              textAlign: TextAlign.center,
              style: t.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          if (controller.error != null && snapshot == null)
            _ErrorCard(onRetry: controller.refresh)
          else ...[
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.signal_cellular_alt_rounded,
                    iconBackground: isLight ? c.strong : c.accent,
                    iconForeground: isLight ? c.accent : c.onAccent,
                    label: 'Mobile',
                    bytes: snapshot?.totals.mobileBytes,
                    loading: snapshot == null,
                    caption: controller.plan == null ? 'Données mobiles' : 'Compté dans le forfait',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.wifi_rounded,
                    iconBackground: c.wifiSoft,
                    iconForeground: c.wifi,
                    label: 'Wi-Fi',
                    bytes: snapshot?.totals.wifiBytes,
                    loading: snapshot == null,
                    caption: 'Hors forfait',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TopApps(apps: snapshot?.mobileApps, source: controller.source, onSeeAll: onOpenApps),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAlerts});
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 18,
              height: 26,
              padding: const EdgeInsets.all(3),
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(color: c.strong, borderRadius: BorderRadius.circular(6)),
              child: Container(
                height: 9,
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('DataWatch', style: DwFonts.style(DwFonts.display, 21, 700, letterSpacing: -0.4)),
          const Spacer(),
          IconButton(
            onPressed: onAlerts,
            tooltip: 'Seuils d’alerte',
            style: IconButton.styleFrom(backgroundColor: c.surface, fixedSize: const Size(44, 44)),
            icon: Icon(Icons.notifications_none_rounded, color: c.text, size: 21),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.label,
    required this.bytes,
    required this.loading,
    required this.caption,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String label;
  final int? bytes;
  final bool loading;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final value = loading ? '…' : (bytes == null ? '—' : formatBytes(bytes!));
    return DwCard(
      radius: DwRadius.lg,
      child: Semantics(
        label: '$label : ${bytes == null ? 'mesure indisponible' : value}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: iconForeground),
                ),
                const SizedBox(width: 8),
                Text(label, style: t.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: DwFonts.style(DwFonts.display, 30, 650, height: 1, letterSpacing: -0.9, tabular: true),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              !loading && bytes == null ? 'Mesure indisponible' : caption,
              style: t.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopApps extends StatelessWidget {
  const _TopApps({required this.apps, required this.source, required this.onSeeAll});

  final List<AppUsage>? apps;
  final UsageSource source;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final list = apps;
    final total = list?.fold<int>(0, (sum, a) => sum + a.bytes) ?? 0;
    final top = list?.take(3).toList() ?? const <AppUsage>[];
    final max = top.isEmpty ? 1 : top.first.bytes;

    return DwCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(child: Text('Les plus gourmandes', style: t.titleMedium)),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(foregroundColor: c.wifi, padding: const EdgeInsets.only(left: 8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('Tout voir'), Icon(Icons.chevron_right_rounded, size: 20)],
                  ),
                ),
              ],
            ),
          ),
          if (list == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              child: Text(
                'Aucune consommation mobile mesurée sur cette période.',
                style: t.bodyMedium!.copyWith(color: c.textSecondary),
              ),
            )
          else
            for (final app in top)
              UsageRow(
                usage: app,
                source: source,
                share: total == 0 ? 0 : app.bytes / total,
                barFraction: app.bytes / max,
              ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Impossible de lire les statistiques', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Android n’a pas répondu. Réessayez dans un instant.',
            style: t.bodyMedium!.copyWith(color: context.dw.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
