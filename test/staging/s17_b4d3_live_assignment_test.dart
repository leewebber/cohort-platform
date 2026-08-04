import 'dart:io';

import 'package:cohort_platform/staging/s17_live_assignment_binding.dart';
import 'package:cohort_platform/staging/s17_occurrence_baseline.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_schedule_preparation.dart';
import 'package:cohort_platform/staging/s17_staging_journey_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B4d.3 live-assignment binding', () {
    test('1. resume binds to authenticated athlete active assignment', () {
      final bound = S17LiveAssignmentBinding.bind(
        athleteId: 'athlete-d',
        liveAssignmentId: 'assign-live',
        liveVersionId: 'version-live',
        liveLineageCode: 'PROG-S15A-STAGING',
        liveAthleteId: 'athlete-d',
        liveIsMaterialised: false,
        defineAssignmentId: 'assign-stale',
        defineVersionId: 'version-stale',
        defineLineageCode: 'PROG-S13-ELIG',
      );
      expect(bound.ok, isTrue);
      expect(bound.assignmentId, 'assign-live');
      expect(bound.versionId, 'version-live');
      expect(bound.lineageCode, 'PROG-S15A-STAGING');
      expect(bound.staleDefinesSuperseded, isTrue);
    });

    test('2. assignment must belong to PROG-S15A-STAGING', () {
      final bound = S17LiveAssignmentBinding.bind(
        athleteId: 'athlete-d',
        liveAssignmentId: 'a',
        liveVersionId: 'v',
        liveLineageCode: 'PROG-OTHER',
        liveAthleteId: 'athlete-d',
        liveIsMaterialised: false,
      );
      expect(bound.ok, isFalse);
      expect(bound.detail, contains('PROG-S15A-STAGING'));
    });

    test('3. S13 or unexpected assignment fails closed', () {
      final s13 = S17LiveAssignmentBinding.bind(
        athleteId: 'athlete-d',
        liveAssignmentId: 'a',
        liveVersionId: 'v',
        liveLineageCode: 'PROG-S13-ELIG',
        liveAthleteId: 'athlete-d',
        liveIsMaterialised: true,
      );
      expect(s13.ok, isFalse);
      expect(s13.detail, contains('PROG-S13-ELIG'));
    });

    test('4. stale define identifiers cannot override live S15A state', () {
      final bound = S17LiveAssignmentBinding.bind(
        athleteId: 'athlete-d',
        liveAssignmentId: 'live-assign',
        liveVersionId: 'live-version',
        liveLineageCode: 'PROG-S15A-STAGING',
        liveAthleteId: 'athlete-d',
        liveIsMaterialised: false,
        defineAssignmentId: 'stale-assign',
        defineVersionId: 'stale-version',
        defineLineageCode: 'PROG-S13-ELIG',
      );
      expect(bound.ok, isTrue);
      expect(bound.assignmentId, isNot('stale-assign'));
      expect(bound.lineageCode, isNot('PROG-S13-ELIG'));
      expect(bound.staleDefinesSuperseded, isTrue);
    });

    test(
      '5–6. enrolled-not-materialised skips enrol and materialises once',
      () async {
        final enrolment = _TrackingEnrolment();
        final materialise = _CountingMaterialise(ok: true);
        final prep = S17SchedulePreparation(
          catalogue: _FakeCatalogue(),
          enrolment: enrolment,
          materialise: materialise,
          projection: _FakeProjection(
            uncompleted: 3,
            projected: 3,
            authored: 3,
          ),
          activeAssignment: _FakeActive(
            assignmentId: 'assign-live',
            versionId: 'multi-slot-version',
            lineageCode: 'PROG-S15A-STAGING',
          ),
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
            currentIsMaterialised: false,
          ),
          current: const S17OccurrenceBaselineSnapshot(
            authoredExecutableSlotCount: 0,
            projectedOccurrenceCount: 0,
            uncompletedOccurrenceCount: 0,
            completedOrSkippedCount: 0,
            lineageCode: 'PROG-S15A-STAGING',
          ),
        );
        expect(result.ok, isTrue);
        expect(enrolment.calls, 0);
        expect(materialise.calls, 1);
        expect(result.detail, contains('enrol/switch skipped'));
      },
    );

    test('7. timezone present on materialise adapter contract', () {
      final adapters = File(
        'lib/staging/s17_preparation_adapters.dart',
      ).readAsStringSync();
      expect(adapters.contains("athleteTimezone = 'UTC'"), isTrue);
      expect(
        adapters.contains(
          'timezone: S17AthleteEnrolmentAdapter.athleteTimezone',
        ),
        isTrue,
      );
    });

    test('8. typed rejection status/code retained safely', () async {
      final prep = S17SchedulePreparation(
        catalogue: _FakeCatalogue(),
        enrolment: _TrackingEnrolment(),
        materialise: _CountingMaterialise(
          ok: false,
          code: 'timezone_unavailable',
        ),
        projection: _FakeProjection(uncompleted: 0, projected: 0, authored: 3),
        activeAssignment: _FakeActive(
          assignmentId: 'assign-live',
          versionId: 'multi-slot-version',
          lineageCode: 'PROG-S15A-STAGING',
        ),
      );
      final result = await prep.ensureScheduleOpsBaseline(
        const S17SchedulePreparationRequest(
          athleteId: 'athlete-d',
          currentLineageCode: 'PROG-S15A-STAGING',
          currentVersionId: 'multi-slot-version',
          currentAssignmentId: 'assign-live',
          resumeExistingEnrolmentOnly: true,
        ),
        current: const S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: 0,
          projectedOccurrenceCount: 0,
          uncompletedOccurrenceCount: 0,
          completedOrSkippedCount: 0,
          lineageCode: 'PROG-S15A-STAGING',
        ),
      );
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.materialisation);
      expect(result.detail, contains('timezone_unavailable'));
    });

    test(
      '9–11. package ownership, prepared execution, no S13 fallback',
      () async {
        final noPackage =
            await S17SchedulePreparation(
              catalogue: _FakeCatalogue(),
              enrolment: _TrackingEnrolment(),
              materialise: _CountingMaterialise(ok: true),
              projection: _FakeProjection(
                uncompleted: 3,
                projected: 3,
                authored: 3,
              ),
              activeAssignment: _FakeActive(
                assignmentId: 'assign-live',
                versionId: 'multi-slot-version',
                lineageCode: 'PROG-S15A-STAGING',
              ),
              packageSelection: _FakePackage(missing: true),
              preparedExecution: _FakePrepared(),
            ).ensureScheduleOpsBaseline(
              const S17SchedulePreparationRequest(
                athleteId: 'athlete-d',
                currentLineageCode: 'PROG-S15A-STAGING',
                currentVersionId: 'multi-slot-version',
                currentAssignmentId: 'assign-live',
                resumeExistingEnrolmentOnly: true,
              ),
              current: const S17OccurrenceBaselineSnapshot(
                authoredExecutableSlotCount: 0,
                projectedOccurrenceCount: 0,
                uncompletedOccurrenceCount: 0,
                completedOrSkippedCount: 0,
                lineageCode: 'PROG-S15A-STAGING',
              ),
            );
        expect(noPackage.stage, S17PreparationStage.packageSelection);

        final s13 =
            await S17SchedulePreparation(
              catalogue: _FakeCatalogue(),
              enrolment: _TrackingEnrolment(),
              materialise: _CountingMaterialise(ok: true),
              projection: _FakeProjection(
                uncompleted: 3,
                projected: 3,
                authored: 3,
              ),
            ).ensureScheduleOpsBaseline(
              const S17SchedulePreparationRequest(
                athleteId: 'athlete-d',
                currentLineageCode: 'PROG-S13-ELIG',
                currentVersionId: 'one-slot',
                currentAssignmentId: 'assign-old',
                resumeExistingEnrolmentOnly: true,
              ),
              current: const S17OccurrenceBaselineSnapshot(
                authoredExecutableSlotCount: 1,
                projectedOccurrenceCount: 1,
                uncompletedOccurrenceCount: 1,
                completedOrSkippedCount: 0,
                lineageCode: 'PROG-S13-ELIG',
              ),
            );
        expect(s13.ok, isFalse);
        expect(s13.stage, S17PreparationStage.silentFallbackGuard);
      },
    );

    test('12–14. creator forbidden; no discovery; no Athlete C', () {
      final runner = File(
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ).readAsStringSync();
      expect(runner.contains('creator_invocation=forbidden'), isTrue);
      expect(
        runner.contains('./tool/staging/create_s17_athlete_d_fixture.sh'),
        isFalse,
      );
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      final bind = File(
        'lib/staging/s17_live_assignment_binding.dart',
      ).readAsStringSync();
      final forbidden = RegExp(
        r'Athlete C\b|listAthletes|discoverAthlete|enumerateAthletes',
      );
      expect(forbidden.hasMatch(entry), isFalse);
      expect(forbidden.hasMatch(bind), isFalse);
      expect(entry.contains('S17RefuseEnrolmentAdapter'), isTrue);
      expect(
        entry.contains('resumeExistingEnrolmentOnly: config.resumeMode'),
        isTrue,
      );
    });

    test(
      '15–18. prep failure blocks journeys; PREREQ_A split; E not selected',
      () {
        expect(S17ResumeMode.unresolvedAfterB4b.contains('E'), isFalse);
        expect(
          () => S17ResumeMode.parseSelectedJourneys('E'),
          throwsA(isA<FormatException>()),
        );
        final entry = File(
          'lib/main_s17_staging_verify.dart',
        ).readAsStringSync();
        expect(entry.contains("setPrereq(\n      'PREREQ_AUTH'"), isTrue);
        expect(entry.contains("setPrereq(\n      'PREREQ_OWN'"), isTrue);
        expect(entry.contains("setPrereq(\n      'PREREQ_FOREIGN'"), isTrue);
        expect(entry.contains('selectedJourneysUnlocked'), isTrue);
        expect(S17StagingJourneyMatrix.codes.contains('E'), isTrue);
      },
    );

    test('19–20. redaction and sentinel remain deterministic', () {
      final bound = S17LiveAssignmentBinding.bind(
        athleteId: 'athlete-d',
        liveAssignmentId: '12345678-aaaa-bbbb-cccc-dddddddddddd',
        liveVersionId: '87654321-aaaa-bbbb-cccc-dddddddddddd',
        liveLineageCode: 'PROG-S15A-STAGING',
        liveAthleteId: 'athlete-d',
        liveIsMaterialised: false,
      );
      expect(bound.redactedDetail.contains('12345678…'), isTrue);
      expect(
        RegExp(
          r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
          caseSensitive: false,
        ).hasMatch(bound.redactedDetail),
        isFalse,
      );
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('S17_FLUTTER_COMPLETE exit='), isTrue);
    });
  });
}

class _TrackingEnrolment implements S17AthleteEnrolmentPort {
  int calls = 0;

  @override
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  }) async {
    calls += 1;
    return const S17EnrolmentOutcome(
      ok: false,
      rejected: true,
      detail: 'should not be called',
    );
  }
}

class _CountingMaterialise implements S17PlanMaterialisePort {
  _CountingMaterialise({required this.ok, this.code = 'ok'});
  final bool ok;
  final String code;
  int calls = 0;

  @override
  Future<S17MaterialisationOutcome> materialise({
    required String athleteId,
    required String assignmentId,
  }) async {
    calls += 1;
    return S17MaterialisationOutcome(
      ok: ok,
      callKind: ok
          ? S17MaterialisationCallKind.success
          : S17MaterialisationCallKind.typedRejection,
      statusName: ok ? 'materialised' : 'validationFailure',
      code: code,
    );
  }
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
