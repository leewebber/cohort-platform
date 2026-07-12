import 'dart:async';

import '../models/strength_rest_timer_state.dart';

/// Local countdown orchestration for strength rest periods.
class StrengthRestTimerController {
  StrengthRestTimerController({
    required this.onStateChanged,
    this.onFinished,
  });

  final void Function(StrengthRestTimerState? state) onStateChanged;
  final void Function(StrengthRestTimerState state)? onFinished;

  Timer? _timer;
  StrengthRestTimerState? _state;

  StrengthRestTimerState? get state => _state;

  void start({
    required String exerciseLocalId,
    required String setLocalId,
    required int totalSeconds,
    required String nextTargetLabel,
    String? prescribedRestLabel,
  }) {
    _cancelTimer();

    _state = StrengthRestTimerState(
      exerciseLocalId: exerciseLocalId,
      setLocalId: setLocalId,
      totalSeconds: totalSeconds,
      remainingSeconds: totalSeconds,
      isRunning: true,
      isPaused: false,
      finished: false,
      prescribedRestLabel: prescribedRestLabel,
      nextTargetLabel: nextTargetLabel,
    );

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

  void skip() {
    _finishTimer();
  }

  void addFifteenSeconds() {
    final current = _state;
    if (current == null || current.finished) {
      return;
    }

    _state = current.copyWith(
      totalSeconds: current.totalSeconds + 15,
      remainingSeconds: current.remainingSeconds + 15,
    );
    onStateChanged(_state);
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
    if (current == null || current.finished || current.isPaused) {
      return;
    }

    final nextRemaining = current.remainingSeconds - 1;
    if (nextRemaining <= 0) {
      _finishTimer();
      return;
    }

    _state = current.copyWith(
      remainingSeconds: nextRemaining,
      isRunning: true,
    );
    onStateChanged(_state);
  }

  void _finishTimer() {
    _cancelTimer();

    final current = _state;
    if (current == null) {
      return;
    }

    _state = current.copyWith(
      remainingSeconds: 0,
      isRunning: false,
      isPaused: false,
      finished: true,
    );
    onStateChanged(_state);
    onFinished?.call(_state!);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
