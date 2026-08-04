import 'dart:io';

import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:cohort_platform/staging/s17_journey_diagnosis.dart';
import 'package:cohort_platform/staging/s17_occurrence_baseline.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_schedule_preparation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B4d.5 targeted G,H,I,J selection', () {
    test('1–2. exact selection and order G→H→I→J', () {
      final selected = S17ResumeMode.parseSelectedJourneys('G,H,I,J');
      expect(selected, ['G', 'H', 'I', 'J']);
      expect(S17JourneyDiagnosis.isExactTargetedSelection(selected), isTrue);
      expect(S17ResumeMode.executionOrderFor(selected), ['G', 'H', 'I', 'J']);
      expect(S17JourneyDiagnosis.targetedExecutionOrder(selected), [
        'G',
        'H',
        'I',
        'J',
      ]);
    });

    test(
      '3–7. G reloads distinct-date pair; fails closed; both-side dates',
      () {
        final d1 = SessionOccurrenceDate(year: 2026, month: 8, day: 1);
        final d2 = SessionOccurrenceDate(year: 2026, month: 8, day: 2);
        final d3 = SessionOccurrenceDate(year: 2026, month: 8, day: 3);
        final ok = S17JourneyDiagnosis.selectDistinctDateSwapPair([
          S17OccurrenceDateView(
            sessionSlotId: 'a',
            scheduledDate: d1,
            isUncompleted: true,
          ),
          S17OccurrenceDateView(
            sessionSlotId: 'b',
            scheduledDate: d1,
            isUncompleted: true,
          ),
          S17OccurrenceDateView(
            sessionSlotId: 'c',
            scheduledDate: d3,
            isUncompleted: true,
          ),
        ]);
        expect(ok.ok, isTrue);
        expect(ok.pair!.dateA, isNot(ok.pair!.dateB));

        final blocked = S17JourneyDiagnosis.selectDistinctDateSwapPair([
          S17OccurrenceDateView(
            sessionSlotId: 'a',
            scheduledDate: d2,
            isUncompleted: true,
          ),
          S17OccurrenceDateView(
            sessionSlotId: 'b',
            scheduledDate: d2,
            isUncompleted: true,
          ),
        ]);
        expect(blocked.ok, isFalse);
        expect(blocked.sameDateContamination, isTrue);
      },
    );

    test('8–12. H horizon class and dayDelta<=0 invalid probe', () {
      final from = SessionOccurrenceDate(year: 2026, month: 8, day: 1);
      final unbounded = S17JourneyDiagnosis.classifyInvalidPushProbe(
        horizonEnd: null,
        fromDate: from,
        harnessLargeDelta: 10000,
      );
      expect(unbounded.classification, 'UNBOUNDED_NULL_HORIZON');
      expect(unbounded.dayDeltaForInvalidProbe, 0);
      expect(unbounded.expectPreviewNotReady, isFalse);

      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('invalid_probe=dayDelta<=0'), isTrue);
      expect(entry.contains('UNBOUNDED_NULL_HORIZON'), isTrue);
      expect(entry.contains('harnessLargeDelta: 10000'), isTrue);
      // Invalid probe path must use 0, not 10000 as sole invalid.
      expect(entry.contains('final invalidDelta = 0'), isTrue);
      expect(entry.contains('dayDelta: invalidDelta'), isTrue);
    });

    test('13–20. I→J skip dependency and typed undo classes', () {
      expect(
        S17JourneyDiagnosis.requireSkipUndoTarget(
          latestOperationType: 'skip',
        ).ok,
        isTrue,
      );
      expect(
        S17JourneyDiagnosis.requireSkipUndoTarget(
          latestOperationType: 'push',
        ).detail,
        startsWith('LATEST_NOT_SKIP'),
      );
      expect(
        S17JourneyDiagnosis.requireSkipUndoTarget(
          latestOperationType: null,
        ).detail,
        startsWith('NO_UNDO_RECORD'),
      );
      expect(
        S17JourneyDiagnosis.classifyUndoFailure(
          hasUndoRecord: true,
          latestIsSkip: true,
          incompleteInverse: true,
          previewReady: false,
          applySucceeded: false,
          postconditionOk: false,
        ),
        S17JourneyDiagnosis.undoClassIncompleteInverse,
      );
      expect(
        S17JourneyDiagnosis.classifyUndoFailure(
          hasUndoRecord: true,
          latestIsSkip: true,
          incompleteInverse: false,
          previewReady: true,
          applySucceeded: true,
          postconditionOk: false,
          expectedRevision: 3,
          observedRevision: 5,
        ),
        S17JourneyDiagnosis.undoClassRevisionMismatch,
      );
      expect(
        S17JourneyDiagnosis.classifyUndoFailure(
          hasUndoRecord: true,
          latestIsSkip: true,
          incompleteInverse: false,
          previewReady: false,
          applySucceeded: false,
          postconditionOk: false,
        ),
        S17JourneyDiagnosis.undoClassRejected,
      );
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('J requires fresh I Skip'), isTrue);
      expect(entry.contains('Blocked: I Skip did not pass'), isTrue);
      expect(entry.contains('pre_rev='), isTrue);
    });

    test('21–26. redaction; D/C/F/K cannot execute; no enrol; no creator', () {
      expect(
        S17JourneyDiagnosis.redactPrefix('abcdefghi'),
        'abcdefghi'.substring(0, 8) + '…',
      );
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(
        entry.contains(
          "final runF = !config.resumeMode || selected.contains('F')",
        ),
        isTrue,
      );
      expect(
        entry.contains(
          "final runG = !config.resumeMode || selected.contains('G')",
        ),
        isTrue,
      );
      expect(entry.contains("selected.contains('D')"), isTrue);
      expect(entry.contains("selected.contains('K')"), isTrue);
      expect(entry.contains('S17RefuseEnrolmentAdapter'), isTrue);
      expect(entry.contains('resumeExistingEnrolmentOnly'), isTrue);
      final runner = File(
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ).readAsStringSync();
      expect(runner.contains('D_ADAPTATION_EXECUTION=forbidden'), isTrue);
      expect(runner.contains('G_DISTINCT_DATE_SELECTION=required'), isTrue);
      expect(runner.contains('H_INVALID_PROBE=dayDelta<=0'), isTrue);
      expect(runner.contains('I_J_FRESH_SKIP_DEPENDENCY=required'), isTrue);
      expect(runner.contains('MATERIALISATION_REUSE_ONLY=enabled'), isTrue);
      expect(
        runner.contains('./tool/staging/create_s17_athlete_d_fixture.sh'),
        isFalse,
      );
      expect(entry.contains('Athlete C'), isFalse);
      expect(entry.contains('S17_FLUTTER_COMPLETE exit='), isTrue);
    });

    test('24. already-materialised resume never calls materialise', () async {
      final materialise = _CountingMaterialise();
      final prep = S17SchedulePreparation(
        catalogue: _FakeCatalogue(),
        enrolment: _RefuseEnrolment(),
        materialise: materialise,
        projection: _FakeProjection(uncompleted: 3, projected: 3, authored: 3),
        activeAssignment: _FakeActive(materialised: true),
        packageSelection: _FakePackage(),
        preparedExecution: _FakePrepared(),
      );
      final result = await prep.ensureScheduleOpsBaseline(
        const S17SchedulePreparationRequest(
          athleteId: 'athlete-d',
          currentLineageCode: 'PROG-S15A-STAGING',
          currentVersionId: 'multi-slot-version',
          currentAssignmentId: 'assign-live',
          resumeExistingEnrolmentOnly: true,
          currentIsMaterialised: true,
        ),
        current: const S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: 3,
          projectedOccurrenceCount: 3,
          uncompletedOccurrenceCount: 3,
          completedOrSkippedCount: 0,
          lineageCode: 'PROG-S15A-STAGING',
        ),
      );
      expect(result.ok, isTrue);
      expect(materialise.calls, 0);
      expect(result.detail, contains('materialisation skipped'));
    });
  });
}

