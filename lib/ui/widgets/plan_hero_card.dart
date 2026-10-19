import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../domain/data_plan.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'reservoir_gauge.dart';

/// Carte principale de l'accueil : forfait déclaré, volume restant estimé et jauge.
class PlanHeroCard extends StatelessWidget {
  const PlanHeroCard({
    super.key,
    required this.plan,
    required this.usage,
    required this.now,
    required this.onEditPlan,
  });

  final DataPlan? plan;
  final PlanUsage? usage;
  final DateTime now;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: BorderRadius.circular(DwRadius.xl),
        border: Border.all(color: c.heroBorder),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: c.heroText),
        child: plan == null
            ? _NoPlan(onEditPlan: onEditPlan)
            : _PlanBody(
                plan: plan!,
                usage: usage,
                now: now,
                onEditPlan: onEditPlan,
              ),
      ),
    );
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan({required this.onEditPlan});
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AUCUN FORFAIT',
                style: DwFonts.overline(c.heroTextSecondary),
              ),
              const SizedBox(height: 10),
              Text(
                'Combien vous reste-t-il ?',
                style: DwFonts.style(
                  DwFonts.display,
                  26,
                  700,
                  height: 1.08,
                  letterSpacing: -0.8,
                ).copyWith(color: c.heroText),
              ),
              const SizedBox(height: 8),
              Text(
                'Indiquez le volume et la date d’achat : DataWatch estime le reste.',
                style: t.bodyMedium!.copyWith(color: c.heroTextSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onEditPlan,
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  minimumSize: const Size(64, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text('Déclarer mon forfait'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const ReservoirGauge(
          remainingFraction: 0,
          fillColor: DwColors.tankOk,
          width: 64,
          height: 148,
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
    required this.onEditPlan,
  });

  final DataPlan plan;
  final PlanUsage? usage;
  final DateTime now;
  final VoidCallback onEditPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final expired = plan.isExpired(now);
    final u = usage;
    final status = _Status.of(u, expired);
    final remaining = u == null ? null : sizeParts(u.remainingBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: _Pill(
                label:
                    '${plan.operator.label} · ${formatBytes(plan.volumeBytes)}',
                color: const Color(0xFFD5DAE3),
                background: const Color(0x14FFFFFF),
                trailingIcon: Icons.edit_outlined,
                semanticLabel:
                    'Modifier le forfait ${plan.operator.label} de ${formatBytes(plan.volumeBytes)}',
                onTap: onEditPlan,
              ),
            ),
            if (status != null) ...[
              const SizedBox(width: 8),
              _Pill(
                label: status.label,
                color: status.color,
                background: status.background,
                dot: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        // Hauteur commune : la jauge (184) ou le texte s'il est agrandi.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expired ? 'RESTANT À LA FIN' : 'RESTANT ESTIMÉ',
                          style: DwFonts.overline(c.heroTextSecondary),
                        ),
                        const SizedBox(height: 8),
                        if (remaining == null)
                          Text(
                            'Mesure indisponible',
                            style: t.titleLarge!.copyWith(color: c.heroText),
                          )
                        else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  remaining.value,
                                  style: DwFonts.hero(
                                    72,
                                  ).copyWith(color: c.heroText),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  remaining.unit,
                                  style: DwFonts.style(
                                    DwFonts.display,
                                    24,
                                    600,
                                    letterSpacing: -0.5,
                                  ).copyWith(color: c.heroText),
                                ),
                              ],
                            ),
                          ),
                        if (u != null) ...[
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: formatShare(u.usedFraction),
                                  style: TextStyle(
                                    color: c.heroText,
                                  ).weight(600),
                                ),
                                TextSpan(
                                  // « 0 % utilisé », « 72 % utilisés ».
                                  text:
                                      ' ${u.usedFraction < 0.015 ? 'utilisé' : 'utilisés'} · ${formatBytes(u.usedBytes)}',
                                ),
                              ],
                            ),
                            style: t.bodyMedium!.copyWith(
                              fontSize: 14,
                              color: const Color(0xFFC9CFD9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Expiry(plan: plan, now: now),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 88,
                height: 184,
                child: ReservoirGauge(
                  remainingFraction: u?.remainingFraction ?? 0,
                  fillColor: status?.tank ?? DwColors.tankOk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: const Color(0x1AFFFFFF)),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: c.heroTextSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mesuré par ce téléphone. Ce n’est pas le solde officiel de l’opérateur.',
                style: t.bodySmall!.copyWith(color: c.heroTextSecondary),
              ),
            ),
            if (expired) ...[
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onEditPlan,
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: t.labelLarge!.copyWith(fontSize: 14),
                ),
                child: const Text('Nouveau suivi'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Expiry extends StatelessWidget {
  const _Expiry({required this.plan, required this.now});
  final DataPlan plan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final expired = plan.isExpired(now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.schedule_rounded,
            size: 18,
            color: expired ? c.heroTextSecondary : c.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expired
                    ? 'Forfait expiré'
                    : 'Expire dans ${formatRemaining(plan.end.difference(now))}',
                style: t.titleSmall!.copyWith(color: c.heroText),
              ),
              Text(
                '${expired ? 'depuis le' : 'le'} ${formatDayMonthTime(plan.end)}',
                style: t.bodySmall!.copyWith(color: c.heroTextSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Status {
  const _Status(this.label, this.color, this.background, this.tank);

  final String label;
  final Color color;
  final Color background;
  final Color tank;

  static _Status? of(PlanUsage? usage, bool expired) {
    if (expired) {
      return const _Status(
        'Expiré',
        Color(0xFFC9CFD9),
        Color(0x14FFFFFF),
        Color(0xFF5A6170),
      );
    }
    if (usage == null) return null;
    return switch (usage.level) {
      UsageLevel.ok => const _Status(
        'Sous contrôle',
        DwColors.tankOk,
        Color(0x24C6F135),
        DwColors.tankOk,
      ),
      UsageLevel.half => const _Status(
        'Plus de 50$nbsp%',
        DwColors.tankOk,
        Color(0x24C6F135),
        DwColors.tankOk,
      ),
      UsageLevel.warning => const _Status(
        'Seuil 80$nbsp%',
        Color(0xFFFFB27A),
        Color(0x29FF9F5A),
        DwColors.tankWarning,
      ),
      UsageLevel.exhausted => const _Status(
        'Épuisé',
        Color(0xFFFF8F8F),
        Color(0x29FF6B6B),
        DwColors.tankCritical,
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
    this.dot = false,
    this.trailingIcon,
    this.semanticLabel,
    this.onTap,
  });

  final String label;
  final Color color;
  final Color background;
  final bool dot;
  final IconData? trailingIcon;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(minHeight: onTap == null ? 30 : 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DwFonts.style(
                DwFonts.body,
                12.5,
                dot ? 600 : 500,
              ).copyWith(color: color),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 6),
            Icon(trailingIcon, size: 14, color: color),
          ],
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        child: onTap == null
            ? content
            : InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }
}
