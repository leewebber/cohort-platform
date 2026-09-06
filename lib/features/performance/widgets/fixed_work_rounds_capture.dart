import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/services/fixed_work_rounds_controller.dart';
import '../../session/services/session_wake_lock.dart';
import '../models/circuit_round_actual.dart';
import '../models/circuit_station_actual.dart';
import '../models/performance_result_data.dart';
import 'performance_numeric_field.dart';
import 'round_time_field.dart';

class FixedWorkRoundsCapture extends StatefulWidget {
  const FixedWorkRoundsCapture({
    super.key,
    required this.result,
    required this.onChanged,
    this.readOnly = false,
    this.linkedExercises = const [],
    this.onOpenExercise,
  });

  final CircuitResultData result;
  final ValueChanged<PerformanceResultData> onChanged;
  final bool readOnly;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final ValueChanged<SessionExecutionExerciseSummary>? onOpenExercise;

  @override
  State<FixedWorkRoundsCapture> createState() => _FixedWorkRoundsCaptureState();
}

class _FixedWorkRoundsCaptureState extends State<FixedWorkRoundsCapture>
    with WidgetsBindingObserver {
  late FixedWorkRoundsController _controller;
  Timer? _ticker;
  bool _manualOpen = false;
  bool _noteOpen = false;
  bool _prescriptionVisible = true;
  ScrollPosition? _scrollPosition;
  final GlobalKey _prescriptionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = FixedWorkRoundsController(result: widget.result);
    _syncTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachScroll());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScroll();
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
    _scrollPosition?.removeListener(_updatePrescriptionVisibility);
    _ticker?.cancel();
    SessionWakeLock.setEnabled(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _attachScroll() {
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(next, _scrollPosition)) return;
    _scrollPosition?.removeListener(_updatePrescriptionVisibility);
    _scrollPosition = next;
    _scrollPosition?.addListener(_updatePrescriptionVisibility);
    _updatePrescriptionVisibility();
  }

  void _updatePrescriptionVisibility() {
    final box = _prescriptionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewHeight = MediaQuery.sizeOf(context).height;
    final visible = bottom > 64 && top < viewHeight - 24;
    if (visible == _prescriptionVisible) return;
    setState(() => _prescriptionVisible = visible);
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

  String _stationWork(CircuitStationActual row) {
    if (row.prescribedDistanceMeters != null) {
      return '${row.prescribedDistanceMeters!.round()} m';
    }
    if (row.prescribedReps != null) {
      return '${row.prescribedReps} reps';
    }
    return '';
  }

  SessionExecutionExerciseSummary? _exerciseFor(String stationId) {
    for (final exercise in widget.linkedExercises) {
      if (exercise.exerciseId == stationId) return exercise;
    }
    return null;
  }

  Future<void> _applyManualTime(CircuitRoundActual round, int? seconds) async {
    if (widget.readOnly) return;
    if (seconds == null) {
      if (round.isCompleted && _controller.laterRoundsExist(round.ordinal)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear this round?'),
            content: const Text(
              'Later rounds already have times. This round will be incomplete.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      _emit(_controller.clearRoundTime(round.ordinal));
      return;
    }
    _emit(_controller.recordManualTime(round.ordinal, seconds));
  }

  void _showCircuitSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: _PrescriptionList(
            result: _controller.result,
            workLabel: _stationWork,
            onOpenExercise: widget.onOpenExercise,
            exerciseFor: _exerciseFor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _controller.result;
    final phase = _controller.phase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: _prescriptionKey,
          child: _PrescriptionList(
            result: result,
            workLabel: _stationWork,
            onOpenExercise: widget.onOpenExercise,
            exerciseFor: _exerciseFor,
          ),
        ),
        if (result.sharedSetup.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.md),
          Text('LOADS', style: CohortTextStyles.sectionLabel),
          for (final setup in result.sharedSetup)
            PerformanceNumericField(
              key: ValueKey('fixed-work-load-${setup.stationId}'),
              label: '${setup.displayName} (kg)',
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
        if (!_prescriptionVisible && phase != FixedWorkPhase.finished)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('fixed-work-view-circuit'),
              onPressed: _showCircuitSheet,
              child: const Text('View circuit'),
            ),
          ),
        if (phase == FixedWorkPhase.finished)
          _FinishedSummary(result: result, clock: _clock)
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
            onFinish: widget.readOnly
                ? null
                : () => _emit(_controller.finishRound()),
          )
        else
          _ReadySurface(
            controller: _controller,
            onStart: widget.readOnly
                ? null
                : () => _emit(_controller.startRound()),
          ),
        if (!widget.readOnly && phase != FixedWorkPhase.finished) ...[
          const SizedBox(height: CohortSpacing.sm),
          TextButton(
            key: const ValueKey('fixed-work-manual-toggle'),
            onPressed: () => setState(() => _manualOpen = !_manualOpen),
            child: Text(
              _manualOpen
                  ? 'Hide manual times'
                  : 'Enter round times manually',
            ),
          ),
          if (_manualOpen) _ManualTimes(controller: _controller, onApply: _applyManualTime),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('fixed-work-end-early'),
              style: TextButton.styleFrom(
                foregroundColor: CohortColors.textMuted,
              ),
              onPressed: () => _confirmEndEarly(),
              child: const Text('End circuit early'),
            ),
          ),
        ] else if (!widget.readOnly)
          _ManualTimes(controller: _controller, onApply: _applyManualTime),
        const SizedBox(height: CohortSpacing.xs),
        TextButton(
          key: const ValueKey('fixed-work-note-toggle'),
          onPressed: () => setState(() => _noteOpen = !_noteOpen),
          child: Text(_noteOpen ? 'Hide note' : 'Note (optional)'),
        ),
        if (_noteOpen)
          TextFormField(
            key: const ValueKey('fixed-work-note'),
            initialValue: result.note ?? '',
            enabled: !widget.readOnly,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note',
            ),
            onChanged: widget.readOnly
                ? null
                : (value) => _emit(
                    result.copyWith(
                      note: value.trim().isEmpty ? null : value.trim(),
                    ),
                  ),
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

