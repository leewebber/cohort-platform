import '../../performance/models/circuit_station_actual.dart';
import '../../../models/authored_station_target_formatter.dart';
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
