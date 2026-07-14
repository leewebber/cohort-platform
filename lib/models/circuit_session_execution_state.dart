import 'circuit_performance_entry.dart';
import 'circuit_session_plan.dart';

/// Whether the athlete is executing live or entering a score after the fact.
enum CircuitEntryMode {
  live,
  postSession,
}

/// Mutable in-session execution state for the circuit engine.
///
/// Holds the immutable plan plus the evolving session score and timer flags.
/// Services mutate copies and replace this state; widgets remain thin.
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
class CircuitSessionExecutionState {
  const CircuitSessionExecutionState({
    required this.plan,
    required this.performance,
    this.entryMode = CircuitEntryMode.live,
    this.isClockRunning = false,
    this.isClockPaused = false,
    this.currentRound = 1,
    this.sessionNote,
    this.endedEarly = false,
    this.endReasonLabel,
    this.trainingSessionId,
  });

  final CircuitSessionPlan plan;
  final CircuitPerformanceEntry performance;
  final CircuitEntryMode entryMode;
  final bool isClockRunning;
  final bool isClockPaused;

  /// Active round or interval index (1-based) for clock-driven formats.
  final int currentRound;
  final String? sessionNote;
  final bool endedEarly;
  final String? endReasonLabel;
  final int? trainingSessionId;

  bool get isRealSession => trainingSessionId != null;

  bool get hasRecordedProgress =>
      performance.hasRecordedScore || performance.completed;

  bool get isScoreComplete => performance.completed;

  CircuitSessionExecutionState copyWith({
    CircuitSessionPlan? plan,
    CircuitPerformanceEntry? performance,
    CircuitEntryMode? entryMode,
    bool? isClockRunning,
    bool? isClockPaused,
    int? currentRound,
    String? sessionNote,
    bool? endedEarly,
    String? endReasonLabel,
    int? trainingSessionId,
    bool clearSessionNote = false,
    bool clearEndReasonLabel = false,
  }) {
    return CircuitSessionExecutionState(
      plan: plan ?? this.plan,
      performance: performance ?? this.performance,
      entryMode: entryMode ?? this.entryMode,
      isClockRunning: isClockRunning ?? this.isClockRunning,
      isClockPaused: isClockPaused ?? this.isClockPaused,
      currentRound: currentRound ?? this.currentRound,
      sessionNote: clearSessionNote ? null : (sessionNote ?? this.sessionNote),
      endedEarly: endedEarly ?? this.endedEarly,
      endReasonLabel: clearEndReasonLabel
          ? null
          : (endReasonLabel ?? this.endReasonLabel),
      trainingSessionId: trainingSessionId ?? this.trainingSessionId,
    );
  }

  CircuitSessionExecutionState updatePerformance(
    CircuitPerformanceEntry updated,
  ) {
    return copyWith(performance: updated);
  }
}
