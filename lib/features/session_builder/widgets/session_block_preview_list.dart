import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../models/session_block_type.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/widgets/strength_prescription_display.dart';

class SessionBlockPreviewList extends StatelessWidget {
  const SessionBlockPreviewList({
    super.key,
    required this.plan,
  });

  final SessionExecutionPlan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.blocks.isEmpty) {
      return const Text(
        'No blocks to preview.',
        style: CohortTextStyles.body,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < plan.blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: CohortSpacing.lg),
          _BlockPreviewCard(block: plan.blocks[index]),
        ],
      ],
    );
  }
}

class _BlockPreviewCard extends StatelessWidget {
  const _BlockPreviewCard({required this.block});

  final SessionExecutionBlock block;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(block.title, style: CohortTextStyles.cardTitle),
              ),
              if (block.workoutFormatLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CohortSpacing.sm,
                    vertical: CohortSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: CohortColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    block.workoutFormatLabel!,
                    style: CohortTextStyles.small,
                  ),
                ),
            ],
          ),
          Text(
            block.blockTypeLabel,
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textSecondary,
            ),
          ),
          if (block.content.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(
              block.blockType.supportsStructuredStrengthPrescription
                  ? block.content.trim()
                  : block.content,
              style: CohortTextStyles.body,
            ),
          ],
          if (block.timerSummary != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              block.timerSummary!,
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textSecondary,
              ),
            ),
          ],
          if (block.linkedExercises.any(
            (exercise) => exercise.prescription?.hasStructuredData == true,
          )) ...[
            const SizedBox(height: CohortSpacing.md),
            StrengthPrescriptionList(exercises: block.linkedExercises),
          ] else if (block.linkedExercises.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            Text('Linked exercises', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.xs),
            for (final exercise in block.linkedExercises)
              Padding(
                padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                child: Text(exercise.displayName, style: CohortTextStyles.body),
              ),
          ],
          if (block.coachNotes != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Text('Coach notes', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.xs),
            Text(block.coachNotes!, style: CohortTextStyles.body),
          ],
        ],
      ),
    );
  }
}
