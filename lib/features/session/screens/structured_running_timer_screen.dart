import 'dart:async';

import 'package:flutter/material.dart';

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
  final Future<void> Function(StructuredRunningCursor cursor) onCheckpoint;

  @override
  State<StructuredRunningTimerScreen> createState() =>
      _StructuredRunningTimerScreenState();
}

class _StructuredRunningTimerScreenState
    extends State<StructuredRunningTimerScreen>
    with WidgetsBindingObserver {
  late final StructuredRunningController _controller;

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
    _controller.exit();
    await widget.onCheckpoint(_controller.cursor);
    if (mounted) Navigator.of(context).pop(_controller.cursor);
  }

  @override
  Widget build(BuildContext context) {
    final cursor = _controller.cursor;
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
            onPressed: _exit,
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
                    cursor.phase == StructuredRunningPhase.work
                        ? 'Work'
                        : 'Recovery',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${cursor.authoredStepId} · repeat ${cursor.repeatOrdinal}',
                    textAlign: TextAlign.center,
                  ),
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
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
