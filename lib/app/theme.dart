import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

final ThemeData cohortTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: CohortColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: CohortColors.phosphor,
    brightness: Brightness.dark,
    surface: CohortColors.surface,
    primary: CohortColors.phosphor,
    secondary: CohortColors.olive,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CohortColors.background,
    foregroundColor: CohortColors.textPrimary,
    elevation: 0,
    centerTitle: false,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: CohortColors.surfaceRaised,
    indicatorColor: CohortColors.oliveSoft,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: selected ? CohortColors.phosphor : CohortColors.textMuted,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected ? CohortColors.phosphor : CohortColors.textMuted,
        size: 22,
      );
    }),
  ),
  useMaterial3: true,
);
