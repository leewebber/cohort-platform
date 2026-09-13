import '../../../models/circuit_capture_strategy.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/circuit_round_actual.dart';
import '../models/circuit_station_actual.dart';
import '../models/performance_result_data.dart';
import '../models/performance_snapshot.dart';

class CircuitCaptureContract {
  const CircuitCaptureContract._();

  static bool isCircuitFormat(WorkoutFormat format) {
    return format == WorkoutFormat.emom || format == WorkoutFormat.rounds;
  }

  static CircuitCaptureStrategy resolveStrategy(SessionExecutionBlock block) {
    return block.timerConfiguration?.captureStrategy ??
        CircuitCaptureStrategy.variableOutput;
  }

  static bool isFixedWork(SessionExecutionBlock block) {
    return isCircuitFormat(block.workoutFormat) &&
        resolveStrategy(block) == CircuitCaptureStrategy.fixedWork;
  }

  static bool hasAuthoredStations(SessionExecutionBlock block) {
    if (isFixedWork(block)) {
      return authoredStationSpecs(block).isNotEmpty &&
          (block.timerConfiguration?.effectiveTargetRounds ?? 0) > 0;
    }
    if (block.workoutFormat == WorkoutFormat.emom) {
      return (occurrenceCount(block) ?? 0) > 0;
    }
    return authoredStationSpecs(block).isNotEmpty &&
        (occurrenceCount(block) ?? 0) > 0;
  }

  static List<TimerStationSpec> authoredStationSpecs(
    SessionExecutionBlock block,
  ) {
    final fromTimer = block.timerConfiguration?.stations ?? const [];
    if (fromTimer.isNotEmpty && isCircuitFormat(block.workoutFormat)) {
      return _mergeLinkedMetadata(block, fromTimer);
    }
    if (!isCircuitFormat(block.workoutFormat) ||
        block.linkedExercises.isEmpty) {
      return const [];
    }
    return [
      for (var i = 0; i < block.linkedExercises.length; i++)
        _specFromLinked(block.linkedExercises[i], i + 1),
    ];
  }

  static int? occurrenceCount(SessionExecutionBlock block) {
    if (block.workoutFormat == WorkoutFormat.emom) {
      final total = block.timerConfiguration?.emomTotalSeconds;
      final interval = block.timerConfiguration?.intervalSeconds ?? 60;
      if (total == null || total <= 0 || interval <= 0) return null;
      return total ~/ interval;
    }
    final specs = authoredStationSpecs(block);
    if (specs.isEmpty) return null;
    final rounds = block.timerConfiguration?.effectiveTargetRounds;
    if (rounds == null || rounds <= 0) return null;
    return rounds * specs.length;
  }

  static String comparisonFamily(SessionExecutionBlock block) {
    final specs = authoredStationSpecs(block);
    final signature = specs
        .map((spec) => _stationSignature(spec))
        .join('|');
    final strategy = resolveStrategy(block).dbValue;
    if (block.workoutFormat == WorkoutFormat.emom) {
      final total = block.timerConfiguration?.emomTotalSeconds ?? 0;
      final interval = block.timerConfiguration?.intervalSeconds ?? 60;
      return '$strategy:emom:$signature:${interval}s:${total}s';
    }
    final rounds = block.timerConfiguration?.effectiveTargetRounds ?? 0;
    return '$strategy:rounds:$signature:${rounds}r';
  }

  static CircuitResultData authoredResult(SessionExecutionBlock block) {
    final specs = authoredStationSpecs(block);
    final strategy = resolveStrategy(block);
    final labels = {
      for (final exercise in block.linkedExercises)
        exercise.exerciseId: exercise.displayName,
    };
    if (strategy == CircuitCaptureStrategy.fixedWork) {
      final target = block.timerConfiguration?.effectiveTargetRounds ?? 0;
      if (specs.isEmpty || target <= 0) {
        return CircuitResultData(
          format: block.workoutFormat.dbValue,
          comparisonFamily: comparisonFamily(block),
          captureStrategy: strategy,
          stations: const [],
          targetRounds: target > 0 ? target : null,
          restBetweenRoundsSeconds:
              block.timerConfiguration?.restBetweenRoundsSeconds,
        );
      }
      return CircuitResultData(
        format: block.workoutFormat.dbValue,
        comparisonFamily: comparisonFamily(block),
        captureStrategy: strategy,
        targetRounds: target,
        restBetweenRoundsSeconds:
            block.timerConfiguration?.restBetweenRoundsSeconds,
        stations: [
          for (var i = 0; i < specs.length; i++)
            _occurrence(
              block: block,
              specs: specs,
              labels: labels,
              ordinal: i + 1,
              forceRound: 0,
            ),
        ],
        sharedSetup: [
          for (final exercise in block.linkedExercises)
            if (_expectsExternalLoad(block, exercise))
              CircuitSharedSetup(
                stationId: exercise.exerciseId,
                displayName: labels[exercise.exerciseId] ?? exercise.displayName,
              ),
        ],
        rounds: [
          for (var ordinal = 1; ordinal <= target; ordinal++)
            CircuitRoundActual(ordinal: ordinal),
        ],
        timerCursor: const CircuitTimerCursor(
          currentRound: 1,
          currentOrdinal: 1,
          remainingSeconds: 0,
          phase: 'ready',
        ),
      );
    }
    final count = occurrenceCount(block);
    if (block.workoutFormat == WorkoutFormat.emom) {
      return CircuitResultData(
        format: block.workoutFormat.dbValue,
        comparisonFamily: comparisonFamily(block),
        captureStrategy: strategy,
        targetRounds: count != null && count > 0 ? count : null,
        intervalSeconds: block.timerConfiguration?.intervalSeconds,
        restBetweenRoundsSeconds:
            block.timerConfiguration?.restBetweenRoundsSeconds,
        stations: [
          for (var i = 0; i < specs.length; i++)
            _occurrence(
              block: block,
              specs: specs,
              labels: labels,
              ordinal: i + 1,
              forceRound: 1,
            ),
        ],
      );
    }
    if (specs.isEmpty || count == null || count <= 0) {
      return CircuitResultData(
        format: block.workoutFormat.dbValue,
        comparisonFamily: comparisonFamily(block),
        captureStrategy: strategy,
        stations: const [],
        targetRounds: block.timerConfiguration?.effectiveTargetRounds,
        intervalSeconds: block.timerConfiguration?.intervalSeconds,
        restBetweenRoundsSeconds:
            block.timerConfiguration?.restBetweenRoundsSeconds,
      );
    }
    return CircuitResultData(
      format: block.workoutFormat.dbValue,
      comparisonFamily: comparisonFamily(block),
      captureStrategy: strategy,
      targetRounds: block.timerConfiguration?.effectiveTargetRounds,
      intervalSeconds: block.timerConfiguration?.intervalSeconds,
      restBetweenRoundsSeconds:
          block.timerConfiguration?.restBetweenRoundsSeconds,
      stations: [
        for (var ordinal = 1; ordinal <= count; ordinal++)
          _occurrence(
            block: block,
            specs: specs,
            labels: labels,
            ordinal: ordinal,
          ),
      ],
    );
  }

