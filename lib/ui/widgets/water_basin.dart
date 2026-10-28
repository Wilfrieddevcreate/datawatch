import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// La cuve : une bande pleine largeur dont le niveau est ce qui reste du
/// forfait. Le niveau monte à l'apparition, suit les changements de mesure et
/// ondule en continu ; les seuils sont des traits dans l'eau.
class WaterBasin extends StatefulWidget {
  const WaterBasin({
    super.key,
    required this.remainingFraction,
    this.fillColor,
    this.thresholds = const [50, 80],
    this.height = 104,
    this.basinColor,
    this.borderColor,
    this.riseDuration = const Duration(milliseconds: 1400),
  });

  /// Part restante du forfait (0–1).
  final double remainingFraction;

  /// Couleur de l'eau (lime par défaut, orange ou rouge en alerte).
  final Color? fillColor;

  /// Seuils d'utilisation, en pourcentage, tracés dans la cuve.
  final List<int> thresholds;
  final double height;
  final Color? basinColor;
  final Color? borderColor;
  final Duration riseDuration;

  @override
  State<WaterBasin> createState() => _WaterBasinState();
}

class _WaterBasinState extends State<WaterBasin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DwMotion.on(context)) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void didUpdateWidget(WaterBasin old) {
    super.didUpdateWidget(old);
    // La couleur de l'eau change au franchissement d'un seuil : une
    // vibration brève l'accompagne.
    if (old.fillColor != widget.fillColor && old.fillColor != null) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final target = widget.remainingFraction.clamp(0.0, 1.0);
    final motion = DwMotion.on(context);
    final used = ((1 - target) * 100).round();

    Widget paint(double level) => AnimatedBuilder(
      animation: _wave,
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _BasinPainter(
          level: level,
          phase: _wave.value,
          fill: widget.fillColor ?? c.accent,
          basin: widget.basinColor ?? c.tank,
          border: widget.borderColor ?? c.tankBorder,
          thresholds: widget.thresholds,
          labelStyle: DwFonts.style(DwFonts.body, 11, 600, tabular: true),
          covered: c.onAccent,
          uncovered: const Color(0xFF8C95A5),
        ),
      ),
    );

    return Semantics(
      label: 'Réservoir du forfait : $used$nbsp% utilisés',
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: motion
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: target),
                  duration: widget.riseDuration,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => paint(value),
                )
              : paint(target),
        ),
      ),
    );
  }
}

class _BasinPainter extends CustomPainter {
  _BasinPainter({
    required this.level,
    required this.phase,
    required this.fill,
    required this.basin,
    required this.border,
    required this.thresholds,
    required this.labelStyle,
    required this.covered,
    required this.uncovered,
  });

  final double level;
  final double phase;
  final Color fill;
  final Color basin;
  final Color border;
  final List<int> thresholds;
  final TextStyle labelStyle;
  final Color covered;
  final Color uncovered;

  static const _amplitude = 2.5;
  static const _wavelength = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = basin);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, 1),
      Paint()..color = border,
    );

    final waterH = h * level;
    final y0 = h - waterH;
    if (waterH > 0) {
      // Surface ondulée : une sinusoïde qui défile avec la phase.
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 3) {
        final y =
            y0 + math.sin(2 * math.pi * (x / _wavelength + phase)) * _amplitude;
        path.lineTo(x, math.min(h, y));
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = fill);

      // Hachures : la texture distingue le « liquide » du fond.
      canvas.save();
      canvas.clipPath(path);
      final hatch = Paint()
        ..color = const Color(0x120F1218)
        ..strokeWidth = 2;
      for (var x = -h; x < w + h; x += 9) {
        canvas.drawLine(Offset(x, h), Offset(x + h, 0), hatch);
      }
      canvas.restore();
    }

    for (final t in thresholds) {
      final ly = h * t / 100;
      final isCovered = y0 < ly - 3;
      final label = TextPainter(
        text: TextSpan(
          text: '$t$nbsp%',
          style: labelStyle.copyWith(color: isCovered ? covered : uncovered),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _dashedLine(
        canvas,
        Offset(20, ly),
        w - 64 - 20,
        isCovered ? const Color(0x590F1218) : const Color(0x38FFFFFF),
      );
      label.paint(canvas, Offset(w - 20 - label.width, ly - label.height / 2));
    }
  }

  void _dashedLine(Canvas canvas, Offset from, double length, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 4.0;
    const gap = 3.0;
    for (var x = 0.0; x < length; x += dash + gap) {
      canvas.drawLine(
        from.translate(x, 0),
        from.translate((x + dash).clamp(0, length), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BasinPainter old) =>
      old.level != level ||
      old.phase != phase ||
      old.fill != fill ||
      old.basin != basin ||
      old.thresholds != thresholds;
}
