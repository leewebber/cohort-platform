import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';

class WorkoutProgressBar extends StatelessWidget {
  const WorkoutProgressBar({
    super.key,
    required this.progress,
    this.label,
  });

  final double progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: CohortTextStyles.small),
          const SizedBox(height: CohortSpacing.sm),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: CohortColors.surfaceRaised,
            color: CohortColors.phosphor,
          ),
        ),
      ],
    );
  }
}

class ExerciseVideoPlaceholder extends StatelessWidget {
  const ExerciseVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CohortColors.border),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 40,
            color: CohortColors.textMuted,
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Movement video coming soon',
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutMetaRow extends StatelessWidget {
  const WorkoutMetaRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.xs),
          Text(value, style: CohortTextStyles.body.copyWith(
            color: CohortColors.textPrimary,
            fontSize: 16,
            height: 1.4,
          )),
        ],
      ),
    );
  }
}
