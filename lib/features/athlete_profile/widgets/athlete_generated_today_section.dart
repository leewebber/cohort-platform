import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';

/// Established no-programme Home entry — opens the canonical programme catalogue.
///
/// Historical filename retained (`athlete_generated_today_section.dart`). The
/// legacy generated-plan Today widget was deleted in Phase 2.10.
class ChoosePlanEntryCard extends StatelessWidget {
  const ChoosePlanEntryCard({super.key, required this.onChoosePlan});

  final VoidCallback onChoosePlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.xl),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CohortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S TRAINING", style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.lg),
          Text('Choose a programme', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Enrol in a Cohort catalogue programme to start training.',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(
            label: 'VIEW PROGRAMMES',
            showTrailingArrow: true,
            onPressed: onChoosePlan,
          ),
        ],
      ),
    );
  }
}
