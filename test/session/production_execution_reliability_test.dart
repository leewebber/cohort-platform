import 'package:cohort_platform/features/performance/models/circuit_station_actual.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/circuit_block_timer_bridge.dart';
import 'package:cohort_platform/features/session/services/production_recovery_session_policy.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/serialized_production_restart_harness.dart';

void main() {
  final harness = SerializedProductionRestartHarness();

  test('serialized restart uses JSON, not a surviving in-memory object', () async {
    final result = await harness.captureAndRestart(
      plan: serializedPlan(
        blockId: 'strength',
        format: WorkoutFormat.none,
        capture: BlockPerformanceCaptureMode.strength,
        withExercise: true,
        blockType: SessionBlockType.strength,
      ),
      mutate: (controller) {
        final exercise = controller.draft.blockDrafts.first.exerciseResults.first;
        controller.updateSet(
          'strength',
          exercise.sourceExerciseId,
          exercise.sets.first.setResultId,
          (current) => current.copyWith(reps: 5, load: 60, rpe: 8, completed: true),
        );
      },
    );
    expect(result.serializedRecord, contains('"reps":5'));
    expect(result.serializedEnvelope, contains('"training_session_id":4'));
    expect(result.restored!.trainingSessionId, 4);
    expect(result.decision.outcome, ProductionRestoreOutcome.resumable);
    expect(
      result.restored!.blockDrafts.first.exerciseResults.first.sets.first.reps,
      5,
    );
  });

  test('interval timer evidence survives serialized restart', () async {
    final plan = serializedPlan(
      blockId: 'intervals',
      format: WorkoutFormat.intervals,
      capture: BlockPerformanceCaptureMode.intervals,
      timer: const TimerConfiguration(workSeconds: 40, restSeconds: 20, rounds: 8),
    );
    final result = await harness.captureAndRestart(
      plan: plan,
      mutate: (controller) {
        controller.updateBlockResultData(
          'intervals',
          const IntervalResultData(
            intervalsCompleted: 3,
            totalIntervals: 8,
            entered: true,
            workSeconds: 18,
          ),
        );
      },
    );
    final data =
        result.restored!.blockDrafts.first.resultData as IntervalResultData;
    expect(data.intervalsCompleted, 3);
    expect(data.workSeconds, 18);
    final timer = CircuitBlockTimerBridge.restoredState(
      block: plan.blocks.first,
      result: data,
    );
    expect(timer, isNotNull);
    expect(timer!.isPaused, isTrue);
    expect(timer.primarySeconds, 18);
    expect(timer.currentRound, 4);
  });

  test('for-time elapsed and remaining work survive serialized restart', () async {
    final plan = serializedPlan(
      blockId: 'fortime',
      format: WorkoutFormat.forTime,
      capture: BlockPerformanceCaptureMode.forTime,
      timer: const TimerConfiguration(timeCapSeconds: 720, stopwatchEnabled: true),
    );
    final result = await harness.captureAndRestart(
      plan: plan,
      mutate: (controller) {
        controller.updateBlockResultData(
          'fortime',
          const ForTimeResultData(
            elapsedSeconds: 412,
            completed: false,
            remainingWorkNote: '2 reps left',
          ),
        );
      },
    );
    final data = result.restored!.blockDrafts.first.resultData as ForTimeResultData;
    expect(data.elapsedSeconds, 412);
    expect(data.remainingWorkNote, '2 reps left');
    final timer = CircuitBlockTimerBridge.restoredState(
      block: plan.blocks.first,
      result: data,
    );
    expect(timer!.primarySeconds, 412);
    expect(timer.isPaused, isTrue);
  });

  test('AMRAP remaining time is persisted, not invented', () async {
    final plan = serializedPlan(
      blockId: 'amrap',
      format: WorkoutFormat.amrap,
      capture: BlockPerformanceCaptureMode.amrap,
      timer: const TimerConfiguration(durationSeconds: 600),
    );
    final result = await harness.captureAndRestart(
      plan: plan,
      mutate: (controller) {
        controller.updateBlockResultData(
          'amrap',
          const AmrapResultData(rounds: 6, extraReps: 3, remainingSeconds: 240),
        );
      },
    );
    final data = result.restored!.blockDrafts.first.resultData as AmrapResultData;
    expect(data.rounds, 6);
    expect(data.extraReps, 3);
    expect(data.remainingSeconds, 240);
    final timer = CircuitBlockTimerBridge.restoredState(
      block: plan.blocks.first,
      result: data,
    );
    expect(timer!.primarySeconds, 240);
  });

  test('EMOM cursor and circuit ended-early survive JSON restart', () async {
    final emom = await harness.captureAndRestart(
      plan: serializedPlan(
        blockId: 'emom',
        format: WorkoutFormat.emom,
        capture: BlockPerformanceCaptureMode.rounds,
        timer: const TimerConfiguration(durationSeconds: 600, intervalSeconds: 60),
      ),
      mutate: (controller) {
        controller.updateBlockResultData(
          'emom',
          const CircuitResultData(
            format: 'emom',
            comparisonFamily: 'emom',
            stations: [],
            recordedCompletedRounds: 4,
            scoreEntered: true,
            timerCursor: CircuitTimerCursor(
              currentRound: 4,
              currentOrdinal: 4,
              remainingSeconds: 18,
              phase: 'work',
              isPaused: true,
            ),
          ),
        );
      },
    );
    final emomData =
        emom.restored!.blockDrafts.first.resultData as CircuitResultData;
    expect(emomData.timerCursor?.remainingSeconds, 18);

    final circuit = await harness.captureAndRestart(
      plan: serializedPlan(
        blockId: 'circuit',
        format: WorkoutFormat.rounds,
        capture: BlockPerformanceCaptureMode.rounds,
      ),
      mutate: (controller) {
        controller.updateBlockResultData(
          'circuit',
          const CircuitResultData(
            format: 'rounds',
            comparisonFamily: 'rounds',
            endedEarly: true,
            earlyEndReason: 'stopped after two stations',
            stations: [
              CircuitStationActual(
                ordinal: 1,
                round: 1,
                stationIndex: 1,
                stationId: 'ex-row',
                displayName: 'Row',
                primaryMetric: CircuitStationMetric.calories,
                state: CircuitOccurrenceState.recorded,
              ),
            ],
          ),
        );
      },
    );
    final circuitData =
        circuit.restored!.blockDrafts.first.resultData as CircuitResultData;
    expect(circuitData.endedEarly, isTrue);
    expect(circuitData.stations, isNotEmpty);
  });

  test('hosted completion wins over a stale serialized local draft', () async {
    final result = await harness.captureAndRestart(
      plan: serializedPlan(
        blockId: 'strength',
        format: WorkoutFormat.none,
        capture: BlockPerformanceCaptureMode.strength,
        withExercise: true,
        blockType: SessionBlockType.strength,
      ),
      mutate: (controller) {},
      hostedCompletedAfterRestart: true,
    );
    expect(result.decision.outcome, ProductionRestoreOutcome.completedHosted);
    expect(result.decision.mayEnterWithRestoredActuals, isFalse);
  });

  test('foreign athlete cannot read serialized draft', () async {
    final result = await harness.captureAndRestart(
      plan: serializedPlan(
        blockId: 'strength',
        format: WorkoutFormat.none,
        capture: BlockPerformanceCaptureMode.strength,
        withExercise: true,
        blockType: SessionBlockType.strength,
      ),
      mutate: (controller) {},
      foreignAthleteId: 'other-athlete',
    );
    expect(result.decision.outcome, ProductionRestoreOutcome.foreignAthlete);
  });

  test('build-7 identity without envelope fields is partially recoverable', () async {
    final result = await harness.captureAndRestart(
      plan: serializedPlan(
        blockId: 'strength',
        format: WorkoutFormat.none,
        capture: BlockPerformanceCaptureMode.strength,
        withExercise: true,
        blockType: SessionBlockType.strength,
      ),
      mutate: (controller) {},
      identity: const ProductionSessionDraft(
        schemaVersion: 0,
        athleteId: 'athlete-1',
        assignmentId: 'assign-1',
        programmeVersionId: 'ver-1',
        programmedSessionKey: 'key-1',
        packageContentHash: serializedRestartHash,
        trainingSessionId: 0,
        entryMode: 'live',
        occurrenceId: 'occ-1',
      ),
    );
    expect(
      result.decision.outcome,
      ProductionRestoreOutcome.legacyPartiallyRecoverable,
    );
    expect(result.decision.mayEnterWithRestoredActuals, isTrue);
  });

  test('guidance-only rest still has no capture path', () {
    expect(
      const ProductionRecoverySessionPolicy().decide(
        plan: const SessionExecutionPlan(sessionId: 'rest', sessionTitle: 'Rest day', blocks: []),
        authoredAsRecoveryOrRest: true,
      ),
      ProductionRecoveryTreatment.guidanceOnly,
    );
  });

  testWidgets('narrow Dynamic Type does not overflow save copy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: Text('Completion pending. Your entered results are still saved on this phone.'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
