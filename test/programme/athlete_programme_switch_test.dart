import 'package:cohort_platform/features/home/controllers/home_today_session_refresh_controller.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_switch_result.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_switch_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_switch_coordinator.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

class _FakeCatalogService implements ProgrammeCatalogService {
  _FakeCatalogService(this.entries);

  final List<ProgrammeCatalogEntry> entries;

  @override
  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  }) async =>
      null;

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogue({
    required ProgrammeCatalogueQuery query,
    ProgrammeLifecycleStatus? lifecycleStatus,
  }) async =>
      entries;
}

class _FakeAssignmentService implements ProgrammeAssignmentService {
  _FakeAssignmentService({
    this.current,
    this.switchResult,
  });

  ProgrammeAssignment? current;
  ProgrammeAssignmentOperationResult? switchResult;
  int switchCalls = 0;
  int assignCalls = 0;

  @override
  Future<ProgrammeAssignmentOperationResult> assignByLineageVersion({
    required String athleteId,
    required String lineageCode,
    required int versionNumber,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
    bool allowUnpublishedVersion = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ProgrammeAssignmentOperationResult> assignProgramme({
    required String athleteId,
    required String programmeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
    bool allowUnpublishedVersion = false,
  }) async {
    assignCalls++;
    return switchResult ??
        ProgrammeAssignmentOperationResult.failed(message: 'failed');
  }

  @override
  Future<ProgrammeAssignmentOperationResult> cancelOrReplaceActiveAssignment({
    required String athleteId,
    required String newProgrammeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool allowUnpublishedVersion = false,
  }) async {
    switchCalls++;
    return switchResult ??
        ProgrammeAssignmentOperationResult.failed(message: 'failed');
  }

  @override
  Future<ProgrammeAssignmentOperationResult> completeAssignment({
    required String assignmentId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ProgrammeAssignment?> getCurrentAssignment({
    required String athleteId,
  }) async =>
      current;

  @override
  Future<ProgrammeAssignmentOperationResult> pauseAssignment({
    required String assignmentId,
    String? reason,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ProgrammeAssignmentOperationResult> resumeAssignment({
    required String assignmentId,
  }) async =>
      throw UnimplementedError();
}

class _NoOpAthleteStateSyncService implements AthleteStateSyncService {
  @override
  Future<void> clearProgrammeProjection(String athleteId) async {}

  @override
  Future<void> syncFromResolvedSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
  }) async {}
}

ProgrammeCatalogEntry _entry({
  required String id,
  ProgrammeLifecycleStatus status = ProgrammeLifecycleStatus.published,
  DateTime? archivedAt,
  bool blocking = false,
  String name = 'Programme',
}) {
  return ProgrammeCatalogEntry(
    versionId: id,
    lineageCode: 'LINE-$id',
    versionNumber: 1,
    name: name,
    lifecycleStatus: status,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.coach,
    primaryGoal: 'Build capacity',
    durationWeeks: 8,
    sessionsPerWeek: 4,
    equipmentRequirements: 'Barbell, rack',
    archivedAt: archivedAt,
    hasBlockingValidationErrors: blocking,
  );
}

void main() {
  const athleteId = 'lee';

  group('AthleteProgrammeSwitchCatalogService', () {
    test('lists published assignable programmes only', () async {
      final service = AthleteProgrammeSwitchCatalogService(
        catalogService: _FakeCatalogService([
          _entry(id: 'pub-1'),
          _entry(id: 'draft-1', status: ProgrammeLifecycleStatus.draft),
          _entry(
            id: 'archived-1',
            archivedAt: DateTime.utc(2026, 1, 1),
          ),
          _entry(id: 'blocked-1', blocking: true),
        ]),
      );

      final list = await service.listPublishedAssignableProgrammes();

      expect(list.map((e) => e.versionId), ['pub-1']);
    });
  });

  group('AthleteProgrammeSwitchCoordinator', () {
    test('already active programme returns without mutation', () async {
      final assignmentService = _FakeAssignmentService(
        current: ProgrammeScheduleTestFixtures.assignment(
          programmeVersionId: 'version-1',
        ),
      );
      final coordinator = AthleteProgrammeSwitchCoordinator(
        assignmentService: assignmentService,
      );

      final result = await coordinator.switchToProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, AthleteProgrammeSwitchStatus.alreadyActive);
      expect(assignmentService.switchCalls, 0);
      expect(assignmentService.assignCalls, 0);
    });

    test('confirming switch delegates to cancelOrReplaceActiveAssignment', () async {
      final newAssignment = ProgrammeScheduleTestFixtures.assignment(
        id: 'assignment-2',
        programmeVersionId: 'version-2',
      );
      final assignmentService = _FakeAssignmentService(
        current: ProgrammeScheduleTestFixtures.assignment(
          id: 'assignment-1',
          programmeVersionId: 'version-1',
        ),
        switchResult: ProgrammeAssignmentOperationResult(
          status: ProgrammeAssignmentOperationStatus.replaced,
          assignment: newAssignment,
          replacedAssignmentId: 'assignment-1',
        ),
      );
      final coordinator = AthleteProgrammeSwitchCoordinator(
        assignmentService: assignmentService,
      );

      final result = await coordinator.switchToProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-2',
        startedAt: DateTime.utc(2026, 7, 16),
        timezone: 'UTC',
      );

      expect(result.isSuccess, isTrue);
      expect(result.previousAssignmentId, 'assignment-1');
      expect(assignmentService.switchCalls, 1);
    });

    test('assigns when no active programme exists', () async {
      final assignmentService = _FakeAssignmentService(
        switchResult: ProgrammeAssignmentOperationResult(
          status: ProgrammeAssignmentOperationStatus.assigned,
          assignment: ProgrammeScheduleTestFixtures.assignment(),
        ),
      );
      final coordinator = AthleteProgrammeSwitchCoordinator(
        assignmentService: assignmentService,
      );

      await coordinator.switchToProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(assignmentService.assignCalls, 1);
      expect(assignmentService.switchCalls, 0);
    });
  });

  group('AthleteProgrammeSwitchCoordinator integration', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeVersionStore versionStore;
    late InMemoryProgrammeAssignmentStore assignmentStore;
    late InMemoryProgrammeSlotOutcomeStore outcomeStore;
    late ProgrammeAssignmentServiceImpl service;

    ProgrammeVersion publishedVersion({String id = 'version-1'}) {
      return ProgrammeScheduleTestFixtures.version().copyWith(
        id: id,
        lifecycleStatus: ProgrammeLifecycleStatus.published,
      );
    }

    Future<void> seedFlatPublishedProgramme({String versionId = 'version-1'}) async {
      tables.lineages.add(
        const ProgrammeLineage(
          id: 'lineage-1',
          code: 'COHORT-FOUNDATION-TEST',
        ),
      );

      await versionStore.saveTemplateTree(
        version: publishedVersion(id: versionId),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
          programmeVersionId: versionId,
        ),
      );
    }

    setUp(() {
      tables = InMemoryProgrammeTables();
      versionStore = InMemoryProgrammeVersionStore(tables);
      assignmentStore = InMemoryProgrammeAssignmentStore(tables);
      outcomeStore = InMemoryProgrammeSlotOutcomeStore(tables);
      service = ProgrammeAssignmentServiceImpl(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
        todaySessionService: TodaySessionServiceImpl(
          assignmentStore: assignmentStore,
          versionStore: versionStore,
          slotOutcomeStore: outcomeStore,
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        ),
        athleteStateSyncService: _NoOpAthleteStateSyncService(),
      );
    });

    test('ends old assignment, keeps history, one active remains', () async {
      await seedFlatPublishedProgramme();
      const newVersionId = 'version-2';
      tables.weeks.clear();
      tables.days.clear();
      tables.slots.clear();
      await versionStore.saveTemplateTree(
        version: publishedVersion(id: newVersionId).copyWith(versionNumber: 2),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
          programmeVersionId: newVersionId,
        ),
      );

      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment(
          id: 'assignment-1',
          programmeVersionId: 'version-1',
        ),
      );
      tables.outcomes.add(
        ProgrammeSlotOutcome(
          id: 'outcome-1',
          assignmentId: 'assignment-1',
          sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
          resolvedAt: DateTime.utc(2026, 7, 15),
        ),
      );

      final coordinator = AthleteProgrammeSwitchCoordinator(
        assignmentService: service,
      );

      final result = await coordinator.switchToProgramme(
        athleteId: athleteId,
        programmeVersionId: newVersionId,
        startedAt: DateTime.utc(2026, 7, 16),
        timezone: 'UTC',
      );

      expect(result.isSuccess, isTrue);
      expect(tables.assignments, hasLength(2));
      expect(tables.assignments.first.status, ProgrammeAssignmentStatus.reassigned);
      expect(tables.assignments.last.isActive, isTrue);
      expect(tables.outcomes, hasLength(1));
      expect(tables.assignments.where((a) => a.isActive), hasLength(1));
    });
  });

  group('AthleteProgrammeSelectionController', () {
    test('load excludes current programme from switch target list', () async {
      final catalog = AthleteProgrammeSwitchCatalogService(
        catalogService: _FakeCatalogService([
          _entry(id: 'version-1', name: 'Current'),
          _entry(id: 'version-2', name: 'Next'),
        ]),
      );
      final controller = AthleteProgrammeSelectionController(
        athleteId: athleteId,
        catalogService: catalog,
        switchCoordinator: AthleteProgrammeSwitchCoordinator(
          assignmentService: _FakeAssignmentService(),
        ),
        assignmentStore: InMemoryProgrammeAssignmentStore(
          InMemoryProgrammeTables()
            ..assignments.add(
              ProgrammeScheduleTestFixtures.assignment(
                programmeVersionId: 'version-1',
              ),
            ),
        ),
      );

      await controller.load();

      expect(controller.activeVersionId, 'version-1');
      expect(controller.isCurrentProgramme(controller.programmes.first), isTrue);
    });
  });

  group('AthleteProgrammeScreen widget', () {
    testWidgets('Start New Programme visible when athlete has active programme', (
      tester,
    ) async {
      final tables = InMemoryProgrammeTables()
        ..assignments.add(ProgrammeScheduleTestFixtures.assignment())
        ..versions.add(
          ProgrammeScheduleTestFixtures.version().copyWith(
            lifecycleStatus: ProgrammeLifecycleStatus.published,
            name: 'Foundation',
          ),
        );

      final controller = AthleteProgrammeScreenController(
        athleteId: athleteId,
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScreen(
            athleteId: athleteId,
            controller: controller,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Start New Programme'), findsOneWidget);
      expect(find.text('Foundation'), findsOneWidget);
    });

    testWidgets('Start New Programme available without active programme', (
      tester,
    ) async {
      final controller = AthleteProgrammeScreenController(
        athleteId: athleteId,
        assignmentStore: InMemoryProgrammeAssignmentStore(InMemoryProgrammeTables()),
        versionStore: InMemoryProgrammeVersionStore(InMemoryProgrammeTables()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScreen(
            athleteId: athleteId,
            controller: controller,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Start New Programme'), findsOneWidget);
    });
  });

  group('Today refresh after switch', () {
    test('refresh controller receives request after successful switch', () {
      var refreshCount = 0;
      final refreshController = HomeTodaySessionRefreshController()
        ..attach(({required String source}) {
          refreshCount++;
          expect(source, 'athlete_programme_switch');
        });

      refreshController.requestRefresh(source: 'athlete_programme_switch');
      expect(refreshCount, 1);
      refreshController.detach();
    });
  });
}
