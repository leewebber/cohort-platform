import '../../session_occurrence/value_objects/session_occurrence_date.dart';

/// Local calendar-date arithmetic (YMD), not fixed-hour / wall-clock deltas.
///
/// Uses UTC midnight as a stable calendar carrier so DST transitions do not
/// alter the intended local date result.
extension SessionOccurrenceDateArithmetic on SessionOccurrenceDate {
  DateTime get _utcMidnight => DateTime.utc(year, month, day);

  int compareTo(SessionOccurrenceDate other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    if (byMonth != 0) return byMonth;
    return day.compareTo(other.day);
  }

  bool isBefore(SessionOccurrenceDate other) => compareTo(other) < 0;

  bool isAfter(SessionOccurrenceDate other) => compareTo(other) > 0;

  bool isOnOrBefore(SessionOccurrenceDate other) => compareTo(other) <= 0;

  bool isOnOrAfter(SessionOccurrenceDate other) => compareTo(other) >= 0;

  SessionOccurrenceDate addCalendarDays(int days) {
    final next = _utcMidnight.add(Duration(days: days));
    return SessionOccurrenceDate(
      year: next.year,
      month: next.month,
      day: next.day,
    );
  }

  /// Inclusive span in calendar days from this date to [other].
  int calendarDaysUntil(SessionOccurrenceDate other) {
    return other._utcMidnight.difference(_utcMidnight).inDays;
  }
}
