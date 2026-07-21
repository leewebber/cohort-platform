import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/cohort_card.dart';
import '../../../../../core/widgets/section_title.dart';
import '../../../governance/widgets/governance_count_row.dart';
import '../../../../programme_impact/models/programme_version_impact_models.dart';
import '../../intelligence/programme_intelligence_copy.dart';
import '../../models/programme_intelligence_view_state.dart';
import 'impact_detail_sheet.dart';

class ProgrammeImpactCard extends StatelessWidget {
  const ProgrammeImpactCard({
    super.key,
    required this.status,
    required this.summary,
    this.errorMessage,
    required this.onRetry,
  });

  final ProgrammeIntelligenceCardStatus status;
  final ProgrammeVersionImpactSummary? summary;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Impact'),
          const SizedBox(height: CohortSpacing.sm),
          if (status == ProgrammeIntelligenceCardStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (status == ProgrammeIntelligenceCardStatus.error)
            _ErrorBody(
              message: errorMessage ?? ProgrammeIntelligenceCopy.impactUnavailableMessage,
              onRetry: onRetry,
            )
          else if (summary == null)
            Text(
              'Impact information is unavailable.',
              style: CohortTextStyles.body.copyWith(color: CohortColors.textSecondary),
            )
          else
            _ImpactBody(summary: summary!, onViewDetails: () {
              showImpactDetailSheet(context: context, summary: summary!);
            }),
        ],
      ),
    );
  }
}

class _ImpactBody extends StatelessWidget {
  const _ImpactBody({
    required this.summary,
    required this.onViewDetails,
  });

  final ProgrammeVersionImpactSummary summary;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final historical = summary.historicalImpact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GovernanceCountRow(
          label: '${summary.activeAssignmentCount} active assignment'
              '${summary.activeAssignmentCount == 1 ? '' : 's'}',
        ),
        GovernanceCountRow(
          label: '${historical.terminalRecordCount} historical session'
              '${historical.terminalRecordCount == 1 ? '' : 's'}',
        ),
        GovernanceCountRow(
          label: '${historical.athleteCount} athlete'
              '${historical.athleteCount == 1 ? '' : 's'} (aggregate)',
        ),
        GovernanceCountRow(
          label: '${summary.distinctSessionRevisionCount} distinct session'
              '${summary.distinctSessionRevisionCount == 1 ? '' : 's'}',
        ),
        GovernanceCountRow(
          label: '${summary.distinctExerciseCount} distinct exercise'
              '${summary.distinctExerciseCount == 1 ? '' : 's'}',
        ),
        if (summary.summaryMessages.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.sm),
          for (final message in summary.summaryMessages.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
              child: Text(message, style: CohortTextStyles.small),
            ),
        ],
        if (summary.warnings.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            summary.warnings.first,
            style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
          ),
        ],
        const SizedBox(height: CohortSpacing.sm),
        TextButton(onPressed: onViewDetails, child: const Text('View details')),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
        ),
        const SizedBox(height: CohortSpacing.sm),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
