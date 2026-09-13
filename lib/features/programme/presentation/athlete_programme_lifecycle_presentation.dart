import '../models/fixed_programme_occurrence_projection.dart';
import 'programme_day_label_formatter.dart';

enum AthleteProgrammeLifecycle { upcoming, active }

class AthleteProgrammeWeekDayPresentation {
  const AthleteProgrammeWeekDayPresentation({
    required this.date,
    required this.state,
    this.occurrence,
    this.isOutsideProgramme = false,
  });

  final DateTime date;
  final FixedProgrammeOccurrenceState state;
  final FixedProgrammeOccurrenceProjection? occurrence;
  final bool isOutsideProgramme;

  String get weekdayLabel => AthleteProgrammeDateFormatter.shortWeekday(date);
  String get dateLabel => '${date.day}';
  String get stateLabel =>
      isOutsideProgramme ? 'Not active' : state.displayLabel;
}

class AthleteProgrammeWeekPresentation {
  const AthleteProgrammeWeekPresentation({
    required this.heading,
    required this.dateRangeLabel,
    required this.days,
  });

  final String heading;
  final String dateRangeLabel;
  final List<AthleteProgrammeWeekDayPresentation> days;
}

class AthleteProgrammeLifecyclePresentation {
  const AthleteProgrammeLifecyclePresentation({
    required this.lifecycle,
    required this.programmeName,
    required this.startDateLabel,
    required this.shortStartDateLabel,
    required this.statusLabel,
    required this.supportingLine,
    required this.week,
    required this.daysUntilStart,
    this.currentWeekNumber,
    this.currentDayLabel,
  });

  final AthleteProgrammeLifecycle lifecycle;
  final String programmeName;
  final String startDateLabel;
  final String shortStartDateLabel;
  final String statusLabel;
  final String supportingLine;
  final AthleteProgrammeWeekPresentation week;
  final int daysUntilStart;
  final int? currentWeekNumber;
  final String? currentDayLabel;

  bool get isUpcoming => lifecycle == AthleteProgrammeLifecycle.upcoming;
}

/// Athlete-visible copy for past unfinished sessions.
///
/// Internal lifecycle may still derive `OVERDUE`. Athletes see Incomplete.
abstract final class IncompleteSessionAthleteCopy {
  static const statusLabel = 'Incomplete';
  static const trainToday = 'Train today';
  static const backfillResults = 'Backfill results';
  static const reschedule = 'Reschedule';
  static const doThisSession = trainToday;
  static const stillCompletable =
      'You can still complete this session now or enter results if you already performed it.';

  static String sectionHeading(int count) =>
      count == 1 ? 'INCOMPLETE SESSION' : 'INCOMPLETE SESSIONS';

  static String countPhrase(int count) =>
      count == 1 ? '1 incomplete session' : '$count incomplete sessions';

  static String scheduledLine(DateTime date) =>
      'Scheduled ${AthleteProgrammeDateFormatter.dayMonth(date)}';

  static String scheduledForLine(DateTime date) =>
      'Scheduled for ${AthleteProgrammeDateFormatter.weekdayDayMonth(date)}';

  static String completedLater({
    required DateTime scheduled,
    required DateTime completed,
  }) =>
      'Scheduled ${AthleteProgrammeDateFormatter.dayMonth(scheduled)} · '
      'Completed ${AthleteProgrammeDateFormatter.dayMonth(completed)}';

  static String backfillHistory({
    required DateTime scheduled,
    required DateTime performed,
    required DateTime entered,
  }) =>
      'Scheduled ${AthleteProgrammeDateFormatter.dayMonth(scheduled)} · '
      'Performed ${AthleteProgrammeDateFormatter.dayMonth(performed)} · '
      'Entered ${AthleteProgrammeDateFormatter.dayMonth(entered)}';
}

