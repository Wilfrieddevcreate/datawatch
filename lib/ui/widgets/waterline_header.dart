import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/data_plan.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'page_header.dart';
import 'water_basin.dart';

/// L'en-tête de l'accueil : le bloc sombre qui passe sous la barre d'état,
/// le restant en gros chiffres, et la cuve pleine largeur en bas.
class WaterlineHeader extends StatelessWidget {
  const WaterlineHeader({
    super.key,
    required this.plan,
    required this.usage,
    required this.now,
    required this.actions,
    required this.dateLine,
    required this.onEditPlan,
  });

  final DataPlan? plan;
  final PlanUsage? usage;
  final DateTime now;
  final List<Widget> actions;
  final String dateLine;
  final VoidCallback onEditPlan;

  static const double basinHeight = 104;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final top = MediaQuery.paddingOf(context).top;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final p = plan;
    final u = usage;
    final expired = p != null && p.isExpired(now);
    final status = _Status.of(c, u, expired);
    final thresholds = p == null
        ? const <int>[]
        : (p.thresholds.where((t) => t < 100).toList()..sort());

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(DwRadius.xl),
        ),
        border: isLight ? null : Border.all(color: c.heroBorder),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: c.heroText),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: top),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                  child: SizedBox(
                    height: DwPage.barHeight,
                    child: Row(
                      children: [
                        DwWordmark(color: c.heroText),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: p == null
                      ? _NoPlan(onEditPlan: onEditPlan, dateLine: dateLine)
                      : _PlanBody(
                          plan: p,
                          usage: u,
                          now: now,
                          status: status,
                          dateLine: dateLine,
                          onEditPlan: onEditPlan,
                        ),
                ),
                const SizedBox(height: 22 + basinHeight),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: WaterBasin(
                remainingFraction: u?.remainingFraction ?? 0,
                fillColor: status?.water ?? c.accent,
                thresholds: thresholds,
                height: basinHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan({required this.onEditPlan, required this.dateLine});
  final VoidCallback onEditPlan;
  final String dateLine;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLine,
          style: t.bodySmall!.copyWith(color: c.heroTextSecondary),
        ),
        const SizedBox(height: 16),
        Text('Restant estimé', style: DwFonts.label(c.heroTextSecondary)),
        const SizedBox(height: 8),
        Text('Aucun forfait déclaré', style: DwFonts.title(30)),
        const SizedBox(height: 8),
        Text(
          'Indiquez le volume et la date d’achat : DataWatch estime ce qu’il reste.',
          style: t.bodyMedium!.copyWith(color: c.heroTextSecondary),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onEditPlan,
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            minimumSize: const Size(64, 48),
          ),
          child: const Text('Déclarer mon forfait'),
        ),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({
    required this.plan,
    required this.usage,
    required this.now,
    required this.status,
    required this.dateLine,
    required this.onEditPlan,
  });

  final DataPlan plan;
  final PlanUsage? usage;
  final DateTime now;
  final _Status? status;
  final String dateLine;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final expired = plan.isExpired(now);
    final u = usage;
    final remaining = u == null ? null : sizeParts(u.remainingBytes);
    final parts = remaining?.value.split(',');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLine,
          style: t.bodySmall!.copyWith(color: c.heroTextSecondary),
        ),
        const SizedBox(height: 16),
        Text(
          expired ? 'Restant à la fin' : 'Restant estimé',
          style: DwFonts.label(c.heroTextSecondary),
        ),
        const SizedBox(height: 8),
        if (remaining == null || parts == null)
          Text('Mesure indisponible', style: DwFonts.title(30))
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: parts[0], style: DwFonts.hero(92)),
                  if (parts.length > 1) ...[
                    TextSpan(
                      text: ',',
                      style: DwFonts.hero(92).copyWith(color: c.accent),
                    ),
                    TextSpan(text: parts[1], style: DwFonts.hero(92)),
                  ],
                  TextSpan(
                    text: '$nbsp${remaining.unit}',
                    style: DwFonts.style(
                      DwFonts.display,
                      28,
                      500,
                    ).copyWith(color: c.heroTextSecondary),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'sur ${formatBytes(plan.volumeBytes)}'),
              if (u != null) ...[
                const TextSpan(text: ' · '),
                TextSpan(
                  text: formatShare(u.usedFraction),
                  style: TextStyle(color: c.heroText).weight(600),
                ),
                TextSpan(
                  // « 0 % utilisé », « 72 % utilisés ».
                  text: ' ${u.usedFraction < 0.015 ? 'utilisé' : 'utilisés'}',
                ),
              ],
              TextSpan(
                text: expired
                    ? ' · expiré le ${formatDayMonthTime(plan.end)}'
                    : ' · expire dans ${formatRemaining(plan.end.difference(now))}',
              ),
            ],
          ),
          style: t.bodyMedium!.copyWith(
            fontSize: 14,
            color: const Color(0xFFC9CFD9),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (status != null)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DwRadius.xs),
                      border: Border.all(color: status!.color),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      status!.label,
                      style: DwFonts.style(
                        DwFonts.body,
                        12,
                        600,
                      ).copyWith(color: status!.color),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            const Spacer(),
            if (expired)
              FilledButton(
                onPressed: onEditPlan,
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: t.labelLarge!.copyWith(fontSize: 14),
                ),
                child: const Text('Nouveau suivi'),
              )
            else
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label:
                        'Modifier le forfait ${plan.operator.label} de ${formatBytes(plan.volumeBytes)}',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onEditPlan,
                      borderRadius: BorderRadius.circular(DwRadius.xs),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 8, 2, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${plan.operator.label} · ${formatBytes(plan.volumeBytes)} · Modifier',
                              style: t.titleSmall!.copyWith(
                                fontSize: 13.5,
                                color: c.accent,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: c.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Status {
  const _Status(this.label, this.color, this.water);

  final String label;
  final Color color;
  final Color water;

  static _Status? of(DwColors c, PlanUsage? usage, bool expired) {
    if (expired) {
      return const _Status('Expiré', Color(0xFFC9CFD9), Color(0xFF5A6170));
    }
    if (usage == null) return null;
    return switch (usage.level) {
      UsageLevel.ok => const _Status(
        'Sous contrôle',
        DwColors.tankOk,
        DwColors.tankOk,
      ),
      UsageLevel.half => const _Status(
        'Plus de 50$nbsp% utilisés',
        DwColors.tankOk,
        DwColors.tankOk,
      ),
      UsageLevel.warning => const _Status(
        'Seuil 80$nbsp% atteint',
        Color(0xFFFFB27A),
        DwColors.tankWarning,
      ),
      UsageLevel.exhausted => const _Status(
        'Forfait épuisé',
        Color(0xFFFF8F8F),
        DwColors.tankCritical,
      ),
    };
  }
}
