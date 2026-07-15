import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/athlete_state.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';
import 'support/programme_schedule_test_fixtures.dart';

void main() {
  group('InMemoryAthleteStateStore', () {
    late InMemoryProgrammeTables tables;
    late InMemoryAthleteStateStore store;

    setUp(() {
      tables = InMemoryProgrammeTables();
      store = InMemoryAthleteStateStore(tables);
    });

    test('inserts projection when athlete row is missing', () async {
      await store.upsertProjection(
        const AthleteState(
          athleteId: 'lee',
          programmeId: 'COHORT-FOUNDATION-TEST',
          currentWeek: 1,
          currentDay: 'day_1',
          currentProtocolId: 'BW-001',
        ),
      );

      expect(tables.athleteStates, hasLength(1));
      expect(tables.athleteStates.first.currentProtocolId, 'BW-001');
    });

    test('updates existing athlete projection instead of inserting duplicate', () async {
      tables.athleteStates.add(
        const AthleteState(
          athleteId: 'lee',
          programmeId: 'OLD',
          currentProtocolId: 'BW-001',
        ),
      );

      await store.upsertProjection(
        const AthleteState(
          athleteId: 'lee',
          programmeId: 'COHORT-FOUNDATION-TEST',
          currentWeek: 1,
          currentDay: 'day_2',
          currentProtocolId: 'RN-006',
        ),
      );

      expect(tables.athleteStates, hasLength(1));
      expect(tables.athleteStates.first.currentDay, 'day_2');
      expect(tables.athleteStates.first.currentProtocolId, 'RN-006');
    });

    test('repeated sync is idempotent', () async {
      final syncService = AthleteStateSyncServiceImpl(athleteStateStore: store);
      final resolution = ResolvedTodaySession.fromResolution(
        const ProgrammeScheduleResolverImpl().resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );

      await syncService.syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );
      await syncService.syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );

      expect(tables.athleteStates, hasLength(1));
    });

    test('duplicate athlete rows produce a clear migration/data error', () async {
      tables.athleteStates.addAll([
        const AthleteState(athleteId: 'lee', currentProtocolId: 'BW-001'),
        const AthleteState(athleteId: 'lee', currentProtocolId: 'RN-006'),
      ]);

      expect(
        () => store.upsertProjection(
          const AthleteState(athleteId: 'lee', currentProtocolId: 'FG-009'),
        ),
        throwsA(
          isA<ProgrammeStoreException>()
              .having((error) => error.code, 'code', '23505')
              .having(
                (error) => error.operation,
                'operation',
                'upsertProjection',
              )
              .having(
                (error) => error.conflictTarget,
                'conflictTarget',
                'athlete_id',
              ),
        ),
      );
    });
  });

  group('reset flow', () {
    test('reset clears outcomes and syncs fresh day_1 projection', () async {
      final tables = InMemoryProgrammeTables();
      final versionStore = InMemoryProgrammeVersionStore(tables);
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );

      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment(dayKey: 'day_2'),
      );
      tables.outcomes.add(
        ProgrammeScheduleTestFixtures.outcome(
          slotId: 'slot-1',
          status: ProgrammeSlotOutcomeStatus.completed,
          dayKey: 'day_1',
        ),
      );
      tables.athleteStates.add(
        const AthleteState(
          athleteId: 'lee',
          programmeId: 'COHORT-FOUNDATION-TEST',
          currentWeek: 1,
          currentDay: 'day_2',
          currentProtocolId: 'RN-006',
        ),
      );

      final assignmentStore = InMemoryProgrammeAssignmentStore(tables);
      final outcomeStore = InMemoryProgrammeSlotOutcomeStore(tables);
      final athleteStore = InMemoryAthleteStateStore(tables);

      final assignment = tables.assignments.first;
      await outcomeStore.deleteOutcomesForAssignment(
        assignmentId: assignment.id,
      );
      await assignmentStore.update(
        assignment.copyWith(
          currentWeek: 1,
          currentDayKey: 'day_1',
          currentSessionOrder: 1,
          status: ProgrammeAssignmentStatus.active,
          clearCompletedAt: true,
          clearLastProgressedTrainingSessionId: true,
        ),
      );

      final todayService = TodaySessionServiceImpl(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        slotOutcomeStore: outcomeStore,
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      );
      final resolution = await todayService.resolveForAthlete('lee');

      await AthleteStateSyncServiceImpl(athleteStateStore: athleteStore)
          .syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );

      expect(tables.outcomes, isEmpty);
      expect(tables.assignments.first.currentDayKey, 'day_1');
      expect(tables.athleteStates, hasLength(1));
      expect(tables.athleteStates.first.currentDay, 'day_1');
      expect(tables.athleteStates.first.currentProtocolId, 'BW-001');
    });
  });

  group('ProgrammeStoreException diagnostics', () {
    test('includes operation and conflict target for 42P10', () {
      final error = ProgrammeStoreException.fromDynamic(
        Exception(
          'PostgrestException(message: there is no unique or exclusion constraint matching the ON CONFLICT specification, code: 42P10)',
        ),
        fallbackMessage: 'Failed to upsert athlete state projection',
        operation: 'upsertProjection',
        tableName: 'athlete_state',
        conflictTarget: 'athlete_id',
      );

      expect(error.isMissingConflictTarget, isTrue);
      expect(error.operation, 'upsertProjection');
      expect(error.tableName, 'athlete_state');
      expect(error.conflictTarget, 'athlete_id');
      expect(error.toString(), contains('onConflict: athlete_id'));
    });
  });
}
