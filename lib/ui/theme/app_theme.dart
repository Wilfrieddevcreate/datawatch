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

  final pill = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(DwRadius.pill),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: DwFonts.body,
    textTheme: text,
    extensions: [c],
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.headlineSmall,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.accent,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium!
            .weight(states.contains(WidgetState.selected) ? 600 : 500)
            .copyWith(
              color: states.contains(WidgetState.selected)
                  ? c.text
                  : c.textSecondary,
            ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? c.onAccent
              : c.textSecondary,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.strong,
        foregroundColor: c.onStrong,
        minimumSize: const Size(64, 56),
        shape: pill,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: c.strong, width: 1.5),
        shape: pill,
        textStyle: text.labelLarge!.copyWith(fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.text,
        minimumSize: const Size(48, 44),
        shape: pill,
        textStyle: text.labelLarge!.copyWith(fontSize: 14),
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DwRadius.md),
        borderSide: BorderSide(color: c.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DwRadius.md),
        borderSide: BorderSide(color: c.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DwRadius.md),
        borderSide: BorderSide(color: c.wifi, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.strong,
      contentTextStyle: text.bodyLarge!.copyWith(color: c.onStrong),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DwRadius.md),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.text),
  );
}
