import 'dart:io';

import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/workout_player/models/previous_performance_snapshot.dart';
import 'package:cohort_platform/staging/s17_adaptation_harness.dart';
import 'package:cohort_platform/staging/s17_completion_harness.dart';
import 'package:cohort_platform/staging/s17_occurrence_baseline.dart';
import 'package:cohort_platform/staging/s17_previous_performance_harness.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_schedule_ops_harness.dart';
import 'package:cohort_platform/staging/s17_schedule_preparation.dart';
import 'package:cohort_platform/staging/s17_staging_journey_matrix.dart';
import 'package:cohort_platform/staging/s17_staging_runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B4c occurrence baseline root cause', () {
    test('PROG-S13-ELIG one-slot is authoredProgrammeInsufficientSlots', () {
      const snap = S17OccurrenceBaselineSnapshot(
        authoredExecutableSlotCount: 1,
        projectedOccurrenceCount: 1,
        uncompletedOccurrenceCount: 1,
        completedOrSkippedCount: 0,
        lineageCode: 'PROG-S13-ELIG',
      );
      final d = S17OccurrenceBaseline.diagnose(snap);
      expect(
        d.cause,
        S17OccurrenceBlockerCause.authoredProgrammeInsufficientSlots,
      );
      expect(d.canPrepareViaMultiSlotEnrolment, isTrue);
      expect(S17OccurrenceBaseline.failClosedReason(snap), isNotNull);
    });

    test('preparation path produces ≥2 uncompleted occurrences', () async {
      final prep = S17SchedulePreparation(
        catalogue: _FakeCatalogue(),
        enrolment: _FakeEnrolment(),
        materialise: _FakeMaterialise(),
        projection: _FakeProjection(uncompleted: 3, projected: 3, authored: 3),
      );
      final result = await prep.ensureScheduleOpsBaseline(
        const S17SchedulePreparationRequest(
          athleteId: 'athlete-d',
          currentLineageCode: 'PROG-S13-ELIG',
          currentVersionId: 'one-slot-version',
          currentAssignmentId: 'assign-1',
        ),
        current: const S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: 1,
          projectedOccurrenceCount: 1,
          uncompletedOccurrenceCount: 1,
          completedOrSkippedCount: 0,
          lineageCode: 'PROG-S13-ELIG',
        ),
      );
      expect(result.ok, isTrue);
      expect(result.uncompletedOccurrences, greaterThanOrEqualTo(2));
      expect(result.lineageCode, 'PROG-S15A-STAGING');
    });

    test('insufficient/ambiguous preparation fails closed', () async {
      final prep = S17SchedulePreparation(
        catalogue: _FakeCatalogue(slots: 1),
        enrolment: _FakeEnrolment(),
        materialise: _FakeMaterialise(),
        projection: _FakeProjection(uncompleted: 1, projected: 1, authored: 1),
      );
      final result = await prep.ensureScheduleOpsBaseline(
        const S17SchedulePreparationRequest(
          athleteId: 'athlete-d',
          currentLineageCode: 'PROG-S13-ELIG',
          currentVersionId: 'one-slot-version',
          currentAssignmentId: 'assign-1',
        ),
        current: const S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: 1,
          projectedOccurrenceCount: 1,
          uncompletedOccurrenceCount: 1,
          completedOrSkippedCount: 0,
          lineageCode: 'PROG-S13-ELIG',
        ),
      );
      expect(result.ok, isFalse);
      expect(result.detail, contains('REFUSED'));
    });
  });

  group('Resume mode', () {
    test('cannot create or discover an athlete via creator invocation', () {
      expect(
        S17ResumeMode.mentionsCreatorInvocation(
          'create_s17_athlete_d_fixture.sh',
        ),
        isTrue,
      );
      final runner = File(
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ).readAsStringSync();
      expect(runner.contains('--resume'), isTrue);
      expect(runner.contains('creator_invocation=forbidden'), isTrue);
      expect(
        runner.contains('./tool/staging/create_s17_athlete_d_fixture.sh'),
        isFalse,
      );
    });

    test('operates only from selected unresolved journeys', () {
      final selected = S17ResumeMode.parseSelectedJourneys('C,D,F,G,H,I,J,K');
      expect(selected, S17ResumeMode.unresolvedAfterB4b);
      final order = S17ResumeMode.executionOrderFor(selected);
      expect(order.first, 'F');
      expect(order.indexOf('K') < order.indexOf('C'), isTrue);
    });

    test('A/B/E can remain prerequisites without mutation repeat', () {
      expect(S17ResumeMode.unresolvedAfterB4b.contains('A'), isFalse);
      expect(S17ResumeMode.unresolvedAfterB4b.contains('B'), isFalse);
      expect(S17ResumeMode.unresolvedAfterB4b.contains('E'), isFalse);
      expect(S17ResumeMode.prerequisiteCodes, contains('PREREQ_IDENTITY'));
    });
  });

  group('Previous performance C', () {
    test('matching surfaces; unlike does not; reference-only', () {
      const harness = S17PreviousPerformanceHarness();
      final records = [
        PreviousPerformanceSnapshot(
          exerciseId: 'ex-1',
          sessionType: PreviousPerformanceSessionType.strength,
          performedAt: DateTime.utc(2026, 8, 1),
          repSummary: '5',
          loadSummary: '40',
        ),
        PreviousPerformanceSnapshot(
          exerciseId: 'ex-other',
          sessionType: PreviousPerformanceSessionType.strength,
          performedAt: DateTime.utc(2026, 8, 2),
          repSummary: '9',
        ),
      ];
      final result = harness.run(
        exerciseId: 'ex-1',
        athleteEnteredRecords: records,
        authoredPrescriptionFingerprintBefore: 'fp-a',
        authoredPrescriptionFingerprintAfter: 'fp-a',
        progressionRewritten: false,
      );
      expect(result, S17JourneyResult.pass);
      expect(
        harness.resolver.resolveLatest(exerciseId: 'missing', records: records),
        isNull,
      );
    });
  });

  group('Adaptation D', () {
    test(
      'requires explicit agreement; reject non-mutating; accept in policy',
      () {
        const harness = S17AdaptationHarness();
        const proposal = S17AdaptationProposalView(
          proposalId: 'p1',
          changeKinds: [AdaptationChangeKind.reduceVolume],
          packageFingerprint: 'fp0',
        );
        expect(
          harness
              .evaluate(
                proposal: proposal,
                action: S17AdaptationAthleteAction.none,
                fingerprintBefore: 'fp0',
                fingerprintAfterSuggestionOnly: 'fp0',
                fingerprintAfterAction: 'fp0',
                acceptInvokedExplicitly: false,
                autoApplied: false,
              )
              .result,
          S17JourneyResult.fail,
        );
        expect(
          harness
              .evaluate(
                proposal: proposal,
                action: S17AdaptationAthleteAction.reject,
                fingerprintBefore: 'fp0',
                fingerprintAfterSuggestionOnly: 'fp0',
                fingerprintAfterAction: 'fp0',
                acceptInvokedExplicitly: false,
                autoApplied: false,
              )
              .result,
          S17JourneyResult.pass,
        );
        expect(
          harness
              .evaluate(
                proposal: proposal,
                action: S17AdaptationAthleteAction.accept,
                fingerprintBefore: 'fp0',
                fingerprintAfterSuggestionOnly: 'fp0',
                fingerprintAfterAction: 'fp1',
                acceptInvokedExplicitly: true,
                autoApplied: false,
              )
              .result,
          S17JourneyResult.pass,
        );
        expect(
          harness
              .evaluate(
                proposal: const S17AdaptationProposalView(
                  proposalId: 'p2',
                  changeKinds: [AdaptationChangeKind.rewritePlan],
                  packageFingerprint: 'fp0',
                ),
                action: S17AdaptationAthleteAction.accept,
                fingerprintBefore: 'fp0',
                fingerprintAfterSuggestionOnly: 'fp0',
                fingerprintAfterAction: 'fp1',
                acceptInvokedExplicitly: true,
                autoApplied: false,
              )
              .result,
          S17JourneyResult.fail,
        );
      },
    );
  });

  group('Schedule ops F–J', () {
    const ops = S17ScheduleOpsHarness();
    final before = S17ScheduleOpSnapshot(
      scheduleRevision: 1,
      occurrenceCount: 3,
      orderedSlotIds: ['a', 'b', 'c'],
      orderedDatesIso: ['2026-08-01', '2026-08-02', '2026-08-03'],
      uncompletedCount: 3,
    );

    test('valid move/swap/push/skip and atomic invalid rejection', () {
      expect(
        ops.evaluateMove(
          S17ScheduleOpOutcome(
            applied: true,
            before: before,
            after: S17ScheduleOpSnapshot(
              scheduleRevision: 2,
              occurrenceCount: 3,
              orderedSlotIds: ['a', 'b', 'c'],
              orderedDatesIso: ['2026-08-02', '2026-08-02', '2026-08-03'],
              uncompletedCount: 3,
            ),
            invalidRejectedAtomically: true,
          ),
        ),
        S17JourneyResult.pass,
      );
      expect(
        S17ScheduleOpsHarness.atomicRejectionHolds(
          before: before,
          afterInvalidAttempt: before,
          invalidPreviewReady: false,
        ),
        isTrue,
      );
      expect(
        ops.evaluateSwap(
          S17ScheduleOpOutcome(
            applied: true,
            before: before,
            after: S17ScheduleOpSnapshot(
              scheduleRevision: 3,
              occurrenceCount: 3,
              orderedSlotIds: ['b', 'a', 'c'],
              orderedDatesIso: ['2026-08-01', '2026-08-02', '2026-08-03'],
              uncompletedCount: 3,
            ),
            invalidRejectedAtomically: true,
          ),
        ),
        S17JourneyResult.pass,
      );
      expect(
        ops.evaluatePush(
          S17ScheduleOpOutcome(
            applied: true,
            before: before,
            after: S17ScheduleOpSnapshot(
              scheduleRevision: 4,
              occurrenceCount: 3,
              orderedSlotIds: ['a', 'b', 'c'],
              orderedDatesIso: ['2026-08-02', '2026-08-03', '2026-08-04'],
              uncompletedCount: 3,
            ),
            invalidRejectedAtomically: true,
          ),
        ),
        S17JourneyResult.pass,
      );
      expect(
        ops.evaluateSkip(
          S17ScheduleOpOutcome(
            applied: true,
            before: before,
            after: S17ScheduleOpSnapshot(
              scheduleRevision: 5,
              occurrenceCount: 3,
              orderedSlotIds: ['a', 'b', 'c'],
              orderedDatesIso: ['2026-08-01', '2026-08-02', '2026-08-03'],
              uncompletedCount: 2,
            ),
            invalidRejectedAtomically: true,
          ),
        ),
        S17JourneyResult.pass,
      );
    });

    test('undo restores prior state; horizon leaves unchanged', () {
      expect(
        ops.evaluateUndo(
          beforeSkip: before,
          undo: S17ScheduleOpOutcome(
            applied: true,
            before: before,
            after: before,
            invalidRejectedAtomically: true,
            restoredTo: before,
          ),
          horizonRejectedWithoutMutation: true,
        ),
        S17JourneyResult.pass,
      );
    });
  });

  group('Completion K', () {
    test('binds package/session identity; duplicate cannot advance twice', () {
      const harness = S17CompletionHarness();
      final result = harness.evaluate(
        expectedAssignmentId: 'asg',
        expectedVersionId: 'ver',
        expectedSessionKey: 'key',
        expectedPackageHash: 'hash',
        primary: const S17CompletionAttempt(
          assignmentId: 'asg',
          versionId: 'ver',
          programmedSessionKey: 'key',
          packageContentHash: 'hash',
          athleteEntered: true,
          succeeded: true,
          advancedToSessionOrder: 2,
        ),
        duplicate: const S17CompletionAttempt(
          assignmentId: 'asg',
          versionId: 'ver',
          programmedSessionKey: 'key',
          packageContentHash: 'hash',
          athleteEntered: true,
          succeeded: true,
          advancedToSessionOrder: 2,
          duplicateOfPrior: true,
          createdDuplicateHistory: false,
        ),
        expectedNextSessionOrder: 2,
      );
      expect(result.result, S17JourneyResult.pass);
    });
  });

  group('Safety', () {
    test('production remains unselectable in runtime config', () {
      const config = S17StagingRuntimeConfig(
        enabled: true,
        supabaseUrl: 'https://otnhhdxstdnwccehacku.supabase.co',
        supabaseAnonKey: 'anon',
        athleteEmail:
            's17_stage_20260803T000000Z_abcd1234.athlete.d@example.invalid',
        athletePassword: 'x',
        athleteId: '11111111-1111-1111-1111-111111111111',
        assignmentId: '22222222-2222-2222-2222-222222222222',
        versionId: '33333333-3333-3333-3333-333333333333',
        packageHash: 'hash',
        runMarker: 's17_stage_20260803T000000Z_abcd1234',
        lineageCode: 'PROG-S13-ELIG',
        resumeMode: true,
      );
      expect(config.validationError(), contains('Production'));
    });

    test('no Athlete C reference in new B4c tooling sources', () {
      final paths = [
        'lib/staging/s17_occurrence_baseline.dart',
        'lib/staging/s17_schedule_preparation.dart',
        'lib/staging/s17_resume_mode.dart',
        'lib/staging/s17_adaptation_harness.dart',
        'lib/staging/s17_completion_harness.dart',
        'lib/staging/s17_previous_performance_harness.dart',
        'lib/staging/s17_schedule_ops_harness.dart',
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ];
      final forbidden = RegExp(
        r'Athlete C\b|athlete_c\b|athleteC\b|S15A Staging Athlete C',
      );
      for (final path in paths) {
        expect(
          forbidden.hasMatch(File(path).readAsStringSync()),
          isFalse,
          reason: path,
        );
      }
    });

    test('journeys report independently with all result categories', () {
      expect(S17StagingJourneyMatrix.codes.length, 11);
      final labels = S17JourneyResult.values.map((e) => e.label).toSet();
      expect(labels, containsAll(['PASS', 'FAIL', 'BLOCKED', 'NOT RUN']));
    });
  });
}

