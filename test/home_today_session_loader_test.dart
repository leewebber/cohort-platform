import 'package:cohort_platform/data/repositories/athlete_state_repository.dart';
import 'package:cohort_platform/data/repositories/programme_repository.dart';
import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/data/repositories/training_session_repository.dart';
import 'package:cohort_platform/features/home/models/home_today_session_state.dart';
import 'package:cohort_platform/features/home/services/home_today_session_loader.dart';
import 'package:cohort_platform/features/programme/debug/programme_dev_fixtures.dart';
import 'package:cohort_platform/features/programme/errors/programme_schedule_exception.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/athlete_state.dart';
import 'package:cohort_platform/models/programme.dart';
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
  _StubProgrammeRepository(this.programmes);

  final Map<String, Programme> programmes;

  @override
  Future<Programme?> getProgrammeById(String programmeId) async =>
      programmes[programmeId];
}

class _StubTrainingSessionRepository extends TrainingSessionRepository {
  @override
  Future<TrainingSession?> getLatestSessionForAthleteAndProtocol({
    required String athleteId,
    required String protocolId,
  }) async =>
      null;
}

class _ThrowingTodaySessionService extends TodaySessionServiceImpl {
  _ThrowingTodaySessionService()
      : super(
          assignmentStore: InMemoryProgrammeAssignmentStore(
            InMemoryProgrammeTables(),
          ),
          versionStore: InMemoryProgrammeVersionStore(
            InMemoryProgrammeTables(),
          ),
          slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(
            InMemoryProgrammeTables(),
          ),
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        );

  @override
  Future<ResolvedTodaySession> resolveForAthlete(String athleteId) {
    throw ProgrammeScheduleException(
      ProgrammeScheduleErrorCode.emptyProgrammeStructure,
      'Pinned programme version could not be loaded',
    );
  }
}

