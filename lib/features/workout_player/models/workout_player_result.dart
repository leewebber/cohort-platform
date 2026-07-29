/// Outcome returned to Home when the athlete finishes the Workout Player.
class WorkoutPlayerResult {
  const WorkoutPlayerResult({
    required this.completed,
    required this.trainingSessionId,
    this.duration,
    this.exercisesCompleted = 0,
    this.totalExercises = 0,
    this.sessionRpe,
    this.notes,
  });

  final bool completed;
  final int? trainingSessionId;
  final Duration? duration;
  final int exercisesCompleted;
  final int totalExercises;
  final int? sessionRpe;
  final String? notes;
}
