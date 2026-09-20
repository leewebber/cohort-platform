import '../../performance/models/circuit_station_actual.dart';
import '../../performance/models/performance_result_data.dart';
import '../../../models/authored_station_target_formatter.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../models/session_execution_plan.dart';
import 'block_timer_controller.dart';

class CircuitBlockTimerBridge {
  const CircuitBlockTimerBridge._();

  static BlockTimerState? restoredState({
    required SessionExecutionBlock block,
    required PerformanceResultData? result,
    Map<String, String> stationLabels = const {},
  }) {
    final configuration = block.timerConfiguration;
    if (configuration == null) return null;
    if (result is CircuitResultData && result.timerCursor != null) {
      return stateFrom(
        cursor: result.timerCursor!,
        format: block.workoutFormat,
        configuration: configuration,
        stationLabels: stationLabels,
      );
    }
    if (result is IntervalResultData) {
      final next = (result.intervalsCompleted + 1).clamp(
        1,
        result.totalIntervals ?? configuration.rounds ?? 1,
      );
      return BlockTimerState(
        format: WorkoutFormat.intervals,
        phase: BlockTimerPhase.work,
        isRunning: false,
        isPaused: true,
        isFinished: false,
        primarySeconds:
            result.workSeconds ?? configuration.workSeconds ?? 40,
        currentRound: next,
        totalRounds: result.totalIntervals ?? configuration.rounds ?? 1,
        phaseLabel: 'Work',
      );
    }
    if (result is ForTimeResultData && result.elapsedSeconds != null) {
      return BlockTimerState(
        format: WorkoutFormat.forTime,
        phase: BlockTimerPhase.stopwatch,
        isRunning: false,
        isPaused: true,
        isFinished: result.completed,
        primarySeconds: result.elapsedSeconds!,
        secondarySeconds: configuration.timeCapSeconds,
        phaseLabel: 'For Time',
      );
    }
    if (result is AmrapResultData && configuration.durationSeconds != null) {
      final remaining = (configuration.durationSeconds! * 2) ~/ 5;
      return BlockTimerState(
        format: WorkoutFormat.amrap,
        phase: BlockTimerPhase.countdown,
        isRunning: false,
        isPaused: true,
        isFinished: false,
        primarySeconds: remaining,
        phaseLabel: 'AMRAP',
      );
    }
    return null;
  }

  static CircuitTimerCursor cursorFrom(BlockTimerState state) {
    return CircuitTimerCursor(
      currentRound: state.currentRound,
      currentOrdinal: state.currentRound,
      remainingSeconds: state.primarySeconds,
      phase: state.phase.name,
      secondarySeconds: state.secondarySeconds,
      isRunning: state.isRunning,
      isPaused: state.isPaused,
      isFinished: state.isFinished,
    );
  }

  static BlockTimerState stateFrom({
    required CircuitTimerCursor cursor,
    required WorkoutFormat format,
    required TimerConfiguration configuration,
    Map<String, String> stationLabels = const {},
  }) {
    final phase = BlockTimerPhase.values.asNameMap()[cursor.phase] ??
        BlockTimerPhase.work;
    final occurrence = format == WorkoutFormat.emom
        ? cursor.currentRound
        : ((cursor.currentRound - 1) *
                  (configuration.stations.isEmpty
                      ? 1
                      : configuration.stations.length)) +
              1;
    return BlockTimerState(
      format: format,
      phase: phase,
      isRunning: false,
      isPaused: !cursor.isFinished,
      isFinished: cursor.isFinished,
      primarySeconds: cursor.remainingSeconds,
      secondarySeconds: cursor.secondarySeconds,
      currentRound: cursor.currentRound,
      totalRounds: format == WorkoutFormat.emom
          ? _emomIntervals(configuration)
          : (configuration.effectiveTargetRounds ?? 1),
      phaseLabel: format == WorkoutFormat.emom
          ? 'Minute ${cursor.currentRound}'
          : phase == BlockTimerPhase.rest
          ? 'Recovery'
          : 'Round ${cursor.currentRound}',
      currentStationLabel: _stationLabel(
        occurrence,
        configuration,
        stationLabels,
      ),
      currentStationTarget: _stationTarget(occurrence, configuration),
      nextStationLabel: _stationLabel(
        occurrence + 1,
        configuration,
        stationLabels,
      ),
      nextStationTarget: _stationTarget(occurrence + 1, configuration),
    );
  }

  static String? _stationLabel(
    int occurrence,
    TimerConfiguration configuration,
    Map<String, String> stationLabels,
  ) {
    final spec = _spec(occurrence, configuration);
    if (spec == null) return null;
    final label = stationLabels[spec.exerciseId]?.trim();
    return (label != null && label.isNotEmpty) ? label : spec.exerciseId;
  }

  static String? _stationTarget(
    int occurrence,
    TimerConfiguration configuration,
  ) {
    final spec = _spec(occurrence, configuration);
    if (spec == null) return null;
    return AuthoredStationTargetFormatter.fromTimerSpec(spec);
  }

  static TimerStationSpec? _spec(
    int occurrence,
    TimerConfiguration configuration,
  ) {
    final stations = configuration.stations;
    if (stations.isEmpty || occurrence < 1) return null;
    return stations[(occurrence - 1) % stations.length];
  }

  static int _emomIntervals(TimerConfiguration configuration) {
    final total = configuration.emomTotalSeconds;
    final interval = configuration.intervalSeconds;
    if (total == null || interval == null || interval <= 0) return 1;
    return total ~/ interval;
  }
}
