import 'package:cohort_platform/data/repositories/athlete_state_repository.dart';
import 'package:cohort_platform/data/repositories/programme_repository.dart';
import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/data/repositories/training_session_repository.dart';
import 'package:cohort_platform/features/home/models/home_today_session_state.dart';
import 'package:cohort_platform/features/home/services/home_today_session_loader.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/athlete_state.dart';
import 'package:cohort_platform/models/programme.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/training_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';
import 'support/programme_schedule_test_fixtures.dart';

class _StubProtocolRepository extends ProtocolRepository {
  @override
  Future<Protocol?> getProtocolById(String protocolId) async {
    if (protocolId == 'BW-001') {
      return Protocol(protocolId: 'BW-001', name: 'Base Work');
    }
    if (protocolId == 'RN-006') {
      return Protocol(protocolId: 'RN-006', name: 'Run Intervals');
    }
    return null;
  }
}

class _StubAthleteStateRepository extends AthleteStateRepository {
  @override
  Future<AthleteState?> getAthleteState(String athleteId) async => null;
}

class _StubProgrammeRepository extends ProgrammeRepository {
  @override
  Future<Programme?> getProgrammeById(String programmeId) async => null;
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
  group('ProgrammeAssignment insert payload', () {
    test('forCreate toInsertMap omits id', () {
      final draft = ProgrammeAssignment.forCreate(
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
        currentWeek: 1,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      );

      expect(draft.id, isEmpty);
      expect(draft.toInsertMap().containsKey('id'), isFalse);
      expect(draft.toUpdateMap().containsKey('id'), isFalse);
    });

    test('legacy fake id is not emitted by forCreate', () {
      final draft = ProgrammeAssignment.forCreate(
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        startedAt: DateTime.utc(2026, 7, 15),
      );

      expect(draft.toInsertMap()['id'], isNull);
    });
  });

  group('InMemoryProgrammeAssignmentStore.insert', () {
    test('assigns deterministic fake id when draft id is empty', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeAssignmentStore(tables);

      final inserted = await store.insert(
        ProgrammeAssignment.forCreate(
          athleteId: 'lee',
          programmeVersionId: 'version-1',
          lineageCode: 'COHORT-FOUNDATION-TEST',
          startedAt: DateTime.utc(2026, 7, 15),
        ),
      );

      expect(inserted.id, 'assignment-test-1');
      expect(inserted.id, isNot(startsWith('assignment-new-')));
    });

    test('preserves explicit id for pre-seeded fixtures', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeAssignmentStore(tables);

      final inserted = await store.insert(
        ProgrammeScheduleTestFixtures.assignment(),
      );

      expect(inserted.id, 'assignment-1');
    });
  });

  group('ProgrammeAssignmentServiceImpl insert integration', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeVersionStore versionStore;
    late InMemoryProgrammeAssignmentStore assignmentStore;
    late ProgrammeAssignmentServiceImpl service;

    Future<void> seedPublishedProgramme() async {
      tables.lineages.add(
        const ProgrammeLineage(
          id: 'lineage-1',
          code: 'COHORT-FOUNDATION-TEST',
        ),
      );
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version().copyWith(
          lifecycleStatus: ProgrammeLifecycleStatus.published,
        ),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
    }

    setUp(() {
      tables = InMemoryProgrammeTables();
      versionStore = InMemoryProgrammeVersionStore(tables);
      assignmentStore = InMemoryProgrammeAssignmentStore(tables);
      service = ProgrammeAssignmentServiceImpl(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
        todaySessionService: TodaySessionServiceImpl(
          assignmentStore: assignmentStore,
          versionStore: versionStore,
          slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        ),
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: InMemoryAthleteStateStore(tables),
        ),
      );
    });

    test('service uses store-returned assignment id', () async {
      await seedPublishedProgramme();

      final result = await service.assignProgramme(
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(result.assignment?.id, 'assignment-test-1');
      expect(result.assignment?.id, isNot(startsWith('assignment-new-')));
    });

    test('replacement uses returned new assignment id', () async {
      await seedPublishedProgramme();
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final newVersionId = 'version-2';
      tables.weeks.clear();
      tables.days.clear();
      tables.slots.clear();
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version().copyWith(
          id: newVersionId,
          versionNumber: 2,
          lifecycleStatus: ProgrammeLifecycleStatus.published,
        ),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
          programmeVersionId: newVersionId,
        ),
      );

      final result = await service.cancelOrReplaceActiveAssignment(
        athleteId: 'lee',
        newProgrammeVersionId: newVersionId,
        startedAt: DateTime.utc(2026, 7, 16),
        timezone: 'UTC',
      );

      expect(result.status, ProgrammeAssignmentOperationStatus.replaced);
      expect(result.assignment?.id, 'assignment-test-1');
      expect(
        tables.assignments.first.supersededByAssignmentId,
        'assignment-test-1',
      );
    });

    test('assignment creation then resolve returns executable session', () async {
      await seedPublishedProgramme();

      final result = await service.assignProgramme(
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      expect(
        result.resolvedTodaySession?.kind,
        ResolvedTodaySessionKind.executable,
      );
      expect(result.resolvedTodaySession?.effectiveProtocolId, 'BW-001');
    });

    test('Home loader sees programme executable after successful assignment',
        () async {
      await seedPublishedProgramme();

      await service.assignProgramme(
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 15),
        timezone: 'UTC',
      );

      final loader = HomeTodaySessionLoader(
        todaySessionService: TodaySessionServiceImpl(
          assignmentStore: assignmentStore,
          versionStore: versionStore,
          slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        ),
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: InMemoryAthleteStateStore(tables),
        ),
        athleteStateRepository: _StubAthleteStateRepository(),
        protocolRepository: _StubProtocolRepository(),
        programmeRepository: _StubProgrammeRepository(),
        trainingSessionRepository: _StubTrainingSessionRepository(),
      );

      final state = await loader.load('lee');

      expect(state, isA<HomeTodaySessionProgrammeExecutable>());
      final executable = state as HomeTodaySessionProgrammeExecutable;
      expect(executable.resolution.effectiveProtocolId, 'BW-001');
      expect(executable.executionContext.assignmentId, 'assignment-test-1');
    });
  });
}
