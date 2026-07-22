import 'package:cohort_platform/data/repositories/athlete_state_store.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/data/repositories/programme_slot_outcome_store.dart';
import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:cohort_platform/features/programme/errors/programme_progression_exception.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/programme_progression_result.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_actions.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_progression_service.dart';
import 'package:cohort_platform/features/programme/services/programme_progression_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_slot_outcome_service_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/features/session/services/programme_session_progression_coordinator.dart';
import 'package:cohort_platform/models/athlete_state.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';
import 'support/programme_schedule_test_fixtures.dart';

void main() {
  group('ProgrammeProgressionServiceImpl', () {
    late InMemoryProgrammeTables tables;
    late ProgrammeProgressionServiceImpl service;
    late ResolvedTodaySession dayOneResolution;

    setUp(() async {
      tables = InMemoryProgrammeTables();
      final versionStore = InMemoryProgrammeVersionStore(tables);
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      service = _buildService(tables);
      dayOneResolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );
    });

    test('in_progress outcome does not advance cursor', () async {
      final before = tables.assignments.first;
      final result = await service.markSessionStarted(
        athleteId: 'lee',
        resolution: dayOneResolution,
        trainingSessionId: 101,
      );

      final after = tables.assignments.first;
      expect(after.currentWeek, before.currentWeek);
      expect(after.currentDayKey, before.currentDayKey);
      expect(after.currentSessionOrder, before.currentSessionOrder);
      expect(result.outcome?.outcomeStatus, ProgrammeSlotOutcomeStatus.inProgress);
      expect(result.status, ProgrammeProgressionStatus.completed);
    });

    test('completed outcome advances to next day when day has one slot', () async {
      final result = await service.completeSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        trainingSessionId: 201,
      );

      expect(tables.assignments.first.currentDayKey, 'day_2');
      expect(result.nextResolvedSession?.effectiveProtocolId, 'RN-006');
      expect(result.status, ProgrammeProgressionStatus.completed);
    });

    test('resolve after day_1 complete returns day_2 executable', () async {
      await service.completeSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        trainingSessionId: 210,
      );

      final todayService = TodaySessionServiceImpl(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      );

      final resolved = await todayService.resolveForAthlete('lee');

      expect(resolved.kind, ResolvedTodaySessionKind.executable);
      expect(resolved.dayKey, 'day_2');
      expect(resolved.effectiveProtocolId, 'RN-006');
      expect(resolved.weekNumber, 1);
    });

    test('getCurrentAssignment preserves progressed cursor after assign', () async {
      tables.assignments[0] = ProgrammeScheduleTestFixtures.assignment(
        dayKey: 'day_2',
        slotOrder: 1,
      );

      final store = InMemoryProgrammeAssignmentStore(tables);
      final current = await ProgrammeAssignmentServiceImpl(
        assignmentStore: store,
        versionStore: InMemoryProgrammeVersionStore(tables),
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
        todaySessionService: TodaySessionServiceImpl(
          assignmentStore: store,
          versionStore: InMemoryProgrammeVersionStore(tables),
          slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        ),
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: InMemoryAthleteStateStore(tables),
        ),
      ).getCurrentAssignment(athleteId: 'lee');

      expect(current?.currentDayKey, 'day_2');
      expect(current?.currentWeek, 1);
    });

    test('completed_partial advances day but preserves remaining required slots', () async {
      tables.assignments[0] = ProgrammeScheduleTestFixtures.assignment();
      final twoSlotTree = ProgrammeScheduleTestFixtures.twoSlotDayTree();
      await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: twoSlotTree,
      );

      final partialService = _buildService(tables);
      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: twoSlotTree,
          outcomes: const [],
        ),
      );

      final result = await partialService.completeSessionPartial(
        athleteId: 'lee',
        resolution: resolution,
        trainingSessionId: 301,
      );

      expect(tables.assignments.first.currentSessionOrder, 2);
      expect(result.nextResolvedSession?.slotId, ProgrammeScheduleTestFixtures.slot2Id);
    });

    test('skipped outcome advances using required-slot rules', () async {
      final result = await service.skipSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        resolutionNote: 'Travel day',
      );

      expect(tables.assignments.first.currentDayKey, 'day_2');
      expect(result.outcome?.outcomeStatus, ProgrammeSlotOutcomeStatus.skipped);
      expect(result.outcome?.resolutionNote, 'Travel day');
    });

    test('optional slot does not block day advancement', () async {
      final optionalTree = ProgrammeScheduleTestFixtures.optionalSlotDayTree();
      await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: optionalTree,
      );

      final optionalService = _buildService(tables);
      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: optionalTree,
          outcomes: const [],
        ),
      );

      final result = await optionalService.completeSession(
        athleteId: 'lee',
        resolution: resolution,
      );

      expect(tables.assignments.first.currentDayKey, 'day_2');
      expect(result.nextResolvedSession?.effectiveProtocolId, 'RN-006');
    });

    test('multiple required slots stay on same day until all resolved', () async {
      final twoSlotTree = ProgrammeScheduleTestFixtures.twoSlotDayTree();
      await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: twoSlotTree,
      );
      final twoSlotService = _buildService(tables);
      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: twoSlotTree,
          outcomes: const [],
        ),
      );

      await twoSlotService.completeSession(
        athleteId: 'lee',
        resolution: resolution,
        trainingSessionId: 401,
      );

      expect(tables.assignments.first.currentDayKey, 'day_1');
      expect(tables.assignments.first.currentSessionOrder, 2);
    });

    test('week rollover advances to next week first day', () async {
      tables.assignments[0] = ProgrammeScheduleTestFixtures.assignment(
        dayKey: 'day_4',
      );
      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: tables.assignments.first,
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );

      final result = await service.completeSession(
        athleteId: 'lee',
        resolution: resolution,
        trainingSessionId: 501,
      );

      expect(tables.assignments.first.currentWeek, 2);
      expect(tables.assignments.first.currentDayKey, 'day_1');
      expect(result.nextResolvedSession?.weekNumber, 2);
    });

    test('rest day clears current protocol projection', () async {
      tables.assignments[0] = ProgrammeScheduleTestFixtures.assignment(
        dayKey: 'day_2',
      );
      tables.athleteStates.add(
        const AthleteState(
          athleteId: 'lee',
          programmeId: 'COHORT-FOUNDATION-TEST',
          currentWeek: 1,
          currentDay: 'day_2',
          currentProtocolId: 'RN-006',
          sessionStatus: 'completed',
        ),
      );

      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: tables.assignments.first,
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );

      await service.completeSession(
        athleteId: 'lee',
        resolution: resolution,
        trainingSessionId: 601,
      );

      expect(tables.assignments.first.currentDayKey, 'day_3');
      final state = tables.athleteStates.first;
      expect(state.currentDay, 'day_3');
      expect(state.currentProtocolId, isNull);
      expect(state.sessionStatus, isNull);
    });

    test('programme completion marks assignment complete', () async {
      final singleDayTree = ProgrammeScheduleTestFixtures.singleWeekTree(
        days: [
          ProgrammeScheduleTestFixtures.trainingDay(
            id: ProgrammeScheduleTestFixtures.day1Id,
            weekId: ProgrammeScheduleTestFixtures.week1Id,
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: ProgrammeScheduleTestFixtures.slot1Id,
                dayId: ProgrammeScheduleTestFixtures.day1Id,
                sessionOrder: 1,
                protocolId: 'BW-001',
              ),
            ],
          ),
        ],
      );
      await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: singleDayTree,
      );

      final completeService = _buildService(tables);
      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: singleDayTree,
          outcomes: const [],
        ),
      );

      final result = await completeService.completeSession(
        athleteId: 'lee',
        resolution: resolution,
        trainingSessionId: 701,
      );

      expect(tables.assignments.first.status, ProgrammeAssignmentStatus.completed);
      expect(tables.assignments.first.completedAt, isNotNull);
      expect(result.status, ProgrammeProgressionStatus.programmeComplete);
      expect(tables.athleteStates.first.currentProtocolId, isNull);
    });

    test('replacement remains unresolved until completed', () async {
      final result = await service.replaceSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        replacementProtocolId: 'FG-009',
      );

      expect(tables.assignments.first.currentDayKey, 'day_1');
      expect(result.outcome?.outcomeStatus, ProgrammeSlotOutcomeStatus.replaced);
      expect(result.nextResolvedSession?.effectiveProtocolId, 'FG-009');
    });

    test('rescheduled remains unresolved', () async {
      final result = await service.resolveAfterOutcome(
        athleteId: 'lee',
        resolution: dayOneResolution,
        outcomeStatus: ProgrammeSlotOutcomeStatus.rescheduled,
      );

      expect(result.status, ProgrammeProgressionStatus.staleResolution);
      expect(tables.outcomes, isEmpty);
    });

    test('duplicate completion is idempotent', () async {
      await service.completeSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        trainingSessionId: 801,
      );

      tables.assignments[0] = tables.assignments.first.copyWith(
        currentWeek: 1,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
        lastProgressedTrainingSessionId: 801,
      );

      final result = await service.completeSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        trainingSessionId: 801,
      );

      expect(tables.assignments.first.currentDayKey, 'day_1');
      expect(result.warnings, isNotEmpty);
    });

    test('stale resolution is rejected', () async {
      final stale = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.executable,
        assignmentId: 'assignment-1',
        programmeVersionId: 'version-1',
        weekNumber: 2,
        dayKey: 'day_2',
        slotId: 'slot-2',
        slotOrder: 1,
        plannedProtocolId: 'RN-006',
        effectiveProtocolId: 'RN-006',
      );

      final result = await service.completeSession(
        athleteId: 'lee',
        resolution: stale,
        trainingSessionId: 901,
      );

      expect(result.status, ProgrammeProgressionStatus.staleResolution);
      expect(tables.outcomes, isEmpty);
    });

    test('outcome persistence failure prevents cursor update', () async {
      tables.denyWrites = true;
      final failingService = _buildService(tables);

      expect(
        () => failingService.completeSession(
          athleteId: 'lee',
          resolution: dayOneResolution,
          trainingSessionId: 1001,
        ),
        throwsA(isA<ProgrammeProgressionException>()),
      );
      expect(tables.outcomes, isEmpty);
      expect(tables.assignments.first.currentDayKey, 'day_1');
    });

    test('cursor update failure returns partialSuccess', () async {
      final failingTables = InMemoryProgrammeTables();
      await InMemoryProgrammeVersionStore(failingTables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      failingTables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final assignmentStore = _FailingOnUpdateAssignmentStore(failingTables);
      final serviceWithFailingAssignment = _buildService(
        failingTables,
        assignmentStore: assignmentStore,
      );

      final result = await serviceWithFailingAssignment.completeSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        trainingSessionId: 1101,
      );

      expect(result.status, ProgrammeProgressionStatus.partialSuccess);
      expect(result.outcome, isNotNull);
      expect(result.updatedAssignment, isNull);
      expect(result.warnings.first, contains('assignment cursor update failed'));
    });

    test('athlete_state sync failure returns partialSuccess', () async {
      final failingTables = InMemoryProgrammeTables();
      await InMemoryProgrammeVersionStore(failingTables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      failingTables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final serviceWithFailingSync = _buildService(
        failingTables,
        athleteStateStore: _FailingAthleteStateStore(failingTables),
      );

      final result = await serviceWithFailingSync.completeSession(
        athleteId: 'lee',
        resolution: dayOneResolution,
        trainingSessionId: 1201,
      );

      expect(result.status, ProgrammeProgressionStatus.partialSuccess);
      expect(result.outcome, isNotNull);
      expect(result.updatedAssignment, isNotNull);
      expect(result.warnings.first, contains('athlete_state sync failed'));
    });
  });

  group('ProgrammeSessionProgressionCoordinator', () {
    test('manual non-programme session remains unchanged', () async {
      final coordinator = ProgrammeSessionProgressionCoordinator(
        progressionService: _NoOpProgressionService(),
      );

      final started = await coordinator.markSessionStartedIfProgrammeBacked(
        athleteId: 'lee',
        programmeContext: null,
        trainingSessionId: 1,
      );
      final completed = await coordinator.handleSessionCompleted(
        athleteId: 'lee',
        programmeContext: null,
        trainingSessionId: 1,
        endedEarly: false,
      );

      expect(started, isNull);
      expect(completed, isNull);
    });

    test('programme execution context round-trips from resolution', () {
      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );

      final context = ProgrammeExecutionContext.fromResolvedSession(resolution);
      expect(context.assignmentId, 'assignment-1');
      expect(context.sessionSlotId, ProgrammeScheduleTestFixtures.slot1Id);
      expect(context.effectiveProtocolId, 'BW-001');
    });
  });
}

