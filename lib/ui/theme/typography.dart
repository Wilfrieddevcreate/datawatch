import 'package:flutter/material.dart';

/// Les trois familles embarquées sont des polices variables : le graisse doit
/// être passée à l'axe `wght`, sinon Flutter affiche la graisse par défaut.
abstract final class DwFonts {
  static const display = 'Bricolage';
  static const body = 'Geist';
  static const mono = 'GeistMono';

  static TextStyle style(
    String family,
    double size,
    int weight, {
    double? height,
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [
        FontVariation.weight(weight.toDouble()),
        if (family == display) FontVariation.opticalSize(size.clamp(12, 96).toDouble()),
      ],
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  static FontWeight _weight(int w) =>
      FontWeight.values[((w / 100).round() - 1).clamp(0, FontWeight.values.length - 1)];

  /// Gros chiffre de la carte forfait.
  static TextStyle hero(double size) =>
      style(display, size, 700, height: 0.92, letterSpacing: -0.045 * size, tabular: true);

  /// Libellé technique en capitales : « RESTANT ESTIMÉ ».
  static TextStyle overline(Color color) =>
      style(mono, 11.5, 500, letterSpacing: 0.9).copyWith(color: color);
}

extension DwTextStyle on TextStyle {
  /// Change la graisse en gardant l'axe variable synchronisé.
  TextStyle weight(int w) => copyWith(
        fontWeight: DwFonts._weight(w),
        fontVariations: [
          ...?fontVariations?.where((v) => v.axis != 'wght'),
          FontVariation.weight(w.toDouble()),
        ],
      );
}

TextTheme dwTextTheme(Color text) {
  final t = TextTheme(
    displayLarge: DwFonts.hero(72),
    displayMedium: DwFonts.hero(60),
    headlineMedium: DwFonts.style(DwFonts.display, 32, 700, height: 1.1, letterSpacing: -1.1),
    headlineSmall: DwFonts.style(DwFonts.display, 26, 700, height: 1.1, letterSpacing: -0.8),
    titleLarge: DwFonts.style(DwFonts.display, 21, 650, height: 1.2, letterSpacing: -0.4),
    titleMedium: DwFonts.style(DwFonts.body, 15, 600, height: 1.3),
    titleSmall: DwFonts.style(DwFonts.body, 14, 600, height: 1.3),
    bodyLarge: DwFonts.style(DwFonts.body, 15, 400, height: 1.45),
    bodyMedium: DwFonts.style(DwFonts.body, 13.5, 400, height: 1.4),
    bodySmall: DwFonts.style(DwFonts.body, 12.5, 400, height: 1.4),
    labelLarge: DwFonts.style(DwFonts.body, 15, 600),
    labelMedium: DwFonts.style(DwFonts.body, 12, 500),
    labelSmall: DwFonts.style(DwFonts.mono, 11.5, 500, letterSpacing: 0.9),
  );
  return t.apply(bodyColor: text, displayColor: text);
}
