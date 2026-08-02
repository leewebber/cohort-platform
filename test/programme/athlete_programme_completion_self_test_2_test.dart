import 'dart:async';

import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_completion.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_store.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/m8_modern_capture_test_fixtures.dart';
import '../support/programme_schedule_test_fixtures.dart';

class _AtomicFakeCompletionStore implements AthleteProgrammeCompletionStore {
  _AtomicFakeCompletionStore(this.tables);

  final InMemoryProgrammeTables tables;
  final Set<String> _logicalKeys = {};
  int committedMutations = 0;
  int calls = 0;

  Map<String, dynamic> _assignmentMap(ProgrammeAssignment value) => {
    ...value.toUpdateMap(),
    'id': value.id,
    'materialised_at': value.materialisedAt?.toIso8601String(),
    'materialisation_source': value.materialisationSource,
    'materialised_package_content_hash': value.materialisedPackageContentHash,
  };

  @override
  Future<Map<String, dynamic>> completeAndAdvance(
    Map<String, dynamic> payload,
  ) async {
    calls++;
    final key = payload['logical_completion_key'] as String;
    await Future<void>.delayed(Duration.zero);
    if (_logicalKeys.contains(key)) {
      return {
        'status': 'already_committed',
        'assignment': _assignmentMap(tables.assignments.single),
      };
    }

    _logicalKeys.add(key);
    committedMutations++;
    final index = tables.assignments.indexWhere(
      (assignment) => assignment.id == payload['assignment_id'],
    );
    final advanced = tables.assignments[index].copyWith(
      currentDayKey: 'day_2',
      currentSessionOrder: 1,
    );
    tables.assignments[index] = advanced;
    return {
      'status': 'committed',
      'assignment': _assignmentMap(advanced),
      'next_cursor': {
        'week_number': 1,
        'day_key': 'day_2',
        'slot_order': 1,
        'protocol_id': 'RN-006',
      },
    };
  }
}

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  ProgrammeExecutionContext context({
    String key = 'prog:assignment-1@version-1:w1:day_1:s1:BW-001',
  }) => ProgrammeExecutionContext(
    assignmentId: ProgrammeScheduleTestFixtures.assignmentId,
    programmeVersionId: ProgrammeScheduleTestFixtures.versionId,
    sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
    weekNumber: 1,
    dayKey: 'day_1',
    sessionOrder: 1,
    plannedProtocolId: 'BW-001',
    effectiveProtocolId: 'BW-001',
    packageContentHash: hash,
    programmedSessionKey: key,
  );

  PerformanceCaptureController controller() {
    final plan = M8ModernCaptureTestFixtures.singleBlockPlan();
    return M8ModernCaptureTestFixtures.performanceController(plan)
      ..markBlockComplete(plan.blocks.single.blockId);
  }

  test(
    'Self-Test 2 completion journey preserves atomic advancement boundary',
    () async {
      final tables = InMemoryProgrammeTables();
      final initial = ProgrammeScheduleTestFixtures.materialisedAssignment(
        athleteId: 'founder-test-athlete',
        packageContentHash: hash,
      );
      tables.assignments.add(initial);
      final store = _AtomicFakeCompletionStore(tables);
      final service = AthleteProgrammeCompletionService(
        store: store,
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
      );

      // 1–4: a materialised assignment prepares an authored w1/day_1/s1 key.
      expect(initial.isMaterialised, isTrue);
      expect(initial.currentWeek, 1);
      expect(initial.currentDayKey, 'day_1');
      expect(initial.currentSessionOrder, 1);
      final oldKey = service.buildLogicalCompletionKey(context());

      // 5–10: one submit commits once and the authority response advances cursor.
      final committed = await service.submit(
        controller: controller(),
        programmeContext: context(),
        trainingSessionId: 9001,
        idempotencyKey: 'first-attempt',
      );
      expect(committed.status, AthleteProgrammeCompletionStatus.committed);
      expect(store.calls, 1);
      expect(store.committedMutations, 1);
      expect(committed.assignment?.currentDayKey, 'day_2');
      expect(tables.assignments.single.currentDayKey, 'day_2');

      // 11–14: retry is replay-only and the next prepared identity differs.
      final replay = await service.submit(
        controller: controller(),
        programmeContext: context(),
        trainingSessionId: 9001,
        idempotencyKey: 'first-attempt',
      );
      expect(replay.status, AthleteProgrammeCompletionStatus.alreadyCommitted);
      expect(store.committedMutations, 1);
      final newKey = 'prog:assignment-1@version-1:w1:day_2:s1:RN-006';
      expect(oldKey, isNot(newKey));
      expect(replay.status.name.contains('coach'), isFalse);
      expect(replay.status.name.contains('commerce'), isFalse);

      // 15–18: concurrent submissions with distinct idempotency keys mutate once.
      final concurrentTables = InMemoryProgrammeTables()
        ..assignments.add(initial);
      final concurrentStore = _AtomicFakeCompletionStore(concurrentTables);
      final concurrentService = AthleteProgrammeCompletionService(
        store: concurrentStore,
        assignmentStore: InMemoryProgrammeAssignmentStore(concurrentTables),
      );
      final results = await Future.wait([
        concurrentService.submit(
          controller: controller(),
          programmeContext: context(),
          trainingSessionId: 9001,
          idempotencyKey: 'parallel-a',
        ),
        concurrentService.submit(
          controller: controller(),
          programmeContext: context(),
          trainingSessionId: 9001,
          idempotencyKey: 'parallel-b',
        ),
      ]);

      expect(
        results.where(
          (result) =>
              result.status == AthleteProgrammeCompletionStatus.committed,
        ),
        hasLength(1),
      );
      expect(concurrentStore.committedMutations, 1);
      expect(concurrentTables.assignments.single.currentDayKey, 'day_2');
    },
  );
}
