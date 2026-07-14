import 'package:cohort_platform/features/session/services/interval_metric_calculator.dart';
import 'package:cohort_platform/models/interval_metric_entry_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = IntervalMetricCalculator();

  group('IntervalMetricCalculator calculations', () {
    test('800m + 3:12 derives 4:00/km pace', () {
      final pace = calculator.calculatePaceSecondsPerKm(
        distanceMeters: 800,
        durationSeconds: 3 * 60 + 12,
      );

      expect(pace, 240);
      expect(
        calculator.formatPaceSecondsPerKm(pace),
        '4:00/km',
      );
    });

    test('20:00 + 4:00/km derives 5000m distance', () {
      final distance = calculator.calculateDistanceMeters(
        durationSeconds: 20 * 60,
        paceSecondsPerKm: 240,
      );

      expect(distance, 5000);
      expect(calculator.formatDistanceMeters(distance), '5000');
    });

    test('800m + 4:00/km derives 3:12 duration', () {
      final duration = calculator.calculateDurationSeconds(
        distanceMeters: 800,
        paceSecondsPerKm: 240,
      );

      expect(duration, 192);
      expect(calculator.formatDurationSeconds(duration), '3:12');
    });
  });

  group('IntervalMetricCalculator parsing', () {
    test('parses duration formats', () {
      expect(calculator.parseDurationSeconds('3:12'), 192);
      expect(calculator.parseDurationSeconds('20:00'), 1200);
      expect(calculator.parseDurationSeconds('1:05:30'), 3930);
    });

    test('parses pace formats', () {
      expect(calculator.parsePaceSecondsPerKm('4:00'), 240);
      expect(calculator.parsePaceSecondsPerKm('4:00/km'), 240);
    });

    test('rejects invalid and empty values', () {
      expect(calculator.parseDurationSeconds(''), isNull);
      expect(calculator.parseDurationSeconds('0:00'), isNull);
      expect(calculator.parsePaceSecondsPerKm(''), isNull);
      expect(calculator.parsePaceSecondsPerKm('0:00'), isNull);
      expect(calculator.parseDistanceMeters(''), isNull);
      expect(calculator.parseDistanceMeters('-5'), isNull);

      expect(
        calculator.calculatePaceSecondsPerKm(
          distanceMeters: 0,
          durationSeconds: 192,
        ),
        isNull,
      );
      expect(
        calculator.calculateDistanceMeters(
          durationSeconds: 0,
          paceSecondsPerKm: 240,
        ),
        isNull,
      );
      expect(
        calculator.calculateDurationSeconds(
          distanceMeters: 800,
          paceSecondsPerKm: 0,
        ),
        isNull,
      );
    });
  });

  group('IntervalMetricCalculator auto application', () {
    test('auto-calculates pace from distance and duration', () {
      final result = calculator.applyAutoCalculation(
        const IntervalMetricInput(
          distanceMeters: 800,
          durationSeconds: 192,
          distanceSource: IntervalMetricEntrySource.manual,
          durationSource: IntervalMetricEntrySource.manual,
        ),
      );

      expect(result.paceSecondsPerKm, 240);
      expect(result.paceSource, IntervalMetricEntrySource.auto);
    });

    test('does not override manually entered pace', () {
      final result = calculator.applyAutoCalculation(
        const IntervalMetricInput(
          distanceMeters: 800,
          durationSeconds: 192,
          paceSecondsPerKm: 300,
          distanceSource: IntervalMetricEntrySource.manual,
          durationSource: IntervalMetricEntrySource.manual,
          paceSource: IntervalMetricEntrySource.manual,
        ),
      );

      expect(result.paceSecondsPerKm, 300);
      expect(result.paceSource, IntervalMetricEntrySource.manual);
    });
  });
}
