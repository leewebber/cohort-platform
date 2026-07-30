import '../../features/workout_player/models/previous_performance_snapshot.dart';
import 'models/execution_result_models.dart';

/// Derives contextual previous-performance snapshots from typed set results.
///
/// Rules:
/// - group by stable exerciseId
/// - require comparable result kinds
/// - prefer most recent non-abandoned completed performance
/// - return no snapshot when evidence is insufficient
class PreviousPerformanceFromResults {
  const PreviousPerformanceFromResults();

  List<PreviousPerformanceSnapshot> derive(
    List<ExerciseExecutionResult> results,
  ) {
    final usable = results.where((r) => !r.abandoned && r.exerciseId.isNotEmpty);
    final byExercise = <String, List<ExerciseExecutionResult>>{};
    for (final r in usable) {
      byExercise.putIfAbsent(r.exerciseId, () => []).add(r);
    }

    final out = <PreviousPerformanceSnapshot>[];
    for (final entry in byExercise.entries) {
      final snapshot = _snapshotForExercise(entry.key, entry.value);
      if (snapshot != null) out.add(snapshot);
    }
    return out;
  }

  /// Latest comparable snapshot for [exerciseId], or null.
  PreviousPerformanceSnapshot? resolveLatest({
    required String exerciseId,
    required List<ExerciseExecutionResult> results,
  }) {
    final id = exerciseId.trim();
    if (id.isEmpty) return null;
    final forExercise = results
        .where((r) => !r.abandoned && r.exerciseId == id)
        .toList();
    return _snapshotForExercise(id, forExercise);
  }

  PreviousPerformanceSnapshot? _snapshotForExercise(
    String exerciseId,
    List<ExerciseExecutionResult> results,
  ) {
    if (results.isEmpty) return null;

    final strength = results.whereType<StrengthExecutionResult>().toList();
    final intervals =
        results.whereType<RunningIntervalExecutionResult>().toList();
    final timed =
        results.whereType<TimedConditioningExecutionResult>().toList();

    // Prefer the most recent comparable kind present.
    DateTime latestOf(Iterable<ExerciseExecutionResult> items) => items
        .map((e) => e.completedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    if (strength.isNotEmpty &&
        (intervals.isEmpty || latestOf(strength).isAfter(latestOf(intervals))) &&
        (timed.isEmpty || latestOf(strength).isAfter(latestOf(timed)))) {
      return _fromStrength(exerciseId, strength);
    }
    if (intervals.isNotEmpty &&
        (timed.isEmpty || latestOf(intervals).isAfter(latestOf(timed)))) {
      return _fromIntervals(exerciseId, intervals);
    }
    if (timed.isNotEmpty) {
      return _fromTimed(exerciseId, timed);
    }
    return null;
  }

  PreviousPerformanceSnapshot? _fromStrength(
    String exerciseId,
    List<StrengthExecutionResult> results,
  ) {
    // Use the most recent completion session (by completedAt of last set).
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final latestCompletionId = results.first.completionId;
    final sessionSets = results
        .where((r) => r.completionId == latestCompletionId)
        .toList()
      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
    if (sessionSets.isEmpty) return null;

    final setCount = sessionSets.length;
    // Only athlete-entered completed values — never prescribed-as-performed.
    final reps =
        sessionSets.map((s) => s.completedReps).whereType<int>().toList();
    final loads = sessionSets.map((s) => s.load).whereType<double>().toList();
    final rpes = sessionSets.map((s) => s.rpe).whereType<int>().toList();
    final unit = sessionSets
        .map((s) => s.loadUnit)
        .whereType<String>()
        .cast<String?>()
        .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => null);

    String? loadSummary;
    if (loads.isNotEmpty) {
      final maxLoad = loads.reduce((a, b) => a > b ? a : b);
      final formatted = maxLoad == maxLoad.roundToDouble()
          ? maxLoad.toInt().toString()
          : maxLoad.toStringAsFixed(1);
      loadSummary = unit == null || unit.isEmpty
          ? formatted
          : '$formatted $unit';
    }

    String? repSummary;
    if (reps.isNotEmpty) {
      final first = reps.first;
      final uniform = reps.every((r) => r == first);
      repSummary = uniform
          ? '$setCount × $first'
          : '$setCount sets (${reps.join(', ')})';
    }

    // Insufficient evidence when athlete never entered load/reps/RPE.
    if (loadSummary == null && repSummary == null && rpes.isEmpty) {
      return null;
    }

    return PreviousPerformanceSnapshot(
      exerciseId: exerciseId,
      sessionType: PreviousPerformanceSessionType.strength,
      performedAt: sessionSets.last.completedAt,
      setSummary: '$setCount ×',
      loadSummary: loadSummary,
      repSummary: repSummary,
      rpe: rpes.isEmpty ? null : rpes.last,
    );
  }

  PreviousPerformanceSnapshot? _fromIntervals(
    String exerciseId,
    List<RunningIntervalExecutionResult> results,
  ) {
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final latestCompletionId = results.first.completionId;
    final intervals = results
        .where((r) => r.completionId == latestCompletionId)
        .toList()
      ..sort((a, b) => a.intervalIndex.compareTo(b.intervalIndex));
    if (intervals.isEmpty) return null;

    final distances =
        intervals.map((i) => i.distance).whereType<double>().toList();
    final unit = intervals
        .map((i) => i.distanceUnit)
        .whereType<String>()
        .cast<String?>()
        .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => 'm');
    final paces = intervals
        .map((i) => i.paceSecondsPerKm)
        .whereType<double>()
        .toList();
    final rpes = intervals.map((i) => i.rpe).whereType<int>().toList();

    String? distanceSummary;
    if (distances.isNotEmpty) {
      final first = distances.first;
      final uniform = distances.every((d) => d == first);
      final formatted = first == first.roundToDouble()
          ? first.toInt().toString()
          : first.toStringAsFixed(0);
      distanceSummary = uniform
          ? '${intervals.length} × $formatted $unit'
          : '${intervals.length} intervals';
    } else {
      distanceSummary = '${intervals.length} intervals';
    }

    String? paceSummary;
    if (paces.isNotEmpty) {
      final avg = paces.reduce((a, b) => a + b) / paces.length;
      paceSummary = 'Average pace ${_formatPace(avg)}/km';
    }

    return PreviousPerformanceSnapshot(
      exerciseId: exerciseId,
      sessionType: PreviousPerformanceSessionType.runningInterval,
      performedAt: intervals.last.completedAt,
      setSummary: '${intervals.length} ×',
      distanceSummary: distanceSummary,
      paceSummary: paceSummary,
      rpe: rpes.isEmpty ? null : rpes.last,
    );
  }

  PreviousPerformanceSnapshot? _fromTimed(
    String exerciseId,
    List<TimedConditioningExecutionResult> results,
  ) {
    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final latest = results.first;
    return PreviousPerformanceSnapshot(
      exerciseId: exerciseId,
      sessionType: PreviousPerformanceSessionType.timedConditioning,
      performedAt: latest.completedAt,
      durationSummary: latest.duration == null
          ? null
          : _formatDuration(latest.duration!),
      distanceSummary: latest.distance?.toStringAsFixed(0),
      repSummary: latest.reps == null
          ? (latest.rounds == null ? null : '${latest.rounds} rounds')
          : '${latest.reps} reps',
      rpe: latest.rpe,
    );
  }

  String _formatPace(double secondsPerKm) {
    final total = secondsPerKm.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}
