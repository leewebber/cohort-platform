import '../../../models/strength_exercise_prescription.dart';
import '../models/active_performance_draft.dart';

/// Derived gym-floor completion for one strength exercise.
///
/// Completeness comes from existing set `completed` flags. Partial draft input
/// without those flags is never treated as complete.
class StrengthExerciseCaptureCompletion {
  const StrengthExerciseCaptureCompletion._();

  static int requiredSetCount({
    required ExercisePerformanceDraft exercise,
    StrengthExercisePrescription? prescription,
  }) {
    if (prescription != null && prescription.sets > 0) {
      return prescription.sets;
    }
    return exercise.sets.length;
  }

  static int completedSetCount(ExercisePerformanceDraft exercise) {
    return exercise.sets.where((set) => set.completed).length;
  }

  static bool isComplete({
    required ExercisePerformanceDraft exercise,
    StrengthExercisePrescription? prescription,
  }) {
    final required = requiredSetCount(
      exercise: exercise,
      prescription: prescription,
    );
    if (required <= 0) return false;
    return completedSetCount(exercise) >= required;
  }

  static String? collapsedStatusLine({
    required ExercisePerformanceDraft exercise,
    StrengthExercisePrescription? prescription,
  }) {
    if (!isComplete(exercise: exercise, prescription: prescription)) {
      return null;
    }
    final completed = completedSetCount(exercise);
    if (completed <= 0) return 'Completed';
    return 'Completed · $completed sets';
  }
}
