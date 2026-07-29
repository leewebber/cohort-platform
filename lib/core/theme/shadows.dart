import 'package:flutter/material.dart';

import 'cohort_lighting.dart';

class CohortShadows {
  CohortShadows._();

  static List<BoxShadow> get cardElevated => CohortLighting.depthLift();

  static List<BoxShadow> get accentGlow =>
      CohortLighting.emissive(opacity: 0.08, blurRadius: 16);

  static List<BoxShadow> get navBar => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.5),
      blurRadius: 12,
      spreadRadius: -2,
      offset: const Offset(0, -3),
    ),
  ];
}
