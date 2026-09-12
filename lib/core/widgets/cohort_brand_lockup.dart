import 'package:flutter/material.dart';

import '../theme/cohort_lighting.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Compact Cohort mark + wordmark used on authenticated primary screens.
///
/// The repository has no separate logo image asset. This is the established
/// in-app lockup: phosphor geometric mark and white `COHORT` wordmark.
class CohortBrandLockup extends StatelessWidget {
  const CohortBrandLockup({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 36.0;
    return Semantics(
      label: 'Cohort',
      header: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('cohort-brand-mark'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: CohortColors.oliveSoft,
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
              border: Border.all(
                color: CohortColors.edgeHighlight.withValues(alpha: 0.28),
              ),
              boxShadow: CohortLighting.emissive(opacity: 0.06, blurRadius: 10),
            ),
            child: Icon(
              Icons.hexagon_outlined,
              color: CohortColors.phosphor,
              size: compact ? 16 : 22,
              shadows: [
                Shadow(
                  color: CohortColors.phosphor.withValues(alpha: 0.4),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? CohortSpacing.sm : CohortSpacing.md),
          Text(
            'COHORT',
            style: CohortTextStyles.h2.copyWith(
              letterSpacing: 2,
              fontSize: compact ? 15 : 18,
              color: CohortColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
