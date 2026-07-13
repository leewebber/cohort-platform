import '../../../models/exercise_progress_result.dart';

/// Progress and note snapshot passed when a strength session finishes.
class StrengthSessionFinishSummary {
  const StrengthSessionFinishSummary({
    required this.sessionTitle,
    required this.exercises,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
    this.sessionNote,
    this.endedEarly = false,
    this.endReasonLabel,
  });

  final String sessionTitle;
  final List<ExerciseProgressSnapshot> exercises;
  final String? sessionNote;
  final bool endedEarly;
  final int completedExerciseCount;
  final int totalExerciseCount;

  /// Athlete-selected reason when [endedEarly] is true.
  final String? endReasonLabel;
}

/// Per-exercise progress captured during the session.
class ExerciseProgressSnapshot {
  const ExerciseProgressSnapshot({
    required this.exerciseName,
    this.progressResult,
  });

  final String exerciseName;
  final ExerciseProgressResult? progressResult;
}
