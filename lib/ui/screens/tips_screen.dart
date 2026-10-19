import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/tips.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/usage_row.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  TipCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final apps = AppScope.of(context).snapshot?.mobileApps;
    final focus = apps == null ? null : focusFor(apps);
    final tips = allTips.where((tip) => _filter == null || tip.category == _filter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Conseils', style: t.headlineMedium),
        const SizedBox(height: 2),
        Text('Choisis d’après votre consommation mesurée.', style: t.bodyMedium!.copyWith(color: c.textSecondary)),
        const SizedBox(height: 16),
        if (focus != null) ...[
          _FocusCard(focus: focus, onShow: () => setState(() => _filter = focus.category)),
          const SizedBox(height: 16),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _FilterChip(label: 'Tous', selected: _filter == null, onTap: () => setState(() => _filter = null)),
              for (final cat in TipCategory.values) ...[
                const SizedBox(width: 8),
                _FilterChip(label: cat.label, selected: _filter == cat, onTap: () => setState(() => _filter = cat)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final tip in tips) ...[
          _TipCard(tip: tip),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.focus, required this.onShow});

  final TipFocus focus;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const ink = Color(0xFF0F1218);
    return DwCard(
      color: DwColors.tankOk,
      radius: DwRadius.xl,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DwOverline('Votre plus gros poste', color: Color(0xFF34470A)),
          const SizedBox(height: 10),
          Text(
            focus.headline,
            style: DwFonts.style(DwFonts.display, 27, 700, height: 1.08, letterSpacing: -0.8).copyWith(color: ink),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '${(focus.share * 100).round()} % des données mobiles',
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  flex: (focus.share * 1000).round().clamp(1, 1000),
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: ((1 - focus.share) * 1000).round().clamp(1, 1000),
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0x240F1218),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(focus.detail, style: t.bodyMedium!.copyWith(color: const Color(0xFF26300A))),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onShow,
            iconAlignment: IconAlignment.end,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            icon: const Icon(Icons.chevron_right_rounded, color: DwColors.tankOk),
            label: Text(focus.category == null ? 'Voir tous les conseils' : 'Voir les conseils ${focus.category!.label.toLowerCase()}'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.strong : c.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? c.strong : c.divider)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(color: selected ? c.onStrong : c.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});
  final Tip tip;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final (icon, bg, fg) = switch (tip.category) {
      TipCategory.video => (Icons.play_circle_outline_rounded, c.warningSoft, c.warningText),
      TipCategory.messaging => (Icons.chat_bubble_outline_rounded, c.positiveSoft, c.positiveText),
      TipCategory.updates => (Icons.download_rounded, c.wifiSoft, c.wifi),
      TipCategory.background => (Icons.smartphone_rounded, c.track, c.textSecondary),
    };
    return DwCard(
      radius: DwRadius.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DwRadius.md)),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: t.titleMedium!.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(tip.body, style: t.bodyMedium!.copyWith(color: c.textSecondary)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tip.highImpact ? c.strong : c.track,
                    borderRadius: BorderRadius.circular(DwRadius.pill),
                  ),
                  child: Text(
                    tip.highImpact ? 'Impact élevé' : 'Impact moyen',
                    style: DwFonts.style(DwFonts.body, 12, 600).copyWith(
                      color: tip.highImpact ? (Theme.of(context).brightness == Brightness.light ? c.accent : c.onStrong) : c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
