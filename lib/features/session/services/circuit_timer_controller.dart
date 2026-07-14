import 'dart:async';

import '../../../models/circuit_format.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/circuit_session_plan.dart';
import '../models/circuit_timer_state.dart';

/// Format-aware local timer orchestration for circuit sessions.
///
/// v0.1 is in-memory only — no persistence.
class CircuitTimerController {
  CircuitTimerController({
    required this.plan,
    required this.onStateChanged,
    this.onFinished,
  });

  final CircuitSessionPlan plan;
  final void Function(CircuitTimerState? state) onStateChanged;
  final void Function(CircuitTimerState state)? onFinished;

  Timer? _timer;
  CircuitTimerState? _state;

  CircuitTimerState? get state => _state;

  static CircuitTimerMode resolveMode(CircuitSessionPlan plan) {
    return switch (plan.format) {
      CircuitFormat.amrap || CircuitFormat.fixedDuration => CircuitTimerMode.countDown,
      CircuitFormat.emom || CircuitFormat.intervalClock =>
        CircuitTimerMode.intervalPhase,
      CircuitFormat.forTime ||
      CircuitFormat.roundsForTime ||
      CircuitFormat.chipper =>
        CircuitTimerMode.countUp,
      CircuitFormat.benchmark => switch (plan.scoreType) {
          CircuitScoreType.roundsAndReps || CircuitScoreType.totalReps =>
            CircuitTimerMode.countDown,
          CircuitScoreType.roundsCompleted => CircuitTimerMode.intervalPhase,
          _ => CircuitTimerMode.countUp,
        },
    };
  }

  void start() {
    _cancelTimer();

    final mode = resolveMode(plan);
    final totalIntervals = plan.intervalCount ?? plan.prescribedRounds;
    final countdownSeconds = _countdownDurationSeconds();

    _state = switch (mode) {
      CircuitTimerMode.countDown => CircuitTimerState(
          mode: mode,
          isStarted: true,
          isRunning: countdownSeconds != null,
          primarySeconds: countdownSeconds ?? 0,
          finished: countdownSeconds == null,
        ),
      CircuitTimerMode.countUp => CircuitTimerState(
          mode: mode,
          isStarted: true,
          isRunning: true,
        ),
      CircuitTimerMode.intervalPhase => CircuitTimerState(
          mode: mode,
          isStarted: true,
          isRunning: true,
          primarySeconds: _intervalPhaseSeconds(),
          currentInterval: 1,
          totalIntervals: totalIntervals,
        ),
    };

    onStateChanged(_state);
    _startTicking();
  }

  void pause() {
    final current = _state;
    if (current == null || current.finished || current.isPaused) {
      return;
    }

    _cancelTimer();
    _state = current.copyWith(
      isRunning: false,
      isPaused: true,
    );
    onStateChanged(_state);
  }

  void resume() {
    final current = _state;
    if (current == null || current.finished || !current.isPaused) {
      return;
    }

    _state = current.copyWith(
      isRunning: true,
      isPaused: false,
    );
    onStateChanged(_state);
    _startTicking();
  }

  void finish() {
    final current = _state;
    if (current == null) {
      return;
    }

    _cancelTimer();
    _state = current.copyWith(
      isRunning: false,
      isPaused: false,
      finished: true,
    );
    onStateChanged(_state);
    onFinished?.call(_state!);
  }

  void skipInterval() {
    final current = _state;
    if (current == null ||
        current.mode != CircuitTimerMode.intervalPhase ||
        current.finished) {
      return;
    }

    _advanceInterval(current);
  }

  void addFifteenSeconds() {
    final current = _state;
    if (current == null || !current.supportsAddFifteen) {
      return;
    }

    _state = current.copyWith(
      primarySeconds: current.primarySeconds + 15,
    );
    onStateChanged(_state);
  }

  void reset() {
    _cancelTimer();
    _state = null;
    onStateChanged(null);
  }

  void dispose() {
    _cancelTimer();
    _state = null;
  }

  void _startTicking() {
    _cancelTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = _state;
    if (current == null || !current.isRunning || current.finished) {
      return;
    }

    switch (current.mode) {
      case CircuitTimerMode.countDown:
        _tickCountDown(current);
      case CircuitTimerMode.countUp:
        _tickCountUp(current);
      case CircuitTimerMode.intervalPhase:
        _tickIntervalPhase(current);
    }
  }

  void _tickCountDown(CircuitTimerState current) {
    final elapsed = current.elapsedSeconds + 1;
    final remaining = current.primarySeconds - 1;

    if (remaining <= 0) {
      _completeTimer(
        current.copyWith(
          primarySeconds: 0,
          elapsedSeconds: elapsed,
          isRunning: false,
          finished: true,
          timeCapped: true,
        ),
      );
      return;
    }

    _state = current.copyWith(
      primarySeconds: remaining,
      elapsedSeconds: elapsed,
    );
    onStateChanged(_state);
  }

  void _tickCountUp(CircuitTimerState current) {
    final elapsed = current.elapsedSeconds + 1;
    final cap = _countdownDurationSeconds();

    if (cap != null && elapsed >= cap) {
      _completeTimer(
        current.copyWith(
          elapsedSeconds: elapsed,
          primarySeconds: elapsed,
          isRunning: false,
          finished: true,
          timeCapped: true,
        ),
      );
      return;
    }

    _state = current.copyWith(
      elapsedSeconds: elapsed,
      primarySeconds: elapsed,
    );
    onStateChanged(_state);
  }

  void _tickIntervalPhase(CircuitTimerState current) {
    final elapsed = current.elapsedSeconds + 1;
    final remaining = current.primarySeconds - 1;

    if (remaining > 0) {
      _state = current.copyWith(
        primarySeconds: remaining,
        elapsedSeconds: elapsed,
      );
      onStateChanged(_state);
      return;
    }

    _advanceInterval(
      current.copyWith(
        elapsedSeconds: elapsed,
      ),
    );
  }

  void _advanceInterval(CircuitTimerState current) {
    final total = current.totalIntervals;
    final nextInterval = current.currentInterval + 1;

    if (total != null && nextInterval > total) {
      _completeTimer(
        current.copyWith(
          currentInterval: total,
          primarySeconds: 0,
          isRunning: false,
          finished: true,
        ),
      );
      return;
    }

    _state = current.copyWith(
      currentInterval: nextInterval,
      primarySeconds: _intervalPhaseSeconds(),
      isRunning: true,
      isPaused: false,
    );
    onStateChanged(_state);
  }

  void _completeTimer(CircuitTimerState next) {
    _cancelTimer();
    _state = next;
    onStateChanged(_state);
    onFinished?.call(next);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  int? _countdownDurationSeconds() {
    final duration = plan.timeCap ?? plan.totalDuration;
    if (duration == null) {
      return null;
    }

    return duration.inSeconds;
  }

  int _intervalPhaseSeconds() {
    return plan.workInterval?.inSeconds ?? 60;
  }
}
