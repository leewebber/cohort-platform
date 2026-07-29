import 'package:flutter/material.dart';

import '../theme/cohort_lighting.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';

enum CohortCardVariant { standard, premium }

class CohortCard extends StatelessWidget {
  const CohortCard({
    super.key,
    required this.child,
    this.onTap,
    this.variant = CohortCardVariant.standard,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final CohortCardVariant variant;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isPremium = variant == CohortCardVariant.premium;
    final panel = CohortLighting.elevatedPanel(premium: isPremium);

    final borderRadius = CohortRadius.largeRadius;

    final card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(CohortSpacing.lg),
      decoration: panel,
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: CohortLighting.radialAtmosphere(),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(onTap: onTap, borderRadius: borderRadius, child: card);
  }
}
