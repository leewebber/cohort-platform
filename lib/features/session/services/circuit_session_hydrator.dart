import '../../../models/circuit_format.dart';
import '../../../models/circuit_performance.dart';
import '../../../models/circuit_performance_entry.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/circuit_session_execution_state.dart';
import '../../../models/circuit_session_plan.dart';

/// Merges persisted circuit rows into in-memory session execution state.
class CircuitSessionHydrator {
  const CircuitSessionHydrator();

  CircuitSessionExecutionState hydrate({
    required CircuitSessionPlan plan,
    required CircuitSessionExecutionState baseState,
    required CircuitPerformance? persisted,
    required bool preservePerformance,
    String? sessionNote,
    bool preserveSessionNote = false,
  }) {
    var nextState = baseState;

    if (!preservePerformance && persisted != null) {
      nextState = nextState.updatePerformance(
        _entryFromPerformance(
          baseEntry: baseState.performance,
          performance: persisted,
          scoreType: plan.scoreType,
        ),
      );

      final restoredRound = _restoredCurrentRound(
        plan: plan,
        performance: persisted,
      );
      if (restoredRound != null) {
        nextState = nextState.copyWith(currentRound: restoredRound);
      }
    }

    if (!preserveSessionNote) {
      final trimmedNote = sessionNote?.trim();
      if (trimmedNote != null && trimmedNote.isNotEmpty) {
        nextState = nextState.copyWith(sessionNote: trimmedNote);
      }
    }

    return nextState;
  }

  CircuitPerformanceEntry _entryFromPerformance({
    required CircuitPerformanceEntry baseEntry,
    required CircuitPerformance performance,
    required CircuitScoreType scoreType,
  }) {
    return baseEntry.copyWith(
      elapsedDuration: performance.elapsedDuration,
      completedRounds: _restoredCompletedRounds(scoreType, performance),
      additionalReps: performance.additionalReps,
      totalReps: performance.totalReps,
      completedMovements: performance.completedMovements,
      prescribedLoad: performance.prescribedLoad,
      actualLoad: performance.actualLoad,
      rpe: performance.rpe,
      completed: performance.completed,
      timeCapped: performance.timeCapped,
      athleteNote: performance.athleteNote,
      dataSource: performance.dataSource,
      clearElapsedDuration: performance.elapsedDuration == null,
      clearCompletedRounds: _restoredCompletedRounds(scoreType, performance) ==
          null,
      clearAdditionalReps: performance.additionalReps == null,
      clearTotalReps: performance.totalReps == null,
      clearCompletedMovements: performance.completedMovements == null,
      clearPrescribedLoad: performance.prescribedLoad == null,
      clearActualLoad: performance.actualLoad == null,
      clearRpe: performance.rpe == null,
      clearAthleteNote: performance.athleteNote == null,
    );
  }

  int? _restoredCompletedRounds(
    CircuitScoreType scoreType,
    CircuitPerformance performance,
  ) {
    if (scoreType == CircuitScoreType.roundsCompleted) {
      return performance.completedIntervals ?? performance.completedRounds;
    }

    return performance.completedRounds;
  }

  int? _restoredCurrentRound({
    required CircuitSessionPlan plan,
    required CircuitPerformance performance,
  }) {
    if (plan.format == CircuitFormat.emom ||
        plan.format == CircuitFormat.intervalClock) {
      final completed =
          performance.completedIntervals ?? performance.completedRounds ?? 0;
      return (completed + 1).clamp(1, plan.intervalCount ?? 999);
    }

    if (performance.completedRounds != null && performance.completedRounds! > 0) {
      return performance.completedRounds! + 1;
    }

    return null;
  }
}
