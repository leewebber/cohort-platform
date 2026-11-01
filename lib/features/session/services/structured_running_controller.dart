import 'dart:async';

import '../../../domain/running_workout/running_workout.dart';
import '../models/structured_running_execution.dart';

typedef StructuredRunningElapsedTime = Duration Function();
typedef StructuredRunningWallClock = DateTime Function();

class StructuredRunningController<T extends TimedRunningExecution> {
  StructuredRunningController.fresh({
    required T execution,
    this.onCheckpoint,
    StructuredRunningElapsedTime? elapsedTime,
    StructuredRunningWallClock? wallClock,
  }) : _execution = execution,
       _frames = _flatten(execution),
       _elapsedTime = elapsedTime ?? _defaultElapsedTime,
       _wallClock = wallClock ?? _defaultWallClock,
       _frameIndex = 0,
       _remainingMilliseconds = _flatten(execution).first.durationMilliseconds,
       _isPaused = true,
       _manualEvidenceState = StructuredRunningManualEvidenceState.notCaptured,
       _isFinished = false,
       _distanceElapsedMilliseconds = 0,
       _distanceConfirmed = false,
       _lastReconciledAtUtc = null;

  StructuredRunningController.restore({
    required T execution,
    required StructuredRunningCursor cursor,
    this.onCheckpoint,
    StructuredRunningElapsedTime? elapsedTime,
    StructuredRunningWallClock? wallClock,
  }) : _execution = execution,
       _frames = _flatten(execution),
       _elapsedTime = elapsedTime ?? _defaultElapsedTime,
       _wallClock = wallClock ?? _defaultWallClock,
       _frameIndex = _restoreIndex(execution, cursor),
       _remainingMilliseconds = cursor.remainingMilliseconds,
       _isPaused = cursor.isPaused,
       _manualEvidenceState = cursor.manualEvidenceState,
       _isFinished = cursor.isFinished,
       _distanceElapsedMilliseconds = cursor.distanceElapsedMilliseconds,
       _distanceConfirmed = cursor.distanceConfirmed,
       _lastReconciledAtUtc = cursor.lastReconciledAtUtc {
    final frame = _frames[_frameIndex];
    final distanceIndex = _frames.indexWhere((f) => f.isDistance);
    if (cursor.remainingMilliseconds < 0 ||
        cursor.distanceElapsedMilliseconds < 0 ||
        cursor.remainingMilliseconds > frame.durationMilliseconds ||
        (frame.isDistance && cursor.remainingMilliseconds != 0) ||
        (cursor.isFinished &&
            (_frameIndex != _frames.length - 1 ||
                cursor.remainingMilliseconds != 0)) ||
        (!cursor.isFinished &&
            !frame.isDistance &&
            cursor.remainingMilliseconds == 0) ||
        (distanceIndex < 0 &&
            (cursor.distanceConfirmed ||
                cursor.distanceElapsedMilliseconds != 0)) ||
        (distanceIndex >= 0 &&
            ((cursor.distanceConfirmed !=
                    (_frameIndex > distanceIndex || cursor.isFinished)) ||
                (_frameIndex < distanceIndex &&
                    cursor.distanceElapsedMilliseconds != 0) ||
                (cursor.distanceConfirmed &&
                    cursor.distanceElapsedMilliseconds == 0)))) {
      throw const StructuredRunningExecutionException(
        'cursor_time_mismatch',
        'The saved running time does not match the pinned workout.',
      );
    }
    if (execution.pauseOnInterruption) {
      _isPaused = true;
      _lastReconciledAtUtc = null;
    }
    if (!_isPaused && !_isFinished) {
      _reconcilePersistedElapsed();
      if (!_isPaused && !_isFinished) {
        _startTicker();
      }
      _checkpoint();
    }
  }

  static final Stopwatch _monotonicClock = Stopwatch()..start();

  static Duration _defaultElapsedTime() => _monotonicClock.elapsed;
  static DateTime _defaultWallClock() => DateTime.now().toUtc();

  final T _execution;
  final List<_StructuredRunningFrame> _frames;
  final StructuredRunningElapsedTime _elapsedTime;
  final StructuredRunningWallClock _wallClock;
  final void Function(StructuredRunningCursor cursor)? onCheckpoint;
  int _frameIndex;
  int _remainingMilliseconds;
  bool _isPaused;
  StructuredRunningManualEvidenceState _manualEvidenceState;
  bool _isFinished;
  int _distanceElapsedMilliseconds;
  bool _distanceConfirmed;
  Timer? _timer;
  Duration? _lastRunningAt;
  DateTime? _lastReconciledAtUtc;
  bool _isBackgrounded = false;

