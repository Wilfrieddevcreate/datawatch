import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/usage_source.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Icône d'application lue sur le téléphone, ou pictogramme pour les
/// regroupements Android (système, partage de connexion…).
class UsageOwnerIcon extends StatefulWidget {
  const UsageOwnerIcon({
    super.key,
    required this.usage,
    required this.source,
    this.size = 40,
  });

  final AppUsage usage;
  final UsageSource source;
  final double size;

  @override
  State<UsageOwnerIcon> createState() => _UsageOwnerIconState();

  /// Vide le cache des icônes. Chaque test a sa propre horloge simulée : une
  /// icône chargée dans un test précédent n'y serait jamais livrée.
  @visibleForTesting
  static void clearCache() => _UsageOwnerIconState._cache.clear();
}

class _UsageOwnerIconState extends State<UsageOwnerIcon> {
  static final Map<String, Future<Uint8List?>> _cache = {};

  Future<Uint8List?>? _icon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UsageOwnerIcon old) {
    super.didUpdateWidget(old);
    if (old.usage.packageName != widget.usage.packageName) _load();
  }

  void _load() {
    final pkg = widget.usage.packageName;
    if (widget.usage.owner != UsageOwner.app || pkg == null) {
      _icon = null;
      return;
    }
    _icon = _cache.putIfAbsent(
      pkg,
      () => widget.source.appIcon(pkg, size: 128).catchError((_) => null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final radius = BorderRadius.circular(widget.size * 0.32);
    final fallback = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.usage.owner == UsageOwner.tethering ? c.strong : c.track,
        borderRadius: radius,
      ),
      child: Icon(
        _glyph(widget.usage.owner),
        size: widget.size * 0.5,
        color: widget.usage.owner == UsageOwner.tethering
            ? c.accent
            : c.textSecondary,
      ),
    );
    if (_icon == null) return ExcludeSemantics(child: fallback);
    return ExcludeSemantics(
      child: FutureBuilder<Uint8List?>(
        future: _icon,
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null) return fallback;
          return ClipRRect(
            borderRadius: radius,
            child: Image.memory(
              bytes,
              width: widget.size,
              height: widget.size,
              gaplessPlayback: true,
            ),
          );
        },
      ),
    );
  }

  static IconData _glyph(UsageOwner owner) => switch (owner) {
    UsageOwner.app => Icons.android_rounded,
    UsageOwner.system => Icons.memory_rounded,
    UsageOwner.removed => Icons.inventory_2_outlined,
    UsageOwner.tethering => Icons.wifi_tethering_rounded,
    UsageOwner.hidden => Icons.extension_outlined,
  };
}

/// Ligne « application · barre · volume · part ».
class UsageRow extends StatelessWidget {
  const UsageRow({
    super.key,
    required this.usage,
    required this.source,
    required this.share,
    required this.barFraction,
    this.barColor,
    this.iconSize = 40,
    this.height = 64,
    this.showDivider = true,
    this.variation,
    this.secondaryLabel,
    this.onTap,
  });

  final AppUsage usage;
  final UsageSource source;

  /// Part du total mesuré (0–1).
  final double share;

  /// Longueur de la barre, relative à la plus grosse ligne (0–1).
  final double barFraction;
  final Color? barColor;
  final double iconSize;
  final double height;
  final bool showDivider;

  /// Évolution par rapport à la période précédente (0,18 = +18 %).
  final double? variation;

  /// Remplace la part du total sous le volume (ex. « 1,05 Go/h »).
  final String? secondaryLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final t = Theme.of(context).textTheme;
    final v = variation;
    return Semantics(
      label:
          '${usage.displayName} : ${formatBytes(usage.bytes)}, ${formatShare(share)} du total'
          '${v == null ? '' : ', ${variationSentence(v)}'}',
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            border: showDivider
                ? Border(top: BorderSide(color: c.divider))
                : null,
          ),
          child: Row(
            children: [
              UsageOwnerIcon(usage: usage, source: source, size: iconSize),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usage.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge!.weight(500),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        children: [
                          Container(height: 6, color: c.divider),
                          FractionallySizedBox(
                            widthFactor: barFraction.clamp(0.02, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: barColor ?? c.strong,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 68),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatBytes(usage.bytes),
                      style: t.bodyLarge!
                          .weight(600)
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          secondaryLabel ?? formatShare(share),
                          style: t.bodySmall!.copyWith(color: c.textSecondary),
                        ),
                        if (v != null) ...[
                          const SizedBox(width: 6),
                          VariationChip(variation: v),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie de la maquette.
class DwCard extends StatelessWidget {
  const DwCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.dw.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Petit libellé en capitales, au-dessus d'un groupe.
class DwOverline extends StatelessWidget {
  const DwOverline(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: DwFonts.overline(color ?? context.dw.textSecondary),
  );
}

/// « ↑ 18 % » sur fond orange (hausse) ou « ↓ 12 % » sur fond vert (baisse).
/// La flèche porte le sens : la couleur n'est jamais seule.
class VariationChip extends StatelessWidget {
  const VariationChip({super.key, required this.variation, this.large = false});

  final double variation;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final up = variation > 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 6,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: up ? c.warningSoft : c.positiveSoft,
        borderRadius: BorderRadius.circular(
          large ? DwRadius.pill : DwRadius.xs,
        ),
      ),
      child: Text(
        formatVariation(variation),
        style: DwFonts.style(
          DwFonts.body,
          large ? 12.5 : 11.5,
          600,
          tabular: true,
        ).copyWith(color: up ? c.warningText : c.positiveText),
      ),
    );
  }
}
