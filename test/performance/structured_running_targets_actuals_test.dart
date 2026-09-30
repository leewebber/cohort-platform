import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/screens/session_finish_review_screen.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/structured_running_execution.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _blockId = '123e4567-e89b-42d3-a456-426614174000';
const _packageHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test(
    'controlled v2 fixture binds exact repetitions and restores losslessly',
    () {
      final fixture = _controlledFixture();
      final controller =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: fixture.plan,
            athleteId: 'athlete-1',
            trainingSessionId: 301,
          )..bindStructuredRunning(
            execution: fixture.execution,
            allowInitialize: true,
          );

      final original = controller.draft.blockDrafts.single;
      final result = original.resultData as IntervalResultData;
      expect(result.intervals, hasLength(3));
      expect(result.intervals.map((row) => row.repeatOrdinal), [1, 2, 3]);
      expect(
        result.intervals.every(
          (row) =>
              row.workoutId == fixture.execution.workout.workoutId &&
              row.sessionBlockId == _blockId &&
              row.authoredStepId!.endsWith(':s:work'),
        ),
        isTrue,
      );

      final record = const PerformanceRecordMapper().fromDraft(
        controller.draft,
      );
      final restored =
          PerformanceCaptureController(
            draft: const PerformanceRecordMapper().toDraft(record),
          )..bindStructuredRunning(
            execution: fixture.execution,
            allowInitialize: false,
          );
      expect(
        restored.draft.blockDrafts.single.blockSnapshot.structuredRunning!
            .toJson(),
        original.blockSnapshot.structuredRunning!.toJson(),
      );
    },
  );

  test('pending, duplicate, stale and malformed actuals fail closed', () {
    final fixture = _controlledFixture();
    final controller =
        PerformanceCaptureController.initializeFromExecutionPlan(
          plan: fixture.plan,
          athleteId: 'athlete-1',
          trainingSessionId: 302,
        )..bindStructuredRunning(
          execution: fixture.execution,
          allowInitialize: true,
        );
    controller.markBlockComplete(_blockId);
    expect(controller.validateForCompletion().isValid, isFalse);
    expect(
      controller.validateForCompletion().fieldErrors.values,
      contains('Review every work repetition before completing this block.'),
    );

    final block = controller.draft.blockDrafts.single;
    final result = block.resultData as IntervalResultData;
    final duplicate = result.replaceInterval(
      result.intervals[1].copyWith(
        workoutId: result.intervals.first.workoutId,
        sessionBlockId: result.intervals.first.sessionBlockId,
        authoredStepId: result.intervals.first.authoredStepId,
        repeatOrdinal: result.intervals.first.repeatOrdinal,
      ),
    );
    final malformedDraft = controller.draft.copyWith(
      blockDrafts: [block.copyWith(resultData: duplicate)],
    );
    expect(
      () => PerformanceCaptureController(draft: malformedDraft)
          .bindStructuredRunning(
            execution: fixture.execution,
            allowInitialize: false,
          ),
      throwsA(
        isA<StructuredRunningExecutionException>().having(
          (error) => error.code,
          'code',
          'structured_actuals_authority_mismatch',
        ),
      ),
    );

    final malformedOrdinal = result.replaceInterval(
      result.intervals[1].copyWith(ordinal: 1),
    );
    expect(
      () =>
          PerformanceCaptureController(
            draft: controller.draft.copyWith(
              blockDrafts: [block.copyWith(resultData: malformedOrdinal)],
            ),
          ).bindStructuredRunning(
            execution: fixture.execution,
            allowInitialize: false,
          ),
      throwsA(
        isA<StructuredRunningExecutionException>().having(
          (error) => error.code,
          'code',
          'structured_actuals_authority_mismatch',
        ),
      ),
    );

    final malformedUnit = result.replaceInterval(
      result.intervals[1].copyWith(paceUnit: 'minutes_per_mile'),
    );
    expect(
      () =>
          PerformanceCaptureController(
            draft: controller.draft.copyWith(
              blockDrafts: [block.copyWith(resultData: malformedUnit)],
            ),
          ).bindStructuredRunning(
            execution: fixture.execution,
            allowInitialize: false,
          ),
      throwsA(isA<StructuredRunningExecutionException>()),
    );
  });

  test(
    'review states drive partial completion and remain separate in History',
    () {
      final fixture = _controlledFixture();
      final controller =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: fixture.plan,
            athleteId: 'athlete-1',
            trainingSessionId: 303,
          )..bindStructuredRunning(
            execution: fixture.execution,
            allowInitialize: true,
          );
      var result =
          controller.draft.blockDrafts.single.resultData as IntervalResultData;
      result = result.replaceInterval(
        result.intervals[0].copyWith(
          state: IntervalWorkState.completed,
          paceSecondsPerKm: 240,
        ),
      );
      result = result.replaceInterval(
        result.intervals[1].copyWith(
          state: IntervalWorkState.paceUnavailable,
          clearPace: true,
        ),
      );
      result = result.replaceInterval(
        result.intervals[2].copyWith(
          state: IntervalWorkState.skipped,
          clearPace: true,
        ),
      );
      controller
        ..updateBlockResultData(_blockId, result)
        ..markBlockComplete(_blockId);

      expect(controller.validateForCompletion().isValid, isTrue);
      expect(
        controller.resolveCompletionStatus(),
        TrainingSessionRecordStatus.partiallyCompleted,
      );
      final record = const PerformanceRecordMapper().fromDraft(
        controller.buildPersistableDraft(
          status: TrainingSessionRecordStatus.partiallyCompleted,
        ),
      );
      final rows = CompletedSessionResultProjection.fromRecords(
        record: record,
      ).blocks.single.interval!.rows;
      expect(rows.map((row) => row.targetLabel).toSet(), {'3:50 /km–4:10 /km'});
      expect(rows.map((row) => row.paceLabel), [
        '4:00 /km',
        'Pace unavailable',
        'Skipped',
      ]);
      expect(rows.map((row) => row.repetitionLabel), [
        'Work repetition 1',
        'Work repetition 2',
        'Work repetition 3',
      ]);
    },
  );

  test('actual correction preserves frozen target and exact identity', () {
    final fixture = _controlledFixture();
    final controller =
        PerformanceCaptureController.initializeFromExecutionPlan(
          plan: fixture.plan,
          athleteId: 'athlete-1',
          trainingSessionId: 304,
        )..bindStructuredRunning(
          execution: fixture.execution,
          allowInitialize: true,
        );
    var result =
        controller.draft.blockDrafts.single.resultData as IntervalResultData;
    for (final row in [...result.intervals]) {
      result = result.replaceInterval(
        row.copyWith(
          state: IntervalWorkState.completed,
          paceSecondsPerKm: 240.0 + row.ordinal,
        ),
      );
    }
    controller
      ..updateBlockResultData(_blockId, result)
      ..markBlockComplete(_blockId);
    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final beforeTarget = record
        .blockResults
        .single
        .blockSnapshot
        .structuredRunning!
        .toJson();
    final draft = PerformanceCorrectionDraft(record);
    final correctedResult =
        (draft.blockResults.single.resultData as IntervalResultData)
            .replaceInterval(
              result.intervals.first.copyWith(paceSecondsPerKm: 245),
            );
    draft.blockResults = [
      draft.blockResults.single.copyWith(resultData: correctedResult),
    ];

    final corrected = const PerformanceCorrectionService().applyLocally(draft);
    expect(
      corrected.blockResults.single.blockSnapshot.structuredRunning!.toJson(),
      beforeTarget,
    );
    final correctedRow =
        (corrected.blockResults.single.resultData as IntervalResultData)
            .intervals
            .first;
    expect(correctedRow.paceSecondsPerKm, 245);
    expect(correctedRow.authoredStepId, result.intervals.first.authoredStepId);
    expect(correctedRow.repeatOrdinal, 1);
  });

  testWidgets('repetition review exposes the three bounded outcomes', (
    tester,
  ) async {
    final fixture = _controlledFixture();
    final controller =
        PerformanceCaptureController.initializeFromExecutionPlan(
          plan: fixture.plan,
          athleteId: 'athlete-1',
          trainingSessionId: 305,
        )..bindStructuredRunning(
          execution: fixture.execution,
          allowInitialize: true,
        );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlockResultEditor(
              blockDraft: controller.draft.blockDrafts.single,
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, _, _) {},
              onDuplicateSet: (_, _) {},
              onRemoveSet: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Target · 3:50 /km–4:10 /km'), findsOneWidget);
    expect(find.text('Actual · Not recorded'), findsOneWidget);
    expect(find.text('Completed + actual pace'), findsOneWidget);
    expect(find.text('Completed — pace unavailable'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
  });

  testWidgets('Review Session keeps frozen target separate from each actual', (
    tester,
  ) async {
    final fixture = _controlledFixture();
    final controller =
        PerformanceCaptureController.initializeFromExecutionPlan(
          plan: fixture.plan,
          athleteId: 'athlete-1',
          trainingSessionId: 306,
        )..bindStructuredRunning(
          execution: fixture.execution,
          allowInitialize: true,
        );
    var result =
        controller.draft.blockDrafts.single.resultData as IntervalResultData;
    result = result.replaceInterval(
      result.intervals[0].copyWith(
        state: IntervalWorkState.completed,
        paceSecondsPerKm: 240,
      ),
    );
    result = result.replaceInterval(
      result.intervals[1].copyWith(
        state: IntervalWorkState.paceUnavailable,
        clearPace: true,
      ),
    );
    result = result.replaceInterval(
      result.intervals[2].copyWith(
        state: IntervalWorkState.skipped,
        clearPace: true,
      ),
    );
    controller
      ..updateBlockResultData(_blockId, result)
      ..markBlockComplete(_blockId);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionFinishReviewScreen(
          performanceController: controller,
          executionController: SessionExecutionController(
            plan: fixture.plan,
            sessionKey: 'controlled-review',
          ),
          trainingSessionId: 306,
          athleteId: 'athlete-1',
        ),
      ),
    );

    expect(find.text('Review Session'), findsOneWidget);
    expect(find.text('Target · 3:50 /km–4:10 /km'), findsNWidgets(3));
    expect(find.text('Actual · 4:00 /km'), findsOneWidget);
    expect(find.text('Actual · Pace unavailable'), findsOneWidget);
    expect(find.text('Actual · Skipped'), findsOneWidget);
  });
}

