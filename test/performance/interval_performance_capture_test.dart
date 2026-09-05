import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/interval_pace_format.dart';
import 'package:cohort_platform/features/performance/services/interval_result_math.dart';
import 'package:cohort_platform/features/performance/widgets/interval_pace_field.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionExecutionPlan _enginePlan() {
  return SessionExecutionPlan(
    sessionId: 'APOLLO-W1-THU-R1',
    sessionTitle: 'Apollo Engine',
    blocks: [
      SessionExecutionBlock(
        blockId: 'engine',
        title: '5K-effort intervals',
        blockType: SessionBlockType.conditioning,
        content: '5 x 3 minutes',
        workoutFormat: WorkoutFormat.intervals,
        position: 1,
        timerConfiguration: const TimerConfiguration(
          rounds: 5,
          workSeconds: 180,
          restSeconds: 120,
          tracking: ['interval_pace'],
        ),
        linkedExercises: const [
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-129',
            displayName: 'Run intervals',
            position: 1,
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('authored five rounds create exactly five interval rows', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 10,
    );
    final block = controller.draft.blockDrafts.single;
    final result = block.resultData as IntervalResultData;
    expect(result.intervals, hasLength(5));
    expect(block.exerciseResults.single.sets, hasLength(5));
    expect(result.intervals.map((row) => row.ordinal), [1, 2, 3, 4, 5]);
    expect(result.intervals.every((row) => row.workSeconds == 180), isTrue);
  });

  test('formats and parses MM:SS /km pace', () {
    expect(IntervalPaceFormat.parse('4:10'), 250);
    expect(IntervalPaceFormat.parse('4:10 /km'), 250);
    expect(IntervalPaceFormat.formatSecondsPerKm(248), '4:08');
    expect(IntervalPaceFormat.parse('4:99'), isNull);
  });

  test('completion count is derived from recorded rows', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 11,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    var result =
        controller.draft.blockDrafts.single.resultData as IntervalResultData;
    result = result.replaceInterval(
      result.intervals[0].copyWith(
        paceSecondsPerKm: 250,
        state: IntervalWorkState.completed,
      ),
    );
    result = result.replaceInterval(
      result.intervals[1].copyWith(
        paceSecondsPerKm: 248,
        state: IntervalWorkState.completed,
      ),
    );
    result = result.replaceInterval(
      result.intervals[2].copyWith(
        state: IntervalWorkState.paceUnavailable,
        clearPace: true,
      ),
    );
    controller.updateBlockResultData(blockId, result);
    final stored =
        controller.draft.blockDrafts.single.resultData as IntervalResultData;
    expect(stored.recordedCount, 3);
    expect(stored.intervalsCompleted, 0);
    expect(stored.toJson()['intervalsCompleted'], 3);
    expect(
      controller.draft.blockDrafts.single.exerciseResults.single.sets
          .where((set) => set.completed)
          .length,
      3,
    );
  });

  test('weighted average excludes recoveries, skips and unavailable pace', () {
    const result = IntervalResultData(
      totalIntervals: 3,
      workSeconds: 180,
      intervals: [
        IntervalWorkResult(
          ordinal: 1,
          workSeconds: 180,
          paceSecondsPerKm: 240,
          state: IntervalWorkState.completed,
        ),
        IntervalWorkResult(
          ordinal: 2,
          workSeconds: 360,
          paceSecondsPerKm: 300,
          state: IntervalWorkState.completed,
        ),
        IntervalWorkResult(
          ordinal: 3,
          workSeconds: 180,
          state: IntervalWorkState.paceUnavailable,
        ),
      ],
    );
    final average = IntervalResultMath.averagePaceSecondsPerKm(result);
    expect(average, closeTo(540 / (180 / 240 + 360 / 300), 0.01));
    expect(IntervalResultMath.fastest(result)!.ordinal, 1);
    expect(IntervalResultMath.slowest(result)!.ordinal, 2);
  });

  test('autosave resume and relaunch restore interval identities', () async {
    final store = InMemoryPerformanceRecordStore();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 12,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    var result =
        controller.draft.blockDrafts.single.resultData as IntervalResultData;
    final firstId = controller
        .draft
        .blockDrafts
        .single
        .exerciseResults
        .single
        .sets
        .first
        .setResultId;
    result = result.replaceInterval(
      result.intervals[0].copyWith(
        paceSecondsPerKm: 250,
        state: IntervalWorkState.completed,
      ),
    );
    result = result.replaceInterval(
      result.intervals[1].copyWith(
        paceSecondsPerKm: 248,
        state: IntervalWorkState.completed,
      ),
    );
    controller.updateBlockResultData(blockId, result);
    await store.saveDraft(controller.draft);

    final resumed = await store.getInProgressForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 12,
    );
    expect(resumed, isNotNull);
    final resumedResult = resumed!.blockResults.single.resultData
        as IntervalResultData;
    expect(resumedResult.intervals[0].paceSecondsPerKm, 250);
    expect(resumed.blockResults.single.exerciseResults.single.setResults.first.setResultId, firstId);

    controller
      ..updateBlockResultData(
        blockId,
        resumedResult.replaceInterval(
          resumedResult.intervals[2].copyWith(
            paceSecondsPerKm: 247,
            state: IntervalWorkState.completed,
          ),
        ),
      )
      ..markBlockComplete(blockId);
    await store.completeRecord(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final relaunched = await store.getTerminalForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 12,
    );
    expect(
      (relaunched!.blockResults.single.resultData as IntervalResultData)
          .intervals
          .map((row) => row.paceSecondsPerKm)
          .toList(),
      [250, 248, 247, null, null],
    );
    expect(
      relaunched.blockResults.single.exerciseResults.single.setResults.map(
        (set) => set.setResultId,
      ),
      resumed.blockResults.single.exerciseResults.single.setResults.map(
        (set) => set.setResultId,
      ),
    );
  });

  testWidgets('interval editor renders five authored rows and no count field', (
    tester,
  ) async {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 13,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlockResultEditor(
            blockDraft: controller.draft.blockDrafts.single,
            onResultChanged: (_) {},
            onAddSet: (_) {},
            onUpdateSet: (_, _, _) {},
            onDuplicateSet: (_, _) {},
            onRemoveSet: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Intervals completed'), findsNothing);
    expect(find.textContaining('Interval 1'), findsOneWidget);
    expect(find.textContaining('Interval 5'), findsOneWidget);
    expect(find.byType(IntervalPaceField), findsWidgets);
  });

  testWidgets('narrow layout and text scaling remain readable', (tester) async {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 14,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 720), textScaler: TextScaler.linear(1.4)),
        child: MaterialApp(
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
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Interval performance'), findsWidgets);
  });
}
