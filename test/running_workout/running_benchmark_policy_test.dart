import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RunningCivilDate date(int year, int month, int day) =>
      RunningCivilDate(year: year, month: month, day: day);

  RunningBenchmarkEvidence evidence({
    String evidenceId = 'benchmark-a',
    String athleteId = 'athlete-a',
    int distanceMetres = 5000,
    int durationMilliseconds = 20 * 60 * 1000,
    RunningCivilDate? localTestDate,
    String timezone = 'Asia/Makassar',
    RunningBenchmarkSourceKind sourceKind = RunningBenchmarkSourceKind.cohort,
    RunningBenchmarkDeclaration declaration =
        RunningBenchmarkDeclaration.completedFiveKilometreTest,
    RunningBenchmarkSurfaceContext surfaceContext =
        RunningBenchmarkSurfaceContext.outdoor,
  }) {
    return RunningBenchmarkEvidence(
      evidenceId: evidenceId,
      athleteId: athleteId,
      distanceMetres: distanceMetres,
      elapsedDurationMilliseconds: durationMilliseconds,
      localTestDate: localTestDate ?? date(2026, 1, 1),
      ianaTimezone: timezone,
      provenance: RunningBenchmarkProvenance(
        sourceKind: sourceKind,
        sourceReference: 'source:$evidenceId',
      ),
      declaration: declaration,
      surfaceContext: surfaceContext,
    );
  }

  RunningPaceCalculationPolicy policy({
    int freshnessDays = 90,
    bool cohortEligible = true,
    bool manualEligible = true,
    bool externalEligible = false,
  }) {
    return RunningPaceCalculationPolicy(
      policyId: 'policy:test',
      policyVersion: 3,
      methodId: 'five_kilometre_speed_percentage',
      methodVersion: 2,
      benchmarkEligibility: RunningBenchmarkEligibilityRules(
        cohortCompletedTestsEligible: cohortEligible,
        manualCompletedTestsEligible: manualEligible,
        externalCompletedTestsEligible: externalEligible,
      ),
      freshnessLocalCivilDays: freshnessDays,
      minimumSpeedBasisPoints: 7000,
      maximumSpeedBasisPoints: 8000,
      displayRounding: RunningPaceDisplayRoundingPolicy(
        incrementMillisecondsPerKilometre: 1000,
        direction: CanonicalPaceRounding.nearest,
      ),
    );
  }

  const selector = RunningBenchmarkSelector();

  test('evidence retains exact athlete-scoped 5 km facts and provenance', () {
    final result = evidence();

    expect(result.evidenceId, 'benchmark-a');
    expect(result.athleteId, 'athlete-a');
    expect(result.distanceMetres, 5000);
    expect(result.elapsedDurationMilliseconds, 1200000);
    expect(result.localTestDate, date(2026, 1, 1));
    expect(result.ianaTimezone, 'Asia/Makassar');
    expect(result.provenance.sourceKind, RunningBenchmarkSourceKind.cohort);
    expect(result.provenance.sourceReference, 'source:benchmark-a');
    expect(result.surfaceContext, RunningBenchmarkSurfaceContext.outdoor);
  });

  test('impossible and incomplete evidence fails with typed codes', () {
    expect(
      () => evidence(evidenceId: ' '),
      throwsCode('missing_benchmark_identity'),
    );
    expect(() => evidence(athleteId: ''), throwsCode('missing_athlete_scope'));
    expect(
      () => evidence(distanceMetres: 4999),
      throwsCode('invalid_benchmark_distance'),
    );
    expect(
      () => evidence(durationMilliseconds: 0),
      throwsCode('invalid_benchmark_duration'),
    );
    expect(
      () => evidence(timezone: 'UTC+8'),
      throwsCode('invalid_iana_timezone'),
    );
    expect(() => date(2026, 2, 30), throwsCode('invalid_local_date'));
    expect(
      () => RunningBenchmarkProvenance(
        sourceKind: RunningBenchmarkSourceKind.manual,
        sourceReference: ' ',
      ),
      throwsCode('missing_benchmark_provenance'),
    );
  });

  test(
    'manual evidence qualifies only when declared as a completed 5 km test',
    () {
      final completedTest = evidence(
        evidenceId: 'manual-test',
        sourceKind: RunningBenchmarkSourceKind.manual,
      );
      final arbitraryActivity = evidence(
        evidenceId: 'manual-activity',
        sourceKind: RunningBenchmarkSourceKind.manual,
        declaration: RunningBenchmarkDeclaration.fiveKilometreActivity,
      );

      expect(policy().benchmarkEligibility.permits(completedTest), isTrue);
      expect(policy().benchmarkEligibility.permits(arbitraryActivity), isFalse);
    },
  );

  test(
    'policy carries explicit versions, eligibility, range, and rounding',
    () {
      final result = policy();

      expect(result.policyVersion, 3);
      expect(result.methodVersion, 2);
      expect(result.freshnessLocalCivilDays, 90);
      expect(result.minimumSpeedBasisPoints, 7000);
      expect(result.maximumSpeedBasisPoints, 8000);

      final calculated = result.calculateRange(evidence());
      expect(result.displayRounding.apply(calculated.fasterPace), 300000);
      expect(result.displayRounding.apply(calculated.slowerPace), 343000);
    },
  );

  test('freshness includes local civil day 90 and excludes day 91', () {
    final benchmark = evidence(localTestDate: date(2026, 1, 1));

    final day90 = selector.select(
      policy: policy(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 4, 1),
      ianaTimezone: 'Asia/Makassar',
      evidence: [benchmark],
    );
    final day91 = selector.select(
      policy: policy(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 4, 2),
      ianaTimezone: 'Asia/Makassar',
      evidence: [benchmark],
    );

    expect(day90, isA<RunningBenchmarkSelectionSuccess>());
    expect((day90 as RunningBenchmarkSelectionSuccess).ageLocalCivilDays, 90);
    expect(
      (day91 as RunningBenchmarkSelectionFailure).code,
      RunningBenchmarkSelectionFailureCode.noFreshEvidence,
    );
  });

  test('freshness uses civil days across a timezone offset boundary', () {
    final benchmark = evidence(
      localTestDate: date(2026, 3, 1),
      timezone: 'Europe/London',
    );

    final result = selector.select(
      policy: policy(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 5, 30),
      ianaTimezone: 'Europe/London',
      evidence: [benchmark],
    );

    expect(result, isA<RunningBenchmarkSelectionSuccess>());
    expect((result as RunningBenchmarkSelectionSuccess).ageLocalCivilDays, 90);
  });

  test(
    'timezone authority must match instead of silently converting dates',
    () {
      final result = selector.select(
        policy: policy(),
        athleteId: 'athlete-a',
        evaluationLocalDate: date(2026, 1, 2),
        ianaTimezone: 'Pacific/Auckland',
        evidence: [evidence(timezone: 'Asia/Makassar')],
      );

      expect(
        (result as RunningBenchmarkSelectionFailure).code,
        RunningBenchmarkSelectionFailureCode.noTimezoneMatchedEvidence,
      );
    },
  );

  test('selection is newest-first then stable identity for equal dates', () {
    final result = selector.select(
      policy: policy(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 4, 1),
      ianaTimezone: 'Asia/Makassar',
      evidence: [
        evidence(evidenceId: 'z-old', localTestDate: date(2026, 3, 1)),
        evidence(evidenceId: 'z-tie', localTestDate: date(2026, 3, 15)),
        evidence(evidenceId: 'a-tie', localTestDate: date(2026, 3, 15)),
      ],
    );

    expect(
      (result as RunningBenchmarkSelectionSuccess).evidence.evidenceId,
      'a-tie',
    );
  });

  test('duplicate stable identities fail instead of using input order', () {
    final result = selector.select(
      policy: policy(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 4, 1),
      ianaTimezone: 'Asia/Makassar',
      evidence: [
        evidence(evidenceId: 'duplicate'),
        evidence(evidenceId: 'duplicate', durationMilliseconds: 19 * 60 * 1000),
      ],
    );

    expect(
      (result as RunningBenchmarkSelectionFailure).code,
      RunningBenchmarkSelectionFailureCode.duplicateEvidenceIdentity,
    );
  });

  test('none-qualified outcomes use typed failure reasons', () {
    final noEvidence = selector.select(
      policy: policy(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 1, 2),
      ianaTimezone: 'Asia/Makassar',
      evidence: const [],
    );
    final wrongAthlete = selector.select(
      policy: policy(),
      athleteId: 'athlete-b',
      evaluationLocalDate: date(2026, 1, 2),
      ianaTimezone: 'Asia/Makassar',
      evidence: [evidence()],
    );
    final arbitraryActivity = selector.select(
      policy: policy(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 1, 2),
      ianaTimezone: 'Asia/Makassar',
      evidence: [
        evidence(
          declaration: RunningBenchmarkDeclaration.fiveKilometreActivity,
        ),
      ],
    );

    expect(
      (noEvidence as RunningBenchmarkSelectionFailure).code,
      RunningBenchmarkSelectionFailureCode.noEvidence,
    );
    expect(
      (wrongAthlete as RunningBenchmarkSelectionFailure).code,
      RunningBenchmarkSelectionFailureCode.noAthleteScopedEvidence,
    );
    expect(
      (arbitraryActivity as RunningBenchmarkSelectionFailure).code,
      RunningBenchmarkSelectionFailureCode.noEligibleCompletedTest,
    );
  });
}

Matcher throwsCode(String code) {
  return throwsA(
    isA<RunningBenchmarkDomainException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );
}
