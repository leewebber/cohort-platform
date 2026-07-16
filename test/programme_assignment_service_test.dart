import 'package:cohort_platform/data/repositories/athlete_state_repository.dart';
import 'package:cohort_platform/data/repositories/programme_repository.dart';
import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/data/repositories/training_session_repository.dart';
import 'package:cohort_platform/features/home/models/home_today_session_state.dart';
import 'package:cohort_platform/features/home/services/home_today_session_loader.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_actions.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_development_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/athlete_state.dart';
import 'package:cohort_platform/models/programme.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/training_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';
import 'support/programme_schedule_test_fixtures.dart';

class _StubAthleteStateRepository extends AthleteStateRepository {
  _StubAthleteStateRepository(this.state);

  final AthleteState? state;

  @override
  Future<AthleteState?> getAthleteState(String athleteId) async => state;
}

class _StubProtocolRepository extends ProtocolRepository {
  _StubProtocolRepository(this.protocols);

  final Map<String, Protocol> protocols;

  @override
  Future<Protocol?> getProtocolById(String protocolId) async =>
      protocols[protocolId];
}

class _StubProgrammeRepository extends ProgrammeRepository {
  @override
  Future<Programme?> getProgrammeById(String programmeId) async => null;
}

class _ThrowingAthleteStateSyncService implements AthleteStateSyncService {
  @override
  Future<void> syncFromResolvedSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
  }) async {
    throw Exception('projection sync failed');
  }

  @override
  Future<void> clearProgrammeProjection(String athleteId) async {}
}

class _StubTrainingSessionRepository extends TrainingSessionRepository {
  @override
  Future<TrainingSession?> getLatestSessionForAthleteAndProtocol({
    required String athleteId,
    required String protocolId,
  }) async =>
      null;
}

