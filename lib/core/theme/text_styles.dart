import 'package:flutter/material.dart';

import 'colors.dart';

class CohortTextStyles {
  CohortTextStyles._();

  static const TextStyle eyebrow = TextStyle(
    color: CohortColors.olive,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
  );

  static const TextStyle h1 = TextStyle(
    color: CohortColors.textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );

  static const TextStyle h2 = TextStyle(
    color: CohortColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  static const TextStyle cardTitle = TextStyle(
    color: CohortColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle body = TextStyle(
    color: CohortColors.textSecondary,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle small = TextStyle(
    color: CohortColors.textSecondary,
    fontSize: 13,
    height: 1.35,
  );

  static const TextStyle muted = TextStyle(
    color: CohortColors.textMuted,
    fontSize: 12,
    height: 1.3,
  );

  static const TextStyle button = TextStyle(
    color: CohortColors.background,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );
}