import '../../performance/models/circuit_station_actual.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import 'block_timer_controller.dart';

class CircuitBlockTimerBridge {
  const CircuitBlockTimerBridge._();

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
      nextStationLabel: _stationLabel(
        occurrence + 1,
        configuration,
        stationLabels,
      ),
    );
  }

  static String? _stationLabel(
    int occurrence,
    TimerConfiguration configuration,
    Map<String, String> stationLabels,
  ) {
    final stations = configuration.stations;
    if (stations.isEmpty || occurrence < 1) return null;
    final spec = stations[(occurrence - 1) % stations.length];
    final label = stationLabels[spec.exerciseId]?.trim();
    return (label != null && label.isNotEmpty) ? label : spec.exerciseId;
  }

  static int _emomIntervals(TimerConfiguration configuration) {
    final total = configuration.emomTotalSeconds;
    final interval = configuration.intervalSeconds;
    if (total == null || interval == null || interval <= 0) return 1;
    return total ~/ interval;
  }
}
