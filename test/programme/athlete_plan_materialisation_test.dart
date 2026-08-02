import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/models/athlete_plan_materialisation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_plan_materialisation_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_plan_materialisation_store.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

class _RecordingMaterialisationStore
    implements AthletePlanMaterialisationStore {
  _RecordingMaterialisationStore(this.result, {this.tables});

  AthletePlanMaterialisationResult result;
  final InMemoryProgrammeTables? tables;
  int calls = 0;
  String? lastAssignmentId;

  @override
  Future<AthletePlanMaterialisationResult> materialise({
    required String programmeAssignmentId,
    String? timezone,
  }) async {
    calls++;
    lastAssignmentId = programmeAssignmentId;
    final tables = this.tables;
    if (result.isSuccess && tables != null) {
      final index = tables.assignments.indexWhere(
        (row) => row.id == programmeAssignmentId,
      );
      if (index >= 0) {
        final current = tables.assignments[index];
        tables.assignments[index] = current.copyWith(
          startedAt: DateTime.utc(2026, 8, 1),
          materialisedAt: DateTime.utc(2026, 8, 1, 12),
          materialisationSource: 'athlete_start_programme',
          materialisedPackageContentHash: 'e' * 64,
          currentWeek: 1,
          currentDayKey: 'day_1',
          currentSessionOrder: 1,
        );
      }
    }
    return result;
  }
}

ProgrammeAssignment _enrolled({
  String id = 'enrol-1',
  DateTime? materialisedAt,
}) {
  return ProgrammeScheduleTestFixtures.assignment(
    id: id,
    athleteId: 'athlete-1',
    programmeVersionId: 'version-exact',
  ).copyWith(
    lineageCode: 'PROG-S14A',
    startedAt: DateTime.utc(2026, 7, 1),
    materialisedAt: materialisedAt,
    materialisationSource: materialisedAt == null
        ? null
        : 'athlete_start_programme',
    materialisedPackageContentHash: materialisedAt == null ? null : 'a' * 64,
  );
}

ProgrammeVersion _version() {
  return const ProgrammeVersion(
    id: 'version-exact',
    lineageId: 'lineage-exact',
    versionNumber: 1,
    lifecycleStatus: ProgrammeLifecycleStatus.published,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    name: 'S14A Programme',
    approvedForGlobal: true,
    packageContentHash:
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
  );
}

