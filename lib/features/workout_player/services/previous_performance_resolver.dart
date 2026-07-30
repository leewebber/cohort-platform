import '../../../core/persistence/models/execution_result_models.dart';
import '../../../core/persistence/previous_performance_from_results.dart';
import '../models/previous_performance_snapshot.dart';

/// Deterministic resolver for the most relevant prior performance.
///
/// Matches by stable [exerciseId] and comparable result types.
/// Prefers the most recent valid completed performance.
/// Excludes abandoned/invalid sets. Does not fabricate history.
class PreviousPerformanceResolver {
  const PreviousPerformanceResolver({
    this.fromResults = const PreviousPerformanceFromResults(),
  });

  final PreviousPerformanceFromResults fromResults;

  /// Latest comparable snapshot for [exerciseId], or null.
  PreviousPerformanceSnapshot? resolveLatest({
    required String exerciseId,
    List<PreviousPerformanceSnapshot>? records,
    List<ExerciseExecutionResult>? executionResults,
    PreviousPerformanceSessionType? requiredType,
  }) {
    final id = exerciseId.trim();
    if (id.isEmpty) return null;

    if (executionResults != null && executionResults.isNotEmpty) {
      final fromTyped = fromResults.resolveLatest(
        exerciseId: id,
        results: executionResults,
      );
      if (fromTyped != null &&
          (requiredType == null || fromTyped.sessionType == requiredType)) {
        return fromTyped;
      }
    }

    final source = records ?? PreviousPerformanceStore.all;
    final matches = source
        .where(
          (s) =>
              s.exerciseId == id &&
              s.hasDisplayableContent &&
              (requiredType == null || s.sessionType == requiredType),
        )
        .toList(growable: false);
    if (matches.isEmpty) return null;

    matches.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return matches.first;
  }
}
