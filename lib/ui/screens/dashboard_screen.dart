import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../core/format.dart';
import '../../data/usage_source.dart';
import '../../domain/data_plan.dart';
import '../period_text.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/primitives.dart';
import '../widgets/text_tabs.dart';
import '../widgets/usage_row.dart';
import '../widgets/waterline_header.dart';
import 'app_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.actions,
    required this.onOpenPlan,
    required this.onOpenApps,
  });

  /// Boutons de l'en-tête, aux couleurs du bloc sombre.
  final List<Widget> actions;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenApps;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final snapshot = controller.snapshot;
    final now = snapshot?.fetchedAt ?? controller.now();
    final plan = controller.plan;
    final periods = plan == null
        ? const [UsagePeriod.today, UsagePeriod.week, UsagePeriod.month]
        : const [
            UsagePeriod.plan,
            UsagePeriod.today,
            UsagePeriod.week,
            UsagePeriod.month,
          ];
    final date = formatLongDate(now);
    final dateLine =
        '${date[0].toUpperCase()}${date.substring(1)}'
        '${snapshot == null ? '' : ' · relevé à ${formatTime(snapshot.fetchedAt)}'}';
    final mobile = snapshot?.totals.mobileBytes;
    final wifi = snapshot?.totals.wifiBytes;
    final split = mobile == null || wifi == null || mobile + wifi == 0
        ? 0.5
        : mobile / (mobile + wifi);

    // Le bloc sombre passe sous la barre d'état : ses icônes doivent être
    // claires ici, quel que soit le thème (les autres onglets gardent le
    // réglage global, fond clair et icônes sombres).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        color: c.accent,
        backgroundColor: c.hero,
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: WaterlineHeader(
                plan: plan,
                usage: controller.planUsage,
                now: now,
                actions: actions,
                dateLine: dateLine,
                onEditPlan: onOpenPlan,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList.list(
                children: [
                  DwReveal(
                    delay: 1,
                    child: Text(
                      _paceSentence(plan, controller.planUsage, now),
                      style: t.bodyMedium!.weight(500).copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  DwReveal(
                    delay: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DwSectionTitle(
                          'Consommation',
                          trailing: controller.loading
                              ? const DwLoader(size: 20)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DwTextTabs<UsagePeriod>(
                          values: periods,
                          selected: controller.effectivePeriod,
                          labelOf: (p) => p.label,
                          onChanged: controller.setPeriod,
                        ),
                        if (snapshot != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            periodCaption(snapshot.period, snapshot.range),
                            style: t.bodySmall!.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (controller.error != null && snapshot == null)
                          _ErrorSheet(onRetry: controller.refresh)
                        else ...[
                          Semantics(
                            label:
                                'Mobile ${mobile == null ? 'indisponible' : formatBytes(mobile)}, Wi-Fi ${wifi == null ? 'indisponible' : formatBytes(wifi)}',
                            excludeSemantics: true,
                            child: DwSplitBar(fraction: split),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Total(
                                  label: 'Mobile',
                                  swatch: c.strong,
                                  bytes: mobile,
                                  loading: snapshot == null,
                                  caption: plan == null
                                      ? 'Données mobiles'
                                      : 'Dans le forfait',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _Total(
                                  label: 'Wi-Fi',
                                  swatch: c.wifi,
                                  bytes: wifi,
                                  loading: snapshot == null,
                                  caption: 'Hors forfait',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  DwReveal(
                    delay: 3,
                    child: _TopApps(
                      apps: snapshot?.mobileApps,
                      source: controller.source,
                      onSeeAll: onOpenApps,
                      variationOf: (app) =>
                          snapshot?.variationOf(app, NetworkKind.mobile),
                    ),
                  ),
                  if (plan != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Mesuré par ce téléphone. Ce n’est pas le solde officiel de l’opérateur.',
                        style: t.bodySmall!.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phrase sous l'en-tête : ce que le rythme actuel annonce pour le forfait.
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

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.swatch,
    required this.bytes,
    required this.loading,
    required this.caption,
  });

  final String label;
  final Color swatch;
  final int? bytes;
  final bool loading;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final unavailable = !loading && bytes == null;
    final value = loading ? '…' : (bytes == null ? '—' : formatBytes(bytes!));
    return Semantics(
      label: '$label : ${unavailable ? 'mesure indisponible' : value}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: DwFonts.label(c.text)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: DwFonts.style(
                DwFonts.display,
                30,
                700,
                height: 1.05,
                letterSpacing: -1,
                tabular: true,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unavailable ? 'Mesure indisponible' : caption,
            style: t.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TopApps extends StatelessWidget {
  const _TopApps({
    required this.apps,
    required this.source,
    required this.onSeeAll,
    required this.variationOf,
  });

  final List<AppUsage>? apps;
  final UsageSource source;
  final VoidCallback onSeeAll;
  final double? Function(AppUsage) variationOf;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final list = apps;
    final total = list?.fold<int>(0, (sum, a) => sum + a.bytes) ?? 0;
    final top = list?.take(3).toList() ?? const <AppUsage>[];
    final max = top.isEmpty ? 1 : top.first.bytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DwSectionTitle(
          'Les plus gourmandes',
          trailing: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: t.titleSmall!.copyWith(fontSize: 13.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tout voir'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        DwSheet(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: list == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: DwLoader()),
                )
              : top.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Aucune consommation mobile mesurée sur cette période.',
                    style: t.bodyMedium!.copyWith(color: c.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, app) in top.indexed)
                      UsageRow(
                        usage: app,
                        source: source,
                        share: total == 0 ? 0 : app.bytes / total,
                        barFraction: app.bytes / max,
                        variation: variationOf(app),
                        showDivider: i > 0,
                        onTap: app.owner == UsageOwner.app
                            ? () => Navigator.of(
                                context,
                              ).push(AppDetailScreen.route(app))
                            : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ErrorSheet extends StatelessWidget {
  const _ErrorSheet({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DwSheet(
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
