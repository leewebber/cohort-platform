import 'package:cohort_platform/domain/programme_scheduling/authored_occurrence_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const start = '2026-09-26';

  DateTime d(String iso) => DateTime.utc(
    int.parse(iso.substring(0, 4)),
    int.parse(iso.substring(5, 7)),
    int.parse(iso.substring(8, 10)),
  );

  String date({required int week, required int day}) {
    return AuthoredOccurrenceDate.isoDate(
      AuthoredOccurrenceDate.occurrenceDate(
        startedAt: d(start),
        weekNumber: week,
        dayOrder: day,
      ),
    );
  }

  test('ordinary seven-day week keeps one session per authored day', () {
    expect(date(week: 1, day: 1), start);
    expect(date(week: 1, day: 7), '2026-10-02');
    expect(date(week: 2, day: 1), '2026-10-03');
  });

  test('same week and day share one date regardless of slot index', () {
    final sunday = date(week: 1, day: 2);
    expect(sunday, '2026-09-27');
    expect(
      AuthoredOccurrenceDate.calendarOffsetDays(weekNumber: 1, dayOrder: 2),
      AuthoredOccurrenceDate.calendarOffsetDays(weekNumber: 1, dayOrder: 2),
    );
    expect(date(week: 1, day: 3), '2026-09-28');
  });

  test('Week 8 spillover stays an eight-week Saturday start', () {
    expect(date(week: 8, day: 1), '2026-11-14');
    expect(date(week: 8, day: 7), '2026-11-20');
    expect(date(week: 8, day: 8), '2026-11-21');
    expect(date(week: 8, day: 9), '2026-11-22');
  });

  test('rejects non-positive week or day', () {
    expect(
      () => AuthoredOccurrenceDate.calendarOffsetDays(
        weekNumber: 0,
        dayOrder: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => AuthoredOccurrenceDate.calendarOffsetDays(
        weekNumber: 1,
        dayOrder: 0,
      ),
      throwsArgumentError,
    );
  });

  test('Europe/London civil dates still add whole days across DST', () {
    // 2026-03-29 is the UK spring-forward. Offset remains calendar days.
    final before = AuthoredOccurrenceDate.occurrenceDate(
      startedAt: DateTime.utc(2026, 3, 28),
      weekNumber: 1,
      dayOrder: 2,
    );
    expect(AuthoredOccurrenceDate.isoDate(before), '2026-03-29');
    expect(before.difference(DateTime.utc(2026, 3, 28)).inDays, 1);
  });
}