class _PrescriptionList extends StatelessWidget {
  const _PrescriptionList({
    required this.result,
    required this.workLabel,
    required this.exerciseFor,
    this.onOpenExercise,
  });

  final CircuitResultData result;
  final String Function(CircuitStationActual) workLabel;
  final SessionExecutionExerciseSummary? Function(String) exerciseFor;
  final ValueChanged<SessionExecutionExerciseSummary>? onOpenExercise;

  @override
  Widget build(BuildContext context) {
    final rounds = result.targetRounds ?? result.rounds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('fixed-work-prescription'),
      children: [
        Text('$rounds ROUNDS', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        for (final row in result.stations)
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.displayName,
                    style: CohortTextStyles.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(workLabel(row), style: CohortTextStyles.body),
                if (onOpenExercise != null && exerciseFor(row.stationId) != null)
                  Semantics(
                    button: true,
                    label: 'Exercise info for ${row.displayName}',
                    child: IconButton(
                      tooltip: 'Exercise info',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.info_outline, size: 20),
                      onPressed: () =>
                          onOpenExercise!(exerciseFor(row.stationId)!),
                    ),
                  ),
              ],
            ),
          ),
        if (result.restBetweenRoundsSeconds != null)
          Padding(
            padding: const EdgeInsets.only(top: CohortSpacing.xs),
            child: Text(
              'Rest  ${result.restBetweenRoundsSeconds} seconds between rounds',
              style: CohortTextStyles.body,
            ),
          ),
      ],
    );
  }
}

class _ReadySurface extends StatelessWidget {
  const _ReadySurface({
    required this.controller,
    required this.onStart,
  });

  final FixedWorkRoundsController controller;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final ordinal = controller.startOrdinal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Round $ordinal of ${controller.targetRounds}',
          key: const ValueKey('fixed-work-position'),
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.md),
        SizedBox(
          height: 64,
          child: CohortButton(
            key: ValueKey('fixed-work-start-$ordinal'),
            label: ordinal == 1 ? 'START TIMER' : 'START ROUND $ordinal',
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
    required this.onFinish,
  });

  final FixedWorkRoundsController controller;
  final String Function(int) clock;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final seconds = controller.displayedWorkSeconds();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Round ${controller.currentRound} of ${controller.targetRounds}',
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
            'Round ${controller.currentRound} completed in ${clock(completed)}',
            style: CohortTextStyles.body,
          ),
        ],
        Text(
          'Next: Round ${controller.currentRound + 1}',
          style: CohortTextStyles.eyebrow,
        ),
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

class _ManualTimes extends StatelessWidget {
  const _ManualTimes({
    required this.controller,
    required this.onApply,
  });

  final FixedWorkRoundsController controller;
  final Future<void> Function(CircuitRoundActual, int?) onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Using another timer? Enter each completed round.',
          style: CohortTextStyles.small,
        ),
        for (final round in controller.result.rounds)
          RoundTimeField(
            key: ValueKey('fixed-work-round-${round.ordinal}'),
            label: 'Round ${round.ordinal}',
            durationSeconds: round.elapsedSeconds,
            onChanged: (value) => onApply(round, value),
          ),
      ],
    );
  }
}

class _FinishedSummary extends StatelessWidget {
  const _FinishedSummary({
    required this.result,
    required this.clock,
  });

  final CircuitResultData result;
  final String Function(int) clock;

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
          Text(
            round.isCompleted
                ? 'Round ${round.ordinal}: ${clock(round.elapsedSeconds!)}'
                : 'Round ${round.ordinal}: incomplete',
            style: CohortTextStyles.body,
          ),
      ],
    );
  }
}