void main() {
  const athleteId = 'lee';

  late InMemoryProgrammeTables tables;
  late InMemoryProgrammeVersionStore versionStore;
  late InMemoryProgrammeAssignmentStore assignmentStore;
  late InMemoryProgrammeSlotOutcomeStore outcomeStore;
  late InMemoryAthleteStateStore athleteStore;
  late ProgrammeAssignmentServiceImpl service;
  late ProgrammeAssignmentDevelopmentServiceImpl developmentService;

  ProgrammeVersion publishedVersion({String id = 'version-1'}) {
    return ProgrammeScheduleTestFixtures.version().copyWith(
      id: id,
      lifecycleStatus: ProgrammeLifecycleStatus.published,
    );
  }

  Future<void> seedFlatPublishedProgramme({
    String versionId = 'version-1',
    ProgrammeTemplateTree? tree,
  }) async {
    tables.lineages.add(
      const ProgrammeLineage(
        id: 'lineage-1',
        code: 'COHORT-FOUNDATION-TEST',
      ),
    );

    await versionStore.saveTemplateTree(
      version: publishedVersion(id: versionId),
      tree: tree ?? ProgrammeScheduleTestFixtures.foundationWeekOneTree(
        versionId: versionId,
      ),
    );
  }

  ProgrammeAssignmentServiceImpl buildService() {
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

  ProgrammeAssignmentDevelopmentServiceImpl buildDevelopmentService() {
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

  setUp(() {
    tables = InMemoryProgrammeTables();
    versionStore = InMemoryProgrammeVersionStore(tables);
    assignmentStore = InMemoryProgrammeAssignmentStore(tables);
    outcomeStore = InMemoryProgrammeSlotOutcomeStore(tables);
    athleteStore = InMemoryAthleteStateStore(tables);
    service = buildService();
    developmentService = buildDevelopmentService();
  });

  group('ProgrammeAssignmentServiceImpl', () {
    test('getCurrentAssignment returns active assignment', () async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final current = await service.getCurrentAssignment(athleteId: athleteId);

      expect(current, isNotNull);
      expect(current!.id, 'assignment-1');
    });

    test('assign athlete to published flat programme', () async {
      await seedFlatPublishedProgramme();

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(result.assignment?.programmeVersionId, 'version-1');
      expect(result.resolvedTodaySession?.kind, ResolvedTodaySessionKind.executable);
      expect(result.resolvedTodaySession?.effectiveProtocolId, 'BW-001');
      expect(result.athleteStateSynced, isTrue);
      expect(tables.assignments, hasLength(1));
    });

    test('assign programme beginning with rest day', () async {
      await seedFlatPublishedProgramme(
        tree: ProgrammeScheduleTestFixtures.singleWeekTree(
          days: [
            ProgrammeScheduleTestFixtures.restDay(
              id: 'day-1',
              weekId: 'week-1',
              dayKey: 'day_1',
              dayOrder: 1,
            ),
            ProgrammeScheduleTestFixtures.trainingDay(
              id: 'day-2',
              weekId: 'week-1',
              dayKey: 'day_2',
              dayOrder: 2,
              slots: [
                ProgrammeScheduleTestFixtures.requiredSlot(
                  id: 'slot-2',
                  dayId: 'day-2',
                  sessionOrder: 1,
                  protocolId: 'RN-006',
                ),
              ],
            ),
          ],
        ),
      );

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(result.assignment?.currentDayKey, 'day_1');
      expect(result.resolvedTodaySession?.kind, ResolvedTodaySessionKind.restDay);
    });

    test('initial cursor finds first valid required slot', () async {
      await seedFlatPublishedProgramme(
        tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
      );

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.assignment?.currentSessionOrder, 1);
      expect(result.resolvedTodaySession?.slotId, 'slot-1');
    });

    test('initial cursor does not assume week 1 day_1 slot 1', () async {
      final weekTwo = ProgrammeVersionWeek(
        id: 'week-2',
        versionId: 'version-1',
        weekNumber: 2,
        title: 'Week 2',
      );
      final day = ProgrammeScheduleTestFixtures.trainingDay(
        id: 'day-10',
        weekId: 'week-2',
        dayKey: 'day_1',
        dayOrder: 1,
        slots: [
          ProgrammeScheduleTestFixtures.requiredSlot(
            id: 'slot-10',
            dayId: 'day-10',
            sessionOrder: 2,
            protocolId: 'FG-009',
          ),
        ],
      );

      await seedFlatPublishedProgramme(
        tree: ProgrammeTemplateTree(
          template: ProgrammeTemplate(
            version: publishedVersion(),
            weeks: [weekTwo],
          ),
          weekNodes: [ProgrammeTemplateWeekNode(week: weekTwo, days: [day])],
        ),
      );

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.assignment?.currentWeek, 2);
      expect(result.assignment?.currentSessionOrder, 2);
    });

    test('existing active assignment returns conflict', () async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.alreadyActiveConflict);
      expect(tables.assignments, hasLength(1));
    });

    test('explicit replacement marks old reassigned and creates new active', () async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final newVersionId = 'version-2';
      tables.weeks.clear();
      tables.days.clear();
      tables.slots.clear();
      await versionStore.saveTemplateTree(
        version: publishedVersion(id: newVersionId).copyWith(versionNumber: 2),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
          versionId: newVersionId,
        ),
      );

      final result = await service.cancelOrReplaceActiveAssignment(
        athleteId: athleteId,
        newProgrammeVersionId: newVersionId,
        startedAt: DateTime.utc(2026, 7, 16),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.replaced);
      expect(result.replacedAssignmentId, 'assignment-1');
      expect(result.assignment?.programmeVersionId, newVersionId);
      expect(tables.assignments.first.status, ProgrammeAssignmentStatus.reassigned);
      expect(tables.assignments.first.supersededByAssignmentId, result.assignment?.id);
      expect(tables.assignments.last.isActive, isTrue);
      expect(tables.outcomes, isEmpty);
    });

    test('new assignment pins programme version', () async {
      await seedFlatPublishedProgramme();

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.assignment?.programmeVersionId, 'version-1');
      expect(result.assignment?.lineageCode, 'COHORT-FOUNDATION-TEST');
    });

    test('archived version rejected', () async {
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version().copyWith(
          lifecycleStatus: ProgrammeLifecycleStatus.archived,
        ),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      tables.lineages.add(
        const ProgrammeLineage(id: 'lineage-1', code: 'COHORT-FOUNDATION-TEST'),
      );

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.invalidProgrammeVersion);
    });

    test('unpublished version rejected normally', () async {
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      tables.lineages.add(
        const ProgrammeLineage(id: 'lineage-1', code: 'COHORT-FOUNDATION-TEST'),
      );

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.invalidProgrammeVersion);
    });

    test('unpublished version allowed only with development override', () async {
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      tables.lineages.add(
        const ProgrammeLineage(id: 'lineage-1', code: 'COHORT-FOUNDATION-TEST'),
      );

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
        allowUnpublishedVersion: true,
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.assigned);
    });

    test('pause preserves cursor and outcomes', () async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment(
        dayKey: 'day_2',
      ));
      tables.outcomes.add(
        ProgrammeScheduleTestFixtures.outcome(
          slotId: 'slot-1',
          status: ProgrammeSlotOutcomeStatus.completed,
        ),
      );

      final result = await service.pauseAssignment(assignmentId: 'assignment-1');

      expect(result.status, ProgrammeAssignmentOperationStatus.paused);
      expect(result.assignment?.currentDayKey, 'day_2');
      expect(tables.outcomes, hasLength(1));
      expect(
        tables.athleteStates.single.currentProtocolId,
        isNull,
      );
    });

    test('resume re-resolves same cursor', () async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment().copyWith(
          status: ProgrammeAssignmentStatus.paused,
          pausedAt: DateTime.utc(2026, 7, 15),
        ),
      );

      final result = await service.resumeAssignment(assignmentId: 'assignment-1');

      expect(result.status, ProgrammeAssignmentOperationStatus.resumed);
      expect(result.assignment?.currentDayKey, 'day_1');
      expect(result.resolvedTodaySession?.effectiveProtocolId, 'BW-001');
    });

    test('complete clears stale protocol projection', () async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());
      tables.athleteStates.add(
        const AthleteState(
          athleteId: athleteId,
          programmeId: 'COHORT-FOUNDATION-TEST',
          currentProtocolId: 'BW-001',
        ),
      );

      final result = await service.completeAssignment(assignmentId: 'assignment-1');

      expect(result.status, ProgrammeAssignmentOperationStatus.completed);
      expect(tables.athleteStates.single.currentProtocolId, isNull);
      expect(tables.athleteStates.single.programmeId, isNull);
    });

    test('projection sync failure returns partialSuccess', () async {
      await seedFlatPublishedProgramme();
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
        athleteStateSyncService: _ThrowingAthleteStateSyncService(),
      );

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.partialSuccess);
      expect(result.assignment, isNotNull);
      expect(result.athleteStateSynced, isFalse);
      expect(result.warnings, isNotEmpty);
    });

    test('idempotent retry does not create duplicate active assignment', () async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final first = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );
      final second = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(first.status, ProgrammeAssignmentOperationStatus.alreadyActiveConflict);
      expect(second.status, ProgrammeAssignmentOperationStatus.alreadyActiveConflict);
      expect(tables.assignments.where((row) => row.isActive), hasLength(1));
    });

    test('store failure is surfaced clearly', () async {
      await seedFlatPublishedProgramme();
      tables.denyWrites = true;
      service = buildService();

      final result = await service.assignProgramme(
        athleteId: athleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.failed);
      expect(result.warnings.first, contains('permission denied'));
    });
  });

  group('ProgrammeAssignmentDevelopmentServiceImpl', () {
    Future<void> seedActiveAssignment() async {
      await seedFlatPublishedProgramme();
      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment().copyWith(
          id: 'assignment-dev',
        ),
      );
    }

    test('development reset clears outcomes only when requested', () async {
      await seedActiveAssignment();
      tables.outcomes.add(
        ProgrammeScheduleTestFixtures.outcome(
          slotId: 'slot-1',
          status: ProgrammeSlotOutcomeStatus.completed,
          assignmentId: 'assignment-dev',
        ),
      );

      final withoutClear = await developmentService.resetAssignment(
        assignmentId: 'assignment-dev',
        weekNumber: 1,
        dayKey: 'day_1',
        slotOrder: 1,
      );
      expect(withoutClear.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(tables.outcomes, hasLength(1));

      final withClear = await developmentService.resetAssignment(
        assignmentId: 'assignment-dev',
        weekNumber: 1,
        dayKey: 'day_1',
        slotOrder: 1,
        clearOutcomes: true,
      );
      expect(withClear.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(tables.outcomes, isEmpty);
    });

    test('development reset validates cursor', () async {
      await seedActiveAssignment();

      final result = await developmentService.resetAssignment(
        assignmentId: 'assignment-dev',
        weekNumber: 99,
        dayKey: 'day_1',
        slotOrder: 1,
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.failed);
      expect(result.warnings.first, contains('Invalid reset cursor'));
    });

    test('development reset re-resolves and syncs projection', () async {
      await seedActiveAssignment();
      tables.assignments[0] = tables.assignments.first.copyWith(currentDayKey: 'day_2');

      final result = await developmentService.resetAssignment(
        assignmentId: 'assignment-dev',
        weekNumber: 1,
        dayKey: 'day_1',
        slotOrder: 1,
      );

      expect(result.resolvedTodaySession?.dayKey, 'day_1');
      expect(result.resolvedTodaySession?.effectiveProtocolId, 'BW-001');
      expect(result.athleteStateSynced, isTrue);
      expect(tables.athleteStates.single.currentProtocolId, 'BW-001');
    });
  });

  group('debug and Home integration boundaries', () {
    test('debug resolve never creates assignment', () async {
      await seedFlatPublishedProgramme();

      final resolved = await ProgrammeDebugActions.resolveCurrentTestSession(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        slotOutcomeStore: outcomeStore,
      );

      expect(resolved.kind, ResolvedTodaySessionKind.noActiveProgramme);
      expect(tables.assignments, isEmpty);
    });

    test('Home without assignment still uses manual fallback', () async {
      final homeTables = InMemoryProgrammeTables();
      await InMemoryProgrammeVersionStore(homeTables).saveTemplateTree(
        version: publishedVersion(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      homeTables.lineages.add(
        const ProgrammeLineage(id: 'lineage-1', code: 'COHORT-FOUNDATION-TEST'),
      );

      final loader = HomeTodaySessionLoader(
        todaySessionService: TodaySessionServiceImpl(
          assignmentStore: InMemoryProgrammeAssignmentStore(homeTables),
          versionStore: InMemoryProgrammeVersionStore(homeTables),
          slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(homeTables),
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        ),
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: InMemoryAthleteStateStore(homeTables),
        ),
        athleteStateRepository: _StubAthleteStateRepository(
          const AthleteState(
            athleteId: athleteId,
            currentProtocolId: 'BD-001',
          ),
        ),
        protocolRepository: _StubProtocolRepository({
          'BD-001': Protocol(protocolId: 'BD-001', name: 'Base Day'),
        }),
        programmeRepository: _StubProgrammeRepository(),
        trainingSessionRepository: _StubTrainingSessionRepository(),
      );

      final state = await loader.load(athleteId);

      expect(state, isA<HomeTodaySessionManual>());
      final manual = state as HomeTodaySessionManual;
      expect(manual.protocol.protocolId, 'BD-001');
    });
  });
}
