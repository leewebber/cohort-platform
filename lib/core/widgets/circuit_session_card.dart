import 'package:flutter/material.dart';

import '../../models/session_step.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';

class CircuitSessionCard extends StatelessWidget {
  const CircuitSessionCard({
    super.key,
    required this.steps,
    required this.isTimerRunning,
    required this.onStartTimer,
    required this.onFinishSession,
  });

  final List<SessionStep> steps;
  final bool isTimerRunning;
  final VoidCallback onStartTimer;
  final VoidCallback onFinishSession;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CIRCUIT',
            style: CohortTextStyles.eyebrow,
          ),

          const SizedBox(height: CohortSpacing.lg),

          Text(
            '${steps.length} movements • Complete all, then rest',
            style: CohortTextStyles.body,
          ),

          const SizedBox(height: CohortSpacing.xl),

          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: CohortSpacing.lg),
            _CircuitStepRow(step: steps[i]),
          ],

          if (isTimerRunning) ...[
            const SizedBox(height: CohortSpacing.xl),
            Text(
              'Elapsed',
              style: CohortTextStyles.eyebrow,
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              '00:00',
              style: CohortTextStyles.h2,
            ),
          ],

          const SizedBox(height: CohortSpacing.xl),

          if (isTimerRunning)
            CohortButton(
              label: 'Finish Session',
              onPressed: onFinishSession,
            )
          else
            CohortButton(
              label: 'Start Timer',
              onPressed: onStartTimer,
            ),
        ],
      ),
    );
  }
}

class _CircuitStepRow extends StatelessWidget {
  const _CircuitStepRow({required this.step});

  final SessionStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.stepNumber.toString(),
          style: CohortTextStyles.cardTitle,
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
              Text(
                step.prescription,
                style: CohortTextStyles.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
