import 'running_pace_calculation.dart';

enum RunningBenchmarkSourceKind { cohort, manual, external }

enum RunningBenchmarkDeclaration {
  completedFiveKilometreTest,
  fiveKilometreActivity,
}

class RunningBenchmarkDomainException implements Exception {
  const RunningBenchmarkDomainException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RunningBenchmarkDomainException($code): $message';
}

class RunningCivilDate implements Comparable<RunningCivilDate> {
  factory RunningCivilDate({
    required int year,
    required int month,
    required int day,
  }) {
    if (year < 1 || year > 9999) {
      throw const RunningBenchmarkDomainException(
        'invalid_local_date',
        'Benchmark local date must be a valid civil calendar date.',
      );
    }
    final carrier = DateTime.utc(year, month, day);
    if (carrier.year != year || carrier.month != month || carrier.day != day) {
      throw const RunningBenchmarkDomainException(
        'invalid_local_date',
        'Benchmark local date must be a valid civil calendar date.',
      );
    }
    return RunningCivilDate._(year, month, day);
  }

  const RunningCivilDate._(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  DateTime get _utcCalendarCarrier => DateTime.utc(year, month, day);

  int calendarDaysUntil(RunningCivilDate other) {
    return other._utcCalendarCarrier.difference(_utcCalendarCarrier).inDays;
  }

  @override
  int compareTo(RunningCivilDate other) {
    return _utcCalendarCarrier.compareTo(other._utcCalendarCarrier);
  }

  @override
  bool operator ==(Object other) {
    return other is RunningCivilDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

class RunningBenchmarkProvenance {
  factory RunningBenchmarkProvenance({
    required RunningBenchmarkSourceKind sourceKind,
    required String sourceReference,
  }) {
    final reference = sourceReference.trim();
    if (reference.isEmpty) {
      throw const RunningBenchmarkDomainException(
        'missing_benchmark_provenance',
        'Benchmark provenance requires a stable source reference.',
      );
    }
    return RunningBenchmarkProvenance._(sourceKind, reference);
  }

  const RunningBenchmarkProvenance._(this.sourceKind, this.sourceReference);

  final RunningBenchmarkSourceKind sourceKind;
  final String sourceReference;
}

class RunningBenchmarkEvidence {
  factory RunningBenchmarkEvidence({
    required String evidenceId,
    required String athleteId,
    required int distanceMetres,
    required int elapsedDurationMilliseconds,
    required RunningCivilDate localTestDate,
    required String ianaTimezone,
    required RunningBenchmarkProvenance provenance,
    required RunningBenchmarkDeclaration declaration,
  }) {
    final canonicalEvidenceId = evidenceId.trim();
    final canonicalAthleteId = athleteId.trim();
    final canonicalTimezone = ianaTimezone.trim();
    if (canonicalEvidenceId.isEmpty) {
      throw const RunningBenchmarkDomainException(
        'missing_benchmark_identity',
        'Benchmark evidence requires a stable identity.',
      );
    }
    if (canonicalAthleteId.isEmpty) {
      throw const RunningBenchmarkDomainException(
        'missing_athlete_scope',
        'Benchmark evidence requires an athlete scope.',
      );
    }
    if (distanceMetres != fiveKilometres) {
      throw const RunningBenchmarkDomainException(
        'invalid_benchmark_distance',
        'Initial B2 benchmark evidence must be exactly 5000 metres.',
      );
    }
    if (elapsedDurationMilliseconds <= 0) {
      throw const RunningBenchmarkDomainException(
        'invalid_benchmark_duration',
        'Benchmark elapsed duration must be positive.',
      );
    }
    if (!_isIanaTimezoneIdentifier(canonicalTimezone)) {
      throw const RunningBenchmarkDomainException(
        'invalid_iana_timezone',
        'Benchmark timezone must be a non-offset IANA identifier.',
      );
    }
    return RunningBenchmarkEvidence._(
      evidenceId: canonicalEvidenceId,
      athleteId: canonicalAthleteId,
      distanceMetres: distanceMetres,
      elapsedDurationMilliseconds: elapsedDurationMilliseconds,
      localTestDate: localTestDate,
      ianaTimezone: canonicalTimezone,
      provenance: provenance,
      declaration: declaration,
    );
  }

  const RunningBenchmarkEvidence._({
    required this.evidenceId,
    required this.athleteId,
    required this.distanceMetres,
    required this.elapsedDurationMilliseconds,
    required this.localTestDate,
    required this.ianaTimezone,
    required this.provenance,
    required this.declaration,
  });

  static const fiveKilometres = 5000;

  final String evidenceId;
  final String athleteId;
  final int distanceMetres;
  final int elapsedDurationMilliseconds;
  final RunningCivilDate localTestDate;
  final String ianaTimezone;
  final RunningBenchmarkProvenance provenance;
  final RunningBenchmarkDeclaration declaration;
}

class RunningBenchmarkEligibilityRules {
  const RunningBenchmarkEligibilityRules({
    required this.cohortCompletedTestsEligible,
    required this.manualCompletedTestsEligible,
    required this.externalCompletedTestsEligible,
  });

  final bool cohortCompletedTestsEligible;
  final bool manualCompletedTestsEligible;
  final bool externalCompletedTestsEligible;

  bool permits(RunningBenchmarkEvidence evidence) {
    if (evidence.declaration !=
        RunningBenchmarkDeclaration.completedFiveKilometreTest) {
      return false;
    }
    return switch (evidence.provenance.sourceKind) {
      RunningBenchmarkSourceKind.cohort => cohortCompletedTestsEligible,
      RunningBenchmarkSourceKind.manual => manualCompletedTestsEligible,
      RunningBenchmarkSourceKind.external => externalCompletedTestsEligible,
    };
  }

  bool get permitsAnyCompletedTest =>
      cohortCompletedTestsEligible ||
      manualCompletedTestsEligible ||
      externalCompletedTestsEligible;
}

class RunningPaceDisplayRoundingPolicy {
  factory RunningPaceDisplayRoundingPolicy({
    required int incrementMillisecondsPerKilometre,
    required CanonicalPaceRounding direction,
  }) {
    if (incrementMillisecondsPerKilometre <= 0) {
      throw const RunningBenchmarkDomainException(
        'invalid_display_rounding_increment',
        'Display rounding increment must be positive.',
      );
    }
    return RunningPaceDisplayRoundingPolicy._(
      incrementMillisecondsPerKilometre,
      direction,
    );
  }

  const RunningPaceDisplayRoundingPolicy._(
    this.incrementMillisecondsPerKilometre,
    this.direction,
  );

  final int incrementMillisecondsPerKilometre;
  final CanonicalPaceRounding direction;

  int apply(ExactCanonicalPace pace) {
    return pace.roundToIncrement(incrementMillisecondsPerKilometre, direction);
  }
}

class RunningPaceCalculationPolicy {
  factory RunningPaceCalculationPolicy({
    required String policyId,
    required int policyVersion,
    required String methodId,
    required int methodVersion,
    required RunningBenchmarkEligibilityRules benchmarkEligibility,
    required int freshnessLocalCivilDays,
    required int minimumSpeedBasisPoints,
    required int maximumSpeedBasisPoints,
    required RunningPaceDisplayRoundingPolicy displayRounding,
  }) {
    final canonicalPolicyId = policyId.trim();
    final canonicalMethodId = methodId.trim();
    if (canonicalPolicyId.isEmpty || policyVersion <= 0) {
      throw const RunningBenchmarkDomainException(
        'invalid_policy_identity',
        'Calculation policy requires an identity and positive version.',
      );
    }
    if (canonicalMethodId.isEmpty || methodVersion <= 0) {
      throw const RunningBenchmarkDomainException(
        'invalid_method_identity',
        'Calculation method requires an identity and positive version.',
      );
    }
    if (!benchmarkEligibility.permitsAnyCompletedTest) {
      throw const RunningBenchmarkDomainException(
        'empty_benchmark_eligibility',
        'Calculation policy must admit at least one completed-test source.',
      );
    }
    if (freshnessLocalCivilDays < 0) {
      throw const RunningBenchmarkDomainException(
        'invalid_freshness_window',
        'Freshness in athlete-local civil days cannot be negative.',
      );
    }
    if (minimumSpeedBasisPoints <= 0 ||
        maximumSpeedBasisPoints <= minimumSpeedBasisPoints) {
      throw const RunningBenchmarkDomainException(
        'invalid_policy_speed_range',
        'Policy speed range must be positive and strictly increasing.',
      );
    }
    return RunningPaceCalculationPolicy._(
      policyId: canonicalPolicyId,
      policyVersion: policyVersion,
      methodId: canonicalMethodId,
      methodVersion: methodVersion,
      benchmarkEligibility: benchmarkEligibility,
      freshnessLocalCivilDays: freshnessLocalCivilDays,
      minimumSpeedBasisPoints: minimumSpeedBasisPoints,
      maximumSpeedBasisPoints: maximumSpeedBasisPoints,
      displayRounding: displayRounding,
    );
  }

  const RunningPaceCalculationPolicy._({
    required this.policyId,
    required this.policyVersion,
    required this.methodId,
    required this.methodVersion,
    required this.benchmarkEligibility,
    required this.freshnessLocalCivilDays,
    required this.minimumSpeedBasisPoints,
    required this.maximumSpeedBasisPoints,
    required this.displayRounding,
  });

  final String policyId;
  final int policyVersion;
  final String methodId;
  final int methodVersion;
  final RunningBenchmarkEligibilityRules benchmarkEligibility;
  final int freshnessLocalCivilDays;
  final int minimumSpeedBasisPoints;
  final int maximumSpeedBasisPoints;
  final RunningPaceDisplayRoundingPolicy displayRounding;

  ExactCanonicalPaceRange calculateRange(
    RunningBenchmarkEvidence evidence, {
    FiveKilometreBenchmarkSpeedCalculator calculator =
        const FiveKilometreBenchmarkSpeedCalculator(),
  }) {
    return calculator.calculateRange(
      benchmarkDurationMilliseconds: evidence.elapsedDurationMilliseconds,
      minimumSpeedBasisPoints: minimumSpeedBasisPoints,
      maximumSpeedBasisPoints: maximumSpeedBasisPoints,
    );
  }
}

enum RunningBenchmarkSelectionFailureCode {
  noEvidence,
  duplicateEvidenceIdentity,
  noAthleteScopedEvidence,
  noTimezoneMatchedEvidence,
  noEligibleCompletedTest,
  noFreshEvidence,
}

sealed class RunningBenchmarkSelectionResult {
  const RunningBenchmarkSelectionResult();
}

class RunningBenchmarkSelectionSuccess extends RunningBenchmarkSelectionResult {
  const RunningBenchmarkSelectionSuccess({
    required this.evidence,
    required this.ageLocalCivilDays,
  });

  final RunningBenchmarkEvidence evidence;
  final int ageLocalCivilDays;
}

class RunningBenchmarkSelectionFailure extends RunningBenchmarkSelectionResult {
  const RunningBenchmarkSelectionFailure(this.code);

  final RunningBenchmarkSelectionFailureCode code;
}

class RunningBenchmarkSelector {
  const RunningBenchmarkSelector();

  RunningBenchmarkSelectionResult select({
    required RunningPaceCalculationPolicy policy,
    required String athleteId,
    required RunningCivilDate evaluationLocalDate,
    required String ianaTimezone,
    required Iterable<RunningBenchmarkEvidence> evidence,
  }) {
    final all = evidence.toList(growable: false);
    if (all.isEmpty) {
      return const RunningBenchmarkSelectionFailure(
        RunningBenchmarkSelectionFailureCode.noEvidence,
      );
    }
    final identities = <String>{};
    if (all.any((candidate) => !identities.add(candidate.evidenceId))) {
      return const RunningBenchmarkSelectionFailure(
        RunningBenchmarkSelectionFailureCode.duplicateEvidenceIdentity,
      );
    }

    final athleteScope = athleteId.trim();
    final athleteEvidence = all
        .where((candidate) => candidate.athleteId == athleteScope)
        .toList(growable: false);
    if (athleteEvidence.isEmpty) {
      return const RunningBenchmarkSelectionFailure(
        RunningBenchmarkSelectionFailureCode.noAthleteScopedEvidence,
      );
    }

    final timezone = ianaTimezone.trim();
    final timezoneEvidence = athleteEvidence
        .where((candidate) => candidate.ianaTimezone == timezone)
        .toList(growable: false);
    if (timezoneEvidence.isEmpty) {
      return const RunningBenchmarkSelectionFailure(
        RunningBenchmarkSelectionFailureCode.noTimezoneMatchedEvidence,
      );
    }

    final eligible = timezoneEvidence
        .where(policy.benchmarkEligibility.permits)
        .toList(growable: false);
    if (eligible.isEmpty) {
      return const RunningBenchmarkSelectionFailure(
        RunningBenchmarkSelectionFailureCode.noEligibleCompletedTest,
      );
    }

    final fresh = <(RunningBenchmarkEvidence, int)>[];
    for (final candidate in eligible) {
      final age = candidate.localTestDate.calendarDaysUntil(
        evaluationLocalDate,
      );
      if (age >= 0 && age <= policy.freshnessLocalCivilDays) {
        fresh.add((candidate, age));
      }
    }
    if (fresh.isEmpty) {
      return const RunningBenchmarkSelectionFailure(
        RunningBenchmarkSelectionFailureCode.noFreshEvidence,
      );
    }

    fresh.sort((left, right) {
      final byDate = right.$1.localTestDate.compareTo(left.$1.localTestDate);
      if (byDate != 0) return byDate;
      return left.$1.evidenceId.compareTo(right.$1.evidenceId);
    });
    return RunningBenchmarkSelectionSuccess(
      evidence: fresh.first.$1,
      ageLocalCivilDays: fresh.first.$2,
    );
  }
}

final RegExp _ianaTimezonePath = RegExp(
  r'^[A-Za-z_]+/[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$',
);

bool _isIanaTimezoneIdentifier(String value) {
  if (value.isEmpty ||
      value.startsWith('Etc/') ||
      value.startsWith('posix/') ||
      value.startsWith('right/')) {
    return false;
  }
  return _ianaTimezonePath.hasMatch(value);
}
