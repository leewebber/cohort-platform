import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';

class IncompleteSessionRecoveryActions extends StatelessWidget {
  const IncompleteSessionRecoveryActions({
    super.key,
    required this.scheduledDate,
    required this.onTrainToday,
    this.onBackfill,
    this.onReschedule,
    this.busy = false,
  });

  final DateTime scheduledDate;
  final VoidCallback? onTrainToday;
  final VoidCallback? onBackfill;
  final VoidCallback? onReschedule;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final date = AthleteProgrammeDateFormatter.weekdayDayMonth(scheduledDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onTrainToday != null) ...[
          Semantics(
            button: true,
            label:
                '${IncompleteSessionAthleteCopy.trainToday}. Opens the original $date session in the workout player.',
            child: CohortButton(
              key: const ValueKey('incomplete-train-today'),
              label: IncompleteSessionAthleteCopy.trainToday,
              onPressed: busy ? null : onTrainToday,
            ),
          ),
          const SizedBox(height: CohortSpacing.sm),
        ],
        if (onBackfill != null) ...[
          Semantics(
            button: true,
            label:
                '${IncompleteSessionAthleteCopy.backfillResults}. Enter results for this session if you already completed it.',
            child: CohortButton(
              key: const ValueKey('incomplete-backfill-results'),
              label: IncompleteSessionAthleteCopy.backfillResults,
              variant: CohortButtonVariant.secondary,
              onPressed: busy ? null : onBackfill,
            ),
          ),
          const SizedBox(height: CohortSpacing.sm),
        ],
        if (onReschedule != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('incomplete-reschedule'),
              onPressed: busy ? null : onReschedule,
              child: Text(
                IncompleteSessionAthleteCopy.reschedule,
                style: CohortTextStyles.body,
              ),
            ),
          ),
      ],
    );
  }
}
