import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../models/session_template_taxonomy.dart';
import '../models/training_library_item_summary.dart';

class SessionTemplateLibraryCard extends StatelessWidget {
  const SessionTemplateLibraryCard({
    super.key,
    required this.summary,
    this.onPreview,
    this.onUseTemplate,
  });

  final TrainingLibraryItemSummary summary;
  final VoidCallback? onPreview;
  final VoidCallback? onUseTemplate;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (summary.modalityFilter != null &&
          summary.modalityFilter!.label != 'All')
        summary.modalityFilter!.label,
      if (summary.sessionType != null) summary.sessionType!,
      if (summary.durationMin != null) '${summary.durationMin} min',
      if (summary.technicalComplexity != null) summary.technicalComplexity!,
      if (summary.requiredEquipment != null) summary.requiredEquipment!,
    ].join(' · ');

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CohortColors.olive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Cohort Template',
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.olive,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.sm),
          if (summary.publicCode != null)
            Text(summary.publicCode!, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Text(summary.title, style: CohortTextStyles.cardTitle),
          if (summary.purpose != null &&
              summary.purpose!.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(summary.purpose!, style: CohortTextStyles.body),
          ],
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(metadata, style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.xs),
          Text(
            'Use Template creates your own editable session. The source template stays unchanged.',
            style: CohortTextStyles.muted,
          ),
          if (onPreview != null || onUseTemplate != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Wrap(
              spacing: CohortSpacing.sm,
              children: [
                if (onPreview != null)
                  TextButton(
                    onPressed: onPreview,
                    child: const Text('Preview template'),
                  ),
                if (onUseTemplate != null)
                  TextButton(
                    onPressed: onUseTemplate,
                    child: const Text('Use template'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
