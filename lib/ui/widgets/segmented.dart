import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Sélecteur en pilule de la maquette (périodes, opérateur, Mo/Go…).
class DwSegmented<T> extends StatelessWidget {
  const DwSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.height = 40,
    this.expand = true,
    this.fontSize = 13,
    this.selectedColorOf,
    this.trackColor,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? Function(T)? iconOf;
  final double height;

  /// Vrai : segments de largeur égale sur toute la ligne.
  final bool expand;
  final double fontSize;

  /// Couleur de fond du segment sélectionné (par défaut : encre).
  final Color Function(T)? selectedColorOf;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final segments = [
      for (final v in values)
        _Segment(
          label: labelOf(v),
          icon: iconOf?.call(v),
          selected: v == selected,
          height: height,
          fontSize: fontSize,
          selectedColor: selectedColorOf?.call(v) ?? c.strong,
          onTap: () => onChanged(v),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor ?? c.track,
        borderRadius: BorderRadius.circular(DwRadius.pill),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            if (expand) Expanded(child: segments[i]) else segments[i],
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.height,
    required this.fontSize,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final double height;
  final double fontSize;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final fg = selected
        ? (ThemeData.estimateBrightnessForColor(selectedColor) ==
                  Brightness.dark
              ? Colors.white
              : c.onAccent)
        : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedColor : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height, minWidth: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 8),
                  ],
                  // Un libellé trop long rétrécit plutôt que d'être tronqué.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: DwFonts.style(
                          DwFonts.body,
                          fontSize,
                          selected ? 600 : 500,
                        ).copyWith(color: fg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
