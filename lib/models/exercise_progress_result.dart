import '../features/performance/progression/progression_comparison.dart';
import '../features/performance/progression/progression_surface.dart';

/// Observational strength progress outcome for one completed exercise.
///
/// [title] and [message] are copied from the canonical progression engine.
/// [progressType] remains only for SessionWins classification.
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

  factory ExerciseProgressResult.fromSurface(
    ProgressionSurfaceProjection surface,
  ) {
    return ExerciseProgressResult(
      progressType: ExerciseProgressType.fromOutcome(
        surface.comparison.outcome,
        deltas: surface.comparison.deltas.map((delta) => delta.key).toList(),
      ),
      title: surface.verdictLabel,
      message: surface.explanation,
      reasons: [
        ...surface.comparison.deltas.map((delta) => delta.label),
        if (surface.personalBestStatus != null) surface.personalBestStatus!,
      ],
    );
  }
}

enum ExerciseProgressType {
  firstPerformance,
  loadProgress,
  repProgress,
  volumeProgress,
  rpeProgress,
  matchedPerformance,
  mixedResult,
  belowLastPerformance,
  notComparable,
  insufficientData;

  static ExerciseProgressType fromOutcome(
    ProgressionOutcome outcome, {
    List<String> deltas = const [],
  }) {
    return switch (outcome) {
      ProgressionOutcome.firstPerformance =>
        ExerciseProgressType.firstPerformance,
      ProgressionOutcome.matched => ExerciseProgressType.matchedPerformance,
      ProgressionOutcome.mixed => ExerciseProgressType.mixedResult,
      ProgressionOutcome.belowLastPerformance =>
        ExerciseProgressType.belowLastPerformance,
      ProgressionOutcome.notComparable => ExerciseProgressType.notComparable,
      ProgressionOutcome.insufficientEvidence =>
        ExerciseProgressType.insufficientData,
      ProgressionOutcome.improved => deltas.contains('load')
          ? ExerciseProgressType.loadProgress
          : deltas.contains('reps')
          ? ExerciseProgressType.repProgress
          : deltas.contains('rpe')
          ? ExerciseProgressType.rpeProgress
          : ExerciseProgressType.loadProgress,
    };
  }
}
