import '../models/previous_performance_snapshot.dart';

/// Deterministic resolver for the most relevant prior performance.
///
/// Matches by stable [exerciseId]. Does not fabricate history.
/// Returns null when evidence is insufficient.
class PreviousPerformanceResolver {
  const PreviousPerformanceResolver();

  /// Latest comparable snapshot for [exerciseId], or null.
  PreviousPerformanceSnapshot? resolveLatest({
    required String exerciseId,
    List<PreviousPerformanceSnapshot>? records,
  }) {
    final id = exerciseId.trim();
    if (id.isEmpty) return null;

    final source = records ?? PreviousPerformanceStore.all;
    final matches = source
        .where((s) => s.exerciseId == id && s.hasDisplayableContent)
        .toList(growable: false);
    if (matches.isEmpty) return null;

    matches.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return matches.first;
  }
}
