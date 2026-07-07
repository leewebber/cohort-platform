import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

final ThemeData cohortTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: CohortColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: CohortColors.olive,
    brightness: Brightness.dark,
    surface: CohortColors.surface,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CohortColors.background,
    foregroundColor: CohortColors.textPrimary,
    elevation: 0,
    centerTitle: false,
  ),
  useMaterial3: true,
);