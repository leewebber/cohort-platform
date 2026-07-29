import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';

/// Restrained emissive lighting — depth via light, not heavy shadows.
class CohortLighting {
  CohortLighting._();

  static List<BoxShadow> emissive({
    Color? color,
    double blurRadius = 14,
    double spreadRadius = -6,
    double opacity = 0.1,
    Offset offset = const Offset(0, 2),
  }) {
    final c = color ?? CohortColors.phosphor;
    return [
      BoxShadow(
        color: c.withValues(alpha: opacity),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        offset: offset,
      ),
    ];
  }

  static List<BoxShadow> depthLift({double opacity = 0.38}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 10,
        spreadRadius: -2,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static Border premiumBorder({bool subtle = false}) {
    return Border.all(
      color: CohortColors.edgeHighlight.withValues(alpha: subtle ? 0.22 : 0.32),
      width: 1,
    );
  }

  static Border standardBorder() {
    return Border.all(color: CohortColors.border, width: 1);
  }

  static Gradient panelFill({required bool premium}) {
    final base = premium
        ? CohortColors.surfacePremium
        : CohortColors.surfaceRaised;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          CohortColors.phosphor.withValues(alpha: premium ? 0.07 : 0.04),
          base,
        ),
        base,
        Color.alphaBlend(
          Colors.black.withValues(alpha: 0.35),
          CohortColors.surface,
        ),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  static Gradient radialAtmosphere({
    Alignment center = const Alignment(-0.6, -1.1),
  }) {
    return RadialGradient(
      center: center,
      radius: 1.35,
      colors: [
        CohortColors.phosphor.withValues(alpha: 0.055),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    );
  }

  static BoxDecoration elevatedPanel({required bool premium}) {
    return BoxDecoration(
      borderRadius: CohortRadius.largeRadius,
      gradient: panelFill(premium: premium),
      border: premium ? premiumBorder() : standardBorder(),
      boxShadow: [
        ...depthLift(opacity: premium ? 0.42 : 0.34),
        if (premium) ...emissive(opacity: 0.07, blurRadius: 18),
      ],
    );
  }

  static BoxDecoration insetPanel() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          CohortColors.background.withValues(alpha: 0.72),
          CohortColors.background.withValues(alpha: 0.88),
        ],
      ),
      border: Border.all(
        color: CohortColors.edgeHighlight.withValues(alpha: 0.18),
        width: 1,
      ),
      boxShadow: emissive(opacity: 0.04, blurRadius: 10, spreadRadius: -4),
    );
  }

  static BoxDecoration primaryButton() {
    return BoxDecoration(
      borderRadius: CohortRadius.mediumRadius,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          CohortColors.phosphorHighlight,
          CohortColors.phosphor,
          CohortColors.phosphorDeep,
        ],
        stops: [0.0, 0.52, 1.0],
      ),
      border: Border.all(
        color: CohortColors.edgeHighlight.withValues(alpha: 0.45),
        width: 1,
      ),
      boxShadow: [
        ...depthLift(opacity: 0.28),
        ...emissive(opacity: 0.12, blurRadius: 16, spreadRadius: -4),
      ],
    );
  }

  static BoxDecoration statusEmissiveDot() {
    return BoxDecoration(
      color: CohortColors.phosphor,
      shape: BoxShape.circle,
      boxShadow: emissive(opacity: 0.35, blurRadius: 5, spreadRadius: 0),
    );
  }

  static BoxDecoration navActiveHalo() {
    return BoxDecoration(
      color: CohortColors.phosphorMuted.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: CohortColors.edgeHighlight.withValues(alpha: 0.25),
        width: 1,
      ),
      boxShadow: emissive(opacity: 0.1, blurRadius: 10, spreadRadius: -3),
    );
  }
}
