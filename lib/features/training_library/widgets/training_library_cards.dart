import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../models/training_library_item_summary.dart';

class SessionLibraryCard extends StatelessWidget {
  const SessionLibraryCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onPreview,
    this.onEdit,
  });

  final TrainingLibraryItemSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (summary.sessionType != null) summary.sessionType!,
      if (summary.durationMin != null) '${summary.durationMin} min',
      if (summary.stepCount != null) '${summary.stepCount} exercises',
    ].join(' · ');

    return CohortCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coach Session', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Text(summary.title, style: CohortTextStyles.cardTitle),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(metadata, style: CohortTextStyles.small),
          ],
          if (onPreview != null || onEdit != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Row(
              children: [
                if (onPreview != null)
                  TextButton(
                    onPressed: onPreview,
                    child: const Text('Preview'),
                  ),
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Edit'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CohortProtocolLibraryCard extends StatelessWidget {
  const CohortProtocolLibraryCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onPreview,
    this.onCopyToSessionLibrary,
  });

  final TrainingLibraryItemSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;
  final VoidCallback? onCopyToSessionLibrary;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (summary.sessionType != null) summary.sessionType!,
      if (summary.durationMin != null) '${summary.durationMin} min',
    ].join(' · ');

    return CohortCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CohortColors.olive.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Cohort Protocol',
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
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(metadata, style: CohortTextStyles.small),
          ],
          if (onPreview != null || onCopyToSessionLibrary != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Wrap(
              spacing: CohortSpacing.sm,
              children: [
                if (onPreview != null)
                  TextButton(
                    onPressed: onPreview,
                    child: const Text('Preview'),
                  ),
                if (onCopyToSessionLibrary != null)
                  TextButton(
                    onPressed: onCopyToSessionLibrary,
                    child: const Text('Copy to Session Library'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
