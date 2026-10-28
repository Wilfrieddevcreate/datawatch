import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/usage_source.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'primitives.dart';

/// Icône d'application lue sur le téléphone, ou vignette portant l'initiale
/// (application sans icône) ou un pictogramme (regroupements Android).
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
    final size = widget.size;
    final owner = widget.usage.owner;
    final radius = BorderRadius.circular(size * 0.26);
    final name = widget.usage.displayName.trim();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: owner == UsageOwner.tethering ? c.strong : c.track,
        borderRadius: radius,
      ),
      child: owner == UsageOwner.app && name.isNotEmpty
          ? Text(
              name.substring(0, 1).toUpperCase(),
              style: DwFonts.style(
                DwFonts.display,
                size * 0.42,
                700,
                height: 1,
              ).copyWith(color: c.text),
            )
          : Icon(
              _glyph(owner),
              size: size * 0.5,
              color: owner == UsageOwner.tethering
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
              width: size,
              height: size,
              gaplessPlayback: true,
            ),
          );
        },
      ),
    );
  }

  static IconData _glyph(UsageOwner owner) => switch (owner) {
    UsageOwner.app => Icons.apps,
    UsageOwner.system => Icons.memory,
    UsageOwner.removed => Icons.inventory_2_outlined,
    UsageOwner.tethering => Icons.wifi_tethering,
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
    this.height = 66,
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
                    const SizedBox(height: 8),
                    DwBar(fraction: barFraction, color: barColor),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 68),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatBytes(usage.bytes),
                      style: DwFonts.style(
                        DwFonts.display,
                        19,
                        700,
                        height: 1,
                        letterSpacing: -0.4,
                        tabular: true,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          secondaryLabel ?? formatShare(share),
                          style: t.bodySmall!.copyWith(color: c.textSecondary),
                        ),
                        if (v != null) ...[
                          const SizedBox(width: 8),
                          DwVariation(variation: v),
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

/// « ↑ 18 % » en orange (hausse) ou « ↓ 12 % » en vert (baisse), sans fond :
/// la flèche porte le sens, la couleur n'est jamais seule.
class DwVariation extends StatelessWidget {
  const DwVariation({
    super.key,
    required this.variation,
    this.large = false,
    this.onDark = false,
  });

  final double variation;
  final bool large;

  /// Sur la carte sombre : teintes claires.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final up = variation > 0;
    final color = onDark
        ? (up ? const Color(0xFFFFB27A) : DwColors.tankOk)
        : (up ? c.warningText : c.positiveText);
    return Text(
      formatVariation(variation),
      style: DwFonts.style(
        DwFonts.body,
        large ? 13 : 12.5,
        600,
        tabular: true,
      ).copyWith(color: color),
    );
  }
}