  T get execution => _execution;
  bool get isDistanceStep => _frames[_frameIndex].isDistance;
  int get stepIndex => _frameIndex;
  int get totalSteps => _frames.length;
  RunningAtomicStep? get nextStep =>
      _frameIndex + 1 < _frames.length ? _frames[_frameIndex + 1].step : null;
  StructuredRunningCursor get cursor {
    final frame = _frames[_frameIndex];
    return StructuredRunningCursor(
      schemaVersion: StructuredRunningCursor.currentSchemaVersion,
      workoutId: _execution.workout.workoutId,
      executionMappingSha256: _execution.executionMappingSha256,
      sessionBlockId: _execution.sessionBlockId,
      authoredStepId: frame.step.stepId,
      repeatOrdinal: frame.repeatOrdinal,
      phase: frame.phase,
      remainingMilliseconds: _remainingMilliseconds,
      isPaused: _isPaused,
      manualEvidenceState: _manualEvidenceState,
      isFinished: _isFinished,
      lastReconciledAtUtc: _lastReconciledAtUtc,
      distanceElapsedMilliseconds: _distanceElapsedMilliseconds,
      distanceConfirmed: _distanceConfirmed,
    );
  }

  void start() {
    if (_isFinished || !_isPaused) return;
    _startTicker();
    _checkpoint();
  }

  void pause() => _pause();

  void background() {
    if (_execution.pauseOnInterruption) {
      _pause();
      return;
    }
    if (_isBackgrounded) return;
    if (!_isPaused && !_isFinished) {
      _consumeClockElapsed();
      _timer?.cancel();
      _timer = null;
      _isBackgrounded = true;
    }
    _checkpoint();
  }

  void resumeFromBackground() {
    if (!_isBackgrounded) return;
    _isBackgrounded = false;
    if (_isPaused || _isFinished) return;
    _consumeClockElapsed();
    if (!_isFinished) {
      _startTicker();
    }
    _checkpoint();
  }

  void exit({bool emitCheckpoint = true}) =>
      _pause(emitCheckpoint: emitCheckpoint);

  void _pause({bool emitCheckpoint = true}) {
    if (_isFinished) return;
    if (!_isPaused) {
      _consumeClockElapsed();
    }
    _isPaused = true;
    _timer?.cancel();
    _timer = null;
    _lastRunningAt = null;
    _lastReconciledAtUtc = null;
    _isBackgrounded = false;
    if (emitCheckpoint) {
      _checkpoint();
    }
  }

  void markManualEvidenceCaptured() {
    _manualEvidenceState = StructuredRunningManualEvidenceState.captured;
    _checkpoint();
  }

  void elapse(Duration duration) {
    if (_isPaused || _isFinished || duration <= Duration.zero) return;
    _advance(duration);
    _lastRunningAt = _elapsedTime();
    if (!_isPaused && !_isFinished) {
      _lastReconciledAtUtc = _utcNow();
    }
    _checkpoint();
  }

  /// Athlete acknowledgement only. Never creates performance actuals.
  void confirmDistanceStep() {
    if (!isDistanceStep || _isFinished) {
      throw StateError('There is no distance step awaiting confirmation.');
    }
    _pause(emitCheckpoint: false);
    if (_distanceElapsedMilliseconds <= 0) {
      throw StateError('Start the distance step before confirming it.');
    }
    _distanceConfirmed = true;
    if (_frameIndex == _frames.length - 1) {
      _isFinished = true;
    } else {
      _frameIndex++;
      _remainingMilliseconds = _frames[_frameIndex].durationMilliseconds;
      _manualEvidenceState = StructuredRunningManualEvidenceState.notCaptured;
    }
    _checkpoint();
  }

  void _advance(Duration duration) {
    var elapsed = duration.inMilliseconds;
    while (elapsed > 0 && !_isFinished) {
      if (isDistanceStep) {
        _distanceElapsedMilliseconds += elapsed;
        return;
      }
      if (elapsed < _remainingMilliseconds) {
        _remainingMilliseconds -= elapsed;
        elapsed = 0;
      } else {
        elapsed -= _remainingMilliseconds;
        if (_frameIndex == _frames.length - 1) {
          _remainingMilliseconds = 0;
          _isFinished = true;
          _isPaused = true;
          _timer?.cancel();
          _timer = null;
          _lastRunningAt = null;
          _lastReconciledAtUtc = null;
          _isBackgrounded = false;
        } else {
          _frameIndex++;
          _remainingMilliseconds = _frames[_frameIndex].durationMilliseconds;
          _manualEvidenceState =
              StructuredRunningManualEvidenceState.notCaptured;
          // Do not silently start a measured test, or carry preparation overshoot
          // into its active timer. The athlete explicitly starts the distance step.
          if (isDistanceStep) {
            _isPaused = true;
            _timer?.cancel();
            _timer = null;
            _lastRunningAt = null;
            _lastReconciledAtUtc = null;
            return;
          }
        }
      }
    }
  }

  void _startTicker() {
    _isPaused = false;
    _isBackgrounded = false;
    _lastRunningAt = _elapsedTime();
    _lastReconciledAtUtc = _utcNow();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _consumeClockElapsed(minimum: const Duration(seconds: 1));
      _checkpoint();
    });
  }

  void _consumeClockElapsed({Duration minimum = Duration.zero}) {
    if (_isPaused || _isFinished) return;
    final now = _elapsedTime();
    final previous = _lastRunningAt ?? now;
    _lastRunningAt = now;
    final measured = now - previous;
    final elapsed = measured < minimum ? minimum : measured;
    if (elapsed > Duration.zero) {
      _advance(elapsed);
    }
    if (!_isPaused && !_isFinished) {
      _lastReconciledAtUtc = _utcNow();
    }
  }

  void _reconcilePersistedElapsed() {
    final anchor = _lastReconciledAtUtc;
    if (anchor == null) {
      _isPaused = true;
      return;
    }
    final now = _utcNow();
    if (now.isBefore(anchor)) {
      // A backward wall-clock change cannot be converted into trustworthy
      // workout time. Preserve the saved position and require explicit Start.
      _isPaused = true;
      _lastReconciledAtUtc = null;
      return;
    }
    _advance(now.difference(anchor));
    if (!_isPaused && !_isFinished) {
      _lastReconciledAtUtc = now;
    }
  }

  DateTime _utcNow() => _wallClock().toUtc();

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lastRunningAt = null;
    _isBackgrounded = false;
  }

  void _checkpoint() => onCheckpoint?.call(cursor);

  static int _restoreIndex(
    TimedRunningExecution execution,
    StructuredRunningCursor cursor,
  ) {
    if (cursor.workoutId != execution.workout.workoutId ||
        cursor.executionMappingSha256 != execution.executionMappingSha256 ||
        cursor.sessionBlockId != execution.sessionBlockId) {
      throw const StructuredRunningExecutionException(
        'cursor_authority_mismatch',
        'The saved running cursor does not match launch authority.',
      );
    }
    final frames = _flatten(execution);
    final matches = <int>[];
    for (var index = 0; index < frames.length; index++) {
      final frame = frames[index];
      if (frame.step.stepId == cursor.authoredStepId &&
          frame.repeatOrdinal == cursor.repeatOrdinal &&
          frame.phase == cursor.phase) {
        matches.add(index);
      }
    }
    if (matches.length != 1) {
      throw const StructuredRunningExecutionException(
        'cursor_step_mismatch',
        'The saved running position does not match the pinned workout.',
      );
    }
    return matches.single;
  }

  static List<_StructuredRunningFrame> _flatten(
    TimedRunningExecution execution,
  ) {
    final frames = <_StructuredRunningFrame>[];
    for (final node in execution.workout.steps) {
      switch (node) {
        case RunningAtomicStep():
          frames.add(
            _frame(node, 1, allowDistance: execution.pauseOnInterruption),
          );
        case RunningRepeatGroup():
          for (var ordinal = 1; ordinal <= node.count; ordinal++) {
            for (final step in node.steps) {
              frames.add(_frame(step, ordinal));
            }
          }
      }
    }
    if (frames.isEmpty) {
      throw const StructuredRunningExecutionException(
        'empty_workout',
        'The pinned running workout has no executable steps.',
      );
    }
    if (frames.where((f) => f.isDistance).length > 1) {
      throw const StructuredRunningExecutionException(
        'unsupported_duration',
        'Only one distance work step is supported.',
      );
    }
    return List.unmodifiable(frames);
  }

  static _StructuredRunningFrame _frame(
    RunningAtomicStep step,
    int repeatOrdinal, {
    bool allowDistance = false,
  }) {
    final distance =
        allowDistance &&
        step.duration.kind == RunningDurationKind.distance &&
        step.duration.millimetres == 10000000 &&
        step.role == RunningStepRole.work;
    final milliseconds = distance ? 0 : step.duration.milliseconds;
    if (!distance &&
        (step.duration.kind != RunningDurationKind.time ||
            milliseconds == null ||
            milliseconds <= 0)) {
      throw const StructuredRunningExecutionException(
        'unsupported_duration',
        'B3 slice 2 supports positive time-based steps only.',
      );
    }
    return _StructuredRunningFrame(
      step: step,
      repeatOrdinal: repeatOrdinal,
      phase:
          step.role == RunningStepRole.recovery ||
              step.role == RunningStepRole.rest
          ? StructuredRunningPhase.recovery
          : StructuredRunningPhase.work,
      durationMilliseconds: milliseconds!,
    );
  }
}

class _StructuredRunningFrame {
  const _StructuredRunningFrame({
    required this.step,
    required this.repeatOrdinal,
    required this.phase,
    required this.durationMilliseconds,
  });

  final RunningAtomicStep step;
  final int repeatOrdinal;
  final StructuredRunningPhase phase;
  final int durationMilliseconds;
  bool get isDistance => step.duration.kind == RunningDurationKind.distance;
}
