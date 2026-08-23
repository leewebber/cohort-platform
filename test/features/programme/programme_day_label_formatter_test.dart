import 'dart:io';

import 'package:cohort_platform/features/programme/presentation/programme_day_label_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgrammeDayLabelFormatter', () {
    test('formats canonical stable day keys for athlete presentation', () {
      expect(ProgrammeDayLabelFormatter.format(dayKey: 'day_1'), 'Day 1');
      expect(ProgrammeDayLabelFormatter.format(dayKey: 'day_12'), 'Day 12');
    });

    test('preserves a supplied authored human-readable label', () {
      expect(
        ProgrammeDayLabelFormatter.format(
          dayKey: 'day_1',
          authoredLabel: 'Monday strength',
        ),
        'Monday strength',
      );
    });

    test('never exposes separators from a non-canonical storage key', () {
      expect(
        ProgrammeDayLabelFormatter.format(dayKey: 'recovery_day'),
        'Recovery Day',
      );
    });
  });

  test('Home and Plans use the shared day-key presentation formatter', () {
    final home = File(
      'lib/features/home/widgets/athlete_programme_today_section.dart',
    ).readAsStringSync();
    final plans = File(
      'lib/features/programme/screens/athlete_programme_schedule_screen.dart',
    ).readAsStringSync();

    expect(home, contains('ProgrammeDayLabelFormatter.format'));
    expect(plans, contains('ProgrammeDayLabelFormatter.format'));
  });
}
