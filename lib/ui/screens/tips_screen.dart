import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/usage_source.dart';
import '../../domain/tips.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/page_header.dart';
import '../widgets/primitives.dart';
import '../widgets/text_tabs.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key, required this.actions});

  final List<Widget> actions;

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  TipCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = context.dw;
    final snapshot = controller.snapshot;
    final apps = snapshot?.mobileApps;
    final focus = apps == null ? null : focusFor(apps);
    // Le coût d'une heure de l'appli la plus gourmande, si on connaît son temps d'écran.
    final top = apps?.where((a) => a.owner == UsageOwner.app).firstOrNull;
    final hourLine = top == null
        ? null
        : hourCostLine(
            top.displayName,
            snapshot!.perHourOf(top),
            controller.plan?.volumeBytes,
          );
    final tips = allTips
        .where((tip) => _filter == null || tip.category == _filter)
        .toList();

    return DwPage(
      title: 'Conseils',
      subtitle: const Text('Choisis d’après votre consommation mesurée.'),
      actions: widget.actions,
      children: [
        if (focus != null) ...[
          DwReveal(
            child: _FocusSheet(
              focus: focus,
              hourLine: hourLine,
              onShow: () => setState(() => _filter = focus.category),
            ),
          ),
          const SizedBox(height: 18),
        ],
        DwReveal(
          delay: 1,
          child: DwChoiceWords<TipCategory?>(
            values: [null, ...TipCategory.values],
            selected: _filter,
            scroll: true,
            height: 44,
            spacing: 22,
            labelOf: (cat) => cat?.label ?? 'Tous',
            onChanged: (cat) => setState(() => _filter = cat),
          ),
        ),
        const SizedBox(height: 16),
        DwReveal(
          delay: 2,
          child: DwSheet(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            child: Column(
              children: [
                for (final (i, tip) in tips.indexed)
                  _TipRow(tip: tip, divider: i > 0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Les conseils sont choisis d’après vos applications les plus gourmandes. DataWatch ne modifie jamais les réglages d’une autre application.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _FocusSheet extends StatelessWidget {
  const _FocusSheet({
    required this.focus,
    required this.hourLine,
    required this.onShow,
  });

  final TipFocus focus;
  final String? hourLine;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    const ink = Color(0xFF0F1218);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DwRadius.lg + 4),
      child: Container(
        color: c.accent,
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -36,
              child: CustomPaint(
                size: const Size(160, 160),
                painter: _HatchDisc(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votre plus gros poste',
                    style: DwFonts.label(const Color(0xFF34470A)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    focus.headline,
                    style: DwFonts.title(30).copyWith(color: ink),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    label: '${(focus.share * 100).round()} % des données mobiles',
                    excludeSemantics: true,
                    child: DwBar(
                      fraction: focus.share,
                      color: ink,
                      track: const Color(0x240F1218),
                      height: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hourLine == null
                        ? focus.detail
                        : '${focus.detail} $hourLine',
                    style: t.bodyMedium!.copyWith(color: const Color(0xFF26300A)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onShow,
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(44, 48),
                      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          focus.category == null
                              ? 'Voir tous les conseils'
                              : 'Voir les conseils ${focus.category!.label.toLowerCase()}',
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18, color: c.accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le disque hachuré de la carte lime.
class _HatchDisc extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final paint = Paint()
      ..color = const Color(0x140F1218)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width + size.height; x += 9) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchDisc old) => false;
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip, required this.divider});

  final Tip tip;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final icon = switch (tip.category) {
      TipCategory.video => Icons.play_circle_outline,
      TipCategory.messaging => Icons.chat_bubble_outline,
      TipCategory.updates => Icons.download_outlined,
      TipCategory.background => Icons.smartphone,
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: c.divider)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 22, color: c.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: t.titleMedium!.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  tip.body,
                  style: t.bodyMedium!.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DwDash(
                      width: 14,
                      color: tip.highImpact ? c.accent : c.track,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tip.highImpact ? 'Impact élevé' : 'Impact moyen',
                      style: DwFonts.style(DwFonts.body, 12.5, 600).copyWith(
                        color: tip.highImpact ? c.text : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
