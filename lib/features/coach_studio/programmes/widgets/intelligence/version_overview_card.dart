import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/cohort_card.dart';
import '../../../../../core/widgets/section_title.dart';
import '../../../governance/widgets/governance_count_row.dart';
import '../../../../programme_impact/models/programme_version_impact_models.dart';
import '../../intelligence/programme_intelligence_copy.dart';
import 'programme_lifecycle_badge.dart';

class VersionOverviewCard extends StatelessWidget {
  const VersionOverviewCard({
    super.key,
    required this.summary,
  });

  final ProgrammeVersionImpactSummary summary;

  @override
  Widget build(BuildContext context) {
    final lineage = summary.lineageContext;

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Version overview'),
          const SizedBox(height: CohortSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(summary.programmeName, style: CohortTextStyles.cardTitle),
              ),
              ProgrammeLifecycleBadge(lifecycleStatus: summary.lifecycleStatus),
            ],
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            ProgrammeIntelligenceCopy.versionLabel(summary.versionNumber),
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.md),
          if (lineage.latestPublishedVersionNumber != null)
            GovernanceCountRow(
              label:
                  'Latest published: Version ${lineage.latestPublishedVersionNumber}',
            ),
          GovernanceCountRow(
            label: lineage.hasNewerVersion
                ? 'A newer version exists in this lineage.'
                : 'This is the newest version in the lineage.',
          ),
          if (summary.summaryMessages.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            for (final message in summary.summaryMessages.take(2))
              GovernanceCountRow(label: message),
          ],
        ],
      ),
    );
  }
}
