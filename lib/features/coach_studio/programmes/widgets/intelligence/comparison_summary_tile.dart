import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../intelligence/programme_intelligence_copy.dart';

class ComparisonSummaryTile extends StatelessWidget {
  const ComparisonSummaryTile({
    super.key,
    required this.summary,
    required this.isPartial,
  });

  final ProgrammeVersionComparisonSummary summary;
  final bool isPartial;

  @override
  Widget build(BuildContext context) {
    final metrics = summary.structureMetrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version ${summary.identity.sourceVersionNumber} → '
          'Version ${summary.identity.targetVersionNumber}',
          style: CohortTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: CohortSpacing.xs),
        if (summary.isIdentical)
          Text('No differences found.', style: CohortTextStyles.small)
        else ...[
          Text(
            'Weeks ${metrics.sourceWeekCount} → ${metrics.targetWeekCount}',
            style: CohortTextStyles.small,
          ),
          Text(
            'Session slots ${metrics.sourceSlotCount} → ${metrics.targetSlotCount}',
            style: CohortTextStyles.small,
          ),
          Text(
            'Exercises ${metrics.sourceDistinctExerciseCount} → '
            '${metrics.targetDistinctExerciseCount}',
            style: CohortTextStyles.small,
          ),
        ],
        if (summary.summaryMessages.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.sm),
          for (final message in summary.summaryMessages.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
              child: Text(message, style: CohortTextStyles.small),
            ),
        ],
        if (isPartial)
          Padding(
            padding: const EdgeInsets.only(top: CohortSpacing.sm),
            child: Text(
              'Comparison is partial.',
              style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
            ),
          ),
      ],
    );
  }
}

String comparisonChangeSummary(ProgrammeChangeType type, int count) {
  if (count == 0) return '';
  final label = ProgrammeIntelligenceCopy.changeTypeLabel(type).toLowerCase();
  return '$count $label';
}
