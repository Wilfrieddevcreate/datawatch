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
        child: plan == null ? _NoPlan(onEditPlan: onEditPlan) : _PlanBody(plan: plan!, usage: usage, now: now, onEditPlan: onEditPlan),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AUCUN FORFAIT DÉCLARÉ', style: DwFonts.overline(c.heroTextSecondary)),
        const SizedBox(height: 10),
        Text(
          'Déclarez votre forfait pour voir ce qu’il vous reste.',
          style: t.headlineSmall!.copyWith(color: c.heroText),
        ),
        const SizedBox(height: 8),
        Text(
          'Volume, date de début et durée suffisent. Tout reste sur ce téléphone.',
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
          child: const Text('Configurer mon forfait'),
        ),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({required this.plan, required this.usage, required this.now, required this.onEditPlan});

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
            _Pill(
              label: '${plan.operator.label} · Forfait ${formatBytes(plan.volumeBytes)}',
              color: const Color(0xFFD5DAE3),
              background: const Color(0x14FFFFFF),
            ),
            const Spacer(),
            if (status != null) _Pill(label: status.label, color: status.color, background: status.background, dot: true),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SizedBox(
                height: 184,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expired ? 'RESTANT À L’EXPIRATION' : 'RESTANT ESTIMÉ', style: DwFonts.overline(c.heroTextSecondary)),
                        const SizedBox(height: 6),
                        if (remaining == null)
                          Text('Mesure indisponible', style: t.titleLarge!.copyWith(color: c.heroText))
                        else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(remaining.value, style: DwFonts.hero(72).copyWith(color: c.heroText)),
                                const SizedBox(width: 6),
                                Text(
                                  remaining.unit,
                                  style: DwFonts.style(DwFonts.display, 24, 600, letterSpacing: -0.5).copyWith(color: c.heroText),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        if (u != null)
                          Text.rich(
                            TextSpan(
                              text: 'sur ${formatBytes(plan.volumeBytes)} · ',
                              children: [
                                TextSpan(
                                  text: formatShare(u.usedFraction),
                                  style: TextStyle(color: c.heroText).weight(600),
                                ),
                                const TextSpan(text: ' utilisés'),
                              ],
                            ),
                            style: t.bodyMedium!.copyWith(fontSize: 14, color: const Color(0xFFC9CFD9)),
                          ),
                      ],
                    ),
                    _Expiry(plan: plan, now: now),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            ReservoirGauge(
              remainingFraction: u?.remainingFraction ?? 0,
              fillColor: status?.tank ?? DwColors.tankOk,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: const Color(0x1AFFFFFF)),
        const SizedBox(height: 14),
        Row(
          children: [
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
          child: Icon(Icons.schedule_rounded, size: 18, color: expired ? c.heroTextSecondary : c.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expired ? 'Forfait expiré' : 'Expire dans ${formatRemaining(plan.end.difference(now))}',
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
    if (expired) return const _Status('Expiré', Color(0xFFC9CFD9), Color(0x14FFFFFF), Color(0xFF5A6170));
    if (usage == null) return null;
    const lime = _Status('Sous contrôle', DwColors.tankOk, Color(0x24C6F135), DwColors.tankOk);
    return switch (usage.level) {
      UsageLevel.ok => lime,
      UsageLevel.half => const _Status('Seuil 50$nbsp% passé', DwColors.tankOk, Color(0x24C6F135), DwColors.tankOk),
      UsageLevel.warning => const _Status('Seuil 80$nbsp% atteint', Color(0xFFFFB27A), Color(0x29FF9F5A), DwColors.tankWarning),
      UsageLevel.exhausted => const _Status('Forfait épuisé', Color(0xFFFF8F8F), Color(0x29FF6B6B), DwColors.tankCritical),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.background, this.dot = false});

  final String label;
  final Color color;
  final Color background;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(DwRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          Text(label, style: DwFonts.style(DwFonts.body, 12.5, dot ? 600 : 500).copyWith(color: color)),
        ],
      ),
    );
  }
}
