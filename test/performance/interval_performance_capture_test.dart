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
    expect(IntervalPaceFormat.parse('4'), isNull);
    expect(IntervalPaceFormat.parse('4:'), isNull);
    expect(IntervalPaceFormat.parse('4:1'), isNull);
    expect(IntervalPaceFormat.isComplete('4:10'), isTrue);
    expect(IntervalPaceFormat.isComplete('4:1'), isFalse);
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

  testWidgets('character entry keeps interval 1 open until explicit complete', (
    tester,
  ) async {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 15,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: BlockResultEditor(
                  blockDraft: controller.draft.blockDrafts.single,
                  onResultChanged: (data) {
                    controller.updateBlockResultData(blockId, data);
                    setState(() {});
                  },
                  onAddSet: (_) {},
                  onUpdateSet: (_, _, _) {},
                  onDuplicateSet: (_, _) {},
                  onRemoveSet: (_, _) {},
                ),
              );
            },
          ),
        ),
      ),
    );

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    await tester.tap(field);
    await tester.pump();

    Future<void> type(String value) async {
      await tester.enterText(field, value);
      await tester.pump();
    }

    await type('4');
    expect(tester.widget<TextField>(field).controller!.text, '4');
    expect(field, findsOneWidget);
    expect(find.text('Enter pace as MM:SS /km'), findsNothing);
    expect(
      (controller.draft.blockDrafts.single.resultData as IntervalResultData)
          .recordedCount,
      0,
    );

    await type('4:');
    expect(tester.widget<TextField>(field).controller!.text, '4:');
    expect(field, findsOneWidget);

    await type('4:1');
    expect(tester.widget<TextField>(field).controller!.text, '4:1');
    expect(field, findsOneWidget);

    await type('4:10');
    expect(tester.widget<TextField>(field).controller!.text, '4:10');
    expect(field, findsOneWidget);
    expect(
      (controller.draft.blockDrafts.single.resultData as IntervalResultData)
          .intervals
          .first
          .state,
      IntervalWorkState.pending,
    );
    expect(
      (controller.draft.blockDrafts.single.resultData as IntervalResultData)
          .recordedCount,
      0,
    );

    await tester.enterText(field, '4:1');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '4:1');
    expect(field, findsOneWidget);

    await tester.enterText(field, '4:10');
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Completed'));
    await tester.pump();

    final recorded =
        controller.draft.blockDrafts.single.resultData as IntervalResultData;
    expect(recorded.intervals.first.state, IntervalWorkState.completed);
    expect(recorded.intervals.first.paceSecondsPerKm, 250);
    expect(recorded.recordedCount, 1);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isNot('4:10'),
    );
  });

  testWidgets('invalid seconds stay open and do not record', (tester) async {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 16,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: BlockResultEditor(
                  blockDraft: controller.draft.blockDrafts.single,
                  onResultChanged: (data) {
                    controller.updateBlockResultData(blockId, data);
                    setState(() {});
                  },
                  onAddSet: (_) {},
                  onUpdateSet: (_, _, _) {},
                  onDuplicateSet: (_, _) {},
                  onRemoveSet: (_, _) {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '4:99');
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Completed'));
    await tester.pump();
    expect(find.text('Enter pace as MM:SS /km'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      (controller.draft.blockDrafts.single.resultData as IntervalResultData)
          .recordedCount,
      0,
    );
  });

  testWidgets('paste and rebuild during focus keep the draft', (tester) async {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 17,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;

    Widget editor() {
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BlockResultEditor(
                blockDraft: controller.draft.blockDrafts.single,
                onResultChanged: (data) {
                  controller.updateBlockResultData(blockId, data);
                  setState(() {});
                },
                onAddSet: (_) {},
                onUpdateSet: (_, _, _) {},
                onDuplicateSet: (_, _) {},
                onRemoveSet: (_, _) {},
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(editor());
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, '4');
    await tester.pump();
    await tester.pumpWidget(editor());
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '4');
    await tester.enterText(find.byType(TextField), '4:10');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '4:10');
    expect(
      (controller.draft.blockDrafts.single.resultData as IntervalResultData)
          .intervals
          .first
          .state,
      IntervalWorkState.pending,
    );
  });

  testWidgets('resume and relaunch keep five interval identities', (
    tester,
  ) async {
    final store = InMemoryPerformanceRecordStore();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _enginePlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 18,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BlockResultEditor(
                blockDraft: controller.draft.blockDrafts.single,
                onResultChanged: (data) {
                  controller.updateBlockResultData(blockId, data);
                  setState(() {});
                },
                onAddSet: (_) {},
                onUpdateSet: (_, _, _) {},
                onDuplicateSet: (_, _) {},
                onRemoveSet: (_, _) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '4:10');
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Completed'));
    await tester.pump();
    await store.saveDraft(controller.draft);
    final resumed = await store.getInProgressForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 18,
    );
    final ids = resumed!.blockResults.single.exerciseResults.single.setResults
        .map((set) => set.setResultId)
        .toList();
    expect(ids, hasLength(5));
    expect(ids.toSet(), hasLength(5));
    expect(
      (resumed.blockResults.single.resultData as IntervalResultData)
          .intervals
          .first
          .paceSecondsPerKm,
      250,
    );
    await store.saveDraft(controller.draft);
    final relaunched = await store.getInProgressForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 18,
    );
    expect(
      relaunched!.blockResults.single.exerciseResults.single.setResults
          .map((set) => set.setResultId),
      ids,
    );
  });
}
