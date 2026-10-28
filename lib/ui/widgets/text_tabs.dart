import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Onglets texte de largeur égale, soulignés d'un trait lime qui glisse.
class DwTextTabs<T> extends StatelessWidget {
  const DwTextTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.underlineColor,
    this.height = 44,
    this.fontSize = 13.5,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final Color? underlineColor;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / values.length;
        return SizedBox(
          height: height + 1,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.divider)),
                ),
                child: Row(
                  children: [
                    for (final v in values)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: v == selected,
                          child: InkWell(
                            onTap: () => onChanged(v),
                            child: SizedBox(
                              height: height,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    labelOf(v),
                                    maxLines: 1,
                                    style:
                                        DwFonts.style(
                                          DwFonts.body,
                                          fontSize,
                                          v == selected ? 600 : 500,
                                        ).copyWith(
                                          color: v == selected
                                              ? c.text
                                              : c.textSecondary,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: index * tabWidth,
                bottom: 0,
                width: tabWidth,
                height: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: underlineColor ?? c.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Choix en mots : des libellés côte à côte, le choix courant en encre
/// souligné de lime. En liste qui s'enroule, ou en bandeau qui défile.
class DwChoiceWords<T> extends StatelessWidget {
  const DwChoiceWords({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.scroll = false,
    this.height = 36,
    this.fontSize = 14,
    this.spacing = 18,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  /// Vrai : une seule ligne qui défile, avec un filet dessous.
  final bool scroll;
  final double height;
  final double fontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final words = [
      for (final v in values)
        _Word(
          label: labelOf(v),
          selected: v == selected,
          height: height,
          fontSize: fontSize,
          underline: scroll ? 3 : 2,
          onTap: () => onChanged(v),
        ),
    ];
    if (!scroll) {
      return Wrap(spacing: spacing, runSpacing: 4, children: words);
    }
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final (i, w) in words.indexed) ...[
              if (i > 0) SizedBox(width: spacing),
              w,
            ],
          ],
        ),
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.label,
    required this.selected,
    required this.height,
    required this.fontSize,
    required this.underline,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double height;
  final double fontSize;
  final double underline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DwRadius.xs),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? c.accent : Colors.transparent,
                width: underline,
              ),
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              style: DwFonts.style(
                DwFonts.body,
                fontSize,
                600,
              ).copyWith(color: selected ? c.text : c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