ProgrammeProgressionServiceImpl _buildService(
  InMemoryProgrammeTables tables, {
  ProgrammeAssignmentStore? assignmentStore,
  ProgrammeSlotOutcomeStore? slotOutcomeStore,
  AthleteStateStore? athleteStateStore,
}) {
  final assignments =
      assignmentStore ?? InMemoryProgrammeAssignmentStore(tables);
  final outcomes = slotOutcomeStore ?? InMemoryProgrammeSlotOutcomeStore(tables);
  final athletes = athleteStateStore ?? InMemoryAthleteStateStore(tables);
  const resolver = ProgrammeScheduleResolverImpl();

  return ProgrammeProgressionServiceImpl(
    assignmentStore: assignments,
    slotOutcomeStore: outcomes,
    versionStore: InMemoryProgrammeVersionStore(tables),
    slotOutcomeService: ProgrammeSlotOutcomeServiceImpl(
      slotOutcomeStore: outcomes,
    ),
    scheduleResolver: resolver,
    todaySessionService: TodaySessionServiceImpl(
      assignmentStore: assignments,
      versionStore: InMemoryProgrammeVersionStore(tables),
      slotOutcomeStore: outcomes,
      scheduleResolver: resolver,
    ),
    athleteStateSyncService: AthleteStateSyncServiceImpl(
      athleteStateStore: athletes,
    ),
  );
}

class _FailingOnUpdateAssignmentStore extends InMemoryProgrammeAssignmentStore {
  _FailingOnUpdateAssignmentStore(super.tables);

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) async {
    throw ProgrammeStoreException('Simulated assignment update failure');
  }
}

class _FailingAthleteStateStore extends InMemoryAthleteStateStore {
  _FailingAthleteStateStore(super.tables);

  @override
  Future<void> upsertProjection(AthleteState projection) async {
    throw ProgrammeStoreException('Simulated athlete_state sync failure');
  }
}

class _NoOpProgressionService implements ProgrammeProgressionService {
  const _NoOpProgressionService();

  @override
  Future<ProgrammeProgressionResult> completeSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeProgressionResult> completeSessionPartial({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeProgressionResult> markSessionStarted({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeProgressionResult> replaceSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required String replacementProtocolId,
    int? trainingSessionId,
    String? resolutionNote,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeProgressionResult> resolveAfterOutcome({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    bool advanceCursor = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeProgressionResult> skipSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    String? resolutionNote,
  }) {
    throw UnimplementedError();
  }
}
