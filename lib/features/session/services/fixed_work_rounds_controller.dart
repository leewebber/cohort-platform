import '../../performance/models/circuit_round_actual.dart';
import '../../performance/models/circuit_station_actual.dart';
import '../../performance/models/performance_result_data.dart';

/// Wall-clock phases for fixed-work rounds.
///
/// Rest never starts the next work interval automatically.
enum FixedWorkPhase { ready, work, rest, finished }

class FixedWorkRoundsController {
  factory FixedWorkRoundsController({
    required CircuitResultData result,
    DateTime Function()? now,
  }) {
    return FixedWorkRoundsController._(result, now ?? DateTime.now);
  }

  FixedWorkRoundsController._(this._result, this._now);

  final DateTime Function() _now;
  CircuitResultData _result;

  CircuitResultData get result => _result;

  FixedWorkPhase get phase {
    return switch (_result.timerCursor?.phase) {
      'work' => FixedWorkPhase.work,
      'rest' => FixedWorkPhase.rest,
      'finished' => FixedWorkPhase.finished,
      _ => FixedWorkPhase.ready,
    };
  }

  int get currentRound => _result.timerCursor?.currentRound ?? 1;

  int get targetRounds =>
      _result.targetRounds ??
      (_result.rounds.isEmpty ? 1 : _result.rounds.length);

  int get restSeconds => _result.restBetweenRoundsSeconds ?? 0;

  int get startOrdinal {
    final current = _round(currentRound);
    if (current != null &&
        current.state == CircuitRoundCompletionState.pending) {
      return currentRound;
    }
    return firstPendingOrdinal ?? currentRound;
  }

  int? get firstPendingOrdinal {
    for (final round in _result.rounds) {
      if (round.state == CircuitRoundCompletionState.pending) {
        return round.ordinal;
      }
    }
    return null;
  }

  bool get canStartCurrentRound {
    if (phase != FixedWorkPhase.ready || _result.endedEarly) return false;
    final round = _round(startOrdinal);
    return round != null &&
        round.state == CircuitRoundCompletionState.pending;
  }

  bool get canFinishCurrentRound {
    if (phase != FixedWorkPhase.work) return false;
    final round = _round(currentRound);
    return round != null &&
        round.state == CircuitRoundCompletionState.pending;
  }

  int displayedWorkSeconds({DateTime? at}) {
    final clock = at ?? _now();
    if (phase == FixedWorkPhase.work) {
      final started = _result.timerCursor?.workStartedAtMs;
      if (started == null) return 0;
      return ((clock.millisecondsSinceEpoch - started) / 1000).floor().clamp(
        0,
        24 * 60 * 60,
      );
    }
    return _round(currentRound)?.elapsedSeconds ?? 0;
  }

