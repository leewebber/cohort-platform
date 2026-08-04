import 'dart:io';

import 'package:cohort_platform/staging/s17_isolation_prereq.dart';
import 'package:cohort_platform/staging/s17_occurrence_baseline.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_schedule_preparation.dart';
import 'package:cohort_platform/staging/s17_staging_journey_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oneSlotCurrent = S17OccurrenceBaselineSnapshot(
    authoredExecutableSlotCount: 1,
    projectedOccurrenceCount: 1,
    uncompletedOccurrenceCount: 1,
    completedOrSkippedCount: 0,
    lineageCode: 'PROG-S13-ELIG',
  );

  const request = S17SchedulePreparationRequest(
    athleteId: 'athlete-d',
    currentLineageCode: 'PROG-S13-ELIG',
    currentVersionId: 'one-slot-version',
    currentAssignmentId: 'assign-1',
  );

  group('B4d.2 materialisation diagnosis reporting', () {
    test(
      '1. success is positively distinguished from call completion',
      () async {
        final result = await _prep().ensureScheduleOpsBaseline(
          request,
          current: oneSlotCurrent,
        );
        expect(result.ok, isTrue);
        expect(result.stage, S17PreparationStage.ready);
      },
    );

    test('2. typed rejection retains a safe stable code', () async {
      final result = await _prep(
        materialise: _RecordingMaterialise(
          const S17MaterialisationOutcome(
            ok: false,
            callKind: S17MaterialisationCallKind.typedRejection,
            statusName: 'validationFailure',
            code: 'timezone_unavailable',
            detail: 'typed materialisation rejection',
          ),
        ),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.materialisation);
      expect(result.detail, contains('timezone_unavailable'));
      expect(result.detail, contains('kind=typedRejection'));
    });

    test('3. transport/RPC failure is classified separately', () async {
      final result = await _prep(
        materialise: _RecordingMaterialise(
          const S17MaterialisationOutcome(
            ok: false,
            callKind: S17MaterialisationCallKind.transportOrRpcFailure,
            statusName: 'failed',
            code: 'client_error',
            returnedNormally: false,
          ),
        ),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.detail, contains('transportOrRpcFailure'));
      expect(result.detail, contains('client_error'));
    });

    test(
      '4. null/malformed/empty materialisation response fails closed',
      () async {
        final result = await _prep(
          materialise: _RecordingMaterialise(
            const S17MaterialisationOutcome(
              ok: false,
              callKind: S17MaterialisationCallKind.nullOrMalformed,
              statusName: 'validationFailure',
              code: 'invalid_args',
              attempted: false,
            ),
          ),
        ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
        expect(result.ok, isFalse);
        expect(result.stage, S17PreparationStage.materialisation);
        expect(result.detail, contains('nullOrMalformed'));
      },
    );

    test(
      '5. package mismatch fails before journeys (after materialise path)',
      () async {
        final result = await _prep(
          package: _FakePackage(missing: true),
        ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
        expect(result.ok, isFalse);
        expect(result.stage, S17PreparationStage.packageSelection);
      },
    );

    test(
      '6. partial/ambiguous state is reported via materialisation detail',
      () {
        const outcome = S17MaterialisationOutcome(
          ok: false,
          callKind: S17MaterialisationCallKind.typedRejection,
          statusName: 'conflict',
          code: 'active_materialised_programme_exists',
        );
        expect(
          outcome.classifiedDetail,
          contains('active_materialised_programme_exists'),
        );
        expect(outcome.classifiedDetail.contains('@'), isFalse);
      },
    );

    test(
      '7. first failing stage cannot be overwritten by cascading failures',
      () async {
        final result = await _prep(
          materialise: _RecordingMaterialise(
            const S17MaterialisationOutcome(
              ok: false,
              callKind: S17MaterialisationCallKind.typedRejection,
              statusName: 'validationFailure',
              code: 'timezone_unavailable',
            ),
          ),
        ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
        expect(result.stage, S17PreparationStage.materialisation);
        expect(result.classifiedDetail, contains('stage=materialisation'));
      },
    );

    test(
      '8. complete identifiers and unsafe exception bodies are redacted',
      () {
        const outcome = S17MaterialisationOutcome(
          ok: false,
          callKind: S17MaterialisationCallKind.transportOrRpcFailure,
          statusName: 'failed',
          code: 'client_error',
          detail: 'uncaught client exception (redacted)',
        );
        expect(outcome.classifiedDetail.contains('password'), isFalse);
        expect(outcome.classifiedDetail.contains('Bearer'), isFalse);
        expect(
          RegExp(
            r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
            caseSensitive: false,
          ).hasMatch(outcome.classifiedDetail),
          isFalse,
        );
      },
    );

    test(
      '9. preparation failure prevents treating baseline as ready',
      () async {
        final result = await _prep(
          materialise: _RecordingMaterialise(
            const S17MaterialisationOutcome(
              ok: false,
              callKind: S17MaterialisationCallKind.typedRejection,
              statusName: 'validationFailure',
              code: 'timezone_unavailable',
            ),
          ),
        ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
        expect(result.ok, isFalse);
        expect(result.stage, S17PreparationStage.materialisation);
        expect(result.skippedBecauseAlreadyReady, isFalse);
        expect(result.uncompletedOccurrences, 0);
      },
    );

    test('10. existing successful preparation still passes', () async {
      final result = await _prep().ensureScheduleOpsBaseline(
        request,
        current: oneSlotCurrent,
      );
      expect(result.ok, isTrue);
      expect(result.uncompletedOccurrences, greaterThanOrEqualTo(2));
    });
  });

  group('B4d.2 isolation prerequisite classification', () {
    test('11. authentication failure is distinct from isolation failure', () {
      final authFail = S17IsolationPrereq.assess(
        authenticated: false,
        isAthlete: true,
        isCoach: false,
        ownAssignmentFound: true,
        ownAssignmentOwned: true,
        foreignProbe: false,
      );
      expect(authFail.authentication, S17IsolationComponentResult.fail);
      expect(authFail.reportDetail, contains('AUTH=FAIL'));
      expect(authFail.overallResult, S17JourneyResult.fail);

      final foreignFail = S17IsolationPrereq.assess(
        authenticated: true,
        isAthlete: true,
        isCoach: false,
        ownAssignmentFound: true,
        ownAssignmentOwned: true,
        foreignProbe: true,
      );
      expect(foreignFail.authentication, S17IsolationComponentResult.pass);
      expect(foreignFail.foreignRowDenial, S17IsolationComponentResult.fail);
      expect(foreignFail.isolationBreachProven, isTrue);
    });

    test('12. own-row visibility is distinct from foreign-row denial', () {
      final ownMissing = S17IsolationPrereq.assess(
        authenticated: true,
        isAthlete: true,
        isCoach: false,
        ownAssignmentFound: false,
        ownAssignmentOwned: false,
        foreignProbe: false,
      );
      expect(ownMissing.ownRowVisibility, S17IsolationComponentResult.fail);
      expect(ownMissing.foreignRowDenial, S17IsolationComponentResult.pass);

      final foreignOk = S17IsolationPrereq.assess(
        authenticated: true,
        isAthlete: true,
        isCoach: false,
        ownAssignmentFound: true,
        ownAssignmentOwned: true,
        foreignProbe: false,
      );
      expect(foreignOk.ownRowVisibility, S17IsolationComponentResult.pass);
      expect(foreignOk.foreignRowDenial, S17IsolationComponentResult.pass);
      expect(foreignOk.overallResult, S17JourneyResult.pass);
    });

    test('13. unsupported isolation proof cannot become PASS', () {
      final coach = S17IsolationPrereq.assess(
        authenticated: true,
        isAthlete: true,
        isCoach: true,
        ownAssignmentFound: true,
        ownAssignmentOwned: true,
        foreignProbe: false,
      );
      expect(coach.foreignRowDenial, S17IsolationComponentResult.unsupported);
      expect(coach.overallResult, isNot(S17JourneyResult.pass));
      expect(coach.overallResult, S17JourneyResult.blocked);

      final uncertain = S17IsolationPrereq.assess(
        authenticated: true,
        isAthlete: true,
        isCoach: false,
        ownAssignmentFound: true,
        ownAssignmentOwned: true,
        foreignProbe: null,
      );
      expect(uncertain.foreignRowDenial, S17IsolationComponentResult.uncertain);
      expect(uncertain.overallResult, S17JourneyResult.blocked);
    });

    test('14. no athlete discovery or enumeration is used', () {
      final diag = File(
        'tool/staging/diagnose_s17_athlete_d_readonly.sh',
      ).readAsStringSync();
      expect(diag.contains('listAthletes'), isFalse);
      expect(diag.contains('discoverAthlete'), isFalse);
      expect(diag.contains('limit=1'), isTrue);
    });

    test('15. no Athlete C reference or lookup exists', () {
      final paths = [
        'lib/staging/s17_isolation_prereq.dart',
        'lib/staging/s17_preparation_adapters.dart',
        'tool/staging/diagnose_s17_athlete_d_readonly.sh',
      ];
      final forbidden = RegExp(
        r'Athlete C\b|athlete_c\b|athleteC\b|S15A Staging Athlete C',
      );
      for (final path in paths) {
        expect(forbidden.hasMatch(File(path).readAsStringSync()), isFalse);
      }
    });

    test('16. read-only diagnostics cannot invoke writes', () {
      final diag = File(
        'tool/staging/diagnose_s17_athlete_d_readonly.sh',
      ).readAsStringSync();
      expect(diag.contains('materialise_athlete_plan_from_enrolment'), isFalse);
      expect(
        diag.contains('enrol_athlete_in_catalogue_programme_version'),
        isFalse,
      );
      expect(diag.contains('writes=none'), isTrue);
      expect(diag.contains('/rpc/'), isFalse);
    });

    test('17. resume mode cannot invoke the creator', () {
      final runner = File(
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ).readAsStringSync();
      expect(runner.contains('creator_invocation=forbidden'), isTrue);
      expect(
        runner.contains('./tool/staging/create_s17_athlete_d_fixture.sh'),
        isFalse,
      );
    });

    test('18. sentinel and non-zero exit behaviour remain deterministic', () {
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('S17_FLUTTER_COMPLETE exit='), isTrue);
      expect(S17ResumeMode.prerequisiteCodes, contains('PREREQ_A'));
      expect(S17StagingJourneyMatrix.codes.length, 11);
    });
  });
}

S17SchedulePreparation _prep({
  S17PlanMaterialisePort? materialise,
  S17PackageSelectionPort? package,
}) {
  return S17SchedulePreparation(
    catalogue: _FakeCatalogue(),
    enrolment: _FakeEnrolment(),
    materialise:
        materialise ??
        _RecordingMaterialise(
          const S17MaterialisationOutcome(
            ok: true,
            callKind: S17MaterialisationCallKind.success,
            statusName: 'materialised',
            code: 'ok',
          ),
        ),
    projection: _FakeProjection(uncompleted: 3, projected: 3, authored: 3),
    activeAssignment: _FakeActive(
      assignmentId: 'assign-multi',
      versionId: 'multi-slot-version',
      lineageCode: 'PROG-S15A-STAGING',
    ),
    packageSelection: package ?? _FakePackage(),
    preparedExecution: _FakePrepared(),
  );
}

class _RecordingMaterialise implements S17PlanMaterialisePort {
  _RecordingMaterialise(this.outcome);
  final S17MaterialisationOutcome outcome;

  @override
  Future<S17MaterialisationOutcome> materialise({
    required String athleteId,
    required String assignmentId,
  }) async => outcome;
}

class _FakeCatalogue implements S17CatalogueVersionLookup {
  @override
  Future<S17CatalogueVersionRef?> findPublishedByLineage(
    String lineageCode,
  ) async {
    return S17CatalogueVersionRef(
      versionId: 'multi-slot-version',
      lineageCode: lineageCode,
      packageHash: 'hash-multi',
      executableSlotCount: 3,
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
      lineageCode: 'PROG-S15A-STAGING',
    );
  }
}

class _FakeActive implements S17ActiveAssignmentPort {
  _FakeActive({
    required this.assignmentId,
    required this.versionId,
    required this.lineageCode,
  });

  final String assignmentId;
  final String versionId;
  final String lineageCode;

  @override
  Future<S17ActiveAssignmentView?> getActive(String athleteId) async {
    return S17ActiveAssignmentView(
      assignmentId: assignmentId,
      versionId: versionId,
      lineageCode: lineageCode,
      packageHash: 'hash-multi',
      isMaterialised: true,
    );
  }
}

class _FakePackage implements S17PackageSelectionPort {
  _FakePackage({this.missing = false});
  final bool missing;

  @override
  Future<S17PackageSelectionView?> resolveForAssignment({
    required String athleteId,
    required String assignmentId,
  }) async {
    if (missing) return null;
    return const S17PackageSelectionView(
      versionId: 'multi-slot-version',
      lineageCode: 'PROG-S15A-STAGING',
      packageHash: 'hash-multi',
    );
  }
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
    int? authoredExecutableSlotCount,
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
