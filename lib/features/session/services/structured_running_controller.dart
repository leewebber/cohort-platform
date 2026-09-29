import 'dart:async';

import '../../../domain/running_workout/running_workout.dart';
import '../models/structured_running_execution.dart';

typedef StructuredRunningElapsedTime = Duration Function();

class StructuredRunningController {
  StructuredRunningController.fresh({
    required VerifiedStructuredRunningExecution execution,
    this.onCheckpoint,
    StructuredRunningElapsedTime? elapsedTime,
  }) : _execution = execution,
       _frames = _flatten(execution.workout),
       _elapsedTime = elapsedTime ?? _defaultElapsedTime,
       _frameIndex = 0,
       _remainingMilliseconds = _flatten(
         execution.workout,
       ).first.durationMilliseconds,
       _isPaused = true,
       _manualEvidenceState = StructuredRunningManualEvidenceState.notCaptured,
       _isFinished = false;

  StructuredRunningController.restore({
    required VerifiedStructuredRunningExecution execution,
    required StructuredRunningCursor cursor,
    this.onCheckpoint,
    StructuredRunningElapsedTime? elapsedTime,
  }) : _execution = execution,
       _frames = _flatten(execution.workout),
       _elapsedTime = elapsedTime ?? _defaultElapsedTime,
       _frameIndex = _restoreIndex(execution, cursor),
       _remainingMilliseconds = cursor.remainingMilliseconds,
       _isPaused = cursor.isPaused,
       _manualEvidenceState = cursor.manualEvidenceState,
       _isFinished = cursor.isFinished {
    final frame = _frames[_frameIndex];
    if (cursor.remainingMilliseconds > frame.durationMilliseconds ||
        (cursor.isFinished &&
            (_frameIndex != _frames.length - 1 ||
                cursor.remainingMilliseconds != 0)) ||
        (!cursor.isFinished && cursor.remainingMilliseconds == 0)) {
      throw const StructuredRunningExecutionException(
        'cursor_time_mismatch',
        'The saved running time does not match the pinned workout.',
      );
    }
    if (!_isPaused && !_isFinished) {
      _startTicker();
    }
  }

  static final Stopwatch _monotonicClock = Stopwatch()..start();

  static Duration _defaultElapsedTime() => _monotonicClock.elapsed;

  final VerifiedStructuredRunningExecution _execution;
  final List<_StructuredRunningFrame> _frames;
  final StructuredRunningElapsedTime _elapsedTime;
  final void Function(StructuredRunningCursor cursor)? onCheckpoint;
  int _frameIndex;
  int _remainingMilliseconds;
  bool _isPaused;
  StructuredRunningManualEvidenceState _manualEvidenceState;
  bool _isFinished;
  Timer? _timer;
  Duration? _lastRunningAt;

  VerifiedStructuredRunningExecution get execution => _execution;
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
    );
  }

  void start() {
    if (_isFinished || !_isPaused) return;
    _startTicker();
    _checkpoint();
  }

  void pause() => _pause();

  void background() => _pause();

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
    _checkpoint();
  }

  void _advance(Duration duration) {
    var elapsed = duration.inMilliseconds;
    while (elapsed > 0 && !_isFinished) {
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
        } else {
          _frameIndex++;
          _remainingMilliseconds = _frames[_frameIndex].durationMilliseconds;
          _manualEvidenceState =
              StructuredRunningManualEvidenceState.notCaptured;
        }
      }
    }
  }

  void _startTicker() {
    _isPaused = false;
    _lastRunningAt = _elapsedTime();
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
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lastRunningAt = null;
  }

  void _checkpoint() => onCheckpoint?.call(cursor);

  static int _restoreIndex(
    VerifiedStructuredRunningExecution execution,
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
    final frames = _flatten(execution.workout);
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

  static List<_StructuredRunningFrame> _flatten(RunningWorkout workout) {
    final frames = <_StructuredRunningFrame>[];
    for (final node in workout.steps) {
      switch (node) {
        case RunningAtomicStep():
          frames.add(_frame(node, 1));
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
    return List.unmodifiable(frames);
  }

  static _StructuredRunningFrame _frame(
    RunningAtomicStep step,
    int repeatOrdinal,
  ) {
    final milliseconds = step.duration.milliseconds;
    if (step.duration.kind != RunningDurationKind.time ||
        milliseconds == null ||
        milliseconds <= 0) {
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
      durationMilliseconds: milliseconds,
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
}
