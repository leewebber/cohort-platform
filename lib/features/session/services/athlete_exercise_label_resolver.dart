import '../../../models/exercise.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../performance/models/performance_snapshot.dart';
import '../../performance/models/training_session_record.dart';
import '../models/session_execution_plan.dart';

/// Athlete-facing exercise label resolution.
///
/// Prefers immutable snapshot names for historical views. Active execution may
/// fall back to live exercise metadata when no usable label was captured.
class AthleteExerciseLabelResolver {
  const AthleteExerciseLabelResolver._();

  static String resolve({
    required String sourceExerciseId,
    String? labelOverride,
    String? snapshotDisplayName,
    String? explicitDisplayName,
    String? exerciseName,
    String? liveExerciseName,
    bool historical = false,
  }) {
    final id = sourceExerciseId.trim();

    final candidates = <String?>[
      labelOverride,
      snapshotDisplayName,
      explicitDisplayName,
      if (!historical) ...[
        exerciseName,
        liveExerciseName,
      ],
    ];

    for (final candidate in candidates) {
      if (_isUsableLabel(candidate, id)) {
        return candidate!.trim();
      }
    }

    return id.isEmpty ? 'Exercise' : id;
  }

  static String fromExerciseLink({
    required SessionBlockExerciseLink link,
    Exercise? exercise,
    bool historical = false,
  }) {
    return resolve(
      sourceExerciseId: link.exerciseId,
      labelOverride: link.displayLabelOverride,
      exerciseName: exercise?.name,
      historical: historical,
    );
  }

  static String fromExecutionSummary(
    SessionExecutionExerciseSummary summary, {
    bool historical = false,
  }) {
    return resolve(
      sourceExerciseId: summary.exerciseId,
      labelOverride: summary.displayLabelOverride,
      explicitDisplayName: summary.displayName,
      exerciseName: summary.exercise?.name,
      historical: historical,
    );
  }

  static String fromSnapshot(
    ExercisePerformanceSnapshot snapshot, {
    bool historical = false,
  }) {
    return resolve(
      sourceExerciseId: snapshot.sourceExerciseId,
      labelOverride: snapshot.labelOverride,
      snapshotDisplayName: snapshot.displayName,
      historical: historical,
    );
  }

  static String fromExerciseDraft(
    ExercisePerformanceDraft draft, {
    SessionExecutionExerciseSummary? executionSummary,
    bool historical = false,
  }) {
    return resolve(
      sourceExerciseId: draft.sourceExerciseId,
      labelOverride:
          draft.exerciseSnapshot.labelOverride ??
          executionSummary?.displayLabelOverride,
      snapshotDisplayName: draft.exerciseSnapshot.displayName,
      explicitDisplayName: executionSummary?.displayName,
      exerciseName: executionSummary?.exercise?.name,
      historical: historical,
    );
  }

  static String fromExerciseResult(
    TrainingExerciseResult exercise, {
    bool historical = true,
  }) {
    return fromSnapshot(
      exercise.exerciseSnapshot,
      historical: historical,
    );
  }

  static bool _isUsableLabel(String? value, String sourceExerciseId) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    if (trimmed == sourceExerciseId.trim()) return false;
    return true;
  }
}
