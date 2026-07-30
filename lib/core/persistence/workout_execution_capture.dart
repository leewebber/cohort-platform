import '../../features/workout_player/models/workout_player_state.dart';
import 'models/execution_result_models.dart';

/// Captures typed execution results already available from Workout Player state.
///
/// Does not require athletes to enter every field. Creates extension points for
/// later load/rep/RPE controls while persisting completion evidence now.
class WorkoutExecutionCapture {
  const WorkoutExecutionCapture();

  List<ExerciseExecutionResult> captureCompletedSteps({
    required WorkoutPlayerState state,
    required String completionId,
    DateTime? completedAt,
  }) {
    final stamp = completedAt ?? state.completedAt ?? DateTime.now().toUtc();
    final sessionId = state.plan.sessionId;
    final results = <ExerciseExecutionResult>[];

    for (final index in state.completedExerciseIndexes) {
      if (index < 0 || index >= state.steps.length) continue;
      final step = state.steps[index];
      final exerciseId = step.exercise.exerciseId.trim();
      if (exerciseId.isEmpty) continue;

      final prescription = step.exercise.prescription;
      final prescribedReps = _parseLeadingInt(
        prescription?.reps.toLegacyMetadataValue(),
      );
      final loadText = prescription?.load?.toLegacyMetadataValue();
      final loadParsed = _parseLoad(loadText);

      for (var setIndex = 1; setIndex <= step.totalSets; setIndex++) {
        // completedReps / load stay null unless the athlete entered them.
        // Never copy programmed prescription into completed evidence.
        results.add(
          StrengthExecutionResult(
            resultId: '$completionId.$exerciseId.set$setIndex',
            exerciseId: exerciseId,
            completedAt: stamp,
            completionId: completionId,
            sessionId: sessionId,
            setIndex: setIndex,
            prescribedReps: prescribedReps,
            completedReps: null,
            load: null,
            loadUnit: loadParsed?.unit,
            totalSets: step.totalSets,
          ),
        );
      }
    }

    return results;
  }

  WorkoutProgressSnapshot snapshotFromState({
    required WorkoutPlayerState state,
    required String athleteId,
    String? assignmentId,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    return WorkoutProgressSnapshot(
      sessionId: state.plan.sessionId,
      athleteId: athleteId,
      assignmentId: assignmentId,
      currentExerciseIndex: state.currentExerciseIndex,
      currentSet: state.currentSet,
      completedExerciseIndexes: state.completedExerciseIndexes.toList()..sort(),
      startedAt: state.startedAt ?? stamp,
      lastUpdatedAt: stamp,
      phase: state.phase.name,
      enteredResults: const [],
    );
  }

  int? _parseLeadingInt(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  ({double value, String unit})? _parseLoad(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(
      r'([\d.]+)\s*(kg|lb|lbs)?',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    final unitRaw = match.group(2)?.toLowerCase();
    final unit = switch (unitRaw) {
      'lb' || 'lbs' => 'lb',
      'kg' => 'kg',
      _ => 'kg',
    };
    return (value: value, unit: unit);
  }
}
