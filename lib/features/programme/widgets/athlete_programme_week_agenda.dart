import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_calendar_agenda_presentation.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';

class AthleteProgrammeWeekAgenda extends StatelessWidget {
  const AthleteProgrammeWeekAgenda({
    super.key,
    required this.rows,
    this.expandedRowId,
    this.onToggleRow,
    this.onOpenSession,
  });

  final List<AthleteCalendarAgendaRow> rows;
  final String? expandedRowId;
  final ValueChanged<AthleteCalendarAgendaRow>? onToggleRow;
  final ValueChanged<AthleteCalendarAgendaRow>? onOpenSession;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows) ...[
          _AgendaRow(
            row: row,
            expanded: expandedRowId == row.rowId,
            onToggle: onToggleRow,
            onOpenSession: onOpenSession,
          ),
          const SizedBox(height: CohortSpacing.sm),
        ],
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.row,
    required this.expanded,
    this.onToggle,
    this.onOpenSession,
  });

  final AthleteCalendarAgendaRow row;
  final bool expanded;
  final ValueChanged<AthleteCalendarAgendaRow>? onToggle;
  final ValueChanged<AthleteCalendarAgendaRow>? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final canExpand = row.hasSession && !row.isOutsideProgramme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final iso =
        '${row.date.year.toString().padLeft(4, '0')}-'
        '${row.date.month.toString().padLeft(2, '0')}-'
        '${row.date.day.toString().padLeft(2, '0')}';
    return Semantics(
      key: ValueKey(
        row.isPrimaryDateRow
            ? 'programme-week-day-$iso'
            : 'calendar-agenda-row-${row.rowId}',
      ),
      button: canExpand,
      expanded: canExpand ? expanded : null,
      label: '${row.semanticsLabel}, ${expanded ? 'expanded' : 'collapsed'}',
      child: CohortCard(
        onTap: canExpand && onToggle != null ? () => onToggle!(row) : null,
        padding: const EdgeInsets.all(CohortSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.headingLabel, style: CohortTextStyles.eyebrow),
                        const SizedBox(height: CohortSpacing.xs),
                        Text(
                          row.sessionTitle,
                          style: CohortTextStyles.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (row.sessionType != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            row.sessionType!,
                            style: CohortTextStyles.muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: CohortSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (row.statusLabel != null)
                        Text(row.statusLabel!, style: CohortTextStyles.small),
                      if (row.wasRescheduled)
                        Text(
                          AthleteCalendarStatusCopy.rescheduled,
                          style: CohortTextStyles.muted,
                        ),
                      if (canExpand)
                        Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ],
              ),
              if (expanded && row.occurrence != null)
                _ExpandedDetail(
                  row: row,
                  occurrence: row.occurrence!,
                  animate: !reduceMotion,
                  onOpenSession: onOpenSession,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedDetail extends StatelessWidget {
  const _ExpandedDetail({
    required this.row,
    required this.occurrence,
    required this.animate,
    this.onOpenSession,
  });

  final AthleteCalendarAgendaRow row;
  final FixedProgrammeOccurrenceProjection occurrence;
  final bool animate;
  final ValueChanged<AthleteCalendarAgendaRow>? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CohortSpacing.md),
        Text(_supportingLine(), style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.sm),
        Wrap(
          spacing: CohortSpacing.sm,
          runSpacing: CohortSpacing.xs,
          children: [
            for (final action in _actions())
              TextButton(
                key: ValueKey('calendar-agenda-action-${action.label}'),
                onPressed: onOpenSession == null
                    ? null
                    : () => onOpenSession!(row),
                child: Text(action.label),
              ),
          ],
        ),
      ],
    );
    if (!animate) return detail;
    return detail;
  }

  String _supportingLine() {
    final scheduled = DateTime.parse(occurrence.originalScheduledDate);
    if (occurrence.state == FixedProgrammeOccurrenceState.completed) {
      return IncompleteSessionAthleteCopy.scheduledLine(scheduled);
    }
    if (occurrence.isLateStartable ||
        occurrence.state == FixedProgrammeOccurrenceState.missed) {
      return '${IncompleteSessionAthleteCopy.scheduledForLine(scheduled)}. '
          '${IncompleteSessionAthleteCopy.stillCompletable}';
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.skipped) {
      return 'This session was skipped.';
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.rest) {
      return 'No training session is scheduled for this programme date.';
    }
    if (row.sessionType != null) {
      return row.sessionType!;
    }
    return occurrence.sessionTitle;
  }

  List<({String label})> _actions() {
    if (occurrence.isResumable) {
      return const [(label: 'Resume')];
    }
    if (occurrence.isToday) {
      return const [(label: 'Begin')];
    }
    if (occurrence.isLateStartable ||
        occurrence.state == FixedProgrammeOccurrenceState.missed) {
      return const [
        (label: IncompleteSessionAthleteCopy.doThisSession),
        (label: 'Reschedule'),
      ];
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.completed) {
      return const [(label: 'View results')];
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.planned) {
      return const [(label: 'View session')];
    }
    return const [];
  }
}
