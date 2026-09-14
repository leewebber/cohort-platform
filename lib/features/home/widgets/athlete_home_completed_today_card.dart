import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/services/completed_session_result_projection.dart';
import '../../programme/models/fixed_programme_occurrence_projection.dart';

class AthleteHomeCompletedTodayCard extends StatelessWidget {
  const AthleteHomeCompletedTodayCard({
    super.key,
    required this.occurrence,
    required this.dateLabel,
    required this.programmeName,
    required this.weekDayLabel,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onViewResults,
    this.record,
    this.history = const [],
    this.historyLoading = false,
  });

  final FixedProgrammeOccurrenceProjection occurrence;
  final String dateLabel;
  final String programmeName;
  final String weekDayLabel;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onViewResults;
  final TrainingSessionRecord? record;
  final List<TrainingSessionRecord> history;
  final bool historyLoading;

  @override
  Widget build(BuildContext context) {
    final projection = record == null
        ? null
        : CompletedSessionResultProjection.fromRecords(
            record: record!,
            athleteHistory: history,
          );
    final summary = <String>[
      if (record?.completedAt case final completedAt?)
        'Finished ${_clock(completedAt)}',
      if (record?.durationSeconds case final duration?)
        'Duration ${_duration(duration)}',
      if (record?.overallRpe case final rpe?) 'RPE $rpe',
    ];
    final collapsedBlocks = projection?.blocks
        .take(3)
        .map((block) => '${block.title} · ${block.summary}')
        .toList(growable: false);
    final hasComparison = projection?.blocks.any(_hasComparison) ?? false;

    return Semantics(
      container: true,
      label: '${occurrence.sessionTitle}, Complete',
      child: CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TODAY', style: CohortTextStyles.sectionLabel),
            const SizedBox(height: CohortSpacing.xs),
            Text(dateLabel, style: CohortTextStyles.muted),
            if (programmeName.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(programmeName, style: CohortTextStyles.small),
            ],
            if (weekDayLabel.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(weekDayLabel, style: CohortTextStyles.small),
            ],
            const SizedBox(height: CohortSpacing.md),
            Text(occurrence.sessionTitle, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.xs),
            const Text('Complete', style: CohortTextStyles.statusActive),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(summary.join(' · '), style: CohortTextStyles.small),
            ],
            if (collapsedBlocks != null && collapsedBlocks.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.sm),
              for (final line in collapsedBlocks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: CohortTextStyles.body),
                ),
            ],
            TextButton(
              onPressed: onToggleExpanded,
              child: Text(expanded ? 'Hide results' : 'Show results'),
            ),
            if (expanded) ...[
              if (historyLoading)
                const Text(
                  'Loading comparison…',
                  style: CohortTextStyles.muted,
                )
              else if (projection == null)
                const Text(
                  'Results are available in the session record.',
                  style: CohortTextStyles.muted,
                )
              else ...[
                if (!hasComparison)
                  const Text(
                    'First recorded performance — no previous comparable result.',
                    style: CohortTextStyles.small,
                  ),
                const SizedBox(height: CohortSpacing.sm),
                for (final block in projection.blocks) ...[
                  Text(block.title, style: CohortTextStyles.cardTitle),
                  Text(block.summary, style: CohortTextStyles.body),
                  for (final exercise in block.exercises) ...[
                    const SizedBox(height: CohortSpacing.xs),
                    Text(exercise.displayName, style: CohortTextStyles.body),
                    if (exercise.bestSetLabel != null)
                      Text(
                        exercise.bestSetLabel!,
                        style: CohortTextStyles.small,
                      ),
                    Text(
                      exercise.comparisonHighlight ?? exercise.comparisonLabel,
                      style: CohortTextStyles.small,
                    ),
                    if (exercise.personalBestLabels.isNotEmpty)
                      for (final label in exercise.personalBestLabels)
                        Text(label, style: CohortTextStyles.small),
                    if (exercise.previousSets.isNotEmpty)
                      Text(
                        'Previous: ${exercise.previousSets.map(_setLine).join(' · ')}',
                        style: CohortTextStyles.muted,
                      ),
                    for (final delta in exercise.deltaLabels)
                      Text(delta, style: CohortTextStyles.small),
                  ],
                  if (block.interval != null) ...[
                    Text(
                      block.interval!.comparisonStatus.label,
                      style: CohortTextStyles.small,
                    ),
                    if (block.interval!.personalRecordLabel != null)
                      Text(
                        block.interval!.personalRecordLabel!,
                        style: CohortTextStyles.small,
                      ),
                  ],
                  if (block.circuit != null) ...[
                    Text(
                      block.circuit!.comparisonStatus.label,
                      style: CohortTextStyles.small,
                    ),
                    if (block.circuit!.fastestIsPersonalRecord)
                      const Text(
                        'Personal best established',
                        style: CohortTextStyles.small,
                      ),
                  ],
                  const SizedBox(height: CohortSpacing.sm),
                ],
              ],
            ],
            CohortButton(
              key: const ValueKey('completed-today-view-result'),
              label: 'View results',
              variant: CohortButtonVariant.secondary,
              onPressed: onViewResults,
            ),
          ],
        ),
      ),
    );
  }

  static String _setLine(CompletedSetResultProjection set) {
    final parts = <String>[
      if (set.loadLabel != null) set.loadLabel!,
      if (set.repsLabel != null) set.repsLabel!,
    ];
    return parts.isEmpty ? 'Set ${set.setNumber}' : parts.join(' ');
  }

  static bool _hasComparison(CompletedBlockResultProjection block) {
    final comparable = {
      StrengthExerciseComparisonStatus.improved,
      StrengthExerciseComparisonStatus.maintained,
      StrengthExerciseComparisonStatus.belowPrevious,
    };
    if (block.exercises.any(
      (exercise) => comparable.contains(exercise.comparisonStatus),
    )) {
      return true;
    }
    if (block.interval != null &&
        comparable.contains(block.interval!.comparisonStatus)) {
      return true;
    }
    if (block.circuit != null &&
        comparable.contains(block.circuit!.comparisonStatus)) {
      return true;
    }
    return false;
  }

  static String _clock(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes}m ${remainder.toString().padLeft(2, '0')}s';
  }
}