void main() {
  const athleteId = 'lee';
  const devAssignmentId = 'aaaaaaaa-bbbb-cccc-dddd-000000000100';

  final protocols = {
    'BW-001': Protocol(protocolId: 'BW-001', name: 'Base Work'),
    'RN-006': Protocol(protocolId: 'RN-006', name: 'Run Intervals'),
  };

  HomeTodaySessionLoader buildLoader({
    required InMemoryProgrammeTables tables,
    AthleteState? manualState,
    TodaySessionServiceImpl? todaySessionService,
  }) {
    final versionStore = InMemoryProgrammeVersionStore(tables);
    final slotOutcomeStore = InMemoryProgrammeSlotOutcomeStore(tables);
    return HomeTodaySessionLoader(
      todaySessionService: todaySessionService ??
          TodaySessionServiceImpl(
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            versionStore: versionStore,
            slotOutcomeStore: slotOutcomeStore,
            scheduleResolver: const ProgrammeScheduleResolverImpl(),
          ),
      athleteStateSyncService: AthleteStateSyncServiceImpl(
        athleteStateStore: InMemoryAthleteStateStore(tables),
      ),
      athleteStateRepository: _StubAthleteStateRepository(manualState),
      protocolRepository: _StubProtocolRepository(protocols),
      programmeRepository: _StubProgrammeRepository(const {}),
      trainingSessionRepository: _StubTrainingSessionRepository(),
      programmeVersionStore: versionStore,
      programmeSlotOutcomeStore: slotOutcomeStore,
    );
  }

  Future<void> seedFoundationAssignment(InMemoryProgrammeTables tables) async {
    final versionId = ProgrammeDevFixtures.foundationTestVersionId;
    await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
      version: ProgrammeScheduleTestFixtures.version().copyWith(id: versionId),
      tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
        versionId: versionId,
      ),
    );
    tables.assignments.add(
      ProgrammeScheduleTestFixtures.assignment().copyWith(
        id: devAssignmentId,
        programmeVersionId: versionId,
        lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
      ),
    );
  }

  group('HomeTodaySessionLoader', () {
    test('active programme executable overrides manual protocol', () async {
      final tables = InMemoryProgrammeTables();
      await seedFoundationAssignment(tables);

      final loader = buildLoader(
        tables: tables,
        manualState: const AthleteState(
          athleteId: athleteId,
          currentProtocolId: 'RN-006',
          programmeId: 'LEGACY',
        ),
      );

      final state = await loader.load(athleteId);

      expect(state, isA<HomeTodaySessionProgrammeExecutable>());
      final executable = state as HomeTodaySessionProgrammeExecutable;
      expect(executable.protocol.protocolId, 'BW-001');
      expect(executable.executionContext.effectiveProtocolId, 'BW-001');
      expect(executable.resolution.dayKey, 'day_1');
    });

    test('rest day state', () async {
      final tables = InMemoryProgrammeTables();
      await seedFoundationAssignment(tables);
      tables.assignments[0] = ProgrammeScheduleTestFixtures.assignment(
        dayKey: 'day_3',
      ).copyWith(
        id: devAssignmentId,
        programmeVersionId: ProgrammeDevFixtures.foundationTestVersionId,
        lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
      );

      final state = await buildLoader(tables: tables).load(athleteId);

      expect(state, isA<HomeTodaySessionRestDay>());
      final restDay = state as HomeTodaySessionRestDay;
      expect(restDay.resolution.dayKey, 'day_3');
      expect(restDay.resolution.suggestedNextCursor, isNotNull);
    });

    test('programme complete state', () async {
      final tables = InMemoryProgrammeTables();
      final versionId = ProgrammeDevFixtures.foundationTestVersionId;
      await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version().copyWith(id: versionId),
        tree: ProgrammeScheduleTestFixtures.singleWeekTree(
          versionId: versionId,
          days: [
            ProgrammeScheduleTestFixtures.trainingDay(
              id: 'day-1',
              weekId: 'week-1',
              dayKey: 'day_1',
              dayOrder: 1,
              slots: [
                ProgrammeScheduleTestFixtures.requiredSlot(
                  id: 'slot-1',
                  dayId: 'day-1',
                  sessionOrder: 1,
                  protocolId: 'BW-001',
                ),
              ],
            ),
          ],
        ),
      );
      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment().copyWith(
          id: devAssignmentId,
          programmeVersionId: versionId,
          lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
        ),
      );
      tables.outcomes.add(
        ProgrammeScheduleTestFixtures.outcome(
          slotId: 'slot-1',
          status: ProgrammeSlotOutcomeStatus.completed,
          assignmentId: devAssignmentId,
        ),
      );

      final state = await buildLoader(tables: tables).load(athleteId);

      expect(state, isA<HomeTodaySessionProgrammeComplete>());
    });

    test('no active programme falls back to manual', () async {
      final tables = InMemoryProgrammeTables();
      final loader = buildLoader(
        tables: tables,
        manualState: const AthleteState(
          athleteId: athleteId,
          currentProtocolId: 'RN-006',
        ),
      );

      final state = await loader.load(athleteId);

      expect(state, isA<HomeTodaySessionManual>());
      expect((state as HomeTodaySessionManual).protocol.protocolId, 'RN-006');
    });

    test('dayComplete state', () async {
      final tables = InMemoryProgrammeTables();
      await seedFoundationAssignment(tables);
      tables.outcomes.add(
        ProgrammeScheduleTestFixtures.outcome(
          slotId: 'slot-1',
          status: ProgrammeSlotOutcomeStatus.completed,
          assignmentId: devAssignmentId,
        ),
      );

      final state = await buildLoader(tables: tables).load(athleteId);

      expect(state, isA<HomeTodaySessionDayComplete>());
      expect(
        (state as HomeTodaySessionDayComplete).resolution.suggestedNextCursor
            ?.dayKey,
        'day_2',
      );
    });

    test('programme-backed executable includes execution context', () async {
      final tables = InMemoryProgrammeTables();
      await seedFoundationAssignment(tables);

      final state = await buildLoader(tables: tables).load(athleteId);

      final executable = state as HomeTodaySessionProgrammeExecutable;
      expect(executable.executionContext.assignmentId, devAssignmentId);
      expect(executable.executionContext.sessionSlotId, 'slot-1');
      expect(executable.executionContext.isProgrammeBacked, isTrue);
    });

    test(
      'differing slot display_title still launches BW-001 with protocol name primary',
      () async {
        final tables = InMemoryProgrammeTables();
        final versionId = ProgrammeDevFixtures.foundationTestVersionId;
        await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
          version:
              ProgrammeScheduleTestFixtures.version().copyWith(id: versionId),
          tree: ProgrammeScheduleTestFixtures.singleWeekTree(
            versionId: versionId,
            days: [
              ProgrammeScheduleTestFixtures.trainingDay(
                id: 'day-1',
                weekId: 'week-1',
                dayKey: 'day_1',
                dayOrder: 1,
                slots: [
                  ProgrammeScheduleTestFixtures.requiredSlot(
                    id: 'slot-1',
                    dayId: 'day-1',
                    sessionOrder: 1,
                    protocolId: 'BW-001',
                    displayTitle: 'Monday Conditioning',
                  ),
                ],
              ),
            ],
          ),
        );
        tables.assignments.add(
          ProgrammeScheduleTestFixtures.assignment().copyWith(
            id: devAssignmentId,
            programmeVersionId: versionId,
            lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
          ),
        );

        final protocolsWithCanonicalName = {
          'BW-001': const Protocol(
            protocolId: 'BW-001',
            name: 'Bodyweight Grinder',
          ),
          'RN-006': Protocol(protocolId: 'RN-006', name: 'Run Intervals'),
        };

        final loader = HomeTodaySessionLoader(
          todaySessionService: TodaySessionServiceImpl(
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            versionStore: InMemoryProgrammeVersionStore(tables),
            slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
            scheduleResolver: const ProgrammeScheduleResolverImpl(),
          ),
          athleteStateSyncService: AthleteStateSyncServiceImpl(
            athleteStateStore: InMemoryAthleteStateStore(tables),
          ),
          athleteStateRepository: _StubAthleteStateRepository(null),
          protocolRepository:
              _StubProtocolRepository(protocolsWithCanonicalName),
          programmeRepository: _StubProgrammeRepository(const {}),
          trainingSessionRepository: _StubTrainingSessionRepository(),
        );

        final state = await loader.load(athleteId);

        expect(state, isA<HomeTodaySessionProgrammeExecutable>());
        final executable = state as HomeTodaySessionProgrammeExecutable;
        expect(executable.protocol.protocolId, 'BW-001');
        expect(executable.protocol.name, 'Bodyweight Grinder');
        expect(executable.executionContext.effectiveProtocolId, 'BW-001');
        expect(executable.resolution.slotTitle, 'Monday Conditioning');
        expect(
          HomeTodaySessionLabels.canonicalSessionTitle(executable.protocol),
          'Bodyweight Grinder',
        );
        expect(
          HomeTodaySessionLabels.executableSubtitle(
            executable.resolution,
            executable.protocol,
          ),
          "Today's session • Monday Conditioning",
        );
      },
    );

    test('refresh after progression shows next day executable', () async {
      final tables = InMemoryProgrammeTables();
      await seedFoundationAssignment(tables);
      tables.outcomes.add(
        ProgrammeScheduleTestFixtures.outcome(
          slotId: 'slot-1',
          status: ProgrammeSlotOutcomeStatus.completed,
          assignmentId: devAssignmentId,
        ),
      );
      tables.assignments[0] = tables.assignments.first.copyWith(
        currentDayKey: 'day_2',
        currentSessionOrder: 1,
      );

      final state = await buildLoader(tables: tables).load(athleteId);

      expect(state, isA<HomeTodaySessionProgrammeExecutable>());
      expect(
        (state as HomeTodaySessionProgrammeExecutable).resolution.dayKey,
        'day_2',
      );
      expect(state.protocol.protocolId, 'RN-006');
    });

    test('resolver error shows error not stale manual session', () async {
      final tables = InMemoryProgrammeTables();
      final loader = HomeTodaySessionLoader(
        todaySessionService: _ThrowingTodaySessionService(),
        athleteStateSyncService: AthleteStateSyncServiceImpl(
          athleteStateStore: InMemoryAthleteStateStore(tables),
        ),
        athleteStateRepository: _StubAthleteStateRepository(
          const AthleteState(
            athleteId: athleteId,
            currentProtocolId: 'RN-006',
          ),
        ),
        protocolRepository: _StubProtocolRepository(protocols),
        programmeRepository: _StubProgrammeRepository(const {}),
        trainingSessionRepository: _StubTrainingSessionRepository(),
      );

      final state = await loader.load(athleteId);

      expect(state, isA<HomeTodaySessionError>());
      expect(state, isNot(isA<HomeTodaySessionManual>()));
    });
  });
}
