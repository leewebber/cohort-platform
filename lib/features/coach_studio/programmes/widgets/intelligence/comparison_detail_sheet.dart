import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../intelligence/programme_intelligence_copy.dart';

Future<void> showComparisonDetailSheet({
  required BuildContext context,
  required ProgrammeVersionComparisonSummary summary,
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
            Text('Version changes', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.md),
            _ChangeGroup(
              title: 'Metadata',
              items: summary.metadataChanges
                  .map((change) => '${change.field}: '
                      '${change.sourceValue ?? '—'} → ${change.targetValue ?? '—'}')
                  .toList(),
            ),
            _ChangeGroup(
              title: 'Weeks',
              items: summary.weekChanges
                  .where((c) => c.changeType != ProgrammeChangeType.unchanged)
                  .map((c) => ProgrammeIntelligenceCopy.changeTypeLabel(c.changeType))
                  .toList(),
            ),
            _ChangeGroup(
              title: 'Training days',
              items: summary.dayChanges
                  .where((c) => c.changeType != ProgrammeChangeType.unchanged)
                  .map((c) => ProgrammeIntelligenceCopy.changeTypeLabel(c.changeType))
                  .toList(),
            ),
            _ChangeGroup(
              title: 'Session slots',
              items: summary.slotChanges
                  .where((c) => c.changeType != ProgrammeChangeType.unchanged)
                  .map(
                    (c) =>
                        '${ProgrammeIntelligenceCopy.changeTypeLabel(c.changeType)}'
                        '${c.sourcePosition != null ? ' · ${c.sourcePosition}' : ''}',
                  )
                  .toList(),
            ),
            _ChangeGroup(
              title: 'Exercises added',
              items: summary.exerciseChanges
                  .where((c) => c.changeType == ProgrammeChangeType.added)
                  .map((c) => c.exerciseName)
                  .toList(),
            ),
            _ChangeGroup(
              title: 'Exercises removed',
              items: summary.exerciseChanges
                  .where((c) => c.changeType == ProgrammeChangeType.removed)
                  .map((c) => c.exerciseName)
                  .toList(),
            ),
            if (summary.sessionRevisionChanges.isNotEmpty)
              _ChangeGroup(
                title: 'Session revisions',
                items: summary.sessionRevisionChanges
                    .map(
                      (change) =>
                          '${change.sourceSessionName ?? 'Session'}: '
                          'Revision ${change.sourceRevisionNumber ?? '?'} → '
                          '${change.targetRevisionNumber ?? '?'}',
                    )
                    .toList(),
              ),
          ],
        ),
      );
    },
  );
}

class _ChangeGroup extends StatelessWidget {
  const _ChangeGroup({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
              child: Text('• $item', style: CohortTextStyles.body),
            ),
        ],
      ),
    );
  }
}
