import '../support/programme_dev_identity.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_content.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_dev_fixtures.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_installer.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_runtime_reset_service.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_actions.dart';
import 'package:cohort_platform/features/programme/debug/programme_dev_fixtures.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_development_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/active_session_state.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/training_session_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_training_session_repository.dart';
import '../support/programme_schedule_test_fixtures.dart';
import '../support/programme_session_authoring_test_support.dart';

void main() {
  group('FounderAcceptanceRuntimeResetService', () {
    late InMemoryPerformanceRecordStore performanceStore;
    late InMemoryTrainingSessionRepository trainingSessionRepository;
    late FounderAcceptanceRuntimeResetService resetService;
    late SessionExecutionPlan plan;

    const athleteId = ProgrammeDevIdentity.athleteId;
    const founderProtocolId = FounderAcceptanceContent.protocolId;
    const unrelatedProtocolId = 'foundation-session-a';
    const founderAssignmentId = 'founder-assignment-test';

    setUp(() {
      performanceStore = InMemoryPerformanceRecordStore();
      trainingSessionRepository = InMemoryTrainingSessionRepository();
      resetService = FounderAcceptanceRuntimeResetService(
        performanceRecordStore: performanceStore,
        trainingSessionRepository: trainingSessionRepository,
      );
      plan = FounderAcceptanceContent.executionPlan();
      AthleteSessionMemoryStore.instance.clearForProtocol(founderProtocolId);
    });

    Future<PerformanceCaptureController> seedFounderPerformanceSession({
      required int trainingSessionId,
      TrainingSessionRecordStatus status =
          TrainingSessionRecordStatus.inProgress,
      bool completeStrengthBlock = false,
    }) async {
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: plan,
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
      );

      if (completeStrengthBlock) {
        final strengthBlockId = 'block-strength';
        final squatId = controller
            .draft
            .blockDraftFor(strengthBlockId)!
            .exerciseResults
            .first
            .sourceExerciseId;
        controller
          ..addSet(strengthBlockId, squatId)
          ..updateSet(
            strengthBlockId,
            squatId,
            controller
                .draft
                .blockDraftFor(strengthBlockId)!
                .exerciseResults
                .first
                .sets
                .first
                .setResultId,
            (set) => set.copyWith(reps: 5, load: 100, completed: true),
          )
          ..markBlockComplete(strengthBlockId);
      }

      if (status == TrainingSessionRecordStatus.inProgress) {
        await performanceStore.createOrResumeInProgress(controller.draft);
        await performanceStore.saveDraft(controller.draft);
      } else {
        for (final block in controller.draft.blockDrafts) {
          controller.markBlockComplete(block.sourceBlockId);
        }
        await performanceStore.completeRecord(
          controller.buildPersistableDraft(status: status),
        );
      }

      return controller;
    }

    Future<PerformanceCaptureController> simulateSessionStart({
      required int trainingSessionId,
    }) async {
      final coordinator = PerformanceRecordSaveCoordinator(
        store: performanceStore,
        trainingSessionRepository: trainingSessionRepository,
      );

      final existing = await coordinator.loadInProgressDraftAsRecord(
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
      );
      if (existing != null) {
        return coordinator.restoreControllerFromRecord(existing);
      }

      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: plan,
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
      );
      await coordinator.createOrResumeInProgress(controller: controller);
      return controller;
    }

    test('reset with no prior founder session is safe', () async {
      final result = await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );

      expect(result.deletedPerformanceRecords, 0);
      expect(result.deletedTrainingSessions, 0);
      expect(result.clearedMemoryKeys, 0);
    });

    test('reset with in-progress founder session clears performance records',
        () async {
      final session = trainingSessionRepository.seed(
        athleteId: athleteId,
        protocolId: founderProtocolId,
        status: TrainingSessionStatus.inProgress,
        startedAt: DateTime.now().toUtc(),
      );
      await seedFounderPerformanceSession(
        trainingSessionId: session.id,
        completeStrengthBlock: true,
      );

      final result = await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );

      expect(result.deletedPerformanceRecords, 1);
      expect(result.deletedTrainingSessions, 1);
      expect(
        await performanceStore.getInProgressForTrainingSession(
          athleteId: athleteId,
          trainingSessionId: session.id,
        ),
        isNull,
      );
    });

    test('reset with completed founder session clears terminal records',
        () async {
      final session = trainingSessionRepository.seed(
        athleteId: athleteId,
        protocolId: founderProtocolId,
        status: TrainingSessionStatus.completed,
        startedAt: DateTime.now().toUtc(),
        completedAt: DateTime.now().toUtc(),
      );
      await seedFounderPerformanceSession(
        trainingSessionId: session.id,
        status: TrainingSessionRecordStatus.completed,
        completeStrengthBlock: true,
      );

      final result = await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );

      expect(result.deletedPerformanceRecords, 1);
      expect(
        await performanceStore.getTerminalForTrainingSession(
          athleteId: athleteId,
          trainingSessionId: session.id,
        ),
        isNull,
      );
    });

    test('founder performance records cleared while unrelated records remain',
        () async {
      final founderSession = trainingSessionRepository.seed(
        athleteId: athleteId,
        protocolId: founderProtocolId,
        status: TrainingSessionStatus.completed,
      );
      final otherSession = trainingSessionRepository.seed(
        athleteId: athleteId,
        protocolId: unrelatedProtocolId,
        status: TrainingSessionStatus.completed,
      );

      await seedFounderPerformanceSession(
        trainingSessionId: founderSession.id,
        status: TrainingSessionRecordStatus.completed,
      );

      final otherController =
          PerformanceCaptureController.initializeFromExecutionPlan(
        plan: SessionExecutionPlan(
          sessionId: unrelatedProtocolId,
          sessionTitle: 'Foundation Session',
          blocks: plan.blocks,
        ),
        athleteId: athleteId,
        trainingSessionId: otherSession.id,
      );
      otherController.markBlockComplete(
        otherController.draft.blockDrafts.first.sourceBlockId,
      );
      await performanceStore.completeRecord(
        otherController.buildPersistableDraft(
          status: TrainingSessionRecordStatus.completed,
        ),
      );

      await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );

      expect(
        await performanceStore.getTerminalForTrainingSession(
          athleteId: athleteId,
          trainingSessionId: founderSession.id,
        ),
        isNull,
      );
      expect(
        await performanceStore.getTerminalForTrainingSession(
          athleteId: athleteId,
          trainingSessionId: otherSession.id,
        ),
        isNotNull,
      );
      expect(trainingSessionRepository.sessions, hasLength(1));
      expect(trainingSessionRepository.sessions.single.protocolId,
          unrelatedProtocolId);
    });

    test('clears in-memory session execution state for founder protocol', () async {
      const trainingSessionId = 8801;
      final sessionKey = AthleteSessionMemoryStore.sessionKey(
        protocolId: founderProtocolId,
        trainingSessionId: trainingSessionId,
      );
      AthleteSessionMemoryStore.instance.write(
        ActiveSessionState.initial(sessionKey: sessionKey, plan: plan).copyWith(
          sessionStatus: SessionExecutionStatus.inProgress,
          completedBlockIds: {'block-warmup', 'block-strength'},
          activeBlockIndex: 2,
        ),
      );

      final result = await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );

      expect(result.clearedMemoryKeys, 1);
      expect(AthleteSessionMemoryStore.instance.read(sessionKey), isNull);
    });

    test('repeated reset remains safe', () async {
      final session = trainingSessionRepository.seed(
        athleteId: athleteId,
        protocolId: founderProtocolId,
        status: TrainingSessionStatus.inProgress,
      );
      await seedFounderPerformanceSession(trainingSessionId: session.id);

      final first = await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );
      final second = await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );

      expect(first.deletedPerformanceRecords, 1);
      expect(second.deletedPerformanceRecords, 0);
      expect(second.deletedTrainingSessions, 0);
      expect(second.clearedMemoryKeys, 0);
    });

    test('post-reset execution shows empty strength editors via restore path',
        () async {
      final session = trainingSessionRepository.seed(
        athleteId: athleteId,
        protocolId: founderProtocolId,
        status: TrainingSessionStatus.inProgress,
      );
      await seedFounderPerformanceSession(
        trainingSessionId: session.id,
        completeStrengthBlock: true,
      );

      await resetService.clearFounderRuntimeState(
        athleteId: athleteId,
        assignmentId: founderAssignmentId,
      );

      final controller = await simulateSessionStart(
        trainingSessionId: session.id,
      );
      final strengthDraft = controller.draft.blockDraftFor('block-strength');

      expect(strengthDraft, isNotNull);
      expect(strengthDraft!.status, TrainingBlockResultStatus.notStarted);
      expect(strengthDraft.exerciseResults, hasLength(2));
      expect(
        strengthDraft.exerciseResults.every((exercise) => exercise.sets.isEmpty),
        isTrue,
      );
      expect(BlockResultEditor.showsCaptureFields(strengthDraft), isTrue);
    });
  });

  group('ProgrammeDebugActions founder reset integration', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeVersionStore versionStore;
    late InMemoryProgrammeAssignmentStore assignmentStore;
    late InMemoryProgrammeSlotOutcomeStore outcomeStore;
    late InMemoryAthleteStateStore athleteStore;
    late InMemoryPerformanceRecordStore performanceStore;
    late InMemoryTrainingSessionRepository trainingSessionRepository;
    late FakeProtocolBuilderService protocolService;

    ProgrammeAssignmentDevelopmentServiceImpl developmentService() {
      return ProgrammeAssignmentDevelopmentServiceImpl(
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
      );
    }

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

    setUp(() async {
      tables = InMemoryProgrammeTables();
      versionStore = InMemoryProgrammeVersionStore(tables);
      assignmentStore = InMemoryProgrammeAssignmentStore(tables);
      outcomeStore = InMemoryProgrammeSlotOutcomeStore(tables);
      athleteStore = InMemoryAthleteStateStore(tables);
      performanceStore = InMemoryPerformanceRecordStore();
      trainingSessionRepository = InMemoryTrainingSessionRepository();
      protocolService = FakeProtocolBuilderService();

      await FounderAcceptanceInstaller(
        protocolBuilderService: protocolService,
        versionStore: versionStore,
      ).install();

      await ProgrammeDebugActions.assignFounderAcceptanceProgramme(
        assignmentService: assignmentService(),
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: athleteStore,
        ),
      );
    });

    test('founder outcome rows cleared and athlete_state reprojects unstarted',
        () async {
      final assignment = tables.assignments.singleWhere(
        (entry) => entry.lineageCode == ProgrammeDevFixtures.founderAcceptanceLineageCode,
      );
      tables.outcomes.add(
        ProgrammeSlotOutcome(
          id: 'founder-outcome-1',
          assignmentId: assignment.id,
          sessionSlotId: FounderAcceptanceDevFixtures.slotId,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
        ),
      );

      final resetResult =
          await ProgrammeDebugActions.resetFounderAcceptanceProgrammeAssignment(
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        developmentService: developmentService(),
        runtimeResetService: FounderAcceptanceRuntimeResetService(
          performanceRecordStore: performanceStore,
          trainingSessionRepository: trainingSessionRepository,
        ),
      );

      expect(resetResult.status, isNot(ProgrammeAssignmentOperationStatus.failed));
      expect(resetResult.assignment?.currentWeek, 1);
      expect(resetResult.assignment?.currentDayKey, 'day_1');
      expect(resetResult.assignment?.currentSessionOrder, 1);
      expect(tables.outcomes, isEmpty);
      expect(
        resetResult.resolvedTodaySession?.kind,
        ResolvedTodaySessionKind.executable,
      );
      expect(
        resetResult.resolvedTodaySession?.outcomeStatus,
        ProgrammeSlotOutcomeStatus.scheduled,
      );

      final athleteState =
          await athleteStore.getByAthleteId(ProgrammeDebugActions.devAthleteId);
      expect(athleteState?.currentProtocolId, FounderAcceptanceContent.protocolId);
      expect(athleteState?.sessionStatus, ProgrammeSlotOutcomeStatus.scheduled.dbValue);
    });

    test('unrelated programme history remains untouched', () async {
      await seedFoundationActiveAssignment(
        tables: tables,
        versionStore: versionStore,
      );
      final foundationOutcomeCount = tables.outcomes.length;

      final resetResult =
          await ProgrammeDebugActions.resetFounderAcceptanceProgrammeAssignment(
        assignmentStore: assignmentStore,
        slotOutcomeStore: outcomeStore,
        versionStore: versionStore,
        developmentService: developmentService(),
        runtimeResetService: FounderAcceptanceRuntimeResetService(
          performanceRecordStore: performanceStore,
          trainingSessionRepository: trainingSessionRepository,
        ),
      );

      expect(resetResult.isSuccess, isTrue);
      expect(tables.outcomes.length, foundationOutcomeCount);
      expect(
        tables.assignments.where(
          (assignment) =>
              assignment.lineageCode ==
                  ProgrammeDevFixtures.foundationTestLineageCode &&
              assignment.status == ProgrammeAssignmentStatus.reassigned,
        ),
        isEmpty,
      );
    });
  });
}

Future<void> seedFoundationActiveAssignment({
  required InMemoryProgrammeTables tables,
  required InMemoryProgrammeVersionStore versionStore,
}) async {
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
