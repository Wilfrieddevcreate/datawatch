import 'package:flutter/material.dart';

/// Deux familles variables : Bricolage Grotesque (chiffres en vedette et
/// titres, graisse 800 très serrée) et Geist (texte). La graisse doit être
/// passée à l'axe `wght`, sinon Flutter affiche la graisse par défaut.
abstract final class DwFonts {
  static const display = 'Bricolage';
  static const body = 'Geist';

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
        if (family == display)
          FontVariation.opticalSize(size.clamp(12, 96).toDouble()),
      ],
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  static FontWeight _weight(int w) =>
      FontWeight.values[((w / 100).round() - 1).clamp(
        0,
        FontWeight.values.length - 1,
      )];

  /// Chiffre en vedette : « 1,38 ».
  static TextStyle hero(double size) => style(
    display,
    size,
    800,
    height: 0.88,
    letterSpacing: -0.05 * size,
    tabular: true,
  );

  /// Titre d'écran ou d'encadré.
  static TextStyle title(double size) =>
      style(display, size, 800, height: 1.0, letterSpacing: -0.045 * size);

  /// Titre de section, posé après le tiret lime.
  static TextStyle section(double size) =>
      style(display, size, 700, height: 1.1, letterSpacing: -0.025 * size);

  /// Petit libellé en minuscules : « Restant estimé ».
  static TextStyle label(Color color) =>
      style(body, 13, 600).copyWith(color: color);
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
    displayLarge: DwFonts.hero(92),
    displayMedium: DwFonts.hero(72),
    headlineMedium: DwFonts.title(36),
    headlineSmall: DwFonts.title(30),
    titleLarge: DwFonts.section(22),
    titleMedium: DwFonts.style(DwFonts.body, 15.5, 600, height: 1.3),
    titleSmall: DwFonts.style(DwFonts.body, 14, 600, height: 1.3),
    bodyLarge: DwFonts.style(DwFonts.body, 15, 400, height: 1.45),
    bodyMedium: DwFonts.style(DwFonts.body, 13.5, 400, height: 1.42),
    bodySmall: DwFonts.style(DwFonts.body, 12.5, 400, height: 1.4),
    labelLarge: DwFonts.style(DwFonts.body, 15, 600),
    labelMedium: DwFonts.style(DwFonts.body, 12, 500),
    labelSmall: DwFonts.style(DwFonts.body, 13, 600),
  );
  return t.apply(bodyColor: text, displayColor: text);
}
