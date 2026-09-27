/// Pure B2 calculation primitives.
///
/// This module does not decide benchmark eligibility, percentage policy,
/// freshness, persistence, freeze, override, or programme composition.
enum CanonicalPaceRounding { down, nearest, up }

class RunningPaceCalculationException implements Exception {
  const RunningPaceCalculationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RunningPaceCalculationException($code): $message';
}

/// Exact positive pace in milliseconds per kilometre.
///
/// Keeping the result as a reduced fraction prevents an unapproved rounding
/// rule from becoming calculation authority.
class ExactCanonicalPace {
  factory ExactCanonicalPace({
    required int numeratorMillisecondsPerKilometre,
    required int denominator,
  }) {
    if (numeratorMillisecondsPerKilometre <= 0 || denominator <= 0) {
      throw const RunningPaceCalculationException(
        'invalid_exact_pace',
        'Exact pace numerator and denominator must be positive.',
      );
    }
    final divisor = _greatestCommonDivisor(
      numeratorMillisecondsPerKilometre,
      denominator,
    );
    return ExactCanonicalPace._(
      numeratorMillisecondsPerKilometre ~/ divisor,
      denominator ~/ divisor,
    );
  }

  const ExactCanonicalPace._(
    this.numeratorMillisecondsPerKilometre,
    this.denominator,
  );

  final int numeratorMillisecondsPerKilometre;
  final int denominator;

  int round(CanonicalPaceRounding rounding) {
    return roundToIncrement(1, rounding);
  }

  int roundToIncrement(
    int incrementMillisecondsPerKilometre,
    CanonicalPaceRounding rounding,
  ) {
    if (incrementMillisecondsPerKilometre <= 0) {
      throw const RunningPaceCalculationException(
        'invalid_rounding_increment',
        'Pace rounding increment must be positive.',
      );
    }
    final scaledDenominator = denominator * incrementMillisecondsPerKilometre;
    final quotient = numeratorMillisecondsPerKilometre ~/ scaledDenominator;
    final remainder = numeratorMillisecondsPerKilometre % scaledDenominator;
    final roundedQuotient = switch (rounding) {
      CanonicalPaceRounding.down => quotient,
      CanonicalPaceRounding.nearest =>
        remainder * 2 < scaledDenominator ? quotient : quotient + 1,
      CanonicalPaceRounding.up => remainder == 0 ? quotient : quotient + 1,
    };
    return roundedQuotient * incrementMillisecondsPerKilometre;
  }

  @override
  bool operator ==(Object other) {
    return other is ExactCanonicalPace &&
        other.numeratorMillisecondsPerKilometre ==
            numeratorMillisecondsPerKilometre &&
        other.denominator == denominator;
  }

  @override
  int get hashCode =>
      Object.hash(numeratorMillisecondsPerKilometre, denominator);
}

class ExactCanonicalPaceRange {
  const ExactCanonicalPaceRange({
    required this.fasterPace,
    required this.slowerPace,
  });

  final ExactCanonicalPace fasterPace;
  final ExactCanonicalPace slowerPace;
}

/// Calculates pace from a five-kilometre duration and a percentage of its
/// average speed.
///
/// Percentages use basis points: 10000 = 100.00%. No percentage values are
/// selected or defaulted here. For a 5 km benchmark:
///
/// `target pace ms/km = duration ms * 2000 / speed basis points`.
class FiveKilometreBenchmarkSpeedCalculator {
  const FiveKilometreBenchmarkSpeedCalculator();

  ExactCanonicalPace calculate({
    required int benchmarkDurationMilliseconds,
    required int speedBasisPoints,
  }) {
    if (benchmarkDurationMilliseconds <= 0) {
      throw const RunningPaceCalculationException(
        'invalid_benchmark_duration',
        'Five-kilometre benchmark duration must be positive.',
      );
    }
    if (speedBasisPoints <= 0) {
      throw const RunningPaceCalculationException(
        'invalid_speed_percentage',
        'Benchmark-speed percentage must be positive.',
      );
    }
    return ExactCanonicalPace(
      numeratorMillisecondsPerKilometre: benchmarkDurationMilliseconds * 2000,
      denominator: speedBasisPoints,
    );
  }

  ExactCanonicalPaceRange calculateRange({
    required int benchmarkDurationMilliseconds,
    required int minimumSpeedBasisPoints,
    required int maximumSpeedBasisPoints,
  }) {
    if (minimumSpeedBasisPoints <= 0 || maximumSpeedBasisPoints <= 0) {
      throw const RunningPaceCalculationException(
        'invalid_speed_percentage',
        'Benchmark-speed percentages must be positive.',
      );
    }
    if (minimumSpeedBasisPoints >= maximumSpeedBasisPoints) {
      throw const RunningPaceCalculationException(
        'invalid_speed_range',
        'Minimum benchmark-speed percentage must be less than maximum.',
      );
    }

    // Pace is inverse to speed: the maximum speed is the faster/lower pace.
    return ExactCanonicalPaceRange(
      fasterPace: calculate(
        benchmarkDurationMilliseconds: benchmarkDurationMilliseconds,
        speedBasisPoints: maximumSpeedBasisPoints,
      ),
      slowerPace: calculate(
        benchmarkDurationMilliseconds: benchmarkDurationMilliseconds,
        speedBasisPoints: minimumSpeedBasisPoints,
      ),
    );
  }
}

int _greatestCommonDivisor(int left, int right) {
  var a = left.abs();
  var b = right.abs();
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return a;
}
