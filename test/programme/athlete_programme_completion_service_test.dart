import 'dart:async';

import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_completion.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_store.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/m8_modern_capture_test_fixtures.dart';
import '../support/programme_schedule_test_fixtures.dart';

class _FakeCompletionStore implements AthleteProgrammeCompletionStore {
  _FakeCompletionStore(this._handler);

  final FutureOr<Map<String, dynamic>> Function(Map<String, dynamic>) _handler;
  final calls = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> completeAndAdvance(
    Map<String, dynamic> payload,
  ) async {
    calls.add(Map<String, dynamic>.from(payload));
    return _handler(payload);
  }
}

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  ProgrammeExecutionContext context() => const ProgrammeExecutionContext(
    assignmentId: ProgrammeScheduleTestFixtures.assignmentId,
    programmeVersionId: ProgrammeScheduleTestFixtures.versionId,
    sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
    weekNumber: 1,
    dayKey: 'day_1',
    sessionOrder: 1,
    plannedProtocolId: 'BW-001',
    effectiveProtocolId: 'BW-001',
    lineageCode: 'COHORT-FOUNDATION-TEST',
    packageContentHash: hash,
    programmedSessionKey: 'prog:assignment-1@version-1:w1:day_1:s1:BW-001',
  );

  PerformanceCaptureController completedController() {
    final plan = M8ModernCaptureTestFixtures.singleBlockPlan();
    return M8ModernCaptureTestFixtures.performanceController(plan)
      ..markBlockComplete(plan.blocks.single.blockId);
  }

  ProgrammeAssignment assignment({
    int week = 1,
    String dayKey = 'day_1',
    int slot = 1,
  }) => ProgrammeScheduleTestFixtures.materialisedAssignment(
    athleteId: 'founder-test-athlete',
    week: week,
    dayKey: dayKey,
    slotOrder: slot,
    packageContentHash: hash,
  );

  Map<String, dynamic> assignmentMap(ProgrammeAssignment value) => {
    ...value.toUpdateMap(),
    'id': value.id,
    'materialised_at': value.materialisedAt?.toIso8601String(),
    'materialisation_source': value.materialisationSource,
    'materialised_package_content_hash': value.materialisedPackageContentHash,
  };

  Map<String, dynamic> committedResponse(ProgrammeAssignment value) => {
    'status': 'committed',
    'code': 'committed',
    'assignment': assignmentMap(value),
    'next_cursor': {
      'week_number': value.currentWeek,
      'day_key': value.currentDayKey,
      'slot_order': value.currentSessionOrder,
      'protocol_id': 'RN-006',
    },
  };

  AthleteProgrammeCompletionService service({
    required _FakeCompletionStore store,
    required InMemoryProgrammeTables tables,
    AthleteLocalRepository? localRepository,
  }) => AthleteProgrammeCompletionService(
    store: store,
    assignmentStore: InMemoryProgrammeAssignmentStore(tables),
    localRepository: localRepository,
  );

  group('AthleteProgrammeCompletionService', () {
    test(
      'commits, maps the result, and clears local prepared session',
      () async {
        final tables = InMemoryProgrammeTables()..assignments.add(assignment());
        final local = AthleteLocalRepository(InMemoryKvStore());
        await local.saveGeneratedSession(
          GeneratedSessionRecord(
            athleteId: 'founder-test-athlete',
            intendedTrainingDate: DateTime.utc(2026, 8, 1),
            generatedAt: DateTime.utc(2026, 8, 1),
            plan: M8ModernCaptureTestFixtures.singleBlockPlan(),
            brief: const WorkoutSessionBrief(sessionName: 'Prepared'),
          ),
        );
        final advanced = assignment(dayKey: 'day_2');
        final store = _FakeCompletionStore((_) => committedResponse(advanced));

        final result =
            await service(
              store: store,
              tables: tables,
              localRepository: local,
            ).submit(
              controller: completedController(),
              programmeContext: context(),
              trainingSessionId: 9001,
              idempotencyKey: 'idem-1',
            );

        expect(result.status, AthleteProgrammeCompletionStatus.committed);
        expect(result.assignment?.currentDayKey, 'day_2');
        expect(result.nextDayKey, 'day_2');
        expect(
          await local.readGeneratedSession('founder-test-athlete'),
          isNull,
        );
        expect(store.calls, hasLength(1));
      },
    );

    test('maps enrolled-only and inactive RPC validation responses', () async {
      final tables = InMemoryProgrammeTables()..assignments.add(assignment());
      final responses = [
        {'status': 'validation_failure', 'code': 'assignment_not_materialised'},
        {'status': 'validation_failure', 'code': 'assignment_inactive'},
      ];
      final store = _FakeCompletionStore((_) => responses.removeAt(0));
      final completion = service(store: store, tables: tables);

      final enrolled = await completion.submit(
        controller: completedController(),
        programmeContext: context(),
        trainingSessionId: 9001,
        idempotencyKey: 'enrolled',
      );
      final inactive = await completion.submit(
        controller: completedController(),
        programmeContext: context(),
        trainingSessionId: 9001,
        idempotencyKey: 'inactive',
      );

      expect(
        enrolled.status,
        AthleteProgrammeCompletionStatus.assignmentNotMaterialised,
      );
      expect(
        inactive.status,
        AthleteProgrammeCompletionStatus.assignmentInactive,
      );
    });

    test('maps stale cursor and logical payload conflicts', () async {
      final tables = InMemoryProgrammeTables()..assignments.add(assignment());
      final responses = [
        {'status': 'conflict', 'code': 'stale_cursor'},
        {'status': 'conflict', 'code': 'logical_completion_payload_conflict'},
      ];
      final completion = service(
        store: _FakeCompletionStore((_) => responses.removeAt(0)),
        tables: tables,
      );

      final stale = await completion.submit(
        controller: completedController(),
        programmeContext: context(),
        trainingSessionId: 9001,
        idempotencyKey: 'stale',
      );
      final conflict = await completion.submit(
        controller: completedController(),
        programmeContext: context(),
        trainingSessionId: 9001,
        idempotencyKey: 'conflict',
      );

      expect(stale.status, AthleteProgrammeCompletionStatus.staleCursor);
      expect(
        conflict.status,
        AthleteProgrammeCompletionStatus.logicalCompletionPayloadConflict,
      );
    });

    test('maps same logical and idempotency replay to success', () async {
      final tables = InMemoryProgrammeTables()..assignments.add(assignment());
      final store = _FakeCompletionStore(
        (_) => {
          'status': 'already_committed',
          'code': 'idempotent_replay',
          'assignment': assignmentMap(assignment(dayKey: 'day_2')),
        },
      );

      final result = await service(store: store, tables: tables).submit(
        controller: completedController(),
        programmeContext: context(),
        trainingSessionId: 9001,
        idempotencyKey: 'same-idempotency',
      );

      expect(result.status, AthleteProgrammeCompletionStatus.alreadyCommitted);
      expect(result.isSuccess, isTrue);
    });

    test(
      'reconciles an uncertain network response when cursor moved',
      () async {
        final tables = InMemoryProgrammeTables()
          ..assignments.add(assignment(dayKey: 'day_2'));
        final result =
            await service(
              store: _FakeCompletionStore(
                (_) => throw StateError('response lost'),
              ),
              tables: tables,
            ).submit(
              controller: completedController(),
              programmeContext: context(),
              trainingSessionId: 9001,
              idempotencyKey: 'lost-response',
            );

        expect(
          result.status,
          AthleteProgrammeCompletionStatus.alreadyCommitted,
        );
        expect(result.code, 'reconciled_after_uncertain');
        expect(result.nextDayKey, 'day_2');
      },
    );

    test('builds programme-shaped logical completion keys', () {
      final completion = AthleteProgrammeCompletionService(
        store: _FakeCompletionStore((_) => throw UnimplementedError()),
        assignmentStore: InMemoryProgrammeAssignmentStore(
          InMemoryProgrammeTables(),
        ),
      );

      expect(
        completion.buildLogicalCompletionKey(context()),
        'prog:assignment-1@version-1:w1:day_1:s1:BW-001',
      );
    });

    test('fingerprints the same record stably', () {
      final completion = AthleteProgrammeCompletionService(
        store: _FakeCompletionStore((_) => throw UnimplementedError()),
        assignmentStore: InMemoryProgrammeAssignmentStore(
          InMemoryProgrammeTables(),
        ),
      );
      final controller = completedController();
      final record = const PerformanceRecordMapper().fromDraft(
        controller.buildPersistableDraft(
          status: controller.resolveCompletionStatus(),
        ),
      );

      expect(
        completion.fingerprintActuals(record),
        completion.fingerprintActuals(record),
      );
    });
  });
}