class _CountingMaterialise implements S17PlanMaterialisePort {
  int calls = 0;
  @override
  Future<S17MaterialisationOutcome> materialise({
    required String athleteId,
    required String assignmentId,
  }) async {
    calls += 1;
    return const S17MaterialisationOutcome(
      ok: true,
      callKind: S17MaterialisationCallKind.success,
      statusName: 'materialised',
      code: 'ok',
    );
  }
}

class _RefuseEnrolment implements S17AthleteEnrolmentPort {
  @override
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  }) async =>
      const S17EnrolmentOutcome(ok: false, rejected: true, detail: 'forbidden');
}

class _FakeCatalogue implements S17CatalogueVersionLookup {
  @override
  Future<S17CatalogueVersionRef?> findPublishedByLineage(
    String lineageCode,
  ) async => S17CatalogueVersionRef(
    versionId: 'multi-slot-version',
    lineageCode: lineageCode,
    packageHash: 'hash-multi',
    executableSlotCount: 3,
  );
}

class _FakeActive implements S17ActiveAssignmentPort {
  _FakeActive({required this.materialised});
  final bool materialised;
  @override
  Future<S17ActiveAssignmentView?> getActive(String athleteId) async =>
      S17ActiveAssignmentView(
        assignmentId: 'assign-live',
        versionId: 'multi-slot-version',
        lineageCode: 'PROG-S15A-STAGING',
        packageHash: 'hash-multi',
        isMaterialised: materialised,
      );
}

class _FakePackage implements S17PackageSelectionPort {
  @override
  Future<S17PackageSelectionView?> resolveForAssignment({
    required String athleteId,
    required String assignmentId,
  }) async => const S17PackageSelectionView(
    versionId: 'multi-slot-version',
    lineageCode: 'PROG-S15A-STAGING',
    packageHash: 'hash-multi',
  );
}

class _FakePrepared implements S17PreparedExecutionPort {
  @override
  Future<bool> isReadyForAssignment({
    required String athleteId,
    required String assignmentId,
    required String expectedVersionId,
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
  }) async => S17OccurrenceBaselineSnapshot(
    authoredExecutableSlotCount: authored,
    projectedOccurrenceCount: projected,
    uncompletedOccurrenceCount: uncompleted,
    completedOrSkippedCount: projected - uncompleted,
    lineageCode: lineageCode,
  );
}
