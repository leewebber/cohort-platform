import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../programme_builder/models/programme_builder_preview.dart';

class ProgrammePreviewStructureView extends StatelessWidget {
  const ProgrammePreviewStructureView({
    super.key,
    required this.preview,
  });

  final ProgrammeBuilderPreview preview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      children: [
        Text(preview.programmeName, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          '${preview.lineageCode} · v${preview.versionNumber}',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.lg),
        for (final week in preview.weeks) ...[
          Text(
            week.title == null || week.title!.isEmpty
                ? 'Week ${week.weekNumber}'
                : 'Week ${week.weekNumber} — ${week.title}',
            style: CohortTextStyles.cardTitle,
          ),
          const SizedBox(height: CohortSpacing.sm),
          for (final day in week.days) ...[
            Text(
              [
                day.dayKey,
                if (day.title != null) day.title!,
                if (day.isRestDay) 'Rest',
              ].join(' · '),
              style: CohortTextStyles.body,
            ),
            for (final slot in day.slots)
              Padding(
                padding: const EdgeInsets.only(left: CohortSpacing.md),
                child: Text(
                  'Slot ${slot.sessionOrder} · ${slot.protocolName ?? slot.protocolId.ifEmpty('No protocol')}'
                  '${slot.isOptional ? ' (Optional)' : ''}',
                  style: CohortTextStyles.small,
                ),
              ),
            const SizedBox(height: CohortSpacing.sm),
          ],
          const SizedBox(height: CohortSpacing.md),
        ],
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