void main() {
  group('ProgrammeAssignment materialisation state', () {
    test('enrolled is not materialised', () {
      final assignment = _enrolled();
      expect(assignment.isMaterialised, isFalse);
      expect(assignment.isEnrolledOnly, isTrue);
      expect(assignment.canStartProgramme, isTrue);
    });

    test('materialised assignment is executable plan state', () {
      final assignment = _enrolled(materialisedAt: DateTime.utc(2026, 8, 1));
      expect(assignment.isMaterialised, isTrue);
      expect(assignment.isEnrolledOnly, isFalse);
      expect(assignment.canStartProgramme, isFalse);
    });

    test('fromMap reads materialisation provenance', () {
      final assignment = ProgrammeAssignment.fromMap({
        'id': 'e1',
        'athlete_id': 'a1',
        'programme_version_id': 'v1',
        'lineage_code': 'PROG',
        'status': 'active',
        'started_at': '2026-08-01',
        'current_week_number': 1,
        'current_day_key': 'day_1',
        'current_slot_order': 1,
        'materialised_at': '2026-08-01T10:00:00Z',
        'materialisation_source': 'athlete_start_programme',
        'materialised_package_content_hash': 'b' * 64,
        'materialised_package_schema_version': '1',
      });
      expect(assignment.isMaterialised, isTrue);
      expect(assignment.materialisedPackageContentHash, 'b' * 64);
      expect(assignment.materialisationSource, 'athlete_start_programme');
    });
  });

  group('AthletePlanMaterialisationResult', () {
    test('parses materialised exact version and hash', () {
      final result = AthletePlanMaterialisationResult.fromRpcMap({
        'status': 'materialised',
        'enrolment_id': 'e1',
        'programme_version_id': 'v-exact',
        'lineage_code': 'PROG',
        'materialised_at': '2026-08-01T12:00:00Z',
        'materialisation_source': 'athlete_start_programme',
        'materialised_package_content_hash': 'c' * 64,
        'started_at': '2026-08-01',
        'timezone': 'UTC',
        'current_week_number': 1,
        'current_day_key': 'day_1',
        'current_slot_order': 1,
        'athlete_id': 'a1',
      });
      expect(result.status, AthletePlanMaterialisationStatus.materialised);
      expect(result.isSuccess, isTrue);
      expect(result.programmeVersionId, 'v-exact');
      expect(result.materialisedPackageContentHash, 'c' * 64);
      expect(result.startedAt, isNotNull);
    });

    test('already_materialised is idempotent success', () {
      final result = AthletePlanMaterialisationResult.fromRpcMap({
        'status': 'already_materialised',
        'enrolment_id': 'e1',
        'programme_version_id': 'v1',
        'athlete_id': 'a1',
      });
      expect(result.isIdempotentAlreadyMaterialised, isTrue);
      expect(result.isSuccess, isTrue);
    });
  });

  group('AthletePlanMaterialisationService', () {
    test('blocks when legacy hasActivePlan preflight is true', () async {
      final store = _RecordingMaterialisationStore(
        const AthletePlanMaterialisationResult(
          status: AthletePlanMaterialisationStatus.materialised,
        ),
      );
      final service = AthletePlanMaterialisationService(
        materialisationStore: store,
        legacyHasActivePlan: () => true,
      );

      final result = await service.startProgramme(
        programmeAssignmentId: 'enrol-1',
        athleteId: 'athlete-1',
        timezone: 'UTC',
      );

      expect(
        result.status,
        AthletePlanMaterialisationStatus.legacyPlanConflict,
      );
      expect(store.calls, 0);
    });

    test('calls RPC with assignment id and exact handoff fields', () async {
      final store = _RecordingMaterialisationStore(
        AthletePlanMaterialisationResult.fromRpcMap({
          'status': 'materialised',
          'enrolment_id': 'enrol-1',
          'programme_version_id': 'version-exact',
          'materialised_package_content_hash': 'd' * 64,
          'started_at': '2026-08-01',
          'athlete_id': 'athlete-1',
        }),
      );
      final service = AthletePlanMaterialisationService(
        materialisationStore: store,
        legacyHasActivePlan: () => false,
      );

      final result = await service.startProgramme(
        programmeAssignmentId: 'enrol-1',
        athleteId: 'athlete-1',
        timezone: 'UTC',
      );

      expect(store.calls, 1);
      expect(store.lastAssignmentId, 'enrol-1');
      expect(result.programmeVersionId, 'version-exact');
      expect(result.toHandoff()?.programmeVersionId, 'version-exact');
    });

    test('reconciles already-materialised after ambiguous failure', () async {
      final tables = InMemoryProgrammeTables()
        ..assignments.add(_enrolled(materialisedAt: DateTime.utc(2026, 8, 1)));
      final store = _RecordingMaterialisationStore(
        const AthletePlanMaterialisationResult(
          status: AthletePlanMaterialisationStatus.failed,
          code: 'client_error',
        ),
      );
      final service = AthletePlanMaterialisationService(
        materialisationStore: store,
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        legacyHasActivePlan: () => false,
      );

      final result = await service.startProgramme(
        programmeAssignmentId: 'enrol-1',
        athleteId: 'athlete-1',
      );

      expect(
        result.status,
        AthletePlanMaterialisationStatus.alreadyMaterialised,
      );
    });
  });

  group('AthleteProgrammeScreenController startProgramme', () {
    test('duplicate tap while starting is ignored', () async {
      final tables = InMemoryProgrammeTables()
        ..assignments.add(_enrolled())
        ..versions.add(_version());
      var calls = 0;
      final inner = _RecordingMaterialisationStore(
        AthletePlanMaterialisationResult.fromRpcMap({
          'status': 'materialised',
          'enrolment_id': 'enrol-1',
          'programme_version_id': 'version-exact',
          'materialised_at': '2026-08-01T12:00:00Z',
          'materialisation_source': 'athlete_start_programme',
          'materialised_package_content_hash': 'e' * 64,
          'started_at': '2026-08-01',
          'athlete_id': 'athlete-1',
        }),
        tables: tables,
      );
      final delayed = _DelayedMaterialisationStore(inner, () => calls++);
      final controller = AthleteProgrammeScreenController(
        athleteId: 'athlete-1',
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        materialisationService: AthletePlanMaterialisationService(
          materialisationStore: delayed,
          assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          legacyHasActivePlan: () => false,
        ),
      );
      await controller.load();

      final first = controller.startProgramme(timezone: 'UTC');
      final second = await controller.startProgramme(timezone: 'UTC');
      expect(second, isNull);
      await first;
      expect(calls, 1);
      expect(controller.isMaterialised, isTrue);
    });

    test('load alone does not materialise', () async {
      final tables = InMemoryProgrammeTables()
        ..assignments.add(_enrolled())
        ..versions.add(_version());
      final store = _RecordingMaterialisationStore(
        const AthletePlanMaterialisationResult(
          status: AthletePlanMaterialisationStatus.materialised,
        ),
      );
      final controller = AthleteProgrammeScreenController(
        athleteId: 'athlete-1',
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        materialisationService: AthletePlanMaterialisationService(
          materialisationStore: store,
          legacyHasActivePlan: () => false,
        ),
      );
      await controller.load();
      expect(store.calls, 0);
      expect(controller.canStartProgramme, isTrue);
    });
  });

  group('AthleteProgrammeScreen Start Programme UI', () {
    testWidgets('shows Start Programme only when enrolled not materialised', (
      tester,
    ) async {
      final tables = InMemoryProgrammeTables()
        ..assignments.add(_enrolled())
        ..versions.add(_version());
      final store = _RecordingMaterialisationStore(
        AthletePlanMaterialisationResult.fromRpcMap({
          'status': 'materialised',
          'enrolment_id': 'enrol-1',
          'programme_version_id': 'version-exact',
          'materialised_at': '2026-08-01T12:00:00Z',
          'materialisation_source': 'athlete_start_programme',
          'materialised_package_content_hash': 'f' * 64,
          'started_at': '2026-08-01',
          'athlete_id': 'athlete-1',
        }),
        tables: tables,
      );
      final controller = AthleteProgrammeScreenController(
        athleteId: 'athlete-1',
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        materialisationService: AthletePlanMaterialisationService(
          materialisationStore: store,
          assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          legacyHasActivePlan: () => false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScreen(
            athleteId: 'athlete-1',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Programme'), findsOneWidget);
      expect(
        find.textContaining('begins this programme today'),
        findsOneWidget,
      );
      expect(find.textContaining('Enrolled · Not started'), findsOneWidget);

      await tester.tap(find.text('Start Programme'));
      await tester.pumpAndSettle();

      expect(store.calls, 1);
      expect(find.text('Start Programme'), findsNothing);
      expect(
        find.textContaining('Today\'s authored session appears on Home'),
        findsOneWidget,
      );
    });
  });
}

class _DelayedMaterialisationStore implements AthletePlanMaterialisationStore {
  _DelayedMaterialisationStore(this.inner, this.onCall);

  final AthletePlanMaterialisationStore inner;
  final VoidCallback onCall;

  @override
  Future<AthletePlanMaterialisationResult> materialise({
    required String programmeAssignmentId,
    String? timezone,
  }) async {
    onCall();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return inner.materialise(
      programmeAssignmentId: programmeAssignmentId,
      timezone: timezone,
    );
  }
}
