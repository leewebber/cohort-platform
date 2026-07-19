import 'dart:async';

import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';

enum BlockTimerPhase {
  preparation,
  work,
  rest,
  countdown,
  stopwatch,
}

class BlockTimerState {
  const BlockTimerState({
    required this.format,
    required this.phase,
    required this.isRunning,
    required this.isPaused,
    required this.isFinished,
    required this.primarySeconds,
    this.secondarySeconds,
    this.currentRound = 1,
    this.totalRounds = 1,
    this.phaseLabel = 'Timer',
  });

  final WorkoutFormat format;
  final BlockTimerPhase phase;
  final bool isRunning;
  final bool isPaused;
  final bool isFinished;
  final int primarySeconds;
  final int? secondarySeconds;
  final int currentRound;
  final int totalRounds;
  final String phaseLabel;

  BlockTimerState copyWith({
    BlockTimerPhase? phase,
    bool? isRunning,
    bool? isPaused,
    bool? isFinished,
    int? primarySeconds,
    int? secondarySeconds,
    int? currentRound,
    int? totalRounds,
    String? phaseLabel,
  }) {
    return BlockTimerState(
      format: format,
      phase: phase ?? this.phase,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isFinished: isFinished ?? this.isFinished,
      primarySeconds: primarySeconds ?? this.primarySeconds,
      secondarySeconds: secondarySeconds,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      phaseLabel: phaseLabel ?? this.phaseLabel,
    );
  }
}

class BlockTimerController {
  BlockTimerController({
    required this.format,
    required this.configuration,
    required this.onStateChanged,
  });

  final WorkoutFormat format;
  final TimerConfiguration configuration;
  final void Function(BlockTimerState state) onStateChanged;

  Timer? _timer;
  BlockTimerState? _state;
  int _elapsed = 0;

  BlockTimerState? get state => _state;

  void dispose() {
    _timer?.cancel();
  }

  void start() {
    _timer?.cancel();
    _elapsed = 0;

    _state = switch (format) {
      WorkoutFormat.amrap => BlockTimerState(
          format: format,
          phase: BlockTimerPhase.countdown,
          isRunning: true,
          isPaused: false,
          isFinished: false,
          primarySeconds: configuration.durationSeconds ?? 0,
          phaseLabel: 'AMRAP',
        ),
      WorkoutFormat.emom => BlockTimerState(
          format: format,
          phase: configuration.preparationSeconds != null
              ? BlockTimerPhase.preparation
              : BlockTimerPhase.countdown,
          isRunning: true,
          isPaused: false,
          isFinished: false,
          primarySeconds: configuration.preparationSeconds ??
              configuration.intervalSeconds ??
              60,
          secondarySeconds: configuration.totalDurationSeconds,
          totalRounds: _emomIntervals(),
          phaseLabel: configuration.preparationSeconds != null
              ? 'Prepare'
              : 'EMOM',
        ),
      WorkoutFormat.forTime => BlockTimerState(
          format: format,
          phase: BlockTimerPhase.stopwatch,
          isRunning: true,
          isPaused: false,
          isFinished: false,
          primarySeconds: 0,
          secondarySeconds: configuration.timeCapSeconds,
          phaseLabel: 'For Time',
        ),
      WorkoutFormat.intervals || WorkoutFormat.tabata => BlockTimerState(
          format: format,
          phase: configuration.preparationSeconds != null
              ? BlockTimerPhase.preparation
              : BlockTimerPhase.work,
          isRunning: true,
          isPaused: false,
          isFinished: false,
          primarySeconds: configuration.preparationSeconds ??
              configuration.workSeconds ??
              (format == WorkoutFormat.tabata ? 20 : 30),
          currentRound: 1,
          totalRounds: configuration.rounds ??
              (format == WorkoutFormat.tabata ? 8 : 1),
          phaseLabel: configuration.preparationSeconds != null
              ? 'Prepare'
              : 'Work',
        ),
      WorkoutFormat.rounds => BlockTimerState(
          format: format,
          phase: BlockTimerPhase.countdown,
          isRunning: false,
          isPaused: false,
          isFinished: false,
          primarySeconds: configuration.restBetweenRoundsSeconds ?? 0,
          currentRound: 1,
          totalRounds: configuration.targetRounds ?? 1,
          phaseLabel: 'Round 1',
        ),
      WorkoutFormat.other => BlockTimerState(
          format: format,
          phase: BlockTimerPhase.countdown,
          isRunning: configuration.durationSeconds != null,
          isPaused: false,
          isFinished: configuration.durationSeconds == null,
          primarySeconds: configuration.durationSeconds ?? 0,
          phaseLabel: 'Timer',
        ),
      WorkoutFormat.none => null,
    };

    if (_state == null) return;
    onStateChanged(_state!);
    if (_state!.isRunning) _tick();
  }

