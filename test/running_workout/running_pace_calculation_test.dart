import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = FiveKilometreBenchmarkSpeedCalculator();
  const twentyMinutes = 20 * 60 * 1000;

  test('calculates percentage of benchmark speed rather than pace', () {
    final benchmarkPace = calculator.calculate(
      benchmarkDurationMilliseconds: twentyMinutes,
      speedBasisPoints: 10000,
    );
    final eightyPercentSpeed = calculator.calculate(
      benchmarkDurationMilliseconds: twentyMinutes,
      speedBasisPoints: 8000,
    );

    expect(benchmarkPace.round(CanonicalPaceRounding.nearest), 240000);
    expect(eightyPercentSpeed.round(CanonicalPaceRounding.nearest), 300000);
    expect(
      eightyPercentSpeed.round(CanonicalPaceRounding.nearest),
      greaterThan(benchmarkPace.round(CanonicalPaceRounding.nearest)),
    );
  });

  test('preserves an exact rational result until rounding is selected', () {
    final pace = calculator.calculate(
      benchmarkDurationMilliseconds: twentyMinutes,
      speedBasisPoints: 9200,
    );

    expect(pace.numeratorMillisecondsPerKilometre, 6000000);
    expect(pace.denominator, 23);
    expect(pace.round(CanonicalPaceRounding.down), 260869);
    expect(pace.round(CanonicalPaceRounding.nearest), 260870);
    expect(pace.round(CanonicalPaceRounding.up), 260870);
  });

  test('rounding has no hidden default and handles exact values', () {
    final exact = calculator.calculate(
      benchmarkDurationMilliseconds: twentyMinutes,
      speedBasisPoints: 7500,
    );

    expect(exact.denominator, 1);
    for (final rounding in CanonicalPaceRounding.values) {
      expect(exact.round(rounding), 320000);
    }
  });

  test('speed ranges return canonical faster-to-slower pace bounds', () {
    final range = calculator.calculateRange(
      benchmarkDurationMilliseconds: twentyMinutes,
      minimumSpeedBasisPoints: 6500,
      maximumSpeedBasisPoints: 7500,
    );

    expect(range.fasterPace.round(CanonicalPaceRounding.nearest), 320000);
    expect(range.slowerPace.round(CanonicalPaceRounding.nearest), 369231);
  });

  test('higher benchmark-speed percentage always means faster pace', () {
    final percentages = [6500, 7500, 8500, 9200, 10000];
    final paces = percentages
        .map(
          (percentage) => calculator
              .calculate(
                benchmarkDurationMilliseconds: twentyMinutes,
                speedBasisPoints: percentage,
              )
              .round(CanonicalPaceRounding.nearest),
        )
        .toList();

    for (var index = 1; index < paces.length; index++) {
      expect(paces[index], lessThan(paces[index - 1]));
    }
  });

  test('invalid inputs fail with stable codes', () {
    expect(
      () => calculator.calculate(
        benchmarkDurationMilliseconds: 0,
        speedBasisPoints: 10000,
      ),
      throwsA(
        isA<RunningPaceCalculationException>().having(
          (error) => error.code,
          'code',
          'invalid_benchmark_duration',
        ),
      ),
    );
    expect(
      () => calculator.calculate(
        benchmarkDurationMilliseconds: twentyMinutes,
        speedBasisPoints: 0,
      ),
      throwsA(
        isA<RunningPaceCalculationException>().having(
          (error) => error.code,
          'code',
          'invalid_speed_percentage',
        ),
      ),
    );
    expect(
      () => calculator.calculateRange(
        benchmarkDurationMilliseconds: twentyMinutes,
        minimumSpeedBasisPoints: 8500,
        maximumSpeedBasisPoints: 8500,
      ),
      throwsA(
        isA<RunningPaceCalculationException>().having(
          (error) => error.code,
          'code',
          'invalid_speed_range',
        ),
      ),
    );
  });
}
