import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/programme_review_models.dart';
import 'programme_studio_copy.dart';
import 'programme_studio_quality.dart';

class ProgrammeStudioQualityView extends StatelessWidget {
  const ProgrammeStudioQualityView({
    super.key,
    required this.programme,
    required this.onOpenIntegrity,
  });

  final ProgrammeReviewProgramme programme;
  final VoidCallback onOpenIntegrity;

  @override
  Widget build(BuildContext context) {
    final report = buildStudioQualityReport(programme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(report.summaryLine, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.lg),
        for (final group in report.groups) ...[
          Text(group.title, style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.sm),
          for (final item in group.items) _StatusRow(item: item),
          const SizedBox(height: CohortSpacing.lg),
        ],
        TextButton(
          onPressed: onOpenIntegrity,
          child: const Text(ProgrammeStudioCopy.viewEvidence),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.item});

  final StudioQualityItem item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.status) {
      StudioQualityStatus.passed => Icons.check_circle_outline,
      StudioQualityStatus.needsAttention => Icons.error_outline,
      StudioQualityStatus.notAssessed => Icons.hourglass_empty,
      StudioQualityStatus.notImplemented => Icons.do_not_disturb_on_outlined,
    };
    final color = switch (item.status) {
      StudioQualityStatus.passed => CohortColors.success,
      StudioQualityStatus.needsAttention => CohortColors.warning,
      StudioQualityStatus.notAssessed => CohortColors.textSecondary,
      StudioQualityStatus.notImplemented => CohortColors.textMuted,
    };
    final status = studioStatusLabel(item.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Semantics(
        label: '${item.label}: $status. ${item.detail}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: CohortSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.label} — $status', style: CohortTextStyles.body),
                  if (item.detail.isNotEmpty)
                    Text(item.detail, style: CohortTextStyles.small),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
