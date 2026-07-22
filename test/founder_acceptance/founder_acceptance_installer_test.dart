import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_content.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_dev_fixtures.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_installer.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_actions.dart';
import 'package:cohort_platform/features/programme/debug/programme_dev_fixtures.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_development_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';
import '../support/programme_session_authoring_test_support.dart';

void main() {
  group('FounderAcceptanceContent', () {
    test('uses stable canonical identifiers', () {
      expect(FounderAcceptanceContent.protocolId, 'm8-modern-capture-test');
      expect(
        FounderAcceptanceContent.programmeLineageCode,
        'FOUNDER-ACCEPTANCE-PROGRAMME',
      );
      expect(FounderAcceptanceDevFixtures.versionId, isNotEmpty);
    });

    test('full capture plan has five typed blocks', () {
      final blocks = FounderAcceptanceContent.sessionBlocks();
      expect(blocks, hasLength(5));
      expect(blocks[0].performanceCaptureMode,
          BlockPerformanceCaptureMode.completion);
      expect(blocks[1].performanceCaptureMode,
          BlockPerformanceCaptureMode.strength);
      expect(blocks[2].performanceCaptureMode,
          BlockPerformanceCaptureMode.endurance);
      expect(blocks[3].performanceCaptureMode, BlockPerformanceCaptureMode.amrap);
      expect(blocks[4].performanceCaptureMode,
          BlockPerformanceCaptureMode.completion);
    });
  });

  group('FounderAcceptanceInstaller', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeVersionStore versionStore;
    late FakeProtocolBuilderService protocolService;
    late FounderAcceptanceInstaller installer;

    setUp(() {
      tables = InMemoryProgrammeTables();
      versionStore = InMemoryProgrammeVersionStore(tables);
      protocolService = FakeProtocolBuilderService();
      installer = FounderAcceptanceInstaller(
        protocolBuilderService: protocolService,
        versionStore: versionStore,
      );
    });

    test('install when absent creates programme session and tree', () async {
      final result = await installer.install();

      expect(result.programmeCreated, isTrue);
      expect(result.sessionCreated, isTrue);
      expect(result.blockCount, 5);
      expect(protocolService.saveCallCount, 1);
      expect(
        protocolService.drafts[FounderAcceptanceContent.protocolId]?.blocks,
        hasLength(5),
      );

      final lineage = await versionStore.getLineageByCode(
        FounderAcceptanceContent.programmeLineageCode,
      );
      expect(lineage?.id, FounderAcceptanceDevFixtures.lineageId);

      final version = await versionStore.getVersionByLineageAndNumber(
        lineageCode: FounderAcceptanceContent.programmeLineageCode,
        versionNumber: 1,
      );
      expect(version?.id, FounderAcceptanceDevFixtures.versionId);

      final tree = await versionStore.loadTemplateTree(version!.id);
      expect(tree?.weekNodes, hasLength(1));
      expect(
        tree?.weekNodes.first.days.first.slots.first.protocolId,
        FounderAcceptanceContent.protocolId,
      );
    });

    test('install when already present updates without duplicate lineage',
        () async {
      await installer.install();
      final lineageCountAfterFirst = tables.lineages.length;

      final second = await installer.install();

      expect(second.programmeUpdated, isTrue);
      expect(tables.lineages.length, lineageCountAfterFirst);
      expect(
        tables.lineages.where(
          (lineage) =>
              lineage.code == FounderAcceptanceContent.programmeLineageCode,
        ),
        hasLength(1),
      );
      expect(protocolService.saveCallCount, 2);
    });

    test('stable IDs retained across reinstall', () async {
      await installer.install();
      await installer.install();

      final version = await versionStore.getVersionByLineageAndNumber(
        lineageCode: FounderAcceptanceContent.programmeLineageCode,
        versionNumber: 1,
      );
      expect(version?.id, FounderAcceptanceDevFixtures.versionId);

      final tree = await versionStore.loadTemplateTree(version!.id);
      expect(tree?.weekNodes.first.week.id, FounderAcceptanceDevFixtures.weekId);
      expect(tree?.weekNodes.first.days.first.day.id,
          FounderAcceptanceDevFixtures.dayId);
      expect(tree?.weekNodes.first.days.first.slots.first.id,
          FounderAcceptanceDevFixtures.slotId);
    });
  });

  group('ProgrammeDebugActions founder acceptance workflow', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeVersionStore versionStore;
    late InMemoryProgrammeAssignmentStore assignmentStore;
    late InMemoryProgrammeSlotOutcomeStore outcomeStore;
    late InMemoryAthleteStateStore athleteStore;
    late FakeProtocolBuilderService protocolService;

    ProgrammeAssignmentServiceImpl assignmentService() {
      return ProgrammeAssignmentServiceImpl(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
        todaySessionService: TodaySessionServiceImpl(
          assignmentStore: assignmentStore,
          versionStore: versionStore,
          slotOutcomeStore: outcomeStore,
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        ),
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );
    }

    Future<void> seedFoundationActiveAssignment() async {
      const foundationAssignmentId = 'aaaaaaaa-bbbb-cccc-dddd-000000000100';
      final versionId = ProgrammeDevFixtures.foundationTestVersionId;

      tables.lineages.add(
        const ProgrammeLineage(
          id: 'lineage-1',
          code: ProgrammeDevFixtures.foundationTestLineageCode,
        ),
      );
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version().copyWith(
          id: versionId,
        ),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
          programmeVersionId: versionId,
        ),
      );
      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment().copyWith(
          id: foundationAssignmentId,
          programmeVersionId: versionId,
          lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
        ),
      );
      tables.outcomes.add(
        ProgrammeScheduleTestFixtures.outcome(
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          status: ProgrammeSlotOutcomeStatus.completed,
          assignmentId: foundationAssignmentId,
        ),
      );
    }

    setUp(() async {
      tables = InMemoryProgrammeTables();
      versionStore = InMemoryProgrammeVersionStore(tables);
      assignmentStore = InMemoryProgrammeAssignmentStore(tables);
      outcomeStore = InMemoryProgrammeSlotOutcomeStore(tables);
      athleteStore = InMemoryAthleteStateStore(tables);
      protocolService = FakeProtocolBuilderService();

      await FounderAcceptanceInstaller(
        protocolBuilderService: protocolService,
        versionStore: versionStore,
      ).install();
    });

    test('assigns when no existing active assignment', () async {
      final assignResult =
          await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      expect(assignResult.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(assignResult.athleteStateSynced, isTrue);
      expect(
        assignResult.assignment?.lineageCode,
        ProgrammeDevFixtures.founderAcceptanceLineageCode,
      );
      expect(
        assignResult.assignment?.programmeVersionId,
        ProgrammeDevFixtures.founderAcceptanceVersionId,
      );
      expect(
        tables.assignments.where((assignment) => assignment.isActive),
        hasLength(1),
      );
    });

    test('replaces another active assignment and preserves historical outcomes',
        () async {
      await seedFoundationActiveAssignment();
      final foundationOutcomeCount = tables.outcomes.length;

      final assignResult =
          await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      expect(assignResult.status, ProgrammeAssignmentOperationStatus.replaced);
      expect(assignResult.replacedAssignmentId, isNotNull);
      expect(
        tables.assignments.where((assignment) => assignment.isActive),
        hasLength(1),
      );
      expect(
        tables.assignments
            .where(
              (assignment) =>
                  assignment.status == ProgrammeAssignmentStatus.reassigned,
            )
            .length,
        1,
      );
      expect(tables.outcomes.length, foundationOutcomeCount);
      expect(
        assignResult.assignment?.lineageCode,
        ProgrammeDevFixtures.founderAcceptanceLineageCode,
      );
    });

    test('is idempotent when founder programme already active', () async {
      final first =
          await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      final second =
          await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      expect(first.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(second.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(second.assignment?.id, first.assignment?.id);
      expect(
        tables.assignments.where((assignment) => assignment.isActive),
        hasLength(1),
      );
    });

    test('does not create duplicate assignment on repeated assign', () async {
      await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );
      await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      expect(
        tables.assignments.where((assignment) => assignment.isActive),
        hasLength(1),
      );
      expect(tables.assignments, hasLength(1));
    });

    test('assignment resolves executable founder session', () async {
      final assignResult =
          await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      expect(assignResult.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(
        assignResult.assignment?.lineageCode,
        ProgrammeDevFixtures.founderAcceptanceLineageCode,
      );

      final resolved =
          await ProgrammeDebugActions.resolveFounderAcceptanceProgramme(
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
      );

      expect(resolved.kind, ResolvedTodaySessionKind.executable);
      expect(
        resolved.effectiveProtocolId,
        FounderAcceptanceContent.protocolId,
      );
    });

    test('home projection resolves M8 Modern Capture Test', () async {
      await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      final athleteState =
          await athleteStore.getByAthleteId(ProgrammeDebugActions.devAthleteId);

      expect(athleteState?.programmeId,
          ProgrammeDevFixtures.founderAcceptanceLineageCode);
      expect(athleteState?.currentProtocolId, FounderAcceptanceContent.protocolId);
    });

    test('reset returns cursor to week 1 day 1 slot 1', () async {
      await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );

      final resetResult =
          await ProgrammeDebugActions.resetFounderAcceptanceProgrammeAssignment(
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        developmentService: ProgrammeAssignmentDevelopmentServiceImpl(
          assignmentStore: assignmentStore,
          slotOutcomeStore: outcomeStore,
          versionStore: versionStore,
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
          todaySessionService: TodaySessionServiceImpl(
            assignmentStore: assignmentStore,
            versionStore: versionStore,
            slotOutcomeStore: outcomeStore,
            scheduleResolver: const ProgrammeScheduleResolverImpl(),
          ),
          athleteStateSyncService: AthleteStateSyncServiceImpl(
            athleteStateStore: athleteStore,
          ),
        ),
      );

      expect(resetResult.status, isNot(ProgrammeAssignmentOperationStatus.failed));
      expect(resetResult.assignment?.currentWeek, 1);
      expect(resetResult.assignment?.currentDayKey, 'day_1');
      expect(resetResult.assignment?.currentSessionOrder, 1);
    });
  });
}
