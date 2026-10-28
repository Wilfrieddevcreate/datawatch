import 'package:flutter/material.dart';

/// Couleurs de la direction « Réservoir, en grand » (voir le canevas).
@immutable
class DwColors extends ThemeExtension<DwColors> {
  const DwColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.track,
    required this.divider,
    required this.text,
    required this.textSecondary,
    required this.strong,
    required this.onStrong,
    required this.accent,
    required this.onAccent,
    required this.wifi,
    required this.wifiSoft,
    required this.warning,
    required this.warningText,
    required this.warningSoft,
    required this.critical,
    required this.positiveText,
    required this.positiveSoft,
    required this.hero,
    required this.heroBorder,
    required this.tank,
    required this.tankBorder,
    required this.heroText,
    required this.heroTextSecondary,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color track;
  final Color divider;
  final Color text;
  final Color textSecondary;

  /// Fond des éléments sélectionnés (encre en clair, blanc en sombre).
  final Color strong;
  final Color onStrong;

  /// Lime : accent, réservoir, indicateur de navigation. Jamais de texte blanc dessus.
  final Color accent;
  final Color onAccent;

  /// Réservé au Wi-Fi et aux liens.
  final Color wifi;
  final Color wifiSoft;

  /// Réservés aux alertes.
  final Color warning;
  final Color warningText;
  final Color warningSoft;
  final Color critical;
  final Color positiveText;
  final Color positiveSoft;

  /// Carte « forfait » : toujours sombre, dans les deux thèmes.
  final Color hero;
  final Color heroBorder;
  final Color tank;
  final Color tankBorder;
  final Color heroText;
  final Color heroTextSecondary;

  static const light = DwColors(
    background: Color(0xFFEEF0F3),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF7F8FA),
    track: Color(0xFFE1E4E9),
    divider: Color(0xFFEEF0F3),
    text: Color(0xFF0F1218),
    textSecondary: Color(0xFF5A6170),
    strong: Color(0xFF0F1218),
    onStrong: Color(0xFFFFFFFF),
    accent: Color(0xFFC6F135),
    onAccent: Color(0xFF0F1218),
    wifi: Color(0xFF3B5BDB),
    wifiSoft: Color(0xFFE3E9FF),
    warning: Color(0xFFFF9F5A),
    warningText: Color(0xFFA33A00),
    warningSoft: Color(0xFFFFEBDD),
    critical: Color(0xFFB42318),
    positiveText: Color(0xFF3F5A0B),
    positiveSoft: Color(0xFFE6F4CC),
    hero: Color(0xFF10131A),
    heroBorder: Color(0xFF10131A),
    tank: Color(0xFF1C212B),
    tankBorder: Color(0xFF2A303C),
    heroText: Color(0xFFF2F4F7),
    heroTextSecondary: Color(0xFFA7AFBD),
  );

  static const dark = DwColors(
    background: Color(0xFF0B0D11),
    surface: Color(0xFF151922),
    surfaceMuted: Color(0xFF1E2330),
    track: Color(0xFF1E2330),
    divider: Color(0xFF262C38),
    text: Color(0xFFF2F4F7),
    textSecondary: Color(0xFF9AA3B2),
    strong: Color(0xFFF2F4F7),
    onStrong: Color(0xFF0F1218),
    accent: Color(0xFFC6F135),
    onAccent: Color(0xFF0F1218),
    wifi: Color(0xFF8DA2FF),
    wifiSoft: Color(0xFF232A4D),
    warning: Color(0xFFFF9F5A),
    warningText: Color(0xFFFFB27A),
    warningSoft: Color(0xFF3A2A20),
    critical: Color(0xFFFF8F8F),
    positiveText: Color(0xFFC2E58A),
    positiveSoft: Color(0xFF26331A),
    hero: Color(0xFF151922),
    heroBorder: Color(0xFF262C38),
    tank: Color(0xFF0B0D11),
    tankBorder: Color(0xFF262C38),
    heroText: Color(0xFFF2F4F7),
    heroTextSecondary: Color(0xFF9AA3B2),
  );

  /// Couleurs vives de la jauge, communes aux deux thèmes.
  static const tankOk = Color(0xFFC6F135);
  static const tankWarning = Color(0xFFFF9F5A);
  static const tankCritical = Color(0xFFFF6B6B);

  @override
  DwColors copyWith() => this;

  @override
  DwColors lerp(DwColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension DwThemeContext on BuildContext {
  DwColors get dw => Theme.of(this).extension<DwColors>()!;
}

/// Angles : 6, 10, 14, 20, 28. Jamais de pilule.
abstract final class DwRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}
