import '../models/fixed_programme_occurrence_projection.dart';
import 'athlete_calendar_agenda_presentation.dart';
import 'athlete_programme_lifecycle_presentation.dart';

class AthleteCalendarMonthCell {
  const AthleteCalendarMonthCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.occurrences,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<FixedProgrammeOccurrenceProjection> occurrences;

  String get isoDate => AthleteCalendarMonthFormatter.isoDate(date);

  String get dateLabel => '${date.day}';

  bool get hasProgrammeContent => occurrences.isNotEmpty;

  FixedProgrammeOccurrenceProjection? get primaryOccurrence =>
      occurrences.isEmpty ? null : occurrences.first;

  String? get compactTitle {
    if (occurrences.isEmpty) return null;
    if (occurrences.length == 1 &&
        occurrences.first.state == FixedProgrammeOccurrenceState.rest) {
      return AthleteCalendarStatusCopy.rest;
    }
    final first = AthleteCalendarMonthFormatter.compactTitle(
      occurrences.first.sessionTitle,
    );
    if (occurrences.length == 1) return first;
    final extra = occurrences.length - 1;
    return '$first\n+$extra session${extra == 1 ? '' : 's'}';
  }

  String? get statusLabel {
    if (occurrences.isEmpty) return null;
    if (occurrences.length == 1) {
      return AthleteCalendarStatusCopy.forOccurrence(occurrences.first);
    }
    return '${AthleteCalendarStatusCopy.forOccurrence(occurrences.first)} · ${occurrences.length} sessions';
  }

  String get semanticsLabel {
    final titles = occurrences
        .map((occurrence) => occurrence.sessionTitle)
        .where((title) => title.trim().isNotEmpty)
        .join(', ');
    return [
      AthleteProgrammeDateFormatter.weekdayDayMonth(date),
      if (isToday) AthleteCalendarStatusCopy.today,
      if (titles.isNotEmpty) titles else if (occurrences.isEmpty) 'No session',
      ?statusLabel,
    ].join(', ');
  }
}

abstract final class AthleteCalendarMonthFormatter {
  static const compactTitleLimit = 16;

  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime parseIsoDate(String iso) => DateTime(
    int.parse(iso.substring(0, 4)),
    int.parse(iso.substring(5, 7)),
    int.parse(iso.substring(8, 10)),
  );

  static DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

  static DateTime addMonths(DateTime date, int delta) =>
      DateTime(date.year, date.month + delta);

  static String compactTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return AthleteCalendarStatusCopy.rest;
    if (trimmed.length <= compactTitleLimit) return trimmed;
    return '${trimmed.substring(0, compactTitleLimit - 1).trimRight()}…';
  }

  static List<AthleteCalendarMonthCell> monthCells({
    required FixedProgrammeCalendarProjection calendar,
    required DateTime month,
    DateTime? selectedDate,
  }) {
    final start = monthStart(month);
    final gridStart = start.subtract(Duration(days: start.weekday - 1));
    final selectedIso = selectedDate == null ? null : isoDate(selectedDate);
    final cells = <AthleteCalendarMonthCell>[];
    for (var index = 0; index < 42; index++) {
      final date = DateTime(
        gridStart.year,
        gridStart.month,
        gridStart.day + index,
      );
      final iso = isoDate(date);
      cells.add(
        AthleteCalendarMonthCell(
          date: date,
          isCurrentMonth: date.month == start.month,
          isToday: iso == calendar.today,
          isSelected: iso == selectedIso,
          occurrences: calendar.occurrencesOnDate(iso),
        ),
      );
    }
    return List.unmodifiable(cells);
  }
}
