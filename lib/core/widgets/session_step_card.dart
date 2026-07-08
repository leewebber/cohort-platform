import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';

class SessionStepCard extends StatelessWidget {
  const SessionStepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.prescription,
    required this.coachCue,
    this.onComplete,
  });

  final int stepNumber;
  final String title;
  final String prescription;
  final String coachCue;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $stepNumber',
            style: CohortTextStyles.eyebrow,
          ),

          const SizedBox(height: CohortSpacing.lg),

          Text(
            title,
            style: CohortTextStyles.h2,
          ),

          const SizedBox(height: CohortSpacing.sm),

          Text(
            prescription,
            style: CohortTextStyles.body,
          ),

          const SizedBox(height: CohortSpacing.xl),

          Text(
            'Coach Cue',
            style: CohortTextStyles.eyebrow,
          ),

          const SizedBox(height: CohortSpacing.sm),

          Text(
            coachCue,
            style: CohortTextStyles.body,
          ),

          const SizedBox(height: CohortSpacing.xl),

          CohortButton(
            label: 'Complete Step',
            onPressed: onComplete ?? () {},
          ),
        ],
      ),
    );
  }
}