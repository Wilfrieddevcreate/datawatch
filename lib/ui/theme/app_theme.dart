import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? DwColors.light : DwColors.dark;
  final text = dwTextTheme(c.text);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.strong,
    onPrimary: c.onStrong,
    secondary: c.accent,
    onSecondary: c.onAccent,
    tertiary: c.wifi,
    onTertiary: Colors.white,
    error: c.critical,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerHighest: c.track,
    outline: c.textSecondary,
    outlineVariant: c.divider,
  );

  RoundedRectangleBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: DwFonts.body,
    textTheme: text,
    extensions: [c],
    splashColor: c.text.withValues(alpha: 0.06),
    highlightColor: c.text.withValues(alpha: 0.04),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.strong,
        foregroundColor: c.onStrong,
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: rounded(DwRadius.md),
        textStyle: text.labelLarge!.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: c.strong, width: 1.5),
        shape: rounded(DwRadius.md),
        textStyle: text.labelLarge!.copyWith(fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(48, 44),
        shape: rounded(DwRadius.sm),
        textStyle: text.labelLarge!.copyWith(fontSize: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.text,
        shape: rounded(DwRadius.sm),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.strong : c.track,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.strong,
      inactiveTrackColor: c.track,
      thumbColor: c.accent,
      overlayColor: c.accent.withValues(alpha: 0.18),
      valueIndicatorColor: c.strong,
      valueIndicatorTextStyle: text.labelMedium!.copyWith(color: c.onStrong),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DwRadius.sm),
        borderSide: BorderSide(color: c.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DwRadius.sm),
        borderSide: BorderSide(color: c.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DwRadius.sm),
        borderSide: BorderSide(color: c.strong, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(DwRadius.lg + 4),
      titleTextStyle: text.headlineSmall!.copyWith(fontSize: 26),
      contentTextStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(DwRadius.lg + 4),
      headerHeadlineStyle: text.headlineSmall,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: c.surface,
      shape: rounded(DwRadius.lg + 4),
      hourMinuteShape: rounded(DwRadius.sm),
      dayPeriodShape: rounded(DwRadius.sm),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.strong,
      contentTextStyle: text.bodyLarge!.copyWith(color: c.onStrong),
      shape: rounded(DwRadius.md),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.text),
  );
}
