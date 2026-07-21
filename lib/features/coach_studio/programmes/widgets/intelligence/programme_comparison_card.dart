import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/cohort_card.dart';
import '../../../../../core/widgets/section_title.dart';
import '../../../../../models/programme_version.dart';
import '../../../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../intelligence/programme_intelligence_copy.dart';
import '../../models/programme_intelligence_view_state.dart';
import 'comparison_detail_sheet.dart';
import 'comparison_summary_tile.dart';
import 'version_comparison_picker.dart';

class ProgrammeComparisonCard extends StatelessWidget {
  const ProgrammeComparisonCard({
    super.key,
    required this.currentVersionId,
    required this.currentVersionNumber,
    required this.lineageVersions,
    required this.status,
    required this.summary,
    required this.isPartial,
    this.errorMessage,
    this.selectedTargetVersionId,
    required this.onTargetChanged,
    required this.onRetry,
  });

  final String currentVersionId;
  final int currentVersionNumber;
  final List<ProgrammeVersion> lineageVersions;
  final ProgrammeIntelligenceCardStatus status;
  final ProgrammeVersionComparisonSummary? summary;
  final bool isPartial;
  final String? errorMessage;
  final String? selectedTargetVersionId;
  final ValueChanged<String?> onTargetChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Comparison'),
          const SizedBox(height: CohortSpacing.sm),
          VersionComparisonPicker(
            currentVersionId: currentVersionId,
            currentVersionNumber: currentVersionNumber,
            versions: lineageVersions,
            selectedTargetVersionId: selectedTargetVersionId,
            onChanged: onTargetChanged,
          ),
          const SizedBox(height: CohortSpacing.md),
          if (selectedTargetVersionId == null)
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
                  errorMessage ?? ProgrammeIntelligenceCopy.comparisonUnavailableMessage,
                  style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          else if (summary != null) ...[
            ComparisonSummaryTile(summary: summary!, isPartial: isPartial),
            const SizedBox(height: CohortSpacing.sm),
            TextButton(
              onPressed: () => showComparisonDetailSheet(
                context: context,
                summary: summary!,
              ),
              child: const Text('View changes'),
            ),
          ],
        ],
      ),
    );
  }
}
