import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../programme_migration/models/programme_migration_plan_models.dart';
import '../../intelligence/programme_intelligence_copy.dart';
import '../../models/programme_intelligence_view_state.dart';
import 'migration_assignment_tile.dart';
import 'migration_summary_row.dart';

class ProgrammeMigrationCard extends StatelessWidget {
  const ProgrammeMigrationCard({
    super.key,
    required this.status,
    required this.plan,
    required this.isPartial,
    this.errorMessage,
    required this.hasComparisonTarget,
    required this.onRetry,
  });

  final ProgrammeIntelligenceCardStatus status;
  final ProgrammeMigrationPlan? plan;
  final bool isPartial;
  final String? errorMessage;
  final bool hasComparisonTarget;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasComparisonTarget)
          Text(
            ProgrammeIntelligenceCopy.selectComparisonPrompt,
            style: CohortTextStyles.body.copyWith(color: CohortColors.textSecondary),
          )
        else if (status == ProgrammeIntelligenceCardStatus.loading)
          const Center(child: CircularProgressIndicator())
        else if (status == ProgrammeIntelligenceCardStatus.error)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorMessage ?? ProgrammeIntelligenceCopy.migrationUnavailableMessage,
                style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          )
        else if (plan == null)
          Text(
            ProgrammeIntelligenceCopy.migrationUnavailableMessage,
            style: CohortTextStyles.body.copyWith(color: CohortColors.textSecondary),
          )
        else
          _MigrationBody(plan: plan!, isPartial: isPartial),
      ],
    );
  }
}

class _MigrationBody extends StatefulWidget {
  const _MigrationBody({
    required this.plan,
    required this.isPartial,
  });

  final ProgrammeMigrationPlan plan;
  final bool isPartial;

  @override
  State<_MigrationBody> createState() => _MigrationBodyState();
}

class _MigrationBodyState extends State<_MigrationBody> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.plan.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MigrationSummaryRow(
          label: 'Total assignments',
          count: summary.totalAssignments,
        ),
        MigrationSummaryRow(
          label: 'Safe immediately',
          count: summary.safeImmediate,
        ),
        MigrationSummaryRow(
          label: 'Safe after session',
          count: summary.safeAfterCurrentSession,
        ),
        MigrationSummaryRow(
          label: 'Safe after week',
          count: summary.safeAfterCurrentWeek,
        ),
        MigrationSummaryRow(
          label: 'Manual review',
          count: summary.manualReview,
        ),
        MigrationSummaryRow(
          label: 'Already completed',
          count: summary.completed,
        ),
        MigrationSummaryRow(label: 'Unknown', count: summary.unknown),
        if (widget.isPartial)
          Padding(
            padding: const EdgeInsets.only(top: CohortSpacing.sm),
            child: Text(
              'Migration plan is partial.',
              style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
            ),
          ),
        if (widget.plan.assignmentPlans.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.sm),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Hide assignments' : 'Show assignments'),
          ),
          if (_expanded)
            for (var i = 0; i < widget.plan.assignmentPlans.length; i++)
              MigrationAssignmentTile(
                label: ProgrammeIntelligenceCopy.assignmentRowLabel(i),
                plan: widget.plan.assignmentPlans[i],
              ),
        ],
      ],
    );
  }
}
