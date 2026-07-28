import 'package:flutter/material.dart';

class CohortColors {
  CohortColors._();

  static const Color background = Color(0xFF030403);
  static const Color surface = Color(0xFF0A0D0B);
  static const Color surfaceRaised = Color(0xFF101412);
  static const Color surfacePremium = Color(0xFF121815);

  static const Color border = Color(0xFF1E2521);
  static const Color borderStrong = Color(0xFF2A332D);
  static const Color borderAccent = Color(0xFF354038);

  /// Thin top-edge catch light (phosphor-tinted, not white).
  static const Color edgeHighlight = Color(0xFF8A9678);

  static const Color textPrimary = Color(0xFFECEEEA);
  static const Color textSecondary = Color(0xFF939C94);
  static const Color textMuted = Color(0xFF5A635C);

  /// Labels, section caps, secondary accents — calm olive.
  static const Color olive = Color(0xFF738864);

  /// Premium phosphor green — primary emissive (luxury dashboard).
  static const Color phosphor = Color(0xFF96A872);
  static const Color phosphorHighlight = Color(0xFFA8B584);
  static const Color phosphorDeep = Color(0xFF7A8B62);
  static const Color phosphorMuted = Color(0xFF5E6D4F);

  /// Back-compat aliases (same phosphor family, not lime).
  static const Color accent = phosphor;
  static const Color accentDeep = phosphorDeep;

  static const Color oliveDark = Color(0xFF222A20);
  static const Color oliveSoft = Color(0xFF141A16);

  static const Color warning = Color(0xFFB8843A);
  static const Color danger = Color(0xFFA85646);
  static const Color success = Color(0xFF667A58);
}
