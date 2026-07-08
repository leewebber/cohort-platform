import 'package:flutter/material.dart';

import '../../models/session_step.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';

class SessionStepCard extends StatelessWidget {
  const SessionStepCard({
    super.key,
    required this.step,
    this.onComplete,
  });

  final SessionStep step;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP ${step.stepNumber}',
            style: CohortTextStyles.eyebrow,
          ),

          const SizedBox(height: CohortSpacing.lg),

          Text(
            step.title,
            style: CohortTextStyles.h2,
          ),

          if (step.prescription != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              step.prescription!,
              style: CohortTextStyles.body,
            ),
          ],

          if (step.coachCue != null) ...[
            const SizedBox(height: CohortSpacing.xl),
            Text(
              'Coach Cue',
              style: CohortTextStyles.eyebrow,
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              step.coachCue!,
              style: CohortTextStyles.body,
            ),
          ],

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
