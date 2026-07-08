import 'package:flutter/material.dart';

import '../../models/protocol_step.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_card.dart';

class ProtocolStepCard extends StatelessWidget {
  const ProtocolStepCard({
    super.key,
    required this.step,
  });

  final ProtocolStep step;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CohortColors.surfaceRaised,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              step.stepOrder.toString(),
              style: CohortTextStyles.cardTitle,
            ),
          ),

          const SizedBox(width: CohortSpacing.lg),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: CohortTextStyles.cardTitle,
                ),

                const SizedBox(height: CohortSpacing.xs),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (step.sets != null)
                      _MetadataChip('${step.sets} sets'),

                    if (step.reps != null)
                      _MetadataChip('${step.reps} reps'),

                    if (step.distance != null)
                      _MetadataChip(step.distance!),

                    if (step.duration != null)
                      _MetadataChip(step.duration!),

                    if (step.rest != null)
                      _MetadataChip('Rest ${step.rest}'),

                    if (step.load != null)
                      _MetadataChip(step.load!),
                  ],
                ),

                if (step.notes != null &&
                    step.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    step.notes!,
                    style: CohortTextStyles.small,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CohortSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: CohortTextStyles.small,
      ),
    );
  }
}