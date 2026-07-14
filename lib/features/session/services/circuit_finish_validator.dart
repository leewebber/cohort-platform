import '../../../models/circuit_format.dart';
import '../../../models/circuit_performance_entry.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/circuit_session_execution_state.dart';
import '../models/circuit_timer_state.dart';

/// Validates whether a circuit session can finish or has started work.
class CircuitFinishValidator {
  const CircuitFinishValidator();

  bool hasWorkStarted({
    required CircuitSessionExecutionState state,
    CircuitTimerState? timerState,
  }) {
    if (state.entryMode == CircuitEntryMode.postSession) {
      return state.performance.hasRecordedScore;
    }

    if (timerState?.isStarted == true) {
      return true;
    }

    return state.performance.hasRecordedScore;
  }

  bool hasValidScore({
    required CircuitPerformanceEntry performance,
    required CircuitScoreType scoreType,
  }) {
    return switch (scoreType) {
      CircuitScoreType.roundsAndReps =>
        performance.completedRounds != null &&
            performance.completedRounds! >= 0,
      CircuitScoreType.elapsedTime => performance.elapsedDuration != null &&
          performance.elapsedDuration!.inSeconds > 0,
      CircuitScoreType.totalReps =>
        performance.totalReps != null && performance.totalReps! > 0,
      CircuitScoreType.roundsCompleted =>
        performance.completedRounds != null &&
            performance.completedRounds! > 0,
      CircuitScoreType.movementsCompleted =>
        performance.completedMovements != null &&
            performance.completedMovements! > 0,
      CircuitScoreType.benchmarkScore => performance.hasRecordedScore,
    };
  }

  String progressSummary({
    required CircuitSessionExecutionState state,
    CircuitTimerState? timerState,
  }) {
    final plan = state.plan;
    final performance = state.performance;

    if (plan.scoreType == CircuitScoreType.roundsCompleted) {
      final completed = performance.completedRounds ??
          (timerState != null && timerState.isStarted
              ? (timerState.currentInterval - 1).clamp(0, 999)
              : 0);
      final total = plan.intervalCount ?? plan.prescribedRounds;
      if (total != null) {
        return '$completed of $total intervals complete';
      }

      return '$completed rounds completed';
    }

    if (plan.scoreType == CircuitScoreType.roundsAndReps) {
      final summary = performance.displayScoreSummary;
      if (summary != null) {
        return summary;
      }

      if (timerState?.isStarted == true && !timerState!.finished) {
        return 'AMRAP in progress';
      }
    }

    if (plan.format == CircuitFormat.chipper &&
        performance.elapsedDuration == null &&
        performance.completedMovements == null &&
        timerState?.isStarted == true) {
      return 'Chipper in progress';
    }

    if (performance.displayScoreSummary != null) {
      return performance.displayScoreSummary!;
    }

    if (timerState?.isStarted == true) {
      return 'Work in progress';
    }

    return 'Ready to start';
  }
}
