import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../programme_impact/models/programme_version_impact_models.dart';
import '../../../governance/widgets/governance_count_row.dart';

Future<void> showImpactDetailSheet({
  required BuildContext context,
  required ProgrammeVersionImpactSummary summary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Impact details', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.md),
            Text('Active assignments', style: CohortTextStyles.cardTitle),
            const SizedBox(height: CohortSpacing.xs),
            if (summary.activeAssignments.isEmpty)
              const Text('No active assignments.')
            else
              for (final assignment in summary.activeAssignments)
                GovernanceCountRow(
                  label: assignment.progressSummary ??
                      'Active assignment on this version',
                ),
            const SizedBox(height: CohortSpacing.lg),
            Text('Session references', style: CohortTextStyles.cardTitle),
            const SizedBox(height: CohortSpacing.xs),
            for (final reference in summary.sessionReferences.take(20))
              GovernanceCountRow(
                label: 'Week ${reference.weekNumber} · ${reference.dayKey} · '
                    '${reference.sessionName} (Rev ${reference.sessionRevisionNumber})',
              ),
            const SizedBox(height: CohortSpacing.lg),
            Text('Exercises', style: CohortTextStyles.cardTitle),
            const SizedBox(height: CohortSpacing.xs),
            for (final exercise in summary.exerciseReferences.take(20))
              GovernanceCountRow(label: exercise.exerciseName),
          ],
        ),
      );
    },
  );
}
