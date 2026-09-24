import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';

/// Concluding Home card after the assignment itself is complete.
class AthleteHomeCompletedProgrammeCard extends StatelessWidget {
  const AthleteHomeCompletedProgrammeCard({
    super.key,
    required this.programmeTitle,
    required this.onViewResults,
    required this.onBrowseProgrammes,
    this.supportingLine,
  });

  final String programmeTitle;
  final VoidCallback onViewResults;
  final VoidCallback onBrowseProgrammes;
  final String? supportingLine;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Complete. You finished $programmeTitle.',
      child: CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Status Complete',
              child: ExcludeSemantics(
                child: Text(
                  'Complete',
                  style: CohortTextStyles.statusActive.copyWith(
                    color: CohortColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: CohortSpacing.md),
            Text(
              'You finished $programmeTitle.',
              style: CohortTextStyles.h1,
            ),
            if (supportingLine != null && supportingLine!.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(supportingLine!, style: CohortTextStyles.body),
            ],
            const SizedBox(height: CohortSpacing.lg),
            CohortButton(
              key: const ValueKey('completed-programme-view-results'),
              label: 'View results',
              semanticLabel: 'View results. $programmeTitle. Status Complete',
              onPressed: onViewResults,
            ),
            const SizedBox(height: CohortSpacing.sm),
            CohortButton(
              key: const ValueKey('completed-programme-browse'),
              label: 'Browse programmes',
              semanticLabel: 'Browse programmes',
              variant: CohortButtonVariant.secondary,
              onPressed: onBrowseProgrammes,
            ),
          ],
        ),
      ),
    );
  }
}
