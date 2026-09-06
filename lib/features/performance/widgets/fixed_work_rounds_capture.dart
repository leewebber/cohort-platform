import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../session/services/fixed_work_rounds_controller.dart';
import '../../session/services/session_wake_lock.dart';
import '../models/circuit_round_actual.dart';
import '../models/performance_result_data.dart';
import 'endurance_duration_field.dart';
import 'performance_numeric_field.dart';

class FixedWorkRoundsCapture extends StatefulWidget {
  const FixedWorkRoundsCapture({
    super.key,
    required this.result,
    required this.onChanged,
    this.readOnly = false,
  });

  final CircuitResultData result;
  final ValueChanged<PerformanceResultData> onChanged;
  final bool readOnly;

  @override
  State<FixedWorkRoundsCapture> createState() => _FixedWorkRoundsCaptureState();
}

class _FixedWorkRoundsCaptureState extends State<FixedWorkRoundsCapture>
    with WidgetsBindingObserver {
  late FixedWorkRoundsController _controller;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = FixedWorkRoundsController(result: widget.result);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant FixedWorkRoundsCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) {
      _controller.hydrate(widget.result);
      _syncTicker();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _emit(_controller.completeRestIfDue());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SessionWakeLock.setEnabled(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    final phase = _controller.phase;
    SessionWakeLock.setEnabled(
      phase == FixedWorkPhase.work || phase == FixedWorkPhase.rest,
    );
    if (phase == FixedWorkPhase.work || phase == FixedWorkPhase.rest) {
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        if (_controller.phase == FixedWorkPhase.rest) {
          _emit(_controller.completeRestIfDue());
        } else {
          setState(() {});
        }
      });
    }
  }

  void _emit(CircuitResultData next) {
    widget.onChanged(next);
    setState(() {});
    _syncTicker();
  }

  String _clock(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  String get _prescriptionLine {
    return widget.result.stations
        .map((row) {
          final work = row.prescribedDistanceMeters != null
              ? '${row.prescribedDistanceMeters!.round()} m'
              : row.prescribedReps != null
              ? '${row.prescribedReps}'
              : '';
          return work.isEmpty ? row.displayName : '${row.displayName} $work';
        })
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final result = _controller.result;
    final phase = _controller.phase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ROUNDS', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.xs),
        Text(_prescriptionLine, style: CohortTextStyles.body),
        if (result.restBetweenRoundsSeconds != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            '${result.restBetweenRoundsSeconds}s recovery between rounds',
            style: CohortTextStyles.small,
          ),
        ],
        if (result.sharedSetup.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.md),
          Text('EQUIPMENT', style: CohortTextStyles.sectionLabel),
          for (final setup in result.sharedSetup)
            PerformanceNumericField(
              key: ValueKey('fixed-work-load-${setup.stationId}'),
              label: '${setup.displayName} load (${setup.loadUnit})',
              value: setup.loadKg?.toString() ?? '',
              allowDecimal: true,
              onChanged: widget.readOnly
                  ? (_) {}
                  : (value) {
                      final parsed = double.tryParse(value);
                      _emit(
                        result.replaceSetup(
                          setup.copyWith(
                            loadKg: parsed,
                            clearLoad: parsed == null,
                          ),
                        ),
                      );
                    },
            ),
        ],
        const SizedBox(height: CohortSpacing.md),
        if (phase == FixedWorkPhase.finished)
          _FinishedSummary(
            result: result,
            clock: _clock,
            readOnly: widget.readOnly,
            onRoundChanged: widget.readOnly
                ? null
                : (round) => _emit(result.replaceRound(round)),
          )
        else if (phase == FixedWorkPhase.rest)
          _RestSurface(
            controller: _controller,
            clock: _clock,
            onSkip: widget.readOnly ? null : () => _emit(_controller.skipRest()),
          )
        else if (phase == FixedWorkPhase.work)
          _WorkSurface(
            controller: _controller,
            clock: _clock,
            prescription: _prescriptionLine,
            onFinish: widget.readOnly
                ? null
                : () => _emit(_controller.finishRound()),
          )
        else
          _ReadySurface(
            controller: _controller,
            prescription: _prescriptionLine,
            onStart: widget.readOnly
                ? null
                : () => _emit(_controller.startRound()),
          ),
        if (!widget.readOnly && phase != FixedWorkPhase.finished) ...[
          const SizedBox(height: CohortSpacing.md),
          TextButton(
            key: const ValueKey('fixed-work-end-early'),
            onPressed: () => _confirmEndEarly(),
            child: const Text('End circuit early'),
          ),
        ],
        const SizedBox(height: CohortSpacing.sm),
        TextFormField(
          key: const ValueKey('fixed-work-note'),
          initialValue: result.note ?? '',
          enabled: !widget.readOnly,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
          ),
          onChanged: widget.readOnly
              ? null
              : (value) => _emit(result.copyWith(note: value.trim().isEmpty ? null : value.trim())),
        ),
      ],
    );
  }

  Future<void> _confirmEndEarly() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        var note = '';
        return AlertDialog(
          title: const Text('End circuit early?'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
            ),
            onChanged: (value) => note = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, note),
              child: const Text('End circuit'),
            ),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;
    _emit(_controller.endEarly(reason: reason.trim().isEmpty ? null : reason.trim()));
  }
}

