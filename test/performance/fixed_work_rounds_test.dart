import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/circuit_round_actual.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/services/circuit_capture_contract.dart';
import 'package:cohort_platform/features/performance/services/circuit_result_comparison.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:cohort_platform/features/performance/services/performance_result_summary_formatter.dart';
import 'package:cohort_platform/features/performance/widgets/fixed_work_rounds_capture.dart';
import 'package:cohort_platform/features/performance/widgets/round_time_field.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/fixed_work_rounds_controller.dart';
import 'package:cohort_platform/features/session/widgets/athlete/athlete_block_card.dart';
import 'package:cohort_platform/features/performance/services/interval_pace_format.dart';
import 'package:cohort_platform/models/circuit_capture_strategy.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionExecutionPlan _w5() {
  return SessionExecutionPlan(
    sessionId: 'APOLLO-W5-SAT-R1',
    sessionTitle: 'Session',
    blocks: [
      SessionExecutionBlock(
        blockId: 'cond',
        title: 'Conditioning',
        blockType: SessionBlockType.conditioning,
        content: 'Three rounds',
        workoutFormat: WorkoutFormat.rounds,
        position: 1,
        timerConfiguration: TimerConfiguration.fromJson({
          'rounds': 3,
          'between_round_recovery_seconds': 90,
          'round_sequence': ['EX-131', 'EX-132', 'EX-050', 'EX-009'],
          'capture_strategy': 'fixed_work',
        }),
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-131',
            displayName: 'Sled Push',
            position: 1,
            prescription: StrengthExercisePrescription.fromJson({
              'distance_m': 20,
              'load': {'type': 'athleteSelected'},
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-132',
            displayName: 'Sled Pull',
            position: 2,
            prescription: StrengthExercisePrescription.fromJson({
              'distance_m': 20,
              'load': {'type': 'athleteSelected'},
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-050',
            displayName: 'SkiErg',
            position: 3,
            prescription: StrengthExercisePrescription.fromJson({
              'distance_m': 250,
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-009',
            displayName: 'Burpees',
            position: 4,
            prescription: StrengthExercisePrescription.fromJson({
              'reps': 8,
            }),
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('resolves W5 as authored fixed-work, never by title', () {
    final block = _w5().blocks.single;
    expect(CircuitCaptureContract.resolveStrategy(block), CircuitCaptureStrategy.fixedWork);
    expect(CircuitCaptureContract.isFixedWork(block), isTrue);
    expect(block.title.toLowerCase().contains('athletic'), isFalse);
    expect(
      TimerConfiguration.fromJson({
        'rounds': 3,
        'round_sequence': ['EX-131'],
        'capture_strategy': 'variable_output',
      }).captureStrategy,
      CircuitCaptureStrategy.variableOutput,
    );
  });

  test('legacy circuit JSON without strategy stays variable-output', () {
    final hydrated = CircuitResultData.fromJson({
      'resultType': 'circuit',
      'format': 'rounds',
      'comparisonFamily': 'rounds:old',
      'stations': [
        {
          'ordinal': 1,
          'round': 1,
          'stationIndex': 1,
          'stationId': 'EX-131',
          'displayName': 'Sled Push',
          'primaryMetric': 'distance',
          'distance': 20,
          'state': 'recorded',
        },
      ],
    });
    expect(hydrated.captureStrategy, CircuitCaptureStrategy.variableOutput);
    expect(hydrated.isFixedWork, isFalse);
    expect(hydrated.rounds, isEmpty);
  });

  test('exactly two load entries and three round timings', () {
    final result = CircuitCaptureContract.authoredResult(_w5().blocks.single);
    expect(result.sharedSetup, hasLength(2));
    expect(result.rounds, hasLength(3));
    expect(result.stations, hasLength(4));
  });

  test('start/finish Round 1 enters 90s rest and rest waits for Start Round 2', () {
    var clock = DateTime.utc(2026, 9, 6, 12);
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
      now: () => clock,
    );
    controller.startRound();
    clock = clock.add(const Duration(seconds: 87));
    controller.finishRound();
    expect(controller.phase, FixedWorkPhase.rest);
    expect(controller.result.rounds.first.elapsedSeconds, 87);
    expect(controller.displayedRestSeconds(), 90);
    clock = clock.add(const Duration(seconds: 90));
    controller.completeRestIfDue();
    expect(controller.phase, FixedWorkPhase.ready);
    expect(controller.currentRound, 2);
    expect(controller.canStartCurrentRound, isTrue);
    expect(controller.phase, isNot(FixedWorkPhase.work));
  });

  test('skip rest arms the next ready state without starting work', () {
    var clock = DateTime.utc(2026, 9, 6, 12);
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
      now: () => clock,
    );
    controller.startRound();
    clock = clock.add(const Duration(seconds: 40));
    controller.finishRound();
    controller.skipRest();
    expect(controller.phase, FixedWorkPhase.ready);
    expect(controller.currentRound, 2);
  });

  test('double finish cannot duplicate a completed round', () {
    var clock = DateTime.utc(2026, 9, 6, 12);
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
      now: () => clock,
    );
    controller.startRound();
    clock = clock.add(const Duration(seconds: 50));
    controller.finishRound();
    clock = clock.add(const Duration(seconds: 10));
    controller.finishRound();
    expect(
      controller.result.rounds.where((round) => round.isCompleted),
      hasLength(1),
    );
    expect(controller.result.rounds.first.elapsedSeconds, 50);
  });

  test('relaunch during rest waits for Start Round 2', () {
    var clock = DateTime.utc(2026, 9, 6, 12);
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
      now: () => clock,
    );
    controller.startRound();
    clock = clock.add(const Duration(seconds: 70));
    controller.finishRound();
    final snapshot = CircuitResultData.fromJson(controller.result.toJson());
    clock = clock.add(const Duration(seconds: 20));
    final relaunched = FixedWorkRoundsController(
      result: snapshot,
      now: () => clock,
    );
    expect(relaunched.phase, FixedWorkPhase.rest);
    expect(relaunched.displayedRestSeconds(), 70);
    clock = clock.add(const Duration(seconds: 70));
    relaunched.hydrate(CircuitResultData.fromJson(relaunched.result.toJson()));
    expect(relaunched.phase, FixedWorkPhase.ready);
    expect(relaunched.currentRound, 2);
    expect(relaunched.canStartCurrentRound, isTrue);
  });

  test('backgrounding uses wall-clock anchors', () {
    var clock = DateTime.utc(2026, 9, 6, 12);
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
      now: () => clock,
    );
    controller.startRound();
    clock = clock.add(const Duration(seconds: 33));
    expect(controller.displayedWorkSeconds(), 33);
    final snapshot = CircuitResultData.fromJson(controller.result.toJson());
    clock = clock.add(const Duration(seconds: 12));
    final resumed = FixedWorkRoundsController(result: snapshot, now: () => clock);
    expect(resumed.phase, FixedWorkPhase.work);
    expect(resumed.displayedWorkSeconds(), 45);
  });

  test('early termination preserves completed rounds', () {
    var clock = DateTime.utc(2026, 9, 6, 12);
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
      now: () => clock,
    );
    controller.startRound();
    clock = clock.add(const Duration(seconds: 61));
    controller.finishRound();
    controller.skipRest();
    controller.startRound();
    controller.endEarly(reason: 'fatigue');
    expect(controller.result.endedEarly, isTrue);
    expect(controller.result.rounds.first.isCompleted, isTrue);
    expect(
      controller.result.rounds[1].state,
      CircuitRoundCompletionState.incomplete,
    );
    expect(
      controller.result.rounds[2].state,
      CircuitRoundCompletionState.incomplete,
    );
  });

  test('same-load comparison is faster-is-better; changed load is not comparable', () {
    CircuitResultData timed(int a, int b, int c, {double load = 80}) {
      final base = CircuitCaptureContract.authoredResult(_w5().blocks.single);
      return base.copyWith(
        sharedSetup: [
          for (final setup in base.sharedSetup)
            setup.copyWith(loadKg: load),
        ],
        rounds: [
          base.rounds[0].copyWith(
            elapsedSeconds: a,
            state: CircuitRoundCompletionState.completed,
          ),
          base.rounds[1].copyWith(
            elapsedSeconds: b,
            state: CircuitRoundCompletionState.completed,
          ),
          base.rounds[2].copyWith(
            elapsedSeconds: c,
            state: CircuitRoundCompletionState.completed,
          ),
        ],
      );
    }

    final faster = timed(80, 82, 84);
    final slower = timed(90, 92, 94);
    expect(CircuitResultComparison.isComparable(faster, slower), isTrue);
    expect(CircuitResultComparison.primarySignal(faster)!.higherIsBetter, isFalse);
    expect(faster.fastestRoundSeconds, 80);
    final heavier = timed(70, 71, 72, load: 100);
    expect(CircuitResultComparison.sameFamily(faster, heavier), isTrue);
    expect(CircuitResultComparison.isComparable(faster, heavier), isFalse);
    final missing = timed(70, 71, 72);
    final noLoad = missing.copyWith(
      sharedSetup: [
        for (final setup in missing.sharedSetup) setup.copyWith(clearLoad: true),
      ],
    );
    expect(noLoad.sharedSetup.every((row) => row.loadKg == null), isTrue);
    expect(CircuitResultComparison.loadsAreComparable(faster, noLoad), isFalse);

    TrainingSessionRecord complete(CircuitResultData data, {required int id}) {
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _w5(),
        athleteId: 'athlete-1',
        trainingSessionId: id,
      );
      final blockId = controller.draft.blockDrafts.single.sourceBlockId;
      controller
        ..updateBlockResultData(blockId, data)
        ..markBlockComplete(blockId);
      return const PerformanceRecordMapper().fromDraft(
        controller.buildPersistableDraft(
          status: TrainingSessionRecordStatus.completed,
        ),
      );
    }

    final previous = complete(slower, id: 61);
    final current = complete(faster, id: 62);
    final comparison = CircuitResultComparison.compare(
      block: current.blockResults.single,
      current: current,
      athleteHistory: [previous],
    );
    expect(comparison.status, StrengthExerciseComparisonStatus.improved);
    expect(comparison.fastestIsPersonalRecord, isTrue);

    final heavierRecord = complete(heavier, id: 63);
    final changed = CircuitResultComparison.compare(
      block: heavierRecord.blockResults.single,
      current: heavierRecord,
      athleteHistory: [previous],
    );
    expect(changed.status, StrengthExerciseComparisonStatus.notComparable);
    expect(changed.primaryLabel, 'Not comparable');
    expect(changed.fastestIsPersonalRecord, isFalse);
  });

  test('completed dashboard and correction keep round times', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w5(),
      athleteId: 'athlete-1',
      trainingSessionId: 51,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    var result =
        controller.draft.blockDrafts.single.resultData as CircuitResultData;
    result = result
        .replaceSetup(result.sharedSetup.first.copyWith(loadKg: 70))
        .replaceSetup(result.sharedSetup.last.copyWith(loadKg: 65))
        .replaceRound(
          result.rounds.first.copyWith(
            elapsedSeconds: 91,
            state: CircuitRoundCompletionState.completed,
          ),
        );
    controller
      ..updateBlockResultData(blockId, result)
      ..markBlockComplete(blockId);
    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final summary = PerformanceResultSummaryFormatter.formatBlock(
      record.blockResults.single,
    );
    expect(summary, contains('1/3 rounds'));
    expect(CompletedCircuitBlockProjection.tryFrom(
      record.blockResults.single,
      current: record,
      athleteHistory: const [],
    ), isNotNull);
    final draft = PerformanceCorrectionDraft(record);
    const PerformanceCorrectionService().validate(draft);
    var corrected = draft.blockResults.single.resultData as CircuitResultData;
    expect(corrected.rounds.first.elapsedSeconds, 91);
    expect(corrected.sharedSetup.first.loadKg, 70);
    corrected = corrected
        .replaceSetup(corrected.sharedSetup.first.copyWith(loadKg: 72))
        .replaceRound(
          corrected.rounds.first.copyWith(elapsedSeconds: 88),
        );
    draft.blockResults[0] = draft.blockResults[0].copyWith(resultData: corrected);
    const PerformanceCorrectionService().validate(draft);
    expect(
      (draft.blockResults.single.resultData as CircuitResultData)
          .sharedSetup
          .first
          .loadKg,
      72,
    );
    expect(
      (draft.blockResults.single.resultData as CircuitResultData)
          .rounds
          .first
          .elapsedSeconds,
      88,
    );
  });

  test('manual times complete rounds without starting rest', () {
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
    );
    controller.recordManualTime(1, 85);
    expect(controller.result.rounds.first.isCompleted, isTrue);
    expect(controller.result.rounds.first.elapsedSeconds, 85);
    expect(controller.phase, FixedWorkPhase.ready);
    expect(controller.startOrdinal, 2);
  });

  test('mixed timer then manual keeps one time per round', () {
    var clock = DateTime.utc(2026, 9, 6, 12);
    final controller = FixedWorkRoundsController(
      result: CircuitCaptureContract.authoredResult(_w5().blocks.single),
      now: () => clock,
    );
    controller.startRound();
    clock = clock.add(const Duration(seconds: 70));
    controller.finishRound();
    controller.skipRest();
    controller.recordManualTime(2, 88);
    expect(controller.result.rounds.map((round) => round.elapsedSeconds), [
      70,
      88,
      null,
    ]);
    expect(controller.startOrdinal, 3);
    controller.recordManualTime(1, 65);
    expect(controller.result.rounds.first.elapsedSeconds, 65);
    expect(
      controller.result.rounds.where((round) => round.isCompleted),
      hasLength(2),
    );
  });

  test('digit drafts format 125 and 1030 like pace fields', () {
    expect(IntervalPaceFormat.applySmartDraft('125'), '1:25');
    expect(IntervalPaceFormat.applySmartDraft('1030'), '10:30');
    expect(IntervalPaceFormat.parse('125')?.round(), 85);
    expect(IntervalPaceFormat.parse('1030')?.round(), 630);
    expect(IntervalPaceFormat.isComplete('12'), isFalse);
    expect(IntervalPaceFormat.hasInvalidSeconds('199'), isTrue);
  });

  testWidgets('prescription appears once with loads and start timer visible', (
    tester,
  ) async {
    final plan = _w5();
    final result = CircuitCaptureContract.authoredResult(plan.blocks.single);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AthleteBlockCard(
              block: plan.blocks.single,
              isExpanded: true,
              isActive: true,
              isComplete: false,
              onToggleExpanded: () {},
              onMarkComplete: () {},
              onReopen: () {},
              onLaunchTimer: null,
              onOpenExercise: (_) {},
              performanceReplacesExerciseList: true,
              performanceSection: FixedWorkRoundsCapture(
                result: result,
                onChanged: (_) {},
                linkedExercises: plan.blocks.single.linkedExercises,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Conditioning'), findsOneWidget);
    expect(find.text('Fixed-work rounds'), findsOneWidget);
    expect(find.text('3 ROUNDS'), findsOneWidget);
    expect(find.text('Sled Push'), findsOneWidget);
    expect(find.text('20 m'), findsNWidgets(2));
    expect(find.text('Sled Push (kg)'), findsOneWidget);
    expect(find.text('Sled Pull (kg)'), findsOneWidget);
    expect(find.text('START TIMER'), findsOneWidget);
    expect(find.textContaining('Three rounds'), findsNothing);
    expect(find.textContaining('Athlete selected'), findsNothing);
    expect(find.text('ROUNDS'), findsNothing);
    expect(find.textContaining('Sled Push 20 m ·'), findsNothing);
    expect(find.textContaining('Distance (m)'), findsNothing);
  });

  testWidgets('manual 125 and 1030 complete rounds; partial drafts do not', (
    tester,
  ) async {
    var latest = CircuitCaptureContract.authoredResult(_w5().blocks.single);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: FixedWorkRoundsCapture(
                  result: latest,
                  onChanged: (value) {
                    setState(() => latest = value as CircuitResultData);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('fixed-work-manual-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(RoundTimeField).at(0), '12');
    await tester.pump();
    expect(latest.rounds.first.isCompleted, isFalse);
    await tester.enterText(find.byType(RoundTimeField).at(0), '125');
    await tester.pump();
    expect(latest.rounds.first.elapsedSeconds, 85);
    expect(latest.rounds.first.isCompleted, isTrue);
    await tester.enterText(find.byType(RoundTimeField).at(1), '1030');
    await tester.pump();
    expect(latest.rounds[1].elapsedSeconds, 630);
    await tester.enterText(find.byType(RoundTimeField).at(2), '199');
    await tester.pump();
    expect(latest.rounds[2].isCompleted, isFalse);
    expect(find.text('Enter seconds as 00–59'), findsOneWidget);
  });

  testWidgets('no overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = CircuitCaptureContract.authoredResult(_w5().blocks.single);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FixedWorkRoundsCapture(
              result: result,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('START TIMER'), findsOneWidget);
  });
}
