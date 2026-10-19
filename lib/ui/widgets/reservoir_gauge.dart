import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// La jauge « réservoir » : le remplissage montre ce qui reste du forfait,
/// les pointillés marquent les seuils d'utilisation.
class ReservoirGauge extends StatelessWidget {
  const ReservoirGauge({
    super.key,
    required this.remainingFraction,
    required this.fillColor,
    this.width = 88,
    this.height = 184,
    this.markers = const [50, 80],
  });

  final double remainingFraction;
  final Color fillColor;
  final double width;
  final double height;

  /// Seuils d'utilisation, en pourcentage, dessinés en pointillés.
  final List<int> markers;

  @override
  Widget build(BuildContext context) {
    final c = context.dw;
    final used = ((1 - remainingFraction) * 100).round();
    return Semantics(
      label: 'Réservoir du forfait : $used % utilisés',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: remainingFraction.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => CustomPaint(
            size: Size(width, height),
            painter: _ReservoirPainter(
              fraction: value,
              fill: fillColor,
              tank: c.tank,
              border: c.tankBorder,
              markers: markers,
              labelStyle: DwFonts.style(DwFonts.mono, 11, 500),
              covered: c.onAccent,
              uncovered: const Color(0xFF8C95A5),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReservoirPainter extends CustomPainter {
  _ReservoirPainter({
    required this.fraction,
    required this.fill,
    required this.tank,
    required this.border,
    required this.markers,
    required this.labelStyle,
    required this.covered,
    required this.uncovered,
  });

  final double fraction;
  final Color fill;
  final Color tank;
  final Color border;
  final List<int> markers;
  final TextStyle labelStyle;
  final Color covered;
  final Color uncovered;

  static const _radius = Radius.circular(24);
  static const _inset = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(Offset.zero & size, _radius);
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRRect(shape, Paint()..color = tank);

    final fillHeight = size.height * fraction;
    if (fillHeight > 0) {
      final fillRect = Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight);
      canvas.drawRect(fillRect, Paint()..color = fill);

      // Hachures discrètes : la texture distingue le « liquide » du fond.
      final hatch = Paint()
        ..color = const Color(0x120F1218)
        ..strokeWidth = 2;
      canvas.save();
      canvas.clipRect(fillRect);
      for (var x = -size.height; x < size.width + size.height; x += 9) {
        canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
      }
      canvas.restore();

      canvas.drawRect(
        Rect.fromLTWH(0, size.height - fillHeight, size.width, 2),
        Paint()..color = const Color(0x8CFFFFFF),
      );
    }

    for (final m in markers) {
      final y = size.height * m / 100;
      final isCovered = fillHeight > size.height - y + 6;
      final lineColor = isCovered ? const Color(0x590F1218) : const Color(0x38FFFFFF);
      _dashedLine(canvas, Offset(_inset, y), size.width - 2 * _inset, lineColor);

      final label = TextPainter(
        text: TextSpan(
          text: '$m$nbsp%',
          style: labelStyle.copyWith(color: isCovered ? covered : uncovered),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(size.width - _inset - label.width, y - 4 - label.height));
    }
    canvas.restore();

    canvas.drawRRect(
      shape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  void _dashedLine(Canvas canvas, Offset from, double length, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 4.0;
    const gap = 3.0;
    for (var x = 0.0; x < length; x += dash + gap) {
      canvas.drawLine(from.translate(x, 0), from.translate((x + dash).clamp(0, length), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_ReservoirPainter old) =>
      old.fraction != fraction || old.fill != fill || old.tank != tank || old.covered != covered;
}