class _FakeCatalogue implements S17CatalogueVersionLookup {
  _FakeCatalogue({this.slots = 3});
  final int slots;

  @override
  Future<S17CatalogueVersionRef?> findPublishedByLineage(
    String lineageCode,
  ) async {
    return S17CatalogueVersionRef(
      versionId: 'multi-slot-version',
      lineageCode: lineageCode,
      packageHash: 'hash-multi',
      executableSlotCount: slots,
    );
  }
}

class _FakeEnrolment implements S17AthleteEnrolmentPort {
  @override
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  }) async {
    return S17EnrolmentOutcome(
      ok: true,
      assignmentId: 'assign-multi',
      versionId: versionId,
    );
  }
}

class _FakeMaterialise implements S17PlanMaterialisePort {
  @override
  Future<bool> materialise({
    required String athleteId,
    required String assignmentId,
  }) async => true;
}

class _FakeProjection implements S17ProjectionBaselinePort {
  _FakeProjection({
    required this.uncompleted,
    required this.projected,
    required this.authored,
  });
  final int uncompleted;
  final int projected;
  final int authored;

  @override
  Future<S17OccurrenceBaselineSnapshot> loadBaseline({
    required String athleteId,
    required String assignmentId,
    required String lineageCode,
    required int authoredExecutableSlotCount,
  }) async {
    return S17OccurrenceBaselineSnapshot(
      authoredExecutableSlotCount: authored,
      projectedOccurrenceCount: projected,
      uncompletedOccurrenceCount: uncompleted,
      completedOrSkippedCount: projected - uncompleted,
      lineageCode: lineageCode,
    );
  }
}
