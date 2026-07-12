/// Observational strength progress outcome for one completed exercise.
class ExerciseProgressResult {
  const ExerciseProgressResult({
    required this.progressType,
    required this.title,
    required this.message,
    required this.reasons,
  });

  final ExerciseProgressType progressType;
  final String title;
  final String message;
  final List<String> reasons;
}

enum ExerciseProgressType {
  firstPerformance,
  loadProgress,
  repProgress,
  volumeProgress,
  rpeProgress,
  matchedPerformance,
  mixedResult,
  insufficientData,
}
