import '../../../core/utils/database_uuid.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/active_performance_draft.dart';
import '../models/circuit_station_actual.dart';
import '../models/performance_result_data.dart';
import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';

class CircuitSetSync {
  const CircuitSetSync._();

  static List<ExercisePerformanceDraft> ensureAuthoredRows({
    required List<ExercisePerformanceDraft> exercises,
    required CircuitResultData result,
    SessionExecutionBlock? block,
  }) {
    if (result.isFixedWork || result.stations.isEmpty) return exercises;
    final byId = {for (final exercise in exercises) exercise.sourceExerciseId: exercise};
    final used = <String>{};
    final next = <ExercisePerformanceDraft>[];
    final grouped = <String, List<CircuitStationActual>>{};
    for (final row in result.stations) {
      grouped.putIfAbsent(row.stationId, () => []).add(row);
    }
    for (final entry in grouped.entries) {
      final existing = byId[entry.key];
      final host =
          existing ??
          ExercisePerformanceDraft(
            exerciseResultId: DatabaseUuid.newV4(),
            sourceExerciseId: entry.key,
            exerciseSnapshot: existing?.exerciseSnapshot ??
                ExercisePerformanceSnapshot(
                  sourceExerciseId: entry.key,
                  displayName: entry.value.first.displayName,
                  position: entry.value.first.stationIndex,
                ),
            position: existing?.position ?? entry.value.first.stationIndex,
          );
      final byOccurrence = {
        for (final set in host.sets) set.setNumber: set,
      };
      next.add(
        host.copyWith(
          sets: [
            for (final row in entry.value)
              applyRow(
                byOccurrence[row.round] ??
                    SetPerformanceDraft.empty(
                      setNumber: row.round,
                      position: row.round,
                      loadUnit: row.loadUnit,
                      distanceUnit: row.distanceUnit,
                    ),
                row,
              ),
          ],
        ),
      );
      used.add(entry.key);
    }
    for (final exercise in exercises) {
      if (!used.contains(exercise.sourceExerciseId)) {
        next.add(exercise);
      }
    }
    return next;
  }

  static SetPerformanceDraft applyRow(
    SetPerformanceDraft set,
    CircuitStationActual row,
  ) {
    final recorded = row.state == CircuitOccurrenceState.recorded;
    return set.copyWith(
      setNumber: row.round,
      position: row.round,
      reps: row.primaryMetric == CircuitStationMetric.calories
          ? row.calories?.round()
          : row.reps,
      clearReps:
          (row.primaryMetric == CircuitStationMetric.calories
              ? row.calories
              : row.reps) ==
          null,
      load: row.load,
      clearLoad: row.load == null,
      loadUnit: row.loadUnit,
      distance: row.distance,
      clearDistance: row.distance == null,
      distanceUnit: row.distanceUnit,
      durationSeconds: row.durationSeconds,
      clearDurationSeconds: row.durationSeconds == null,
      completed: recorded,
    );
  }

  static TrainingSetResult applyToRecordedSet(
    TrainingSetResult set,
    CircuitStationActual row,
  ) {
    return set.copyWith(
      reps: row.primaryMetric == CircuitStationMetric.calories
          ? row.calories?.round()
          : row.reps,
      clearReps:
          (row.primaryMetric == CircuitStationMetric.calories
              ? row.calories
              : row.reps) ==
          null,
      load: row.load,
      clearLoad: row.load == null,
      loadUnit: row.loadUnit,
      distance: row.distance,
      clearDistance: row.distance == null,
      distanceUnit: row.distanceUnit,
      durationSeconds: row.durationSeconds,
      clearDurationSeconds: row.durationSeconds == null,
      completed: row.state == CircuitOccurrenceState.recorded,
    );
  }

  static CircuitStationActual applySetToRow(
    CircuitStationActual row,
    TrainingSetResult set,
  ) {
    final calories = row.primaryMetric == CircuitStationMetric.calories
        ? set.reps?.toDouble()
        : row.calories;
    final recorded = set.completed &&
        (row.primaryMetric == CircuitStationMetric.completion ||
            _hasPrimary(row.primaryMetric, set, calories));
    return row.copyWith(
      calories: calories,
      clearCalories: calories == null,
      reps: row.primaryMetric == CircuitStationMetric.calories
          ? row.reps
          : set.reps,
      clearReps:
          row.primaryMetric != CircuitStationMetric.calories && set.reps == null,
      distance: set.distance,
      clearDistance: set.distance == null,
      durationSeconds: set.durationSeconds,
      clearDuration: set.durationSeconds == null,
      load: set.load,
      clearLoad: set.load == null,
      loadUnit: set.loadUnit,
      state: recorded
          ? CircuitOccurrenceState.recorded
          : CircuitOccurrenceState.pending,
    );
  }

  static CircuitResultData hydrateFromSets({
    required CircuitResultData result,
    required List<TrainingExerciseResult> exercises,
  }) {
    if (result.isFixedWork || result.stations.isEmpty) return result;
    final byExercise = {
      for (final exercise in exercises)
        exercise.sourceExerciseId: {
          for (final set in exercise.setResults) set.setNumber: set,
        },
    };
    return result.copyWith(
      stations: [
        for (final row in result.stations)
          byExercise[row.stationId]?[row.round] == null
              ? row
              : applySetToRow(row, byExercise[row.stationId]![row.round]!),
      ],
    );
  }

  static bool _hasPrimary(
    CircuitStationMetric metric,
    TrainingSetResult set,
    double? calories,
  ) {
    return switch (metric) {
      CircuitStationMetric.calories => calories != null,
      CircuitStationMetric.reps => set.reps != null,
      CircuitStationMetric.distance => set.distance != null,
      CircuitStationMetric.duration => set.durationSeconds != null,
      CircuitStationMetric.load => set.load != null,
      CircuitStationMetric.completion => set.completed,
    };
  }
}