  static bool _expectsExternalLoad(
    SessionExecutionBlock block,
    SessionExecutionExerciseSummary exercise,
  ) {
    return StrengthActualLoadKind.fromPrescription(
      blockType: block.blockType,
      prescription: exercise.prescription,
    ).expectsExternalLoad;
  }

  static CircuitStationActual _occurrence({
    required SessionExecutionBlock block,
    required List<TimerStationSpec> specs,
    required Map<String, String> labels,
    required int ordinal,
    int? forceRound,
  }) {
    final spec = specs[(ordinal - 1) % specs.length];
    final round = forceRound ??
        (block.workoutFormat == WorkoutFormat.emom
            ? ordinal
            : ((ordinal - 1) ~/ specs.length) + 1);
    return CircuitStationActual(
      ordinal: ordinal,
      round: round,
      stationIndex: spec.position,
      stationId: spec.exerciseId,
      displayName: labels[spec.exerciseId] ?? spec.exerciseId,
      primaryMetric: _metric(spec),
      prescribedCalories: spec.calories,
      prescribedReps: spec.reps,
      prescribedDistanceMeters: spec.distanceMeters,
      prescribedDistanceText: spec.distanceText,
    );
  }

  static CircuitStationMetric _metric(TimerStationSpec spec) {
    if (spec.calories != null) return CircuitStationMetric.calories;
    if (spec.reps != null) return CircuitStationMetric.reps;
    if (spec.distanceMeters != null ||
        (spec.distanceText?.trim().isNotEmpty == true)) {
      return CircuitStationMetric.distance;
    }
    return CircuitStationMetric.completion;
  }

  static String _stationSignature(TimerStationSpec spec) {
    if (spec.calories != null) return '${spec.exerciseId}:cal${spec.calories}';
    if (spec.reps != null) return '${spec.exerciseId}:reps${spec.reps}';
    if (spec.distanceMeters != null) {
      return '${spec.exerciseId}:${spec.distanceMeters}m';
    }
    if (spec.distanceText?.trim().isNotEmpty == true) {
      return '${spec.exerciseId}:${spec.distanceText}m';
    }
    return '${spec.exerciseId}:done';
  }

  static List<TimerStationSpec> _mergeLinkedMetadata(
    SessionExecutionBlock block,
    List<TimerStationSpec> specs,
  ) {
    return [
      for (final spec in specs)
        _enrich(spec, _linkedSpec(block, spec.exerciseId)),
    ];
  }

  static TimerStationSpec? _linkedSpec(
    SessionExecutionBlock block,
    String exerciseId,
  ) {
    for (var i = 0; i < block.linkedExercises.length; i++) {
      final exercise = block.linkedExercises[i];
      if (exercise.exerciseId != exerciseId) continue;
      return _specFromLinked(exercise, i + 1);
    }
    return null;
  }

  static TimerStationSpec _specFromLinked(
    SessionExecutionExerciseSummary exercise,
    int position,
  ) {
    final prescription = exercise.prescription;
    return TimerStationSpec(
      exerciseId: exercise.exerciseId,
      position: position,
      calories: prescription?.calories,
      reps: prescription?.reps.exactReps,
      distanceMeters: prescription?.prescribedDistanceMeters,
      distanceText: prescription?.prescribedDistanceText,
    );
  }

  static TimerStationSpec _enrich(
    TimerStationSpec base,
    TimerStationSpec? extra,
  ) {
    if (extra == null) return base;
    return TimerStationSpec(
      exerciseId: base.exerciseId,
      position: base.position,
      minute: base.minute,
      calories: base.calories ?? extra.calories,
      reps: base.reps ?? extra.reps,
      distanceMeters: base.distanceMeters ?? extra.distanceMeters,
      distanceText: base.distanceText ?? extra.distanceText,
    );
  }
}
