import 'package:cohort_platform/features/performance/models/block_capture_mode_resolver.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/block_timer_controller.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes authored EMOM duration_seconds as a valid total', () {
    final timer = TimerConfiguration.fromJson({
      'duration_seconds': 480,
      'interval_seconds': 60,
      'alternating': [
        {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
        {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
      ],
    });
    expect(timer.emomTotalSeconds, 480);
    expect(timer.intervalSeconds, 60);
    expect(timer.isValidForFormat(WorkoutFormat.emom), isTrue);
    expect(timer.stations, hasLength(2));
    expect(timer.stations.first.calories, 12);
    expect(timer.stations.last.reps, 8);
  });

  test('decodes authored rounds JSON as target round count', () {
    final timer = TimerConfiguration.fromJson({
      'rounds': 3,
      'between_round_recovery_seconds': 90,
      'round_sequence': ['EX-131', 'EX-132', 'EX-050', 'EX-009'],
    });
    expect(timer.effectiveTargetRounds, 3);
    expect(timer.restBetweenRoundsSeconds, 90);
    expect(timer.stations.map((station) => station.exerciseId), [
      'EX-131',
      'EX-132',
      'EX-050',
      'EX-009',
    ]);
  });

  test('EMOM timer starts with authored minute count and stations', () {
    BlockTimerState? latest;
    final controller = BlockTimerController(
      format: WorkoutFormat.emom,
      configuration: TimerConfiguration.fromJson({
        'duration_seconds': 480,
        'interval_seconds': 60,
        'alternating': [
          {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
          {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
        ],
      }),
      onStateChanged: (state) => latest = state,
    );
    controller.start();
    expect(latest?.totalRounds, 8);
    expect(latest?.currentRound, 1);
    expect(latest?.primarySeconds, 60);
    expect(latest?.currentStationLabel, 'EX-049');
    expect(latest?.nextStationLabel, 'EX-009');
    controller.dispose();
  });

  test('rounds timer uses authored recovery and target rounds', () {
    BlockTimerState? latest;
    final controller = BlockTimerController(
      format: WorkoutFormat.rounds,
      configuration: TimerConfiguration.fromJson({
        'rounds': 3,
        'between_round_recovery_seconds': 90,
        'round_sequence': ['EX-131', 'EX-132', 'EX-050', 'EX-009'],
      }),
      onStateChanged: (state) => latest = state,
    );
    controller.start();
    expect(latest?.totalRounds, 3);
    expect(latest?.currentRound, 1);
    expect(latest?.phase, BlockTimerPhase.work);
    controller.startRecovery();
    expect(latest?.phase, BlockTimerPhase.rest);
    expect(latest?.primarySeconds, 90);
    controller.dispose();
  });

  test('farmer-carry distance_m becomes a distance capture field', () {
    final prescription = StrengthExercisePrescription.fromJson({
      'sets': 3,
      'distance_m': '30-40',
      'load': 'heavy',
    });
    expect(prescription.prescribedDistanceText, '30-40');
    expect(prescription.performanceCapture?.distanceUnit, 'm');
    expect(prescription.performanceCapture?.loadLabel, 'Load per hand');
  });

  test('timer restore keeps the authored minute and remaining time', () {
    late BlockTimerState started;
    final controller = BlockTimerController(
      format: WorkoutFormat.emom,
      configuration: TimerConfiguration.fromJson({
        'duration_seconds': 480,
        'interval_seconds': 60,
        'alternating': [
          {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
          {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
        ],
      }),
      stationLabels: const {'EX-049': 'RowErg', 'EX-009': 'Burpees'},
      onStateChanged: (state) => started = state,
    );
    controller.start();
    controller.pause();
    final paused = started.copyWith(
      currentRound: 3,
      primarySeconds: 41,
      currentStationLabel: 'RowErg',
      nextStationLabel: 'Burpees',
    );
    controller.restore(paused);
    expect(controller.state?.currentRound, 3);
    expect(controller.state?.primarySeconds, 41);
    expect(controller.state?.currentStationLabel, 'RowErg');
    expect(controller.state?.currentStationTarget, '12 cal');
    expect(controller.state?.nextStationLabel, 'Burpees');
    expect(controller.state?.nextStationTarget, '8 reps');
    expect(controller.state?.isPaused, isTrue);
    controller.dispose();
  });

  test('EMOM start exposes RowErg 12 cal then Burpees 8 reps', () {
    late BlockTimerState latest;
    final controller = BlockTimerController(
      format: WorkoutFormat.emom,
      configuration: TimerConfiguration.fromJson({
        'duration_seconds': 480,
        'interval_seconds': 60,
        'alternating': [
          {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
          {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
        ],
      }),
      stationLabels: const {'EX-049': 'RowErg', 'EX-009': 'Burpees'},
      onStateChanged: (state) => latest = state,
    );
    controller.start();
    expect(latest.currentRound, 1);
    expect(latest.totalRounds, 8);
    expect(latest.currentStationLabel, 'RowErg');
    expect(latest.currentStationTarget, '12 cal');
    expect(latest.nextStationLabel, 'Burpees');
    expect(latest.nextStationTarget, '8 reps');
    controller.dispose();
  });

  test('resolver maps EMOM and rounds to circuit capture', () {
    expect(
      BlockCaptureModeResolver.resolve(
        blockType: SessionBlockType.conditioning,
        workoutFormat: WorkoutFormat.emom,
        linkedExerciseCount: 2,
      ),
      BlockCaptureMode.circuit,
    );
    expect(
      BlockCaptureModeResolver.resolveForBlock(
        SessionExecutionBlock(
          blockId: 'rounds',
          title: 'Circuit',
          blockType: SessionBlockType.conditioning,
          content: '',
          workoutFormat: WorkoutFormat.rounds,
          position: 1,
          timerConfiguration: TimerConfiguration.fromJson({
            'rounds': 3,
            'between_round_recovery_seconds': 90,
            'round_sequence': ['EX-131', 'EX-132', 'EX-050', 'EX-009'],
          }),
        ),
      ),
      BlockCaptureMode.circuit,
    );
  });
}
