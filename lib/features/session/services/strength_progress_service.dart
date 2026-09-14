import '../../performance/progression/personal_bests.dart';
import '../../performance/progression/progression_surface.dart';
import '../../performance/progression/strength_progression.dart';
import '../../../models/exercise_progress_result.dart';
import '../../../models/previous_exercise_performance.dart';
import '../models/strength_set_entry.dart';

/// Session-player adapter: extracts logged evidence, then delegates comparison
/// to [StrengthProgressionComparison].
///
/// Does not own comparability, metric deltas, outcome vocabulary, PBs, or
/// athlete-facing explanation.
class StrengthProgressService {
  const StrengthProgressService();

  ExerciseProgressResult evaluate({
    required PreviousExercisePerformance? previousPerformance,
    required List<StrengthSetEntry> todayCompletedSets,
    String exerciseId = 'logged-exercise',
    int? prescribedSetCount,
    List<PersonalBest> personalBests = const [],
  }) {
    final completedToday = todayCompletedSets
        .where((set) => set.completed)
        .toList();
    final current = StrengthProgressionEvidence.fromLoggedSets(
      exerciseId: exerciseId,
      completedSets: completedToday,
      prescribedSetCount: prescribedSetCount ?? completedToday.length,
    );
    final previous = previousPerformance == null || !previousPerformance.hasHistory
        ? null
        : StrengthProgressionEvidence.fromPrevious(
            exerciseId: exerciseId,
            sets: [
              for (final set in previousPerformance.sets)
                (loadLabel: set.loadLabel, reps: set.reps, rpe: set.rpe),
            ],
          );
    final comparison = StrengthProgressionComparison.compare(
      current: current,
      previous: previous,
      previousPerformedAt: previousPerformance?.performedAt,
    );
    return ExerciseProgressResult.fromSurface(
      ProgressionSurfaceProjection(
        comparison: comparison,
        personalBests: personalBests,
      ),
    );
  }
}