  void pause() {
    final current = _state;
    if (current == null || current.isFinished || current.isPaused) return;
    _timer?.cancel();
    _state = current.copyWith(isRunning: false, isPaused: true);
    onStateChanged(_state!);
  }

  void resume() {
    final current = _state;
    if (current == null || current.isFinished || !current.isPaused) return;
    _state = current.copyWith(isRunning: true, isPaused: false);
    onStateChanged(_state!);
    _tick();
  }

  void reset() {
    start();
  }

  int _emomIntervals() {
    final total = configuration.totalDurationSeconds;
    final interval = configuration.intervalSeconds;
    if (total == null || interval == null || interval <= 0) return 1;
    return (total / interval).ceil();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    final current = _state;
    if (current == null || !current.isRunning || current.isFinished) return;

    switch (format) {
      case WorkoutFormat.amrap:
      case WorkoutFormat.other:
        if (current.primarySeconds <= 1) {
          _finish(current);
          return;
        }
        _state = current.copyWith(primarySeconds: current.primarySeconds - 1);
      case WorkoutFormat.forTime:
        _elapsed++;
        final cap = configuration.timeCapSeconds;
        if (cap != null && _elapsed >= cap) {
          _finish(current.copyWith(primarySeconds: cap));
          return;
        }
        _state = current.copyWith(primarySeconds: _elapsed);
      case WorkoutFormat.emom:
        _tickEmom(current);
      case WorkoutFormat.intervals:
      case WorkoutFormat.tabata:
        _tickIntervals(current);
      case WorkoutFormat.rounds:
      case WorkoutFormat.none:
        break;
    }

    if (_state != null) onStateChanged(_state!);
  }

  void _tickEmom(BlockTimerState current) {
    if (current.primarySeconds <= 1) {
      final nextRound = current.currentRound + 1;
      if (nextRound > current.totalRounds) {
        _finish(current);
        return;
      }
      _state = current.copyWith(
        currentRound: nextRound,
        primarySeconds: configuration.intervalSeconds ?? 60,
        phase: BlockTimerPhase.countdown,
        phaseLabel: 'EMOM · Round $nextRound',
      );
      return;
    }
    _state = current.copyWith(primarySeconds: current.primarySeconds - 1);
  }

  void _tickIntervals(BlockTimerState current) {
    if (current.primarySeconds <= 1) {
      if (current.phase == BlockTimerPhase.preparation) {
        _state = current.copyWith(
          phase: BlockTimerPhase.work,
          primarySeconds: configuration.workSeconds ??
              (format == WorkoutFormat.tabata ? 20 : 30),
          phaseLabel: 'Work',
        );
        return;
      }
      if (current.phase == BlockTimerPhase.work) {
        _state = current.copyWith(
          phase: BlockTimerPhase.rest,
          primarySeconds: configuration.restSeconds ??
              (format == WorkoutFormat.tabata ? 10 : 15),
          phaseLabel: 'Rest',
        );
        return;
      }
      final nextRound = current.currentRound + 1;
      if (nextRound > current.totalRounds) {
        _finish(current);
        return;
      }
      _state = current.copyWith(
        currentRound: nextRound,
        phase: BlockTimerPhase.work,
        primarySeconds: configuration.workSeconds ??
            (format == WorkoutFormat.tabata ? 20 : 30),
        phaseLabel: 'Work · Round $nextRound',
      );
      return;
    }
    _state = current.copyWith(primarySeconds: current.primarySeconds - 1);
  }

  void _finish(BlockTimerState current) {
    _timer?.cancel();
    _state = current.copyWith(
      isRunning: false,
      isPaused: false,
      isFinished: true,
      primarySeconds: 0,
      phaseLabel: 'Complete',
    );
    onStateChanged(_state!);
  }
}
