import 'dart:convert';

import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const freezer = RunningTargetSnapshotFreezer();

  RunningCivilDate date(int year, int month, int day) =>
      RunningCivilDate(year: year, month: month, day: day);

  RunningPaceCalculationPolicy policy({
    int policyVersion = 4,
    int methodVersion = 7,
    int minimumSpeedBasisPoints = 8123,
    int maximumSpeedBasisPoints = 9345,
  }) {
    return RunningPaceCalculationPolicy(
      policyId: 'coach-authored-policy',
      policyVersion: policyVersion,
      methodId: 'percentage-of-five-kilometre-speed',
      methodVersion: methodVersion,
      benchmarkEligibility: const RunningBenchmarkEligibilityRules(
        cohortCompletedTestsEligible: true,
        manualCompletedTestsEligible: true,
        externalCompletedTestsEligible: false,
      ),
      freshnessLocalCivilDays: 90,
      minimumSpeedBasisPoints: minimumSpeedBasisPoints,
      maximumSpeedBasisPoints: maximumSpeedBasisPoints,
      displayRounding: RunningPaceDisplayRoundingPolicy(
        incrementMillisecondsPerKilometre: 1000,
        direction: CanonicalPaceRounding.nearest,
      ),
    );
  }

  RunningBenchmarkEvidence benchmark({
    String evidenceId = 'five-k-test-a',
    int elapsedDurationMilliseconds = 21 * 60 * 1000,
    RunningCivilDate? localTestDate,
    RunningBenchmarkDeclaration declaration =
        RunningBenchmarkDeclaration.completedFiveKilometreTest,
    RunningBenchmarkSurfaceContext surface =
        RunningBenchmarkSurfaceContext.treadmill,
  }) {
    return RunningBenchmarkEvidence(
      evidenceId: evidenceId,
      athleteId: 'athlete-a',
      distanceMetres: 5000,
      elapsedDurationMilliseconds: elapsedDurationMilliseconds,
      localTestDate: localTestDate ?? date(2026, 7, 1),
      ianaTimezone: 'Asia/Makassar',
      provenance: RunningBenchmarkProvenance(
        sourceKind: RunningBenchmarkSourceKind.manual,
        sourceReference: 'manual:$evidenceId',
      ),
      declaration: declaration,
      surfaceContext: surface,
    );
  }

  RunningTargetStepScope scope() => RunningTargetStepScope(
    workoutId: 'rw1:coach-authored',
    stepIds: const ['work:1', 'work:2'],
  );

  FrozenRunningTargetSnapshot freeze({
    FrozenRunningTargetSnapshot? existing,
    RunningPaceCalculationPolicy? authoredPolicy,
    Iterable<RunningBenchmarkEvidence>? evidence,
    DateTime? commitmentAtUtc,
    RunningTargetFreezeSource source = RunningTargetFreezeSource.inAppStart,
  }) {
    return freezer.freeze(
      existing: existing,
      authoredPolicy: authoredPolicy ?? policy(),
      scope: scope(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 7, 2),
      ianaTimezone: 'Asia/Makassar',
      evidence: evidence ?? [benchmark()],
      commitmentAtUtc: commitmentAtUtc ?? DateTime.utc(2026, 7, 2, 1, 2, 3),
      freezeSource: source,
    );
  }

  test('freezes the complete advisory calculation authority', () {
    final snapshot = freeze() as FrozenCalculatedRunningTarget;
    final json = snapshot.toJson();

    expect(json['schema_version'], 1);
    expect(json['state'], 'calculated');
    expect(json['authority'], 'advisory');
    expect(snapshot.policy.policyVersion, 4);
    expect(snapshot.policy.methodVersion, 7);
    expect(snapshot.policy.minimumSpeedBasisPoints, 8123);
    expect(snapshot.policy.maximumSpeedBasisPoints, 9345);
    expect(snapshot.scope.stepIds, ['work:1', 'work:2']);
    expect(snapshot.benchmark.evidenceId, 'five-k-test-a');
    expect(snapshot.benchmark.distanceMetres, 5000);
    expect(snapshot.benchmark.elapsedDurationMilliseconds, 1260000);
    expect(
      snapshot.benchmark.surfaceContext,
      RunningBenchmarkSurfaceContext.treadmill,
    );
    expect(snapshot.freezeSource, RunningTargetFreezeSource.inAppStart);
    expect(snapshot.frozenAtUtc, DateTime.utc(2026, 7, 2, 1, 2, 3));

    final policyJson = json['policy']! as Map<String, Object>;
    final rounding = policyJson['display_rounding']! as Map<String, Object>;
    expect(rounding['increment_milliseconds_per_kilometre'], 1000);
    expect(rounding['direction'], 'nearest');
    final benchmarkJson = json['benchmark']! as Map<String, Object>;
    expect(benchmarkJson['duration_basis'], 'elapsed_including_pauses');
    expect(benchmarkJson['source_kind'], 'manual');
    expect(benchmarkJson['surface_context'], 'treadmill');
    expect(jsonEncode(json), contains('calculated_exact_range'));
    expect(jsonEncode(json), contains('elapsed_duration_milliseconds'));
  });

  test('policy percentages and step scope are always explicitly authored', () {
    final snapshot =
        freeze(
              authoredPolicy: policy(
                minimumSpeedBasisPoints: 8234,
                maximumSpeedBasisPoints: 9123,
              ),
            )
            as FrozenCalculatedRunningTarget;

    expect(snapshot.policy.minimumSpeedBasisPoints, 8234);
    expect(snapshot.policy.maximumSpeedBasisPoints, 9123);
    expect(snapshot.scope.workoutId, 'rw1:coach-authored');
    expect(snapshot.scope.stepIds, hasLength(2));
  });

  test('no authored numeric policy freezes an honest intent-only state', () {
    final snapshot =
        freezer.freeze(
              authoredPolicy: null,
              scope: scope(),
              athleteId: 'athlete-a',
              evaluationLocalDate: date(2026, 7, 2),
              ianaTimezone: 'Asia/Makassar',
              evidence: [benchmark()],
              commitmentAtUtc: DateTime.utc(2026, 7, 2),
              freezeSource: RunningTargetFreezeSource.inAppStart,
            )
            as FrozenIntentOnlyRunningTarget;

    expect(snapshot.reason, RunningIntentOnlyReason.noAuthoredTargetPolicy);
    expect(snapshot.policy, isNull);
    expect(snapshot.toJson(), isNot(contains('calculated_exact_range')));
  });

  test('missing, stale, and ineligible evidence remain intent-only', () {
    FrozenIntentOnlyRunningTarget result(
      Iterable<RunningBenchmarkEvidence> evidence,
      RunningCivilDate evaluationDate,
    ) {
      return freezer.freeze(
            authoredPolicy: policy(),
            scope: scope(),
            athleteId: 'athlete-a',
            evaluationLocalDate: evaluationDate,
            ianaTimezone: 'Asia/Makassar',
            evidence: evidence,
            commitmentAtUtc: DateTime.utc(2026, 10, 1),
            freezeSource: RunningTargetFreezeSource.inAppStart,
          )
          as FrozenIntentOnlyRunningTarget;
    }

    expect(
      result(const [], date(2026, 7, 2)).reason,
      RunningIntentOnlyReason.noEvidence,
    );
    expect(
      result([benchmark()], date(2026, 10, 1)).reason,
      RunningIntentOnlyReason.noFreshEvidence,
    );
    expect(
      result([
        benchmark(
          declaration: RunningBenchmarkDeclaration.fiveKilometreActivity,
        ),
      ], date(2026, 7, 2)).reason,
      RunningIntentOnlyReason.noEligibleCompletedTest,
    );
  });

  test('retry returns the same snapshot despite a later benchmark', () {
    final first = freeze() as FrozenCalculatedRunningTarget;
    final retry = freeze(
      existing: first,
      authoredPolicy: policy(
        policyVersion: 5,
        methodVersion: 8,
        minimumSpeedBasisPoints: 8501,
        maximumSpeedBasisPoints: 9876,
      ),
      evidence: [
        benchmark(
          evidenceId: 'later-faster-test',
          elapsedDurationMilliseconds: 18 * 60 * 1000,
          localTestDate: date(2026, 7, 2),
        ),
      ],
      commitmentAtUtc: DateTime.utc(2026, 7, 3),
    );

    expect(identical(retry, first), isTrue);
    expect(
      (retry as FrozenCalculatedRunningTarget).benchmark.evidenceId,
      'five-k-test-a',
    );
    expect(retry.policy.policyVersion, 4);
    expect(retry.frozenAtUtc, DateTime.utc(2026, 7, 2, 1, 2, 3));
  });

  test('intent-only retry also remains frozen after evidence appears', () {
    final first = freezer.freeze(
      authoredPolicy: policy(),
      scope: scope(),
      athleteId: 'athlete-a',
      evaluationLocalDate: date(2026, 7, 2),
      ianaTimezone: 'Asia/Makassar',
      evidence: const [],
      commitmentAtUtc: DateTime.utc(2026, 7, 2),
      freezeSource: RunningTargetFreezeSource.inAppStart,
    );
    final retry = freeze(existing: first, evidence: [benchmark()]);

    expect(identical(retry, first), isTrue);
    expect(
      (retry as FrozenIntentOnlyRunningTarget).reason,
      RunningIntentOnlyReason.noEvidence,
    );
  });

  test('device export is represented without becoming a live integration', () {
    final snapshot = freeze(source: RunningTargetFreezeSource.deviceExport);
    expect(snapshot.freezeSource, RunningTargetFreezeSource.deviceExport);
    expect(snapshot.toJson()['freeze_source'], 'device_export');
  });

  test('scope and timestamp validation fail closed', () {
    expect(
      () => RunningTargetStepScope(workoutId: '', stepIds: const ['step']),
      throwsSnapshotCode('missing_workout_scope'),
    );
    expect(
      () => RunningTargetStepScope(workoutId: 'workout', stepIds: const []),
      throwsSnapshotCode('missing_step_scope'),
    );
    expect(
      () => RunningTargetStepScope(
        workoutId: 'workout',
        stepIds: const ['step', 'step'],
      ),
      throwsSnapshotCode('duplicate_step_scope'),
    );
    expect(
      () => freeze(commitmentAtUtc: DateTime(2026, 7, 2)),
      throwsSnapshotCode('non_utc_freeze_timestamp'),
    );
  });
}

Matcher throwsSnapshotCode(String code) {
  return throwsA(
    isA<RunningTargetSnapshotException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );
}
