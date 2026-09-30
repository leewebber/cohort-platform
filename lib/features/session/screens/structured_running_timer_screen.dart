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
  });

  final VerifiedStructuredRunningExecution execution;
  final StructuredRunningCursor? initialCursor;
  final Future<bool> Function(StructuredRunningCursor cursor) onCheckpoint;

  @override
  State<StructuredRunningTimerScreen> createState() =>
      _StructuredRunningTimerScreenState();
}

class _StructuredRunningTimerScreenState
    extends State<StructuredRunningTimerScreen>
    with WidgetsBindingObserver {
  late final StructuredRunningController _controller;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    void checkpoint(StructuredRunningCursor cursor) {
      if (mounted) setState(() {});
      unawaited(widget.onCheckpoint(cursor));
    }

    final initial = widget.initialCursor;
    _controller = initial == null
        ? StructuredRunningController.fresh(
            execution: widget.execution,
            onCheckpoint: checkpoint,
          )
        : StructuredRunningController.restore(
            execution: widget.execution,
            cursor: initial,
            onCheckpoint: checkpoint,
          );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _controller.background();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    _controller.exit(emitCheckpoint: false);
    final saved = await widget.onCheckpoint(_controller.cursor);
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _roleLabel(step.role),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _positionLabel(step.role, cursor.repeatOrdinal),
                    key: const ValueKey('structured-running-position'),
                    textAlign: TextAlign.center,
                  ),
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
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: cursor.isFinished
                        ? null
                        : cursor.isPaused
                        ? _controller.start
                        : _controller.pause,
                    child: Text(cursor.isPaused ? 'Start' : 'Pause'),
                  ),
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
                      child: const Text('Review repetitions'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _targetWidgets({
    required RunningAtomicStep step,
    required RunningLaunchTarget? target,
  }) {
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
