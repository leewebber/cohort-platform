import 'package:flutter/material.dart';

import '../../../core/accessibility/journey_interaction.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../models/authored_station_target_formatter.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../presentation/daily_journey_accessibility.dart';
import '../services/block_timer_controller.dart';

class BlockTimerScreen extends StatefulWidget {
  const BlockTimerScreen({
    super.key,
    required this.blockTitle,
    required this.format,
    required this.configuration,
    this.initialState,
    this.stationLabels = const {},
    this.prescriptionLines = const [],
    this.restoredWorkNote,
    this.onCheckpoint,
  });

  final String blockTitle;
  final WorkoutFormat format;
  final TimerConfiguration configuration;
  final BlockTimerState? initialState;
  final Map<String, String> stationLabels;
  final List<String> prescriptionLines;
  final String? restoredWorkNote;
  final ValueChanged<BlockTimerState>? onCheckpoint;

  @override
  State<BlockTimerScreen> createState() => _BlockTimerScreenState();
}

class _BlockTimerScreenState extends State<BlockTimerScreen>
    with WidgetsBindingObserver {
  BlockTimerController? _controller;
  BlockTimerState? _state;
  String? _announcement;

  @override
  void initState() {
    super.initState();
    _controller = BlockTimerController(
      format: widget.format,
      configuration: widget.configuration,
      stationLabels: widget.stationLabels,
      onStateChanged: (state) {
        final previousRound = _state?.currentRound;
        final justFinished = state.isFinished && _state?.isFinished != true;
        final wasPaused = _state?.isPaused;
        setState(() => _state = state);
        if (wasPaused == false && state.isPaused) {
          _announce(
            '${widget.format.displayLabel} timer paused. ${_timeSummary(state)}',
          );
        } else if (wasPaused == true && !state.isPaused && !state.isFinished) {
          _announce(
            '${widget.format.displayLabel} timer resumed. ${_timeSummary(state)}',
          );
        }
        if (previousRound != null && previousRound != state.currentRound) {
          widget.onCheckpoint?.call(state);
        }
        if (justFinished) {
          widget.onCheckpoint?.call(state);
          _announce(
            '${widget.format.displayLabel} block completed. ${_timeSummary(state)}',
          );
          if (widget.format == WorkoutFormat.emom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context, state);
            });
          }
        }
      },
    );
    final restored = widget.initialState;
    if (restored != null) {
      _controller!.restore(restored);
      _announcement =
          '${widget.format.displayLabel} timer restored, '
          '${restored.isPaused ? 'paused' : 'running'}. '
          '${_timeSummary(restored)}';
    } else {
      _controller!.start();
    }
    _state = _controller!.state;
    WidgetsBinding.instance.addObserver(this);
  }

  void _announce(String message) {
    setState(() => _announcement = message);
  }

  String _timeSummary(BlockTimerState state) {
    final clock = _formatTime(state.primarySeconds);
    if (widget.format == WorkoutFormat.forTime) {
      return 'Elapsed $clock';
    }
    return 'Time remaining $clock';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      final current = _controller?.state;
      if (current != null) {
        _controller?.pause();
        widget.onCheckpoint?.call(_controller?.state ?? current);
      }
    }
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              JourneyMinTap(
                child: TextButton(
                  onPressed: _confirmExit,
                  child: const Text('Back to block'),
                ),
              ),
              JourneyAnnouncement(message: _announcement),
              const SizedBox(height: CohortSpacing.md),
              Text(widget.blockTitle, style: CohortTextStyles.h2),
              Text(widget.format.displayLabel, style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.md),
              if (state != null) ...[
                Text(state.phaseLabel, style: CohortTextStyles.body),
                const SizedBox(height: CohortSpacing.sm),
                if (state.totalRounds > 1)
                  Text(
                    widget.format == WorkoutFormat.emom
                        ? 'MINUTE ${state.currentRound} OF ${state.totalRounds}'
                        : 'ROUND ${state.currentRound} OF ${state.totalRounds}',
                    key: const ValueKey('block-timer-position'),
                    style: CohortTextStyles.eyebrow,
                  ),
                if (state.currentStationLabel != null) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    state.currentStationLabel!.toUpperCase(),
                    key: const ValueKey('block-timer-current-station'),
                    style: CohortTextStyles.h2,
                  ),
                ],
                if (state.currentStationTarget != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    state.currentStationTarget!.toUpperCase(),
                    key: const ValueKey('block-timer-current-target'),
                    style: CohortTextStyles.cardTitle,
                  ),
                ],
                const SizedBox(height: CohortSpacing.md),
                ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatTime(state.primarySeconds),
                      key: const ValueKey('block-timer-clock'),
                      style: CohortTextStyles.h1.copyWith(fontSize: 64),
                    ),
                  ),
                ),
                if (AuthoredStationTargetFormatter.nextStationLine(
                      label: state.nextStationLabel,
                      target: state.nextStationTarget,
                    )
                    case final next?) ...[
                  const SizedBox(height: CohortSpacing.md),
                  Text(
                    next,
                    key: const ValueKey('block-timer-next-station'),
                    style: CohortTextStyles.small.copyWith(
                      color: CohortColors.textSecondary,
                    ),
                  ),
                ],
                Semantics(
                  container: true,
                  liveRegion: false,
                  label: [
                    '${widget.format.displayLabel} timer',
                    state.isPaused ? 'Paused' : 'Running',
                    if (state.totalRounds > 1)
                      widget.format == WorkoutFormat.emom
                          ? 'Minute ${state.currentRound} of ${state.totalRounds}'
                          : 'Round ${state.currentRound} of ${state.totalRounds}',
                    if (state.currentStationLabel != null)
                      state.currentStationLabel,
                    if (state.currentStationTarget != null)
                      'Target ${state.currentStationTarget}',
                    _timeSummary(state),
                    ?AuthoredStationTargetFormatter.nextStationLine(
                      label: state.nextStationLabel,
                      target: state.nextStationTarget,
                    ),
                  ].join('. '),
                ),
              ],
              const SizedBox(height: CohortSpacing.xl),
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
              if (widget.format == WorkoutFormat.emom &&
                  state?.isFinished != true)
                Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
                  child: CohortButton(
                    label: 'End early',
                    variant: CohortButtonVariant.secondary,
                    onPressed: () {
                      _controller?.pause();
                      Navigator.pop(context, _controller?.state);
                    },
                  ),
                ),
              if (widget.format == WorkoutFormat.emom &&
                  state?.isFinished == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
                  child: CohortButton(
                    label: 'Record result',
                    onPressed: () => Navigator.pop(context, _controller?.state),
                  ),
                ),
              if (widget.format == WorkoutFormat.forTime &&
                  state?.isFinished != true)
                Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
                  child: CohortButton(
                    label: 'Record time',
                    onPressed: () {
                      _controller?.pause();
                      Navigator.pop(context, _controller?.state);
                    },
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: CohortButton(
                      label: state?.isPaused == true ? 'Resume' : 'Pause',
                      semanticLabel: state?.isPaused == true
                          ? 'Resume ${widget.format.displayLabel} timer'
                          : 'Pause ${widget.format.displayLabel} timer',
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
                      semanticLabel: 'Reset ${widget.format.displayLabel} timer',
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
              if (widget.prescriptionLines.isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.lg),
                for (final line in widget.prescriptionLines)
                  Text(line, style: CohortTextStyles.body),
              ],
              if (widget.restoredWorkNote?.trim().isNotEmpty == true) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  widget.restoredWorkNote!,
                  key: const ValueKey('block-timer-restored-work'),
                  style: CohortTextStyles.body,
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
