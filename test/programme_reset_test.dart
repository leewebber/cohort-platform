import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:cohort_platform/features/programme/debug/programme_dev_fixtures.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_actions.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_resolution_cache.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_development_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';
import 'support/programme_schedule_test_fixtures.dart';

void main() {
  const devAssignmentId = 'aaaaaaaa-bbbb-cccc-dddd-000000000100';

  group('ProgrammeDebugActions.resetTestProgrammeAssignment', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeVersionStore versionStore;
    late InMemoryProgrammeAssignmentStore assignmentStore;
    late InMemoryProgrammeSlotOutcomeStore outcomeStore;
    late InMemoryAthleteStateStore athleteStore;

    setUp(() async {
      tables = InMemoryProgrammeTables();
      versionStore = InMemoryProgrammeVersionStore(tables);
      assignmentStore = InMemoryProgrammeAssignmentStore(tables);
      outcomeStore = InMemoryProgrammeSlotOutcomeStore(tables);
      athleteStore = InMemoryAthleteStateStore(tables);

      final versionId = ProgrammeDevFixtures.foundationTestVersionId;
      final version = ProgrammeScheduleTestFixtures.version().copyWith(
        id: versionId,
      );
      await versionStore.saveTemplateTree(
        version: version,
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
          programmeVersionId: versionId,
        ),
      );
      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment().copyWith(
          id: devAssignmentId,
          programmeVersionId: ProgrammeDevFixtures.foundationTestVersionId,
          lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
        ),
      );
    });

    ProgrammeSlotOutcome completedDayOneOutcome({
      String dayKey = 'day_1',
      String slotId = ProgrammeScheduleTestFixtures.slot1Id,
    }) {
      return ProgrammeScheduleTestFixtures.outcome(
        slotId: slotId,
        status: ProgrammeSlotOutcomeStatus.completed,
        assignmentId: devAssignmentId,
        dayKey: dayKey,
      );
    }

    Future<ProgrammeAssignmentOperationResult> reset() {
      return ProgrammeDebugActions.resetTestProgrammeAssignment(
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
    }

    test('reset removes completed day_1 outcome', () async {
      tables.outcomes.add(completedDayOneOutcome());

      final result = await reset();

      expect(result.status, ProgrammeAssignmentOperationStatus.assigned);
      expect(tables.outcomes, isEmpty);
    });

    test('fresh resolve after reset returns day_1 executable', () async {
      tables.outcomes.add(completedDayOneOutcome());
      tables.assignments[0] = ProgrammeScheduleTestFixtures.assignment(
        dayKey: 'day_2',
      ).copyWith(
        id: devAssignmentId,
        programmeVersionId: ProgrammeDevFixtures.foundationTestVersionId,
        lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
      );

      await reset();

      final todayService = TodaySessionServiceImpl(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        slotOutcomeStore: outcomeStore,
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      );
      final resolved = await todayService.resolveForAthlete('lee');

      expect(resolved.kind, ResolvedTodaySessionKind.executable);
      expect(resolved.dayKey, 'day_1');
      expect(resolved.effectiveProtocolId, 'BW-001');
    });

    test('reset clears multiple outcomes', () async {
      tables.outcomes.addAll([
        completedDayOneOutcome(),
        ProgrammeScheduleTestFixtures.outcome(
          slotId: ProgrammeScheduleTestFixtures.slot2Id,
          status: ProgrammeSlotOutcomeStatus.skipped,
          assignmentId: devAssignmentId,
          dayKey: 'day_2',
        ),
      ]);

      await reset();

      expect(tables.outcomes, isEmpty);
    });

    test('zero deleted when outcomes existed returns failed result', () async {
      tables.outcomes.add(completedDayOneOutcome());
      outcomeStore.simulateRlsBlockedDelete = true;

      final result = await reset();

      expect(result.status, ProgrammeAssignmentOperationStatus.failed);
      expect(result.warnings.first, contains('DELETE removed 0 rows'));
      expect(tables.outcomes, isNotEmpty);
      expect(tables.assignments.first.currentDayKey, 'day_1');
    });

    test('RLS delete failure is surfaced', () async {
      tables.outcomes.add(completedDayOneOutcome());
      outcomeStore.denyDelete = true;

      final result = await reset();

      expect(result.status, ProgrammeAssignmentOperationStatus.failed);
      expect(result.warnings.first, contains('permission denied'));
      expect(tables.outcomes, isNotEmpty);
    });

    test('cache is replaced with the fresh post-reset resolution', () async {
      ProgrammeDebugResolutionCache.store(
        ResolvedTodaySession.fromResolution(
          const ProgrammeScheduleResolverImpl().resolve(
            assignment: ProgrammeScheduleTestFixtures.assignment(
              dayKey: 'day_2',
            ),
            tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
              programmeVersionId:
                  ProgrammeDevFixtures.foundationTestVersionId,
            ),
            outcomes: [
              completedDayOneOutcome(),
            ],
          ),
        ),
      );

      tables.outcomes.add(completedDayOneOutcome());

      await reset();

      final cached = ProgrammeDebugResolutionCache.lastResolution;
      expect(cached, isNotNull);
      expect(cached!.kind, ResolvedTodaySessionKind.executable);
      expect(cached.dayKey, 'day_1');
      expect(cached.effectiveProtocolId, 'BW-001');
    });
  });

  group('InMemoryProgrammeSlotOutcomeStore.deleteOutcomesForAssignment', () {
    test('returns deleted count and ids', () async {
      final tables = InMemoryProgrammeTables()
        ..outcomes.addAll([
          ProgrammeScheduleTestFixtures.outcome(
            slotId: ProgrammeScheduleTestFixtures.slot1Id,
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
          ProgrammeScheduleTestFixtures.outcome(
            slotId: ProgrammeScheduleTestFixtures.slot2Id,
            status: ProgrammeSlotOutcomeStatus.skipped,
            dayKey: 'day_2',
          ),
        ]);
      final store = InMemoryProgrammeSlotOutcomeStore(tables);

      final result = await store.deleteOutcomesForAssignment(
        assignmentId: 'assignment-1',
      );

      expect(result.deletedCount, 2);
      expect(result.deletedIds, hasLength(2));
      expect(tables.outcomes, isEmpty);
    });
  });
}
