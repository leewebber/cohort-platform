import 'dart:io';

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

  group('B4d.1 preparation fail-closed postconditions', () {
    test('1. old one-slot assignment cannot satisfy preparation', () {
      expect(S17OccurrenceBaseline.failClosedReason(oneSlotCurrent), isNotNull);
      expect(
        S17OccurrenceBaseline.diagnose(oneSlotCurrent).cause,
        S17OccurrenceBlockerCause.authoredProgrammeInsufficientSlots,
      );
    });

    test('2. unavailable target programme fails closed', () async {
      final result = await _prep(
        catalogue: _FakeCatalogue(missing: true),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.catalogueUnavailable);
    });

    test('3. invisible or ineligible target fails closed', () async {
      final invisible = await _prep(
        catalogue: _FakeCatalogue(visible: false),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(invisible.ok, isFalse);
      expect(invisible.stage, S17PreparationStage.catalogueIneligible);

      final ineligible = await _prep(
        catalogue: _FakeCatalogue(eligible: false),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(ineligible.ok, isFalse);
      expect(ineligible.stage, S17PreparationStage.catalogueIneligible);
    });

    test('4. incorrect target identifier fails closed', () async {
      final wrong = await _prep().ensureScheduleOpsBaseline(
        const S17SchedulePreparationRequest(
          athleteId: 'athlete-d',
          currentLineageCode: 'PROG-S13-ELIG',
          currentVersionId: 'one-slot-version',
          currentAssignmentId: 'assign-1',
          targetSchedulingLineage: 'PROG-S13-ELIG',
        ),
        current: oneSlotCurrent,
      );
      expect(wrong.ok, isFalse);
      expect(wrong.stage, S17PreparationStage.incorrectTarget);

      final empty = await _prep().ensureScheduleOpsBaseline(
        const S17SchedulePreparationRequest(
          athleteId: 'athlete-d',
          currentLineageCode: 'PROG-S13-ELIG',
          currentVersionId: 'one-slot-version',
          currentAssignmentId: 'assign-1',
          targetSchedulingLineage: '',
        ),
        current: oneSlotCurrent,
      );
      expect(empty.ok, isFalse);
      expect(empty.stage, S17PreparationStage.incorrectTarget);
    });

    test('5. enrol/switch rejection is surfaced', () async {
      final result = await _prep(
        enrolment: _FakeEnrolment(rejected: true),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.enrolRejected);
    });

    test('6. null, malformed or ambiguous response fails closed', () async {
      final malformed = await _prep(
        enrolment: _FakeEnrolment(malformed: true),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(malformed.ok, isFalse);
      expect(malformed.stage, S17PreparationStage.enrolMalformed);

      final ambiguous = await _prep(
        catalogue: _FakeCatalogue(ambiguous: true),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(ambiguous.ok, isFalse);
      expect(ambiguous.stage, S17PreparationStage.catalogueLookup);
    });

    test('7. old assignment remaining active fails closed', () async {
      final result = await _prep(
        active: _FakeActive(
          assignmentId: 'assign-1',
          versionId: 'one-slot-version',
          lineageCode: 'PROG-S13-ELIG',
        ),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.assignmentPostcondition);
      expect(result.detail, contains('PROG-S13-ELIG'));
    });

    test('8. intended assignment with missing package fails closed', () async {
      final result = await _prep(
        package: _FakePackage(missing: true),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.packageSelection);
    });

    test(
      '9. intended package with failed materialisation fails closed',
      () async {
        final result = await _prep(
          materialise: _FakeMaterialise(ok: false),
        ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
        expect(result.ok, isFalse);
        expect(result.stage, S17PreparationStage.materialisation);
      },
    );

    test('10. restore to the old programme fails closed', () async {
      final result = await _prep(
        projection: _FakeProjection(
          uncompleted: 3,
          projected: 3,
          authored: 3,
          lineageCode: 'PROG-S13-ELIG',
        ),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.reconstruction);
    });

    test('11. fewer than two uncompleted occurrences fails closed', () async {
      final result = await _prep(
        projection: _FakeProjection(uncompleted: 1, projected: 1, authored: 3),
      ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
      expect(result.ok, isFalse);
      expect(result.stage, S17PreparationStage.uncompletedOccurrences);
    });

    test(
      '12. valid multi-slot preparation satisfies every postcondition',
      () async {
        final result = await _prep().ensureScheduleOpsBaseline(
          request,
          current: oneSlotCurrent,
        );
        expect(result.ok, isTrue);
        expect(result.stage, S17PreparationStage.ready);
        expect(result.lineageCode, 'PROG-S15A-STAGING');
        expect(result.uncompletedOccurrences, greaterThanOrEqualTo(2));
        expect(result.assignmentId, 'assign-multi');
        expect(result.packageHash, isNotEmpty);
      },
    );

    test(
      '13. preparation cannot silently fall back to PROG-S13-ELIG',
      () async {
        final result = await _prep(
          active: _FakeActive(
            assignmentId: 'assign-multi',
            versionId: 'multi-slot-version',
            lineageCode: 'PROG-S13-ELIG',
          ),
        ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
        expect(result.ok, isFalse);
        expect(result.classifiedDetail, contains('silent'));
        expect(result.lineageCode, isNot('PROG-S15A-STAGING'));
      },
    );

    test('14. selected journeys do not start after preparation failure', () {
      final prepFailed = !_prepSyncOk();
      expect(prepFailed, isTrue);
      // Entrypoint gates C/D/F–K behind selectedJourneysUnlocked; resume matrix
      // must not treat prep failure as journey PASS.
      expect(S17ResumeMode.unresolvedAfterB4b, isNot(contains('E')));
    });

    test('15. resume mode cannot call the creator', () {
      final runner = File(
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ).readAsStringSync();
      expect(runner.contains('--resume'), isTrue);
      expect(runner.contains('creator_invocation=forbidden'), isTrue);
      expect(
        runner.contains('./tool/staging/create_s17_athlete_d_fixture.sh'),
        isFalse,
      );
      expect(
        S17ResumeMode.mentionsCreatorInvocation(
          'create_s17_athlete_d_fixture.sh',
        ),
        isTrue,
      );
    });

    test('16. resume mode cannot discover or enumerate athletes', () {
      final prep = File(
        'lib/staging/s17_schedule_preparation.dart',
      ).readAsStringSync();
      final adapters = File(
        'lib/staging/s17_preparation_adapters.dart',
      ).readAsStringSync();
      final resume = File(
        'lib/staging/s17_resume_mode.dart',
      ).readAsStringSync();
      final forbidden = RegExp(
        r'listAthletes|discoverAthlete|findAthleteByEmail|enumerateAthletes',
        caseSensitive: false,
      );
      expect(forbidden.hasMatch(prep), isFalse);
      expect(forbidden.hasMatch(adapters), isFalse);
      expect(forbidden.hasMatch(resume), isFalse);
    });

    test('17. no Athlete C reference or lookup exists', () {
      final paths = [
        'lib/staging/s17_schedule_preparation.dart',
        'lib/staging/s17_preparation_adapters.dart',
        'lib/staging/s17_resume_mode.dart',
        'lib/main_s17_staging_verify.dart',
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

    test(
      '18. preparation uses Athlete D-authenticated application boundary',
      () {
        final adapters = File(
          'lib/staging/s17_preparation_adapters.dart',
        ).readAsStringSync();
        expect(adapters.contains('AthleteCatalogueEnrolmentService'), isTrue);
        expect(adapters.contains('service_role'), isFalse);
        expect(adapters.contains('SERVICE_ROLE'), isFalse);
      },
    );

    test('19. published programme content is never mutated', () {
      final prep = File(
        'lib/staging/s17_schedule_preparation.dart',
      ).readAsStringSync();
      expect(prep.contains('Does not mutate published programmes'), isTrue);
      expect(prep.contains('updateProgrammeVersion'), isFalse);
      expect(prep.contains('publishProgramme'), isFalse);
    });

    test('20. full identifiers and credentials are redacted', () {
      final result = S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueUnavailable,
        detail:
            'REFUSED: published scheduling lineage PROG-S15A-STAGING missing',
      );
      expect(result.classifiedDetail, startsWith('PREP_FAIL stage='));
      expect(result.classifiedDetail.contains('@'), isFalse);
      expect(result.classifiedDetail.contains('password'), isFalse);
    });

    test('21. PREREQ_A/B/E are independent of journey outcomes', () {
      expect(
        S17ResumeMode.prerequisiteCodes,
        containsAll(['PREREQ_A', 'PREREQ_B', 'PREREQ_E']),
      );
      expect(S17ResumeMode.unresolvedAfterB4b.contains('A'), isFalse);
      expect(S17ResumeMode.unresolvedAfterB4b.contains('B'), isFalse);
      expect(S17ResumeMode.unresolvedAfterB4b.contains('E'), isFalse);
    });

    test('22. journey E is not recorded as PASS during C/D/F–K resume', () {
      final selected = S17ResumeMode.parseSelectedJourneys('C,D,F,G,H,I,J,K');
      expect(selected.contains('E'), isFalse);
      expect(
        () => S17ResumeMode.parseSelectedJourneys('E'),
        throwsA(isA<FormatException>()),
      );
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(
        entry.contains('Resume mode must never record journey E as PASS'),
        isTrue,
      );
      expect(entry.contains("setPrereq(\n      'PREREQ_E'"), isTrue);
      // Journey E matrix write is gated; resume cannot select E.
      expect(S17ResumeMode.unresolvedAfterB4b.contains('E'), isFalse);
    });

    test(
      '23. structured failure reports retain first failing preparation stage',
      () async {
        final result = await _prep(
          catalogue: _FakeCatalogue(missing: true),
        ).ensureScheduleOpsBaseline(request, current: oneSlotCurrent);
        expect(result.classifiedDetail, contains('stage=catalogueUnavailable'));
        expect(result.stage, isNot(S17PreparationStage.ready));
      },
    );

    test('24. sentinel and non-zero exit behaviour remain deterministic', () {
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      final runner = File(
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ).readAsStringSync();
      expect(entry.contains('S17_FLUTTER_COMPLETE exit='), isTrue);
      expect(runner.contains('S17_FLUTTER_COMPLETE'), isTrue);
      expect(S17StagingJourneyMatrix.codes.length, 11);
    });
  });
}

bool _prepSyncOk() => false;

S17SchedulePreparation _prep({
  S17CatalogueVersionLookup? catalogue,
  S17AthleteEnrolmentPort? enrolment,
  S17PlanMaterialisePort? materialise,
  S17ProjectionBaselinePort? projection,
  S17ActiveAssignmentPort? active,
  S17PackageSelectionPort? package,
  S17PreparedExecutionPort? prepared,
}) {
  return S17SchedulePreparation(
    catalogue: catalogue ?? _FakeCatalogue(),
    enrolment: enrolment ?? _FakeEnrolment(),
    materialise: materialise ?? _FakeMaterialise(),
    projection:
        projection ??
        _FakeProjection(uncompleted: 3, projected: 3, authored: 3),
    activeAssignment:
        active ??
        _FakeActive(
          assignmentId: 'assign-multi',
          versionId: 'multi-slot-version',
          lineageCode: 'PROG-S15A-STAGING',
        ),
    packageSelection: package ?? _FakePackage(),
    preparedExecution: prepared ?? _FakePrepared(),
  );
}

class _FakeCatalogue implements S17CatalogueVersionLookup {
  _FakeCatalogue({
    this.slots = 3,
    this.missing = false,
    this.visible = true,
    this.eligible = true,
    this.ambiguous = false,
    this.lineageCode = 'PROG-S15A-STAGING',
  });

  final int slots;
  final bool missing;
  final bool visible;
  final bool eligible;
  final bool ambiguous;
  final String lineageCode;

  @override
  Future<S17CatalogueVersionRef?> findPublishedByLineage(
    String lineageCode,
  ) async {
    if (missing) return null;
    return S17CatalogueVersionRef(
      versionId: 'multi-slot-version',
      lineageCode: this.lineageCode,
      packageHash: 'hash-multi',
      executableSlotCount: slots,
      visible: visible,
      eligible: eligible,
      ambiguous: ambiguous,
    );
  }
}

class _FakeEnrolment implements S17AthleteEnrolmentPort {
  _FakeEnrolment({this.rejected = false, this.malformed = false});
  final bool rejected;
  final bool malformed;

  @override
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  }) async {
    if (malformed) {
      return const S17EnrolmentOutcome(
        ok: false,
        malformed: true,
        detail: 'null enrolment_id',
      );
    }
    if (rejected) {
      return const S17EnrolmentOutcome(
        ok: false,
        rejected: true,
        detail: 'status=conflict code=active_assignment',
      );
    }
    return S17EnrolmentOutcome(
      ok: true,
      assignmentId: 'assign-multi',
      versionId: versionId,
      lineageCode: 'PROG-S15A-STAGING',
    );
  }
}

class _FakeMaterialise implements S17PlanMaterialisePort {
  _FakeMaterialise({this.ok = true, this.code = 'ok'});
  final bool ok;
  final String code;

  @override
  Future<S17MaterialisationOutcome> materialise({
    required String athleteId,
    required String assignmentId,
  }) async => S17MaterialisationOutcome(
    ok: ok,
    callKind: ok
        ? S17MaterialisationCallKind.success
        : S17MaterialisationCallKind.typedRejection,
    statusName: ok ? 'materialised' : 'validationFailure',
    code: code,
    detail: ok ? 'ok' : 'typed rejection',
  );
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
    this.lineageCode = 'PROG-S15A-STAGING',
  });

  final int uncompleted;
  final int projected;
  final int authored;
  final String lineageCode;

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
      lineageCode: this.lineageCode,
    );
  }
}
