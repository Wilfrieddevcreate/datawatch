import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../../data/usage_source.dart';
import '../../domain/data_plan.dart';
import '../period_text.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/plan_hero_card.dart';
import '../widgets/segmented.dart';
import '../widgets/usage_row.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.actions,
    required this.onOpenPlan,
    required this.onOpenApps,
  });

  final List<Widget> actions;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenApps;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final snapshot = controller.snapshot;
    final now = snapshot?.fetchedAt ?? controller.now();
    final periods = controller.plan == null
        ? const [UsagePeriod.today, UsagePeriod.week, UsagePeriod.month]
        : const [
            UsagePeriod.plan,
            UsagePeriod.today,
            UsagePeriod.week,
            UsagePeriod.month,
          ];

    return DwPage(
      title: now.hour >= 5 && now.hour < 18 ? 'Bonjour' : 'Bonsoir',
      overline: formatLongDate(now),
      compactTitle: 'Accueil',
      subtitle: Text(_paceSentence(controller.plan, controller.planUsage, now)),
      actions: actions,
      onRefresh: controller.refresh,
      children: [
        PlanHeroCard(
          plan: controller.plan,
          usage: controller.planUsage,
          now: now,
          onEditPlan: onOpenPlan,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: Text('Consommation', style: t.titleLarge)),
            if (controller.loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (snapshot != null)
              Text(
                'Mis à jour à ${formatTime(snapshot.fetchedAt)}',
                style: t.bodySmall!.copyWith(color: c.textSecondary),
              ),
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.signal_cellular_alt_rounded,
                    iconBackground: isLight ? c.strong : c.accent,
                    iconForeground: isLight ? c.accent : c.onAccent,
                    label: 'Mobile',
                    bytes: snapshot?.totals.mobileBytes,
                    loading: snapshot == null,
                    caption: controller.plan == null
                        ? 'Données mobiles'
                        : 'Dans le forfait',
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
          ),
          const SizedBox(height: 12),
          _TopApps(
            apps: snapshot?.mobileApps,
            source: controller.source,
            onSeeAll: onOpenApps,
          ),
        ],
      ],
    );
  }

  /// Phrase d'en-tête : ce que le rythme actuel annonce pour le forfait.
  static String _paceSentence(DataPlan? plan, PlanUsage? usage, DateTime now) {
    if (plan == null) {
      return 'Déclarez votre forfait pour savoir combien de temps il va tenir.';
    }
    if (plan.isExpired(now)) {
      return 'Votre forfait a expiré le ${formatDayMonth(plan.end)}. Après une recharge, démarrez un nouveau suivi.';
    }
    if (usage == null) {
      return 'Forfait ${plan.operator.label} suivi jusqu’au ${formatDayMonthTime(plan.end)}.';
    }
    if (usage.level == UsageLevel.exhausted) {
      return 'Le volume déclaré est épuisé, selon la mesure de ce téléphone.';
    }
    return switch (projectPace(plan, usage, now)) {
      PaceUnknown() =>
        'Votre rythme de consommation s’affichera d’ici quelques heures.',
      PaceLastsUntilEnd() =>
        'À ce rythme, votre forfait tiendra jusqu’à son expiration.',
      PaceRunsOut(:final at) =>
        'À ce rythme, il sera épuisé le ${formatDayMonth(at)} ${formatPartOfDay(at)}, avant son expiration.',
    };
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
        label:
            '$label : ${!loading && bytes == null ? 'mesure indisponible' : value}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: iconForeground),
                ),
                const SizedBox(width: 8),
                Text(label, style: t.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: DwFonts.style(
                  DwFonts.display,
                  30,
                  650,
                  height: 1,
                  letterSpacing: -0.9,
                  tabular: true,
                ),
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
  const _TopApps({
    required this.apps,
    required this.source,
    required this.onSeeAll,
  });

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
                Expanded(
                  child: Text('Les plus gourmandes', style: t.titleMedium),
                ),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: c.wifi,
                    padding: const EdgeInsets.only(left: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tout voir'),
                      Icon(Icons.chevron_right_rounded, size: 20),
                    ],
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
