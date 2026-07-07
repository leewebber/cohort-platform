import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';

class CohortCard extends StatelessWidget {
  const CohortCard({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.lg),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: CohortRadius.largeRadius,
        border: Border.all(
          color: CohortColors.border,
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: CohortRadius.largeRadius,
      child: card,
    );
  }
}