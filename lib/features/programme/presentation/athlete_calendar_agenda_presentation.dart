import '../models/fixed_programme_occurrence_projection.dart';
import 'athlete_programme_lifecycle_presentation.dart';

/// Athlete-facing Calendar status. Internal `OVERDUE` stays off this surface.
abstract final class AthleteCalendarStatusCopy {
  static const planned = 'Planned';
  static const inProgress = 'In progress';
  static const complete = 'Complete';
  static const incomplete = IncompleteSessionAthleteCopy.statusLabel;
  static const rest = 'Rest';
  static const skipped = 'Skipped';
  static const rescheduled = 'Rescheduled';
  static const today = 'Today';
  static const noSession = 'No session';
  static const notActive = 'Not active';

  static String forOccurrence(FixedProgrammeOccurrenceProjection occurrence) {
    return switch (occurrence.state) {
      FixedProgrammeOccurrenceState.planned => planned,
      FixedProgrammeOccurrenceState.today => planned,
      FixedProgrammeOccurrenceState.inProgress => inProgress,
      FixedProgrammeOccurrenceState.inProgressOverdue => inProgress,
      FixedProgrammeOccurrenceState.overdue => incomplete,
      FixedProgrammeOccurrenceState.missed => incomplete,
      FixedProgrammeOccurrenceState.completed => complete,
      FixedProgrammeOccurrenceState.skipped => skipped,
      FixedProgrammeOccurrenceState.rest => rest,
    };
  }
}

class AthleteCalendarAgendaRow {
  const AthleteCalendarAgendaRow({
    required this.rowId,
    required this.date,
    required this.isToday,
    required this.isOutsideProgramme,
    this.isPrimaryDateRow = true,
    this.occurrence,
  });

  final String rowId;
  final DateTime date;
  final bool isToday;
  final bool isOutsideProgramme;
  final bool isPrimaryDateRow;
  final FixedProgrammeOccurrenceProjection? occurrence;

  bool get hasSession => occurrence != null;

  bool get isAuthoredRest =>
      occurrence != null &&
      occurrence!.state == FixedProgrammeOccurrenceState.rest;

  bool get isEmptyDay => occurrence == null && !isOutsideProgramme;

  String get weekdayLabel => AthleteProgrammeDateFormatter.shortWeekday(date);

  String get dateLabel => '${date.day}';

  String get headingLabel {
    final day = '$weekdayLabel $dateLabel';
    return isToday ? '$day · ${AthleteCalendarStatusCopy.today}' : day;
  }

  String get sessionTitle {
    if (isOutsideProgramme) return AthleteCalendarStatusCopy.notActive;
    if (isEmptyDay) return AthleteCalendarStatusCopy.noSession;
    if (isAuthoredRest) return AthleteCalendarStatusCopy.rest;
    return occurrence!.sessionTitle;
  }

  String? get sessionType {
    final type = occurrence?.sessionType?.trim();
    if (type == null || type.isEmpty) return null;
    return type;
  }

  String? get statusLabel {
    if (isOutsideProgramme || isEmptyDay) return null;
    return AthleteCalendarStatusCopy.forOccurrence(occurrence!);
  }

  bool get wasRescheduled => occurrence?.wasRescheduled == true;

  String get semanticsLabel {
    final parts = <String>[
      AthleteProgrammeDateFormatter.weekdayDayMonth(date),
      if (isToday) AthleteCalendarStatusCopy.today,
      sessionTitle,
      ?sessionType,
      ?statusLabel,
      if (wasRescheduled) AthleteCalendarStatusCopy.rescheduled,
    ];
    return parts.join(', ');
  }
}

abstract final class AthleteCalendarAgendaFormatter {
  static List<AthleteCalendarAgendaRow> weekRows({
    required FixedProgrammeCalendarProjection calendar,
    required DateTime weekStart,
  }) {
    final rows = <AthleteCalendarAgendaRow>[];
    for (var index = 0; index < 7; index++) {
      final date = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      ).add(Duration(days: index));
      final iso = _isoDate(date);
      final matches = calendar.occurrencesOnDate(iso);
      final outside = iso.compareTo(calendar.startDate) < 0;
      final isToday = iso == calendar.today;
      if (matches.isEmpty) {
        rows.add(
          AthleteCalendarAgendaRow(
            rowId: 'empty:$iso',
            date: date,
            isToday: isToday,
            isOutsideProgramme: outside,
            isPrimaryDateRow: true,
          ),
        );
        continue;
      }
      for (final occurrence in matches) {
        rows.add(
          AthleteCalendarAgendaRow(
            rowId: occurrence.occurrenceId,
            date: date,
            isToday: isToday,
            isOutsideProgramme: outside,
            isPrimaryDateRow:
                occurrence.occurrenceId == matches.first.occurrenceId,
            occurrence: occurrence,
          ),
        );
      }
    }
    return List.unmodifiable(rows);
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
