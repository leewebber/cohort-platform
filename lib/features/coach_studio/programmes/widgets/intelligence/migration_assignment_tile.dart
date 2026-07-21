import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../programme_migration/models/programme_migration_plan_models.dart';
import '../../intelligence/programme_intelligence_copy.dart';

class MigrationAssignmentTile extends StatelessWidget {
  const MigrationAssignmentTile({
    super.key,
    required this.label,
    required this.plan,
  });

  final String label;
  final AssignmentMigrationPlan plan;

  @override
  Widget build(BuildContext context) {
    final position = plan.currentProgrammePosition?.displayLabel ??
        'Week ${plan.currentWeek} · ${plan.currentDayKey} · '
            'Slot ${plan.currentSessionOrder}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: CohortSpacing.sm),
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: CohortColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: CohortTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                )),
              ),
              _ClassificationBadge(classification: plan.migrationClassification),
            ],
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text('Current position: $position', style: CohortTextStyles.small),
          if (plan.completionPercent != null)
            Text(
              'Completion: ${plan.completionPercent}%',
              style: CohortTextStyles.small,
            ),
          const SizedBox(height: CohortSpacing.xs),
          Text(plan.recommendation, style: CohortTextStyles.small),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            plan.reasoning,
            style: CohortTextStyles.small.copyWith(color: CohortColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ClassificationBadge extends StatelessWidget {
  const _ClassificationBadge({required this.classification});

  final MigrationClassification classification;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CohortColors.oliveSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: CohortColors.olive),
      ),
      child: Text(
        ProgrammeIntelligenceCopy.migrationClassificationLabel(classification),
        style: CohortTextStyles.small.copyWith(
          color: CohortColors.olive,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
