import '../vocabulary/workout_exercise_execution_outcome.dart';

/// Historical outcome for one exercise slot in the execution snapshot.
class WorkoutExerciseExecutionEntry {
  const WorkoutExerciseExecutionEntry({
    required this.sourceBlockLocalId,
    required this.exerciseLinkLocalId,
    required this.exerciseId,
    required this.stepIndex,
    required this.outcome,
    this.note,
  });

  final String sourceBlockLocalId;
  final String exerciseLinkLocalId;
  final String exerciseId;
  final int stepIndex;
  final WorkoutExerciseExecutionOutcome outcome;
  final String? note;

  @override
  bool operator ==(Object other) {
    return other is WorkoutExerciseExecutionEntry &&
        other.sourceBlockLocalId == sourceBlockLocalId &&
        other.exerciseLinkLocalId == exerciseLinkLocalId &&
        other.exerciseId == exerciseId &&
        other.stepIndex == stepIndex &&
        other.outcome == outcome &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(
    sourceBlockLocalId,
    exerciseLinkLocalId,
    exerciseId,
    stepIndex,
    outcome,
    note,
  );
}
