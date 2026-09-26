import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/services/completed_session_result_projection.dart';
import '../../programme/models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_home_today_presentation.dart';

class AthleteHomeCompletedTodayCard extends StatelessWidget {
  const AthleteHomeCompletedTodayCard({
    super.key,
    required this.occurrence,
    required this.dateLabel,
    required this.programmeName,
    required this.weekDayLabel,
    required this.onViewResults,
    this.record,
    this.grouped = false,
  });

  final FixedProgrammeOccurrenceProjection occurrence;
  final String dateLabel;
  final String programmeName;
  final String weekDayLabel;
  final VoidCallback onViewResults;
  final TrainingSessionRecord? record;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final projection = record == null
        ? null
        : CompletedSessionResultProjection.fromRecords(record: record!);
    final summary = <String>[
      if (record?.completedAt case final completedAt?)
        'Finished ${_clock(completedAt)}',
      if (projection?.durationSeconds case final duration?)
        if (duration > 0) 'Duration ${_duration(duration)}',
      if (record?.overallRpe case final rpe?) 'RPE $rpe',
    ];
    final collapsedBlocks = projection?.blocks
        .take(3)
        .map((block) => '${block.title} · ${block.summary}')
        .toList(growable: false);
    final timeLabel = AthleteHomeTodayFormatter.timeOfDayLabel(
      occurrence.timeOfDay,
      sameDayGroup: grouped,
    );
    return CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!grouped) ...[
              const Text('TODAY', style: CohortTextStyles.sectionLabel),
              const SizedBox(height: CohortSpacing.xs),
              Text(
                dateLabel,
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
              if (programmeName.trim().isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(programmeName, style: CohortTextStyles.small),
              ],
              if (weekDayLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(weekDayLabel, style: CohortTextStyles.small),
              ],
              const SizedBox(height: CohortSpacing.md),
            ],
            if (timeLabel != null) ...[
              Semantics(
                label: AthleteHomeTodayFormatter.timeOfDaySpoken(
                  occurrence.timeOfDay,
                  sameDayGroup: grouped,
                ) ?? timeLabel,
                child: ExcludeSemantics(
                  child: Text(timeLabel, style: CohortTextStyles.sectionLabel),
                ),
              ),
              const SizedBox(height: CohortSpacing.xs),
            ],
            Text(occurrence.sessionTitle, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.xs),
            Semantics(
              label: 'Status Complete',
              child: ExcludeSemantics(
                child: const Text(
                  'Complete',
                  style: CohortTextStyles.statusActive,
                ),
              ),
            ),
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
            const SizedBox(height: CohortSpacing.md),
            CohortButton(
              key: const ValueKey('completed-today-view-result'),
              label: 'View results',
              semanticLabel: 'View results. ${occurrence.sessionTitle}. Status Complete',
              variant: CohortButtonVariant.secondary,
              onPressed: onViewResults,
            ),
          ],
        ),
    );
  }

  static String _clock(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _duration(int seconds) {
    if (seconds <= 0) return '';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes}m ${remainder.toString().padLeft(2, '0')}s';
  }
}
