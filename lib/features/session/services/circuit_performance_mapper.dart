import '../../../models/circuit_performance.dart';
import '../../../models/circuit_performance_entry.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/circuit_session_plan.dart';

/// Maps in-session [CircuitPerformanceEntry] rows to [CircuitPerformance] records.
class CircuitPerformanceMapper {
  const CircuitPerformanceMapper();

  CircuitPerformance fromEntry({
    required int trainingSessionId,
    required String protocolId,
    required CircuitSessionPlan plan,
    required CircuitPerformanceEntry entry,
    required bool completed,
    bool skipped = false,
  }) {
    return CircuitPerformance(
      id: 0,
      trainingSessionId: trainingSessionId,
      protocolId: protocolId,
      circuitFormat: plan.format,
      scoreType: plan.scoreType,
      elapsedDurationSeconds: entry.elapsedDuration?.inSeconds,
      completedRounds: _completedRoundsForDb(plan.scoreType, entry),
      additionalReps: entry.additionalReps,
      totalReps: entry.totalReps,
      completedIntervals: _completedIntervalsForDb(plan.scoreType, entry),
      completedMovements: entry.completedMovements,
      prescribedLoad: _prescribedLoadFromPlan(plan),
      actualLoad: _nullableString(entry.actualLoad),
      rpe: entry.rpe,
      completed: completed,
      timeCapped: entry.timeCapped,
      skipped: skipped,
      dataSource: entry.dataSource,
      athleteNote: _nullableString(entry.athleteNote),
    );
  }

  int? _completedRoundsForDb(
    CircuitScoreType scoreType,
    CircuitPerformanceEntry entry,
  ) {
    return switch (scoreType) {
      CircuitScoreType.roundsAndReps => entry.completedRounds,
      CircuitScoreType.roundsCompleted => null,
      _ => entry.completedRounds,
    };
  }

  int? _completedIntervalsForDb(
    CircuitScoreType scoreType,
    CircuitPerformanceEntry entry,
  ) {
    if (scoreType != CircuitScoreType.roundsCompleted) {
      return null;
    }

    return entry.completedRounds;
  }

  String? _prescribedLoadFromPlan(CircuitSessionPlan plan) {
    for (final movement in plan.movements) {
      final load = movement.load?.trim();
      if (load != null && load.isNotEmpty) {
        return load;
      }
    }

    return null;
  }

  String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