class _ReadySurface extends StatelessWidget {
  const _ReadySurface({
    required this.controller,
    required this.prescription,
    required this.onStart,
  });

  final FixedWorkRoundsController controller;
  final String prescription;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ROUND ${controller.currentRound} OF ${controller.targetRounds}',
          key: const ValueKey('fixed-work-position'),
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(prescription, style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.md),
        SizedBox(
          height: 64,
          child: CohortButton(
            key: ValueKey('fixed-work-start-${controller.currentRound}'),
            label: 'START ROUND ${controller.currentRound}',
            onPressed: onStart,
          ),
        ),
      ],
    );
  }
}

class _WorkSurface extends StatelessWidget {
  const _WorkSurface({
    required this.controller,
    required this.clock,
    required this.prescription,
    required this.onFinish,
  });

  final FixedWorkRoundsController controller;
  final String Function(int) clock;
  final String prescription;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final seconds = controller.displayedWorkSeconds();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ROUND ${controller.currentRound} OF ${controller.targetRounds}',
          key: const ValueKey('fixed-work-position'),
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Semantics(
          label:
              'Round ${controller.currentRound} of ${controller.targetRounds}. Elapsed ${clock(seconds)}.',
          child: Text(
            clock(seconds),
            key: const ValueKey('fixed-work-clock'),
            style: CohortTextStyles.h1.copyWith(fontSize: 56),
          ),
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(prescription, style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.md),
        SizedBox(
          height: 64,
          child: CohortButton(
            key: ValueKey('fixed-work-finish-${controller.currentRound}'),
            label: 'ROUND ${controller.currentRound} FINISHED',
            onPressed: onFinish,
          ),
        ),
      ],
    );
  }
}

class _RestSurface extends StatelessWidget {
  const _RestSurface({
    required this.controller,
    required this.clock,
    required this.onSkip,
  });

  final FixedWorkRoundsController controller;
  final String Function(int) clock;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final remaining = controller.displayedRestSeconds();
    int? completed;
    for (final round in controller.result.rounds) {
      if (round.ordinal == controller.currentRound) {
        completed = round.elapsedSeconds;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('REST', key: const ValueKey('fixed-work-rest'), style: CohortTextStyles.h2),
        Text(
          'Next: ROUND ${controller.currentRound + 1} OF ${controller.targetRounds}',
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Semantics(
          label:
              'Rest. ${clock(remaining)} remaining. Next round ${controller.currentRound + 1}.',
          child: Text(
            clock(remaining),
            key: const ValueKey('fixed-work-clock'),
            style: CohortTextStyles.h1.copyWith(fontSize: 56),
          ),
        ),
        if (completed != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Round ${controller.currentRound}: ${clock(completed)}',
            style: CohortTextStyles.body,
          ),
        ],
        const SizedBox(height: CohortSpacing.md),
        SizedBox(
          height: 64,
          child: CohortButton(
            key: const ValueKey('fixed-work-skip-rest'),
            label: 'Skip rest',
            variant: CohortButtonVariant.secondary,
            onPressed: onSkip,
          ),
        ),
      ],
    );
  }
}

class _FinishedSummary extends StatelessWidget {
  const _FinishedSummary({
    required this.result,
    required this.clock,
    required this.readOnly,
    this.onRoundChanged,
  });

  final CircuitResultData result;
  final String Function(int) clock;
  final bool readOnly;
  final ValueChanged<CircuitRoundActual>? onRoundChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.endedEarly ? 'Circuit ended early' : 'Circuit complete',
          style: CohortTextStyles.cardTitle,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          '${result.completedRounds}/${result.targetRounds ?? result.rounds.length} rounds',
          style: CohortTextStyles.body,
        ),
        for (final round in result.rounds)
          if (!readOnly &&
              (round.isCompleted ||
                  round.state == CircuitRoundCompletionState.incomplete))
            EnduranceDurationField(
              key: ValueKey('fixed-work-round-${round.ordinal}'),
              label: 'Round ${round.ordinal}',
              durationSeconds: round.elapsedSeconds,
              onDurationSecondsChanged: (value) {
                onRoundChanged?.call(
                  round.copyWith(
                    elapsedSeconds: value,
                    state: value == null
                        ? CircuitRoundCompletionState.incomplete
                        : CircuitRoundCompletionState.completed,
                    clearElapsed: value == null,
                  ),
                );
              },
            )
          else
            Text(
              round.isCompleted
                  ? 'Round ${round.ordinal}: ${clock(round.elapsedSeconds!)}'
                  : 'Round ${round.ordinal}: incomplete',
              style: CohortTextStyles.body,
            ),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          'Finish Session remains available for RPE and notes.',
          style: CohortTextStyles.small,
        ),
      ],
    );
  }
}
