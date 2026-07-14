/// Local timer display state for circuit execution (v0.1 — in-memory only).
enum CircuitTimerMode {
  countUp,
  countDown,
  intervalPhase,
}

class CircuitTimerState {
  const CircuitTimerState({
    required this.mode,
    this.isStarted = false,
    this.isRunning = false,
    this.isPaused = false,
    this.finished = false,
    this.primarySeconds = 0,
    this.elapsedSeconds = 0,
    this.currentInterval = 1,
    this.totalIntervals,
    this.timeCapped = false,
  });

  final CircuitTimerMode mode;
  final bool isStarted;
  final bool isRunning;
  final bool isPaused;
  final bool finished;
  final int primarySeconds;
  final int elapsedSeconds;
  final int currentInterval;
  final int? totalIntervals;
  final bool timeCapped;

  bool get supportsAddFifteen =>
      mode == CircuitTimerMode.intervalPhase && isStarted && !finished;

  bool get supportsSkip =>
      mode == CircuitTimerMode.intervalPhase && isStarted && !finished;

  CircuitTimerState copyWith({
    CircuitTimerMode? mode,
    bool? isStarted,
    bool? isRunning,
    bool? isPaused,
    bool? finished,
    int? primarySeconds,
    int? elapsedSeconds,
    int? currentInterval,
    int? totalIntervals,
    bool? timeCapped,
    bool clearTotalIntervals = false,
  }) {
    return CircuitTimerState(
      mode: mode ?? this.mode,
      isStarted: isStarted ?? this.isStarted,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      finished: finished ?? this.finished,
      primarySeconds: primarySeconds ?? this.primarySeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentInterval: currentInterval ?? this.currentInterval,
      totalIntervals:
          clearTotalIntervals ? null : (totalIntervals ?? this.totalIntervals),
      timeCapped: timeCapped ?? this.timeCapped,
    );
  }
}