abstract final class AthleteProgrammeLifecycleFormatter {
  static AthleteProgrammeLifecyclePresentation fromFixedProjection(
    FixedProgrammeCalendarProjection projection,
  ) {
    final today = DateTime.parse(projection.today);
    final start = DateTime.parse(projection.startDate);
    final isUpcoming = projection.startsInFuture;
    final todayOccurrence = projection.todayOccurrence;
    final daysUntilStart = start.difference(today).inDays;
    final currentDayLabel = todayOccurrence == null
        ? null
        : ProgrammeDayLabelFormatter.format(dayKey: todayOccurrence.dayKey);
    final currentWeekNumber =
        todayOccurrence?.weekNumber ??
        _weekNumberFromCurrentWeek(projection.currentWeek);

    return AthleteProgrammeLifecyclePresentation(
      lifecycle: isUpcoming
          ? AthleteProgrammeLifecycle.upcoming
          : AthleteProgrammeLifecycle.active,
      programmeName: projection.programmeName,
      startDateLabel: AthleteProgrammeDateFormatter.longDate(start),
      shortStartDateLabel: AthleteProgrammeDateFormatter.dayMonth(start),
      statusLabel: isUpcoming
          ? 'Starts ${AthleteProgrammeDateFormatter.dayMonth(start)}'
          : _activeStatusLabel(currentWeekNumber, currentDayLabel),
      supportingLine: isUpcoming
          ? _upcomingSupportingLine(daysUntilStart)
          : todayOccurrence == null
          ? 'No authored training session is scheduled today.'
          : "Today's authored session is available on Home.",
      week: isUpcoming
          ? _firstProgrammeWeek(projection, start)
          : _currentProgrammeWeek(projection),
      daysUntilStart: daysUntilStart < 0 ? 0 : daysUntilStart,
      currentWeekNumber: isUpcoming ? null : currentWeekNumber,
      currentDayLabel: isUpcoming ? null : currentDayLabel,
    );
  }

  static String _activeStatusLabel(int? weekNumber, String? dayLabel) {
    if (weekNumber == null) return 'Programme active';
    if (dayLabel == null) return 'Week $weekNumber';
    return 'Week $weekNumber · $dayLabel';
  }

  static String _upcomingSupportingLine(int daysUntilStart) {
    if (daysUntilStart == 1) {
      return 'Your first session unlocks tomorrow.';
    }
    return 'Your first session unlocks in $daysUntilStart days.';
  }

  static int? _weekNumberFromCurrentWeek(
    List<FixedProgrammeCalendarDayProjection> days,
  ) {
    for (final day in days) {
      final weekNumber = day.occurrence?.weekNumber;
      if (weekNumber != null) return weekNumber;
    }
    return null;
  }

  static AthleteProgrammeWeekPresentation _firstProgrammeWeek(
    FixedProgrammeCalendarProjection projection,
    DateTime start,
  ) {
    final days = List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      final occurrence = _occurrenceOn(projection.occurrences, date);
      return AthleteProgrammeWeekDayPresentation(
        date: date,
        state: occurrence?.state ?? FixedProgrammeOccurrenceState.rest,
        occurrence: occurrence,
      );
    }, growable: false);
    return AthleteProgrammeWeekPresentation(
      heading: 'FIRST WEEK',
      dateRangeLabel: AthleteProgrammeDateFormatter.dateRange(
        days.first.date,
        days.last.date,
      ),
      days: List.unmodifiable(days),
    );
  }

  static AthleteProgrammeWeekPresentation _currentProgrammeWeek(
    FixedProgrammeCalendarProjection projection,
  ) {
    final days = projection.currentWeek
        .map(
          (day) => AthleteProgrammeWeekDayPresentation(
            date: DateTime.parse(day.date),
            state: day.state,
            occurrence: day.occurrence,
            isOutsideProgramme:
                DateTime.parse(
                  day.date,
                ).compareTo(DateTime.parse(projection.startDate)) <
                0,
          ),
        )
        .toList(growable: false);
    return AthleteProgrammeWeekPresentation(
      heading: 'THIS WEEK',
      dateRangeLabel: AthleteProgrammeDateFormatter.dateRange(
        days.first.date,
        days.last.date,
      ),
      days: List.unmodifiable(days),
    );
  }

  static FixedProgrammeOccurrenceProjection? _occurrenceOn(
    List<FixedProgrammeOccurrenceProjection> occurrences,
    DateTime date,
  ) {
    final isoDate = _isoDate(date);
    for (final occurrence in occurrences) {
      if (occurrence.scheduledDate == isoDate) return occurrence;
    }
    return null;
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

abstract final class AthleteProgrammeDateFormatter {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _shortWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String shortWeekday(DateTime date) => _shortWeekdays[date.weekday - 1];

  static String longDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

  static String weekdayDayMonth(DateTime date) =>
      '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

  static String monthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';

  static String shortDayMonth(DateTime date) =>
      '${date.day} ${_shortMonths[date.month - 1]}';

  static String dayMonth(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  static String dateRange(DateTime start, DateTime end) {
    if (start.month == end.month && start.year == end.year) {
      return '${start.day}–${end.day} ${_months[start.month - 1]}';
    }
    return '${dayMonth(start)}–${dayMonth(end)}';
  }
}
