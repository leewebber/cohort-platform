import 'package:cohort_platform/features/app_shell/presentation/athlete_time_aware_greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AthleteTimeAwareGreeting', () {
    test('formats morning afternoon and evening with first name', () {
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: DateTime(2026, 9, 10, 8),
          displayName: 'Lee Webber',
        ),
        'Good morning, Lee',
      );
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: DateTime(2026, 9, 10, 12),
          displayName: 'Lee',
        ),
        'Good afternoon, Lee',
      );
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: DateTime(2026, 9, 10, 17),
          displayName: 'Lee',
        ),
        'Good evening, Lee',
      );
    });

    test('missing name falls back to the period only', () {
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: DateTime(2026, 9, 10, 8),
          displayName: null,
        ),
        'Good morning',
      );
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: DateTime(2026, 9, 10, 8),
          displayName: '   ',
        ),
        'Good morning',
      );
    });
  });

  group('AthleteIanaClock', () {
    test('uses assignment zone instead of UTC when they disagree', () {
      final utc = DateTime.utc(2026, 9, 11, 3);
      final newYork = AthleteIanaClock.nowInZone(
        'America/New_York',
        utcNow: utc,
      );
      expect(newYork.hour, 23);
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: newYork,
          displayName: 'Lee',
        ),
        'Good evening, Lee',
      );
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: AthleteIanaClock.nowInZone(null, utcNow: utc),
          displayName: 'Lee',
        ),
        'Good morning, Lee',
      );
    });

    test('unknown IANA names fall back to UTC not the device zone', () {
      final utc = DateTime.utc(2026, 9, 10, 22, 30);
      final local = AthleteIanaClock.nowInZone('Not/AZone', utcNow: utc);
      expect(local.hour, utc.hour);
      expect(local.minute, utc.minute);
    });

    test('Atlantic/Canary uses EU summer time', () {
      final utc = DateTime.utc(2026, 9, 10, 23, 30);
      final canary = AthleteIanaClock.nowInZone(
        'Atlantic/Canary',
        utcNow: utc,
      );
      expect(canary.hour, 0);
      expect(
        AthleteTimeAwareGreeting.format(
          localNow: canary,
          displayName: 'Lee',
        ),
        'Good morning, Lee',
      );
    });
  });
}
