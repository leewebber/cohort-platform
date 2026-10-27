import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/running_workout/running_workout.dart';
import '../models/structured_running_execution.dart';
import '../services/structured_running_controller.dart';

class StructuredRunningTimerScreen extends StatefulWidget {
  const StructuredRunningTimerScreen({
    super.key,
    required this.execution,
    required this.onCheckpoint,
    this.initialCursor,
    this.elapsedTime,
    this.wallClock,
  });

  final TimedRunningExecution execution;
  final StructuredRunningCursor? initialCursor;
  final Future<bool> Function(StructuredRunningCursor cursor) onCheckpoint;
  final StructuredRunningElapsedTime? elapsedTime;
  final StructuredRunningWallClock? wallClock;

  @override
  State<StructuredRunningTimerScreen> createState() =>
      _StructuredRunningTimerScreenState();
}

class _StructuredRunningTimerScreenState
    extends State<StructuredRunningTimerScreen>
    with WidgetsBindingObserver {
  late final StructuredRunningController _controller;
  bool _isExiting = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    void checkpoint(StructuredRunningCursor cursor) {
      if (mounted) setState(() {});
      if (!_saveFailed) unawaited(_saveCheckpoint(cursor));
    }

    final initial = widget.initialCursor;
    _controller = initial == null
        ? StructuredRunningController.fresh(
            execution: widget.execution,
            onCheckpoint: checkpoint,
            elapsedTime: widget.elapsedTime,
            wallClock: widget.wallClock,
          )
        : StructuredRunningController.restore(
            execution: widget.execution,
            cursor: initial,
            onCheckpoint: checkpoint,
            elapsedTime: widget.elapsedTime,
            wallClock: widget.wallClock,
          );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _controller.background();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _controller.resumeFromBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCheckpoint(StructuredRunningCursor cursor) async {
    bool saved;
    try {
      saved = await widget.onCheckpoint(cursor);
    } catch (_) {
      saved = false;
    }
    if (!mounted || saved || !widget.execution.pauseOnInterruption) return;
    setState(() => _saveFailed = true);
    _controller.pause();
  }

  Future<void> _retrySave() async {
    bool saved;
    try {
      saved = await widget.onCheckpoint(_controller.cursor);
    } catch (_) {
      saved = false;
    }
    if (mounted) setState(() => _saveFailed = !saved);
  }

  Future<void> _exit() async {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    _controller.exit(emitCheckpoint: false);
    bool saved;
    try {
      saved = await widget.onCheckpoint(_controller.cursor);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(_controller.cursor);
      return;
    }
    setState(() => _isExiting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not save the timer. Retry before exiting.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cursor = _controller.cursor;
    final step = widget.execution.stepForCursor(cursor);
    final target = widget.execution.targetsByStepId[step.stepId];
    final seconds = (cursor.remainingMilliseconds / 1000).ceil();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Structured run'),
          leading: IconButton(
            tooltip: 'Exit timer',
            onPressed: _isExiting ? null : _exit,
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minimumHeight = constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0.0;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minimumHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          step.label ?? _roleLabel(step.role),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.execution.pauseOnInterruption
                              ? 'Step ${_controller.stepIndex + 1} of ${_controller.totalSteps} · ${_positionLabel(step.role, cursor.repeatOrdinal)}'
                              : _positionLabel(step.role, cursor.repeatOrdinal),
                          key: const ValueKey('structured-running-position'),
                          textAlign: TextAlign.center,
                        ),
                        if (step.notes case final notes?) ...[
                          const SizedBox(height: 8),
                          Text(notes, textAlign: TextAlign.center),
                        ],
                        if (widget.execution.pauseOnInterruption &&
                            _controller.nextStep != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Next: ${_controller.nextStep!.label ?? _roleLabel(_controller.nextStep!.role)}',
                            key: const ValueKey('structured-running-next'),
                          ),
                        ],
                        if (widget.execution.authoredGuidance
                            case final guidance?) ...[
                          const SizedBox(height: 12),
                          Text(
                            guidance,
                            key: const ValueKey('structured-running-guidance'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 12),
                        ..._targetWidgets(step: step, target: target),
                        const SizedBox(height: 24),
                        Text(
                          cursor.isFinished ? 'Timer finished' : '$seconds s',
                          key: const ValueKey('structured-running-clock'),
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed:
                              cursor.isFinished || _saveFailed || _isExiting
                              ? null
                              : cursor.isPaused
                              ? _controller.start
                              : _controller.pause,
                          child: Text(
                            cursor.isPaused
                                ? (widget.execution.pauseOnInterruption
                                      ? 'Start / resume'
                                      : 'Start')
                                : 'Pause',
                          ),
                        ),
                        if (widget.execution.pauseOnInterruption &&
                            cursor.isPaused &&
                            !cursor.isFinished) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Paused. Start / resume when ready. Time away does not count as training.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_saveFailed) ...[
                          const Text(
                            'Could not save this timer. Keep the app open and retry.',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: _retrySave,
                            child: const Text('Retry saving timer'),
                          ),
                        ],
                        if (cursor.isFinished) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Timer finished. Record evidence before completing the block.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            key: const ValueKey('review-running-repetitions'),
                            onPressed: _isExiting ? null : _exit,
                            child: Text(
                              widget.execution.pauseOnInterruption
                                  ? 'Record run results'
                                  : 'Review repetitions',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _targetWidgets({
    required RunningAtomicStep step,
    required RunningLaunchTarget? target,
  }) {
    if (widget.execution.pauseOnInterruption) {
      return [
        Text(
          _authoredTarget(step.target),
          key: const ValueKey('authored-running-target'),
          textAlign: TextAlign.center,
        ),
      ];
    }
    if (step.role != RunningStepRole.work || target == null) {
      return const [Text('No pace target')];
    }
    if (target.state == RunningLaunchTargetState.intentOnly) {
      return const [
        Text(
          'Pace target unavailable',
          key: ValueKey('structured-running-target-unavailable'),
        ),
        SizedBox(height: 4),
        Text(
          'No eligible recent 5 km benchmark was available when this session started. Follow the authored guidance. Cohort has not estimated a pace.',
          textAlign: TextAlign.center,
        ),
      ];
    }
    final faster = target.fasterDisplayMillisecondsPerKilometre;
    final slower = target.slowerDisplayMillisecondsPerKilometre;
    if (faster == null || slower == null) {
      throw const StructuredRunningExecutionException(
        'missing_calculated_target_range',
        'A calculated running target is missing its frozen pace range.',
      );
    }
    return [
      const Text('Advisory pace target'),
      const SizedBox(height: 4),
      Text(
        '${_formatPace(faster)}–${_formatPace(slower)} /km',
        key: const ValueKey('structured-running-target-range'),
      ),
    ];
  }

  static String _authoredTarget(RunningTarget target) => switch (target.kind) {
    RunningTargetKind.qualityPaceRef => throw const FormatException(
      'Quality target acceptance is required.',
    ),
    RunningTargetKind.none => 'Follow the authored guidance',
    RunningTargetKind.pace =>
      '${_exactPace(target.paceMillisecondsPerKilometre!)} /km',
    RunningTargetKind.paceRange =>
      '${_exactPace(target.paceMillisecondsPerKilometreLow!)}–${_exactPace(target.paceMillisecondsPerKilometreHigh!)} /km',
    RunningTargetKind.heartRate => '${target.heartRateBpm} bpm',
    RunningTargetKind.heartRateRange =>
      '${target.heartRateBpmLow}–${target.heartRateBpmHigh} bpm',
    RunningTargetKind.heartRateZoneRef =>
      'Heart-rate zone: ${target.heartRateZoneRef}\nUse your configured zone. Cohort has not resolved its BPM limits.',
    RunningTargetKind.power => '${target.powerWatts} W',
    RunningTargetKind.powerRange =>
      '${target.powerWattsLow}–${target.powerWattsHigh} W',
    RunningTargetKind.cadenceRange =>
      '${target.cadenceStepsPerMinuteLow}–${target.cadenceStepsPerMinuteHigh} steps/min',
    RunningTargetKind.rpe => 'RPE ${target.rpeCr10}/10',
    RunningTargetKind.rpeRange =>
      'RPE ${target.rpeCr10Low}–${target.rpeCr10High}/10',
  };

  static String _exactPace(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final fraction = ms % 1000;
    return '$minutes:$seconds${fraction == 0 ? '' : '.${fraction.toString().padLeft(3, '0')}'}';
  }

  static String _roleLabel(RunningStepRole role) => switch (role) {
    RunningStepRole.warmUp => 'Warm-up',
    RunningStepRole.work => 'Work',
    RunningStepRole.recovery => 'Recovery',
    RunningStepRole.rest => 'Rest',
    RunningStepRole.coolDown => 'Cool-down',
    RunningStepRole.open => 'Open',
  };

  static String _positionLabel(RunningStepRole role, int repeatOrdinal) =>
      role == RunningStepRole.work
      ? 'Work repetition $repeatOrdinal'
      : '${_roleLabel(role)} · repetition $repeatOrdinal';

  static String _formatPace(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
