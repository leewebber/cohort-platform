import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/circuit_station_actual.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/circuit_capture_contract.dart';
import 'package:cohort_platform/features/performance/services/circuit_result_comparison.dart';
import 'package:cohort_platform/features/performance/services/emom_score_contract.dart';
import 'package:cohort_platform/features/performance/widgets/emom_result_capture.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/block_timer_controller.dart';
import 'package:cohort_platform/features/session/services/session_finish_eligibility.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionExecutionPlan _apolloEmom({bool includeStations = true}) {
  return SessionExecutionPlan(
    sessionId: 'APOLLO-W1-SAT-R1',
    sessionTitle: 'Apollo Athletic',
    blocks: [
      SessionExecutionBlock(
        blockId: 'b1100016-0000-4000-8000-000000000016',
        title: 'Alternating EMOM',
        blockType: SessionBlockType.conditioning,
        content: 'Minute 1: RowErg 12 calories. Minute 2: Burpees 8 reps.',
        workoutFormat: WorkoutFormat.emom,
        position: 1,
        timerConfiguration: TimerConfiguration.fromJson({
          'duration_seconds': 480,
          'interval_seconds': 60,
          if (includeStations)
            'alternating': [
              {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
              {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
            ],
        }),
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-049',
            displayName: 'RowErg',
            position: 1,
            prescription: StrengthExercisePrescription.fromJson({
              'calories': 12,
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-009',
            displayName: 'Burpees',
            position: 2,
            prescription: StrengthExercisePrescription.fromJson({'reps': 8}),
          ),
        ],
      ),
      SessionExecutionBlock(
        blockId: 'cool-down',
        title: 'Cool down',
        blockType: SessionBlockType.coolDown,
        content: 'Easy walk',
        workoutFormat: WorkoutFormat.none,
        position: 2,
      ),
    ],
  );
}

CircuitResultData _score(
  CircuitResultData result, {
  required int completed,
  bool prescribed = true,
  bool entered = true,
  bool endedEarly = false,
  double? rowCalories,
  int? burpeeReps,
}) {
  var next = result.copyWith(
    recordedCompletedRounds: completed,
    prescribedTargetsUsed: prescribed,
    endedEarly: endedEarly,
    scoreEntered: entered,
  );
  if (!prescribed) {
    if (rowCalories != null) {
      next = next.replaceStation(
        next.stations.first.copyWith(
          calories: rowCalories,
          state: CircuitOccurrenceState.recorded,
        ),
      );
    }
    if (burpeeReps != null) {
      next = next.replaceStation(
        next.stations[1].copyWith(
          reps: burpeeReps,
          state: CircuitOccurrenceState.recorded,
        ),
      );
    }
  }
  return next;
}

void main() {
  test('valid alternating EMOM projects two stations and eight intervals', () {
    final block = _apolloEmom().blocks.first;
    expect(CircuitCaptureContract.occurrenceCount(block), 8);
    expect(CircuitCaptureContract.authoredStationSpecs(block), hasLength(2));
    final result = CircuitCaptureContract.authoredResult(block);
    expect(result.stations, hasLength(2));
    expect(result.targetRounds, 8);
    expect(result.prescribedCount, 8);
  });

  test('missing timer stations still author eight intervals', () {
    final result = CircuitCaptureContract.authoredResult(
      _apolloEmom(includeStations: false).blocks.first,
    );
    expect(result.targetRounds, 8);
    expect(result.isEmomScore, isTrue);
    expect(result.prescribedCount, 8);
  });

  test('stations alternate across all eight intervals', () {
    final specs = CircuitCaptureContract.authoredStationSpecs(
      _apolloEmom().blocks.first,
    );
    expect([
      for (var i = 1; i <= 8; i++) specs[(i - 1) % specs.length].exerciseId,
    ], ['EX-049', 'EX-009', 'EX-049', 'EX-009', 'EX-049', 'EX-009', 'EX-049', 'EX-009']);
  });

  test('finished timer proposes 8 of 8', () {
    final result = CircuitCaptureContract.authoredResult(
      _apolloEmom().blocks.first,
    );
    final suggested = EmomScoreContract.suggestedCompletedIntervals(
      result: result,
      timer: const BlockTimerState(
        format: WorkoutFormat.emom,
        phase: BlockTimerPhase.countdown,
        isRunning: false,
        isPaused: false,
        isFinished: true,
        primarySeconds: 0,
        currentRound: 8,
        totalRounds: 8,
      ),
    );
    expect(suggested, 8);
  });

  test('prescribed-target completion does not require station actuals', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _apolloEmom(),
      athleteId: 'athlete-1',
      trainingSessionId: 41,
    );
    final blockId = controller.draft.blockDrafts.first.sourceBlockId;
    final authored =
        controller.draft.blockDrafts.first.resultData as CircuitResultData;
    controller
      ..updateBlockResultData(
        blockId,
        _score(authored, completed: 8),
      )
      ..markBlockComplete(blockId);
    final validation = controller.validateForCompletion();
    expect(validation.isValid, isTrue);
    expect(
      (controller.draft.blockDrafts.first.resultData as CircuitResultData)
          .stations
          .every((row) => !row.hasRecordedActual),
      isTrue,
    );
  });

  test('adjusted targets require the missing station field', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _apolloEmom(),
      athleteId: 'athlete-1',
      trainingSessionId: 42,
    );
    final blockId = controller.draft.blockDrafts.first.sourceBlockId;
    final authored =
        controller.draft.blockDrafts.first.resultData as CircuitResultData;
    controller
      ..updateBlockResultData(
        blockId,
        _score(authored, completed: 8, prescribed: false),
      )
      ..markBlockComplete(blockId);
    final validation = controller.validateForCompletion();
    expect(validation.isValid, isFalse);
    expect(
      validation.fieldErrors.values,
      contains('Enter your adjusted RowErg calories.'),
    );
    controller.reopenBlock(blockId);
    controller
      ..updateBlockResultData(
        blockId,
        _score(
          authored,
          completed: 8,
          prescribed: false,
          rowCalories: 10,
          burpeeReps: 8,
        ),
      )
      ..markBlockComplete(blockId);
    expect(controller.validateForCompletion().isValid, isTrue);
  });

  test('zero intervals cannot become full completion', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _apolloEmom(),
      athleteId: 'athlete-1',
      trainingSessionId: 43,
    );
    final blockId = controller.draft.blockDrafts.first.sourceBlockId;
    final authored =
        controller.draft.blockDrafts.first.resultData as CircuitResultData;
    controller
      ..updateBlockResultData(
        blockId,
        _score(authored, completed: 0, endedEarly: false),
      )
      ..markBlockComplete(blockId);
    expect(controller.validateForCompletion().isValid, isFalse);
    expect(
      controller.validateForCompletion().fieldErrors.values,
      contains('Choose whether you completed the full EMOM or ended early.'),
    );
    controller.reopenBlock(blockId);
    controller
      ..updateBlockResultData(
        blockId,
        _score(authored, completed: 0, endedEarly: true),
      )
      ..markBlockComplete(blockId);
    expect(controller.validateForCompletion().isValid, isTrue);
    expect(
      (controller.draft.blockDrafts.first.resultData as CircuitResultData)
          .endedEarly,
      isTrue,
    );
  });

  test('manual route without timer equals timer route evidence', () {
    final plan = _apolloEmom();
    final manual = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'athlete-1',
      trainingSessionId: 44,
    );
    final timed = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'athlete-1',
      trainingSessionId: 45,
    );
    final authored =
        manual.draft.blockDrafts.first.resultData as CircuitResultData;
    manual.updateBlockResultData(
      authored ==
              (manual.draft.blockDrafts.first.resultData as CircuitResultData)
          ? manual.draft.blockDrafts.first.sourceBlockId
          : manual.draft.blockDrafts.first.sourceBlockId,
      _score(authored, completed: 7, endedEarly: true),
    );
    timed.updateBlockResultData(
      timed.draft.blockDrafts.first.sourceBlockId,
      _score(authored, completed: 7, endedEarly: true).copyWith(
        timerCursor: const CircuitTimerCursor(
          currentRound: 7,
          currentOrdinal: 7,
          remainingSeconds: 12,
          phase: 'countdown',
          isPaused: true,
        ),
      ),
    );
    final manualScore =
        manual.draft.blockDrafts.first.resultData as CircuitResultData;
    final timedScore =
        timed.draft.blockDrafts.first.resultData as CircuitResultData;
    expect(manualScore.completedRounds, timedScore.completedRounds);
    expect(manualScore.prescribedTargetsUsed, timedScore.prescribedTargetsUsed);
    expect(manualScore.usedInAppTimer, isFalse);
    expect(timedScore.usedInAppTimer, isTrue);
    expect(
      CircuitResultComparison.primarySignal(manualScore)?.value,
      CircuitResultComparison.primarySignal(timedScore)?.value,
    );
  });

  test('unsaved result does not complete the block', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _apolloEmom(),
      athleteId: 'athlete-1',
      trainingSessionId: 46,
    );
    expect(
      controller.draft.blockDrafts.first.status,
      TrainingBlockResultStatus.notStarted,
    );
    expect(
      (controller.draft.blockDrafts.first.resultData as CircuitResultData)
          .scoreEntered,
      isFalse,
    );
  });

  test('next block and finish session unlock after valid EMOM', () {
    final plan = _apolloEmom();
    final execution = SessionExecutionController(
      plan: plan,
      sessionKey: 'emom-finish-47',
    );
    final performance = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'athlete-1',
      trainingSessionId: 47,
    );
    final emomId = plan.blocks.first.blockId;
    final coolId = plan.blocks.last.blockId;
    performance
      ..updateBlockResultData(
        emomId,
        _score(
          performance.draft.blockDrafts.first.resultData as CircuitResultData,
          completed: 8,
        ),
      )
      ..markBlockComplete(emomId);
    execution.markBlockComplete(emomId);
    expect(execution.state.isBlockComplete(emomId), isTrue);
    expect(execution.state.activeBlock?.blockId, coolId);
    performance.markBlockComplete(coolId);
    execution.markBlockComplete(coolId);
    final finish = const SessionFinishEligibilityEvaluator().evaluate(
      incompleteBlockCount: execution.state.incompleteCount,
      performanceDraft: performance.draft,
    );
    expect(finish.canFinish, isTrue);
  });

  test('timer-absent evidence persists and can finish', () async {
    final store = InMemoryPerformanceRecordStore();
    final plan = _apolloEmom();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'athlete-1',
      trainingSessionId: 48,
    );
    final emomId = plan.blocks.first.blockId;
    controller
      ..updateBlockResultData(
        emomId,
        _score(
          controller.draft.blockDrafts.first.resultData as CircuitResultData,
          completed: 8,
        ),
      )
      ..markBlockComplete(emomId)
      ..markBlockComplete(plan.blocks.last.blockId);
    await store.saveDraft(controller.draft);
    final resumed = await store.getInProgressForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 48,
    );
    final persisted =
        resumed!.blockResults.first.resultData as CircuitResultData;
    expect(persisted.completedRounds, 8);
    expect(persisted.timerCursor, isNull);
    expect(persisted.usedInAppTimer, isFalse);
    await store.completeRecord(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    expect(
      (await store.getTerminalForTrainingSession(
        athleteId: 'athlete-1',
        trainingSessionId: 48,
      ))!.status,
      TrainingSessionRecordStatus.completed,
    );
  });

  test('repeated save stays idempotent', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _apolloEmom(),
      athleteId: 'athlete-1',
      trainingSessionId: 49,
    );
    final blockId = controller.draft.blockDrafts.first.sourceBlockId;
    final scored = _score(
      controller.draft.blockDrafts.first.resultData as CircuitResultData,
      completed: 8,
    );
    controller
      ..updateBlockResultData(blockId, scored)
      ..markBlockComplete(blockId)
      ..updateBlockResultData(blockId, scored)
      ..markBlockComplete(blockId);
    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    expect(record.blockResults.where((block) => block.sourceBlockId == blockId), hasLength(1));
    expect(
      (record.blockResults.first.resultData as CircuitResultData).completedRounds,
      8,
    );
  });

  test('history compares intervals and rejects unrelated EMOMs', () {
    final authored = CircuitCaptureContract.authoredResult(
      _apolloEmom().blocks.first,
    );
    final today = _score(authored, completed: 8);
    final last = _score(authored, completed: 7, endedEarly: true);
    expect(CircuitResultComparison.isComparable(today, last), isTrue);
    expect(
      EmomScoreContract.comparisonLine(today: today, previous: last),
      contains('Last time: 7 of 8'),
    );
    expect(
      EmomScoreContract.completedSummary(today),
      contains('8 of 8 intervals completed'),
    );
    expect(
      CircuitResultComparison.isComparable(
        today,
        today.copyWith(targetRounds: 10),
      ),
      isFalse,
    );
  });

  test('local restore keeps EMOM timer configuration', () {
    const codec = SessionExecutionPlanCodec();
    final restored = codec.decodePlan(codec.encodePlan(_apolloEmom()));
    expect(restored.blocks.first.timerConfiguration?.stations, hasLength(2));
    expect(restored.blocks.first.timerConfiguration?.emomTotalSeconds, 480);
    expect(CircuitCaptureContract.occurrenceCount(restored.blocks.first), 8);
  });

  testWidgets('result surface never shows 0 of 0 stations', (tester) async {
    final result = CircuitCaptureContract.authoredResult(
      _apolloEmom().blocks.first,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EmomResultCapture(
              result: result,
              showActions: false,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('0 of 0 stations'), findsNothing);
    expect(find.textContaining('8 of 8'), findsWidgets);
    expect(find.text('Record at least one station actual before completing this block.'), findsNothing);
  });
}
