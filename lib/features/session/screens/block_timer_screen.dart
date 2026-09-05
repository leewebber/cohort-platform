import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../services/block_timer_controller.dart';

class BlockTimerScreen extends StatefulWidget {
  const BlockTimerScreen({
    super.key,
    required this.blockTitle,
    required this.format,
    required this.configuration,
    this.initialState,
    this.stationLabels = const {},
  });

  final String blockTitle;
  final WorkoutFormat format;
  final TimerConfiguration configuration;
  final BlockTimerState? initialState;
  final Map<String, String> stationLabels;

  @override
  State<BlockTimerScreen> createState() => _BlockTimerScreenState();
}

class _BlockTimerScreenState extends State<BlockTimerScreen> {
  BlockTimerController? _controller;
  BlockTimerState? _state;

  @override
  void initState() {
    super.initState();
    _controller = BlockTimerController(
      format: widget.format,
      configuration: widget.configuration,
      stationLabels: widget.stationLabels,
      onStateChanged: (state) => setState(() => _state = state),
    );
    final restored = widget.initialState;
    if (restored != null) {
      _controller!.restore(restored);
    } else {
      _controller!.start();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit timer?'),
        content: const Text('Your timer will stay paused when you return.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      _controller?.pause();
      Navigator.pop(context, _controller?.state);
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _controller?.pause();
        Navigator.of(context).pop(_controller?.state);
      },
      child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: _confirmExit,
                child: const Text('← Back to block'),
              ),
              const SizedBox(height: CohortSpacing.md),
              Text(widget.blockTitle, style: CohortTextStyles.h2),
              Text(widget.format.displayLabel, style: CohortTextStyles.eyebrow),
              const Spacer(),
              if (state != null) ...[
                Text(state.phaseLabel, style: CohortTextStyles.body),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  _formatTime(state.primarySeconds),
                  style: CohortTextStyles.h1.copyWith(fontSize: 56),
                ),
                if (state.totalRounds > 1)
                  Text(
                    widget.format == WorkoutFormat.emom
                        ? 'Minute ${state.currentRound} of ${state.totalRounds}'
                        : 'Round ${state.currentRound} of ${state.totalRounds}',
                    style: CohortTextStyles.small,
                  ),
                if (state.currentStationLabel != null) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    'Now ${state.currentStationLabel}',
                    style: CohortTextStyles.body,
                  ),
                ],
                if (state.nextStationLabel != null)
                  Text(
                    'Next ${state.nextStationLabel}',
                    style: CohortTextStyles.small,
                  ),
              ],
              const Spacer(),
              if (widget.format == WorkoutFormat.rounds &&
                  state?.phase == BlockTimerPhase.work &&
                  state?.isFinished != true)
                Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
                  child: CohortButton(
                    label: 'Start recovery',
                    onPressed: () => _controller?.startRecovery(),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: CohortButton(
                      label: state?.isPaused == true ? 'Resume' : 'Pause',
                      onPressed: () {
                        if (state?.isPaused == true) {
                          _controller?.resume();
                        } else {
                          _controller?.pause();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: CohortSpacing.sm),
                  Expanded(
                    child: CohortButton(
                      label: 'Reset',
                      onPressed: () async {
                        final reset = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reset timer?'),
                            content: const Text(
                              'This will restart the timer from the beginning.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        );
                        if (reset == true) _controller?.reset();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
