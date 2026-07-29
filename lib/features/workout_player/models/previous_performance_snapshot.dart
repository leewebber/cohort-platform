/// Typed prior-performance context for Workout Player (no fabricated history).
enum PreviousPerformanceSessionType {
  strength,
  runningInterval,
  timedConditioning,
  other,
}

/// Immutable snapshot of the most relevant prior performance for an exercise.
class PreviousPerformanceSnapshot {
  const PreviousPerformanceSnapshot({
    required this.exerciseId,
    required this.sessionType,
    required this.performedAt,
    this.setSummary,
    this.loadSummary,
    this.repSummary,
    this.paceSummary,
    this.durationSummary,
    this.distanceSummary,
    this.rpe,
    this.coachNote,
  });

  final String exerciseId;
  final PreviousPerformanceSessionType sessionType;
  final DateTime performedAt;
  final String? setSummary;
  final String? loadSummary;
  final String? repSummary;
  final String? paceSummary;
  final String? durationSummary;
  final String? distanceSummary;
  final int? rpe;
  final String? coachNote;

  bool get hasDisplayableContent =>
      setSummary != null ||
      loadSummary != null ||
      repSummary != null ||
      paceSummary != null ||
      durationSummary != null ||
      distanceSummary != null ||
      rpe != null;
}

/// In-memory store of prior performances (memory only — no cloud).
class PreviousPerformanceStore {
  PreviousPerformanceStore._();

  static final List<PreviousPerformanceSnapshot> _items = [];

  static List<PreviousPerformanceSnapshot> get all =>
      List.unmodifiable(_items);

  static void record(PreviousPerformanceSnapshot snapshot) {
    if (snapshot.exerciseId.trim().isEmpty) return;
    if (!snapshot.hasDisplayableContent) return;
    _items.add(snapshot);
  }

  static void recordAll(Iterable<PreviousPerformanceSnapshot> snapshots) {
    for (final s in snapshots) {
      record(s);
    }
  }

  static void clear() => _items.clear();
}
