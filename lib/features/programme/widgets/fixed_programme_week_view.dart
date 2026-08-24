import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';

class FixedProgrammeWeekView extends StatelessWidget {
  const FixedProgrammeWeekView({
    super.key,
    required this.presentation,
    this.onOccurrenceTap,
    this.onViewCalendar,
  });

  final AthleteProgrammeWeekPresentation presentation;
  final ValueChanged<FixedProgrammeOccurrenceProjection>? onOccurrenceTap;
  final VoidCallback? onViewCalendar;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      padding: const EdgeInsets.all(CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.heading,
                      style: CohortTextStyles.sectionLabel,
                    ),
                    const SizedBox(height: CohortSpacing.xs),
                    Text(
                      presentation.dateRangeLabel,
                      style: CohortTextStyles.small,
                    ),
                  ],
                ),
              ),
              if (onViewCalendar != null)
                TextButton(
                  onPressed: onViewCalendar,
                  child: const Text('View Calendar'),
                ),
            ],
          ),
          const SizedBox(height: CohortSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 420 ? 7 : 4;
              const spacing = CohortSpacing.xs;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final day in presentation.days)
                    SizedBox(
                      width: width,
                      child: _FixedProgrammeDayCell(
                        day: day,
                        onTap: onOccurrenceTap,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FixedProgrammeDayCell extends StatelessWidget {
  const _FixedProgrammeDayCell({required this.day, this.onTap});

  final AthleteProgrammeWeekDayPresentation day;
  final ValueChanged<FixedProgrammeOccurrenceProjection>? onTap;

  @override
  Widget build(BuildContext context) {
    final occurrence = day.occurrence;
    final canTap = occurrence != null && onTap != null;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _dayColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _dayColor.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CohortSpacing.xs,
            vertical: CohortSpacing.sm,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(day.weekdayLabel, style: CohortTextStyles.tileLabel),
              const SizedBox(height: 2),
              Text(day.dateLabel, style: CohortTextStyles.tileValue),
              const SizedBox(height: 3),
              Text(
                day.isOutsideProgramme
                    ? 'Not active'
                    : _compactStateLabel(day.state),
                style: CohortTextStyles.tileLabel.copyWith(color: _dayColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      key: ValueKey(
        'programme-week-day-${day.date.toIso8601String().substring(0, 10)}',
      ),
      button: canTap,
      enabled: canTap,
      label:
          '${day.weekdayLabel} ${day.dateLabel}, ${day.stateLabel}'
          '${occurrence == null ? '' : ', ${occurrence.sessionTitle}'}',
      child: canTap
          ? InkWell(
              onTap: () => onTap!(occurrence),
              borderRadius: BorderRadius.circular(10),
              child: content,
            )
          : content,
    );
  }

  Color get _dayColor =>
      day.isOutsideProgramme ? const Color(0xFF626860) : _stateColor(day.state);

  String _compactStateLabel(FixedProgrammeOccurrenceState state) {
    return switch (state) {
      FixedProgrammeOccurrenceState.inProgress => 'In progress',
      FixedProgrammeOccurrenceState.inProgressOverdue => 'Overdue',
      FixedProgrammeOccurrenceState.completed => 'Done',
      _ => state.displayLabel,
    };
  }

  Color _stateColor(FixedProgrammeOccurrenceState state) {
    return switch (state) {
      FixedProgrammeOccurrenceState.today => const Color(0xFFB7CA83),
      FixedProgrammeOccurrenceState.inProgress => const Color(0xFF8FB8D8),
      FixedProgrammeOccurrenceState.inProgressOverdue => const Color(
        0xFFE0A96D,
      ),
      FixedProgrammeOccurrenceState.completed => const Color(0xFF7DBE91),
      FixedProgrammeOccurrenceState.missed => const Color(0xFFD47F74),
      FixedProgrammeOccurrenceState.planned => const Color(0xFF8E9A82),
      FixedProgrammeOccurrenceState.rest => const Color(0xFF737A70),
    };
  }
}
