/// Authored-day calendar offset for fixed programme occurrences.
///
/// `week_number` is the package week order (contiguous from 1).
/// Dates are civil dates; callers apply IANA "today" separately.
library;

abstract final class AuthoredOccurrenceDate {
  static const schemaVersion = 1;

  /// `((week_number - 1) * 7) + (day_order - 1)`
  static int calendarOffsetDays({
    required int weekNumber,
    required int dayOrder,
  }) {
    if (weekNumber < 1 || dayOrder < 1) {
      throw ArgumentError(
        'week_number and day_order must be >= 1 (week=$weekNumber day=$dayOrder)',
      );
    }
    return ((weekNumber - 1) * 7) + (dayOrder - 1);
  }

  /// Local civil date of an authored slot. Clock-time DST is not applied.
  static DateTime occurrenceDate({
    required DateTime startedAt,
    required int weekNumber,
    required int dayOrder,
  }) {
    final start = DateTime.utc(startedAt.year, startedAt.month, startedAt.day);
    return start.add(
      Duration(
        days: calendarOffsetDays(weekNumber: weekNumber, dayOrder: dayOrder),
      ),
    );
  }

  static String isoDate(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
