import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Scoped to the local coach builder. The production dark theme is unchanged.
/// Every foreground belongs to a surface role; the dark toolbar keeps its own
/// light foreground instead of inheriting a page-wide text override.
const builderInk = Color(0xff20291f);
const builderMuted = Color(0xff53604e);
const builderOutline = Color(0xff667260);
const builderGreen = Color(0xff40552b);
const builderWarning = Color(0xff704100);
const builderWarningSurface = Color(0xfffff3d6);

final ThemeData founderBuilderTheme = _theme();
ThemeData _theme() {
  const scheme = ColorScheme.light(
    primary: builderGreen,
    onPrimary: Colors.white,
    primaryContainer: Color(0xffe4ecd9),
    onPrimaryContainer: Color(0xff243318),
    secondary: builderGreen,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xffe4ecd9),
    onSecondaryContainer: builderInk,
    surface: Colors.white,
    onSurface: builderInk,
    surfaceContainerLow: Color(0xfff4f6f0),
    surfaceContainer: Color(0xffedf0e8),
    surfaceContainerHigh: Color(0xffe4e9de),
    surfaceContainerHighest: Color(0xffe4e9de),
    onSurfaceVariant: builderMuted,
    outline: builderOutline,
    outlineVariant: builderOutline,
    error: Color(0xffa12220),
    onError: Colors.white,
    errorContainer: Color(0xffffe9e5),
    onErrorContainer: Color(0xff701b18),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surfaceContainerLow,
    textTheme: base.textTheme.apply(
      bodyColor: builderInk,
      displayColor: builderInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CohortColors.surfaceRaised,
      foregroundColor: CohortColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      actionsIconTheme: IconThemeData(color: CohortColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: builderOutline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      labelStyle: const TextStyle(color: builderMuted),
      floatingLabelStyle: const TextStyle(color: builderGreen),
      hintStyle: const TextStyle(color: builderMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: builderOutline),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: builderGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? scheme.surfaceContainerHigh
              : builderGreen,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? builderMuted : Colors.white,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? builderMuted : builderGreen,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(builderGreen),
        side: const WidgetStatePropertyAll(BorderSide(color: builderOutline)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      labelStyle: const TextStyle(color: builderInk),
      side: const BorderSide(color: builderOutline),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : builderMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? builderGreen
            : scheme.surfaceContainer,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(builderOutline),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? builderGreen : Colors.white,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: builderOutline, width: 2),
    ),
    dividerColor: builderOutline,
  );
}