  int displayedRestSeconds({DateTime? at}) {
    if (phase != FixedWorkPhase.rest) return 0;
    final started = _result.timerCursor?.restStartedAtMs;
    if (started == null) return restSeconds;
    final clock = at ?? _now();
    final elapsed =
        ((clock.millisecondsSinceEpoch - started) / 1000).floor();
    final remaining = restSeconds - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  CircuitResultData startRound() {
    if (!canStartCurrentRound) return _result;
    final startedAt = _now().millisecondsSinceEpoch;
    final ordinal = startOrdinal;
    _result = _result
        .replaceRound(
          _round(ordinal)!.copyWith(startedAtMs: startedAt),
        )
        .copyWith(
          timerCursor: CircuitTimerCursor(
            currentRound: ordinal,
            currentOrdinal: ordinal,
            remainingSeconds: 0,
            phase: 'work',
            isRunning: true,
            workStartedAtMs: startedAt,
          ),
        );
    return _result;
  }

  CircuitResultData finishRound() {
    if (!canFinishCurrentRound) return _result;
    final finishedAt = _now().millisecondsSinceEpoch;
    final ordinal = currentRound;
    final started = _result.timerCursor?.workStartedAtMs ??
        _round(ordinal)?.startedAtMs ??
        finishedAt;
    final elapsed = ((finishedAt - started) / 1000).floor().clamp(0, 24 * 60 * 60);
    _result = _result.replaceRound(
      _round(ordinal)!.copyWith(
        elapsedSeconds: elapsed,
        state: CircuitRoundCompletionState.completed,
        startedAtMs: started,
        finishedAtMs: finishedAt,
      ),
    );
    if (ordinal >= targetRounds) {
      _result = _result.copyWith(
        timerCursor: CircuitTimerCursor(
          currentRound: ordinal,
          currentOrdinal: ordinal,
          remainingSeconds: elapsed,
          phase: 'finished',
          isFinished: true,
          workStartedAtMs: started,
        ),
      );
      return _result;
    }
    if (restSeconds <= 0) {
      _result = _result.copyWith(
        timerCursor: CircuitTimerCursor(
          currentRound: ordinal + 1,
          currentOrdinal: ordinal + 1,
          remainingSeconds: 0,
          phase: 'ready',
        ),
      );
      return _result;
    }
    _result = _result.copyWith(
      timerCursor: CircuitTimerCursor(
        currentRound: ordinal,
        currentOrdinal: ordinal,
        remainingSeconds: restSeconds,
        phase: 'rest',
        isRunning: true,
        restStartedAtMs: finishedAt,
      ),
    );
    return _result;
  }

  CircuitResultData recordManualTime(int ordinal, int seconds) {
    final existing = _round(ordinal);
    if (existing == null || seconds < 0) return _result;
    _result = _result.replaceRound(
      existing.copyWith(
        elapsedSeconds: seconds,
        state: CircuitRoundCompletionState.completed,
      ),
    );
    return _alignCursorAfterManual();
  }

  CircuitResultData clearRoundTime(int ordinal) {
    final existing = _round(ordinal);
    if (existing == null) return _result;
    _result = _result.replaceRound(
      existing.copyWith(
        state: CircuitRoundCompletionState.pending,
        clearElapsed: true,
        clearStarted: true,
        clearFinished: true,
      ),
    );
    if (phase == FixedWorkPhase.work || phase == FixedWorkPhase.rest) {
      return _result;
    }
    return _alignCursorAfterManual();
  }

  bool laterRoundsExist(int ordinal) {
    return _result.rounds.any(
      (round) => round.ordinal > ordinal && round.isCompleted,
    );
  }

  CircuitResultData skipRest() => _armNextRound();

  CircuitResultData completeRestIfDue({DateTime? at}) {
    if (phase != FixedWorkPhase.rest) return _result;
    if (displayedRestSeconds(at: at) > 0) return _result;
    return _armNextRound();
  }

  CircuitResultData endEarly({String? reason}) {
    if (phase == FixedWorkPhase.finished && _result.endedEarly) {
      return _result;
    }
    final now = _now().millisecondsSinceEpoch;
    var next = _result;
    if (phase == FixedWorkPhase.work) {
      final ordinal = currentRound;
      final started = next.timerCursor?.workStartedAtMs;
      next = next.replaceRound(
        _round(ordinal)!.copyWith(
          state: CircuitRoundCompletionState.incomplete,
          startedAtMs: started,
          finishedAtMs: now,
          clearElapsed: true,
        ),
      );
    }
    next = next.copyWith(
      rounds: [
        for (final round in next.rounds)
          round.state == CircuitRoundCompletionState.pending
              ? round.copyWith(state: CircuitRoundCompletionState.incomplete)
              : round,
      ],
      endedEarly: true,
      earlyEndReason: reason,
      timerCursor: CircuitTimerCursor(
        currentRound: currentRound,
        currentOrdinal: currentRound,
        remainingSeconds: 0,
        phase: 'finished',
        isFinished: true,
      ),
    );
    _result = next;
    return _result;
  }

  CircuitResultData hydrate(CircuitResultData result) {
    _result = result;
    if (phase == FixedWorkPhase.rest) {
      completeRestIfDue();
    }
    return _result;
  }

  CircuitResultData _alignCursorAfterManual() {
    final pending = firstPendingOrdinal;
    if (pending == null) {
      _result = _result.copyWith(
        timerCursor: CircuitTimerCursor(
          currentRound: targetRounds,
          currentOrdinal: targetRounds,
          remainingSeconds: 0,
          phase: 'finished',
          isFinished: true,
        ),
      );
      return _result;
    }
    if (phase == FixedWorkPhase.rest) return _result;
    if (phase == FixedWorkPhase.work) {
      final working = _round(currentRound);
      if (working == null ||
          working.state == CircuitRoundCompletionState.pending) {
        return _result;
      }
    }
    _result = _result.copyWith(
      timerCursor: CircuitTimerCursor(
        currentRound: pending,
        currentOrdinal: pending,
        remainingSeconds: 0,
        phase: 'ready',
      ),
    );
    return _result;
  }

  CircuitResultData _armNextRound() {
    if (phase != FixedWorkPhase.rest && phase != FixedWorkPhase.ready) {
      return _result;
    }
    final nextRound = currentRound + (phase == FixedWorkPhase.rest ? 1 : 0);
    if (nextRound > targetRounds) {
      _result = _result.copyWith(
        timerCursor: CircuitTimerCursor(
          currentRound: targetRounds,
          currentOrdinal: targetRounds,
          remainingSeconds: 0,
          phase: 'finished',
          isFinished: true,
        ),
      );
      return _result;
    }
    _result = _result.copyWith(
      timerCursor: CircuitTimerCursor(
        currentRound: nextRound,
        currentOrdinal: nextRound,
        remainingSeconds: 0,
        phase: 'ready',
      ),
    );
    return _result;
  }

  CircuitRoundActual? _round(int ordinal) {
    for (final round in _result.rounds) {
      if (round.ordinal == ordinal) return round;
    }
    return null;
  }
}