({SessionExecutionPlan plan, VerifiedStructuredRunningExecution execution})
_controlledFixture() {
  const timer = TimerConfiguration(workSeconds: 60, restSeconds: 30, rounds: 3);
  final plan = const SessionExecutionPlan(
    sessionId: 'controlled-v2-running-fixture',
    sessionTitle: 'Controlled v2 structured run',
    blocks: [
      SessionExecutionBlock(
        blockId: _blockId,
        title: 'Identity is not this title',
        blockType: SessionBlockType.conditioning,
        content: 'Hold the authored work effort. Recover easily.',
        workoutFormat: WorkoutFormat.intervals,
        position: 7,
        timerConfiguration: timer,
      ),
    ],
  );
  final workout = const RunningWorkoutProjector()
      .project(
        format: WorkoutFormat.intervals,
        configuration: timer,
        sourceRef: _blockId,
      )
      .workout!;
  final steps = workout.steps.whereType<RunningRepeatGroup>().single.steps;
  final stepIds = steps.map((step) => step.stepId).toList(growable: false);
  final workStepId = steps
      .singleWhere((step) => step.role == RunningStepRole.work)
      .stepId;
  final bindings = stepIds
      .map((stepId) => (stepId: stepId, sessionBlockId: _blockId))
      .toList(growable: false);
  final authority = AuthoredRunningExecutionAuthority.fromCanonicalJson({
    'schema_version': 1,
    'workout_id': workout.workoutId,
    'step_ids': stepIds,
    'executable_step_bindings': [
      for (final stepId in stepIds)
        {'step_id': stepId, 'session_block_id': _blockId},
    ],
    'execution_mapping_sha256': RunningExecutionMappingHash.compute(
      workoutId: workout.workoutId,
      bindings: bindings,
    ),
    'advisory_attachments': [
      {
        'attachment_id': 'TARGET-WORK',
        'step_ids': [workStepId],
      },
    ],
  });
  final snapshot = RunningTargetSnapshotAggregate.fromJson({
    'schema_version': 1,
    'authority': 'advisory',
    'occurrence_id': 'occurrence-controlled',
    'athlete_id': 'athlete-1',
    'assignment_id': 'assignment-controlled',
    'programme_version_id': 'version-controlled',
    'session_slot_id': 'slot-controlled',
    'package_content_hash': _packageHash,
    'workout_id': workout.workoutId,
    'frozen_at_utc': '2026-09-29T02:00:00.000Z',
    'freeze_source': 'in_app_start',
    'targets': [
      {
        'schema_version': 1,
        'authority': 'advisory',
        'attachment_id': 'TARGET-WORK',
        'scope': {
          'workout_id': workout.workoutId,
          'step_ids': [workStepId],
        },
        'frozen_at_utc': '2026-09-29T02:00:00.000Z',
        'freeze_source': 'in_app_start',
        'policy': {
          'policy_id': 'CONTROLLED-POLICY',
          'policy_version': 1,
          'method_id': 'PERCENT-BENCHMARK-SPEED',
          'method_version': 1,
          'minimum_speed_basis_points': 8123,
          'maximum_speed_basis_points': 9345,
          'freshness_local_civil_days': 90,
          'benchmark_eligibility': {
            'cohort_completed_tests_eligible': true,
            'manual_completed_tests_eligible': true,
            'external_completed_tests_eligible': false,
          },
          'display_rounding': {
            'increment_milliseconds_per_kilometre': 1000,
            'direction': 'nearest',
          },
        },
        'state': 'calculated',
        'benchmark': {
          'athlete_id': 'athlete-1',
          'distance_metres': 5000,
          'elapsed_duration_milliseconds': 1200000,
          'duration_basis': 'elapsed_including_pauses',
          'source_kind': 'local_controlled_fixture',
        },
        'calculated_exact_range': {
          'unit': 'milliseconds_per_kilometre',
          'faster': {'numerator': 229600, 'denominator': 1},
          'slower': {'numerator': 250400, 'denominator': 1},
        },
      },
    ],
  });
  return (
    plan: plan,
    execution: VerifiedStructuredRunningExecution.fromLaunch(
      plan: plan,
      authority: authority,
      frozenSnapshot: snapshot,
    ),
  );
}
