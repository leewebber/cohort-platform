/// Completion metadata persisted when a training session is closed.
class TrainingSessionCompletionContext {
  const TrainingSessionCompletionContext({
    this.sessionNote,
    this.endedEarly = false,
    this.completionReason,
    this.completedExerciseCount,
    this.totalExerciseCount,
  });

  final String? sessionNote;
  final bool endedEarly;
  final String? completionReason;
  final int? completedExerciseCount;
  final int? totalExerciseCount;
}
