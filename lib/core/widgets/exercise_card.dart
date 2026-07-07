import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_card.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
  });

  final Exercise exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.movementPattern ?? 'Exercise',
                  style: CohortTextStyles.eyebrow,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  exercise.name,
                  style: CohortTextStyles.cardTitle,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  [
                    exercise.equipment,
                    exercise.bodyRegion,
                    exercise.technicalComplexity,
                  ]
                      .where(
                        (value) =>
                            value != null && value.trim().isNotEmpty,
                      )
                      .join(' • '),
                  style: CohortTextStyles.small,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  exercise.primaryCapability ?? '',
                  style: const TextStyle(
                    color: CohortColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: CohortColors.textMuted,
          ),
        ],
      ),
    );
  }
}