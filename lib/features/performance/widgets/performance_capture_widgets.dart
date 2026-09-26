import 'package:flutter/material.dart';

import '../../../core/accessibility/journey_interaction.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/strength_prescription_formatter.dart';
import '../services/strength_exercise_capture_completion.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/presentation/daily_journey_accessibility.dart';
import '../../session/services/athlete_exercise_label_resolver.dart';
import '../../workout_player/models/previous_performance_snapshot.dart';
import '../../workout_player/services/previous_performance_resolver.dart';
import '../models/previous_strength_performance.dart';
import '../models/active_performance_draft.dart';
import '../services/completed_session_result_projection.dart';
import '../models/performance_snapshot.dart';
import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/training_block_result_status.dart';
import 'endurance_duration_field.dart';
import 'circuit_capture_editor.dart';
import 'emom_result_capture.dart';
import 'fixed_work_rounds_capture.dart';
import 'interval_pace_field.dart';
import 'performance_numeric_field.dart';
import '../services/interval_pace_format.dart';
import '../services/endurance_metrics_calculator.dart';
import '../services/performance_result_summary_formatter.dart';
import '../services/running_pace_plausibility.dart';
import 'implausible_running_pace_warning.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';

class PerformanceSaveIndicator extends StatelessWidget {
  const PerformanceSaveIndicator({
    super.key,
    required this.state,
    this.errorMessage,
    this.onRetry,
    this.pendingRetained = false,
  });

  final PerformanceSaveState state;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool pendingRetained;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      PerformanceSaveState.idle => '',
      PerformanceSaveState.saving => 'Saving',
      PerformanceSaveState.completing => 'Completion pending',
      PerformanceSaveState.saved =>
        pendingRetained ? 'Completion confirmed' : 'Saved',
      PerformanceSaveState.error =>
        errorMessage ?? 'Couldn’t save — Retry',
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          label: label,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CohortTextStyles.small),
                if (state == PerformanceSaveState.completing)
                  Text(
                    'Your entered results are still saved on this phone.',
                    style: CohortTextStyles.small,
                  ),
              ],
            ),
          ),
        ),
        if (state == PerformanceSaveState.error && onRetry != null)
          Align(
            alignment: Alignment.centerLeft,
            child: JourneyMinTap(
              child: Semantics(
                button: true,
                label: 'Retry save. Local results are still on this phone',
                child: TextButton(
                  key: const ValueKey('performance-save-retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum PerformanceSaveState { idle, saving, completing, saved, error }

class _MaterialSwitchListTile extends StatelessWidget {
  const _MaterialSwitchListTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class SessionRpeSelector extends StatelessWidget {
  const SessionRpeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session RPE (optional)', style: CohortTextStyles.cardTitle),
        const SizedBox(height: CohortSpacing.xs),
        Text(
          'How hard did the session feel? 1 = very easy, 10 = maximal.',
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Wrap(
          spacing: CohortSpacing.sm,
          runSpacing: CohortSpacing.sm,
          children: [
            for (var rpe = 1; rpe <= 10; rpe++)
              ChoiceChip(
                label: Text('$rpe'),
                selected: value == rpe,
                onSelected: (_) => onChanged(value == rpe ? null : rpe),
              ),
          ],
        ),
      ],
    );
  }
}

class BlockResultEditor extends StatelessWidget {
  const BlockResultEditor({
    super.key,
    required this.blockDraft,
    required this.onResultChanged,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onDuplicateSet,
    required this.onRemoveSet,
    this.onApplyElapsedSeconds,
    this.linkedExercises = const [],
    this.onOpenExercise,
    this.previousPerformanceResolver = const PreviousPerformanceResolver(),
    this.previousStrengthHistory,
    this.onRetryPreviousStrength,
  });

  final BlockPerformanceDraft blockDraft;
  final ValueChanged<PerformanceResultData> onResultChanged;
  final void Function(String exerciseId) onAddSet;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  )
  onUpdateSet;
  final void Function(String exerciseId, String setResultId) onDuplicateSet;
  final void Function(String exerciseId, String setResultId) onRemoveSet;
  final ValueChanged<int>? onApplyElapsedSeconds;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final ValueChanged<SessionExecutionExerciseSummary>? onOpenExercise;
  final PreviousPerformanceResolver previousPerformanceResolver;
  final PreviousStrengthHistoryState? previousStrengthHistory;
  final VoidCallback? onRetryPreviousStrength;

  static bool showsCaptureFields(BlockPerformanceDraft blockDraft) {
    return _captureModeFor(blockDraft) != BlockCaptureMode.completion ||
        blockDraft.exerciseResults.any((exercise) => exercise.sets.isNotEmpty);
  }

  /// These capture modes render each linked movement themselves. The active
  /// block must not render a second summary list above them.
  static bool rendersExerciseRows(BlockPerformanceDraft blockDraft) {
    final mode = _captureModeFor(blockDraft);
    return (mode == BlockCaptureMode.strength ||
            mode == BlockCaptureMode.completion) &&
        blockDraft.exerciseResults.isNotEmpty &&
        mode != BlockCaptureMode.circuit;
  }

  static BlockCaptureMode _captureModeFor(BlockPerformanceDraft blockDraft) {
    if (blockDraft.captureMode != BlockCaptureMode.auto) {
      return blockDraft.captureMode;
    }
    return switch (blockDraft.resultType) {
      PerformanceResultType.strength => BlockCaptureMode.strength,
      PerformanceResultType.amrap => BlockCaptureMode.amrap,
      PerformanceResultType.forTime => BlockCaptureMode.forTime,
      PerformanceResultType.interval => BlockCaptureMode.interval,
      PerformanceResultType.distance => BlockCaptureMode.endurance,
      PerformanceResultType.endurance => BlockCaptureMode.endurance,
      PerformanceResultType.rounds => BlockCaptureMode.rounds,
      PerformanceResultType.circuit => BlockCaptureMode.circuit,
      PerformanceResultType.customMetric => BlockCaptureMode.customMetric,
      PerformanceResultType.duration => BlockCaptureMode.endurance,
      PerformanceResultType.completion => BlockCaptureMode.completion,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!showsCaptureFields(blockDraft)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultEditorBody(
          blockDraft: blockDraft,
          linkedExercises: linkedExercises,
          onResultChanged: onResultChanged,
          onAddSet: onAddSet,
          onUpdateSet: onUpdateSet,
          onDuplicateSet: onDuplicateSet,
          onRemoveSet: onRemoveSet,
          onApplyElapsedSeconds: onApplyElapsedSeconds,
          onOpenExercise: onOpenExercise,
          previousPerformanceResolver: previousPerformanceResolver,
          previousStrengthHistory: previousStrengthHistory,
          onRetryPreviousStrength: onRetryPreviousStrength,
        ),
      ],
    );
  }
}

class _ResultEditorBody extends StatelessWidget {
  const _ResultEditorBody({
    required this.blockDraft,
    required this.linkedExercises,
    required this.onResultChanged,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onDuplicateSet,
    required this.onRemoveSet,
    this.onApplyElapsedSeconds,
    this.onOpenExercise,
    this.previousPerformanceResolver = const PreviousPerformanceResolver(),
    this.previousStrengthHistory,
    this.onRetryPreviousStrength,
  });

  final BlockPerformanceDraft blockDraft;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final ValueChanged<PerformanceResultData> onResultChanged;
  final void Function(String exerciseId) onAddSet;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  )
  onUpdateSet;
  final void Function(String exerciseId, String setResultId) onDuplicateSet;
  final void Function(String exerciseId, String setResultId) onRemoveSet;
  final ValueChanged<int>? onApplyElapsedSeconds;
  final ValueChanged<SessionExecutionExerciseSummary>? onOpenExercise;
  final PreviousPerformanceResolver previousPerformanceResolver;
  final PreviousStrengthHistoryState? previousStrengthHistory;
  final VoidCallback? onRetryPreviousStrength;

  @override
  Widget build(BuildContext context) {
    final mode = _effectiveCaptureMode(blockDraft);
    switch (mode) {
      case BlockCaptureMode.strength:
        return _StrengthEditor(
          key: ValueKey('strength-accordion-${blockDraft.sourceBlockId}'),
          blockDraft: blockDraft,
          linkedExercises: linkedExercises,
          onAddSet: onAddSet,
          onUpdateSet: onUpdateSet,
          onDuplicateSet: onDuplicateSet,
          onRemoveSet: onRemoveSet,
          onOpenExercise: onOpenExercise,
          previousPerformanceResolver: previousPerformanceResolver,
          previousStrengthHistory: previousStrengthHistory,
          onRetryPreviousStrength: onRetryPreviousStrength,
        );
      case BlockCaptureMode.amrap:
        return _AmrapEditor(
          result:
              blockDraft.resultData as AmrapResultData? ??
              const AmrapResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.forTime:
        return _ForTimeEditor(
          result:
              blockDraft.resultData as ForTimeResultData? ??
              const ForTimeResultData(),
          onChanged: onResultChanged,
          onApplyElapsedSeconds: onApplyElapsedSeconds,
        );
      case BlockCaptureMode.interval:
        return _IntervalEditor(
          key: ValueKey('interval-editor-${blockDraft.sourceBlockId}'),
          result:
              blockDraft.resultData as IntervalResultData? ??
              const IntervalResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.endurance:
        return _EnduranceEditor(
          result:
              blockDraft.resultData as EnduranceResultData? ??
              const EnduranceResultData(),
          onChanged: onResultChanged,
          blockTitle: blockDraft.blockSnapshot.title,
          workoutFormat: blockDraft.blockSnapshot.workoutFormat.name,
        );
      case BlockCaptureMode.circuit:
        final circuit =
            blockDraft.resultData as CircuitResultData? ??
            const CircuitResultData(
              format: 'rounds',
              comparisonFamily: '',
              stations: [],
            );
        if (circuit.isFixedWork) {
          return FixedWorkRoundsCapture(
            result: circuit,
            onChanged: onResultChanged,
            linkedExercises: linkedExercises,
            onOpenExercise: onOpenExercise,
          );
        }
        if (circuit.isEmomScore) {
          return EmomResultCapture(
            result: circuit,
            showActions: false,
            onChanged: onResultChanged,
          );
        }
        return CircuitCaptureEditor(
          result: circuit,
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.rounds:
        final roundsData = blockDraft.resultData;
        if (roundsData is CircuitResultData && roundsData.isFixedWork) {
          return FixedWorkRoundsCapture(
            result: roundsData,
            onChanged: onResultChanged,
            linkedExercises: linkedExercises,
            onOpenExercise: onOpenExercise,
          );
        }
        return _RoundsEditor(
          result:
              blockDraft.resultData as RoundsResultData? ??
              const RoundsResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.customMetric:
        return _CustomMetricEditor(
          result:
              blockDraft.resultData as CustomMetricResultData? ??
              const CustomMetricResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.completion:
      case BlockCaptureMode.auto:
        return _ExerciseAcknowledgementEditor(
          blockDraft: blockDraft,
          linkedExercises: linkedExercises,
          onUpdateSet: onUpdateSet,
          onOpenExercise: onOpenExercise,
        );
    }
  }

  BlockCaptureMode _effectiveCaptureMode(BlockPerformanceDraft blockDraft) {
    return BlockResultEditor._captureModeFor(blockDraft);
  }
}

class _AmrapEditor extends StatelessWidget {
  const _AmrapEditor({required this.result, required this.onChanged});
  final AmrapResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PerformanceNumericField(
          key: const ValueKey('amrap-rounds'),
          label: 'Rounds',
          value: '${result.rounds}',
          onChanged: (value) =>
              onChanged(result.copyWith(rounds: int.tryParse(value) ?? 0)),
        ),
        PerformanceNumericField(
          key: const ValueKey('amrap-extra-reps'),
          label: 'Extra reps',
          value: '${result.extraReps}',
          onChanged: (value) =>
              onChanged(result.copyWith(extraReps: int.tryParse(value) ?? 0)),
        ),
      ],
    );
  }
}

class _ForTimeEditor extends StatelessWidget {
  const _ForTimeEditor({
    required this.result,
    required this.onChanged,
    this.onApplyElapsedSeconds,
  });

  final ForTimeResultData result;
  final ValueChanged<PerformanceResultData> onChanged;
  final ValueChanged<int>? onApplyElapsedSeconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PerformanceNumericField(
          label: 'Elapsed seconds',
          value: result.elapsedSeconds?.toString() ?? '',
          onChanged: (value) =>
              onChanged(result.copyWith(elapsedSeconds: int.tryParse(value))),
        ),
        if (result.remainingWorkNote?.trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Remaining: ${result.remainingWorkNote}'),
          ),
        _MaterialSwitchListTile(
          title: 'Completed',
          value: result.completed,
          onChanged: (value) => onChanged(result.copyWith(completed: value)),
        ),
        if (onApplyElapsedSeconds != null)
          TextButton(
            onPressed: () => onApplyElapsedSeconds!(result.elapsedSeconds ?? 0),
            child: const Text('Use timer elapsed time'),
          ),
      ],
    );
  }
}

class _IntervalEditor extends StatefulWidget {
  const _IntervalEditor({
    super.key,
    required this.result,
    required this.onChanged,
  });
  final IntervalResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  State<_IntervalEditor> createState() => _IntervalEditorState();
}

class _IntervalEditorState extends State<_IntervalEditor> {
  bool _expanded = true;
  int? _openOrdinal = 1;
  int? _focusOrdinal = 1;

  IntervalResultData get _result => widget.result;

  int? _nextPendingOrdinal(int afterOrdinal) {
    for (final item in _result.intervals) {
      if (item.ordinal > afterOrdinal &&
          item.state == IntervalWorkState.pending) {
        return item.ordinal;
      }
    }
    return null;
  }

  void _persistRow(IntervalWorkResult next, {required bool advanceIfRecorded}) {
    widget.onChanged(_result.replaceInterval(next));
    if (!advanceIfRecorded || !next.state.countsAsCompleted) return;
    setState(() {
      _openOrdinal = _nextPendingOrdinal(next.ordinal);
      _focusOrdinal = _openOrdinal;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_result.usesPerIntervalCapture) {
      return PerformanceNumericField(
        label:
            'Intervals completed${_result.totalIntervals == null ? '' : ' / ${_result.totalIntervals}'}',
        value: '${_result.intervalsCompleted}',
        onChanged: (value) => widget.onChanged(
          _result.copyWith(intervalsCompleted: int.tryParse(value) ?? 0),
        ),
      );
    }

    final prescribed = _result.prescribedCount ?? _result.intervals.length;
    final recorded = _result.recordedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: 'Interval performance, $recorded of $prescribed recorded',
          hint: _expanded
              ? 'Collapse interval performance'
              : 'Expand interval performance',
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INTERVAL PERFORMANCE',
                        style: CohortTextStyles.sectionLabel,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Interval performance · $recorded of $prescribed recorded',
                        style: CohortTextStyles.small,
                      ),
                    ],
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: CohortSpacing.sm),
          for (final row in _result.intervals)
            _IntervalWorkRow(
              key: ValueKey('interval-row-${row.ordinal}'),
              row: row,
              expanded: _openOrdinal == row.ordinal,
              autofocus: _focusOrdinal == row.ordinal,
              onToggle: () => setState(() {
                _openOrdinal = _openOrdinal == row.ordinal ? null : row.ordinal;
                _focusOrdinal = _openOrdinal;
              }),
              onPersist: (next) => _persistRow(next, advanceIfRecorded: false),
              onRecorded: (next) => _persistRow(next, advanceIfRecorded: true),
            ),
        ],
      ],
    );
  }
}

class _IntervalWorkRow extends StatefulWidget {
  const _IntervalWorkRow({
    super.key,
    required this.row,
    required this.expanded,
    required this.onToggle,
    required this.onPersist,
    required this.onRecorded,
    this.autofocus = false,
  });

  final IntervalWorkResult row;
  final bool expanded;
  final bool autofocus;
  final VoidCallback onToggle;
  final ValueChanged<IntervalWorkResult> onPersist;
  final ValueChanged<IntervalWorkResult> onRecorded;

  @override
  State<_IntervalWorkRow> createState() => _IntervalWorkRowState();
}

class _IntervalWorkRowState extends State<_IntervalWorkRow> {
  final GlobalKey<IntervalPaceFieldState> _paceKey =
      GlobalKey<IntervalPaceFieldState>();
  String? _errorText;
  String _draft = '';

  IntervalWorkResult get row => widget.row;

  String get _stateLabel {
    return switch (row.state) {
      IntervalWorkState.completed => IntervalPaceFormat.display(
        row.paceSecondsPerKm,
      ),
      IntervalWorkState.paceUnavailable => 'Pace unavailable',
      IntervalWorkState.skipped => 'Skipped',
      IntervalWorkState.pending => 'Not recorded',
    };
  }

  double? _draftPace() {
    final text = _paceKey.currentState?.draftText ?? _draft;
    return IntervalPaceFormat.parse(text);
  }

  bool _tryRecordCompleted() {
    final pace = _draftPace() ?? row.paceSecondsPerKm;
    if (pace == null) {
      setState(() {
        _errorText = IntervalPaceFormat.invalidPaceMessage;
      });
      return false;
    }
    setState(() => _errorText = null);
    widget.onRecorded(
      row.copyWith(paceSecondsPerKm: pace, state: IntervalWorkState.completed),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final workLabel = row.workSeconds >= 60 && row.workSeconds % 60 == 0
        ? '${row.workSeconds ~/ 60}:00 work'
        : '${row.workSeconds}s work';
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onToggle,
              child: Semantics(
                button: true,
                expanded: widget.expanded,
                label: 'Interval ${row.ordinal}, $workLabel, $_stateLabel',
                hint: widget.expanded ? 'Collapse interval' : 'Expand interval',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Interval ${row.ordinal} · $workLabel',
                        style: CohortTextStyles.body,
                      ),
                    ),
                    Text(_stateLabel, style: CohortTextStyles.small),
                    Icon(
                      widget.expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.expanded) ...[
              const SizedBox(height: CohortSpacing.sm),
              IntervalPaceField(
                key: _paceKey,
                secondsPerKm: row.paceSecondsPerKm,
                enabled:
                    row.state != IntervalWorkState.paceUnavailable &&
                    row.state != IntervalWorkState.skipped,
                autofocus: widget.autofocus,
                errorText: _errorText,
                onDraftChanged: (value) {
                  _draft = value;
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                onChanged: (pace) {
                  final nextState = pace == null
                      ? (row.state == IntervalWorkState.completed
                            ? IntervalWorkState.pending
                            : row.state)
                      : row.state;
                  widget.onPersist(
                    row.copyWith(
                      paceSecondsPerKm: pace,
                      clearPace: pace == null,
                      state: nextState,
                    ),
                  );
                },
                onSubmitted: (_) => _tryRecordCompleted(),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Completed'),
                value: row.state.countsAsCompleted,
                onChanged: (value) {
                  if (value == true) {
                    _tryRecordCompleted();
                    return;
                  }
                  setState(() => _errorText = null);
                  widget.onPersist(
                    row.copyWith(
                      state: IntervalWorkState.pending,
                      clearPace: false,
                    ),
                  );
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Pace unavailable'),
                value: row.state == IntervalWorkState.paceUnavailable,
                onChanged: (value) {
                  setState(() => _errorText = null);
                  if (value == true) {
                    widget.onRecorded(
                      row.copyWith(
                        state: IntervalWorkState.paceUnavailable,
                        clearPace: true,
                      ),
                    );
                    return;
                  }
                  widget.onPersist(
                    row.copyWith(state: IntervalWorkState.pending),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnduranceEditor extends StatefulWidget {
  const _EnduranceEditor({
    required this.result,
    required this.onChanged,
    this.blockTitle,
    this.workoutFormat,
  });

  final EnduranceResultData result;
  final ValueChanged<PerformanceResultData> onChanged;
  final String? blockTitle;
  final String? workoutFormat;

  @override
  State<_EnduranceEditor> createState() => _EnduranceEditorState();
}

class _EnduranceEditorState extends State<_EnduranceEditor> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.result.note ?? '');
  }

  @override
  void didUpdateWidget(covariant _EnduranceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result.note != oldWidget.result.note &&
        widget.result.note != _noteController.text) {
      _noteController.text = widget.result.note ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  static const _units = ['km', 'mi', 'm'];

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final liveMetric = EnduranceMetricsCalculator.liveMetric(
      distance: result.distance,
      distanceUnit: result.distanceUnit,
      durationSeconds: result.durationSeconds,
    );
    final runningWarning = RunningPacePlausibility.warning(
      distance: result.distance,
      distanceUnit: result.distanceUnit,
      durationSeconds: result.durationSeconds,
      workoutFormat: widget.workoutFormat,
      blockTitle: widget.blockTitle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PerformanceNumericField(
          label: 'Distance',
          value: result.distance?.toString() ?? '',
          allowDecimal: true,
          onChanged: (value) => widget.onChanged(
            result.copyWith(distance: double.tryParse(value)),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _units.contains(result.distanceUnit)
              ? result.distanceUnit
              : 'km',
          decoration: const InputDecoration(labelText: 'Distance unit'),
          items: _units
              .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            widget.onChanged(result.copyWith(distanceUnit: value));
          },
        ),
        EnduranceDurationField(
          durationSeconds: result.durationSeconds,
          onDurationSecondsChanged: (seconds) =>
              widget.onChanged(result.copyWith(durationSeconds: seconds)),
        ),
        if (liveMetric != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(liveMetric.label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Text(liveMetric.value, style: CohortTextStyles.body),
        ],
        if (runningWarning != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          ImplausibleRunningPaceWarning(warning: runningWarning),
        ],
        PerformanceNumericField(
          label: 'Average heart rate (optional)',
          value: result.averageHeartRate?.toString() ?? '',
          onChanged: (value) => widget.onChanged(
            result.copyWith(averageHeartRate: int.tryParse(value)),
          ),
        ),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          onChanged: (value) => widget.onChanged(
            result.copyWith(note: value.trim().isEmpty ? null : value.trim()),
          ),
        ),
      ],
    );
  }
}

class _RoundsEditor extends StatelessWidget {
  const _RoundsEditor({required this.result, required this.onChanged});
  final RoundsResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PerformanceNumericField(
          label: 'Rounds completed',
          value: '${result.roundsCompleted}',
          onChanged: (value) => onChanged(
            result.copyWith(roundsCompleted: int.tryParse(value) ?? 0),
          ),
        ),
        PerformanceNumericField(
          label: 'Extra reps',
          value: '${result.extraReps}',
          onChanged: (value) =>
              onChanged(result.copyWith(extraReps: int.tryParse(value) ?? 0)),
        ),
      ],
    );
  }
}

class _CustomMetricEditor extends StatelessWidget {
  const _CustomMetricEditor({required this.result, required this.onChanged});

  final CustomMetricResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Metric label'),
          controller: TextEditingController(text: result.label ?? ''),
          onChanged: (value) => onChanged(
            result.copyWith(label: value.trim().isEmpty ? null : value.trim()),
          ),
        ),
        PerformanceNumericField(
          label: 'Value',
          value: result.numericValue?.toString() ?? '',
          allowDecimal: true,
          onChanged: (value) =>
              onChanged(result.copyWith(numericValue: double.tryParse(value))),
        ),
      ],
    );
  }
}

class _ExerciseAcknowledgementEditor extends StatelessWidget {
  const _ExerciseAcknowledgementEditor({
    required this.blockDraft,
    required this.linkedExercises,
    required this.onUpdateSet,
    this.onOpenExercise,
  });

  final BlockPerformanceDraft blockDraft;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  )
  onUpdateSet;
  final ValueChanged<SessionExecutionExerciseSummary>? onOpenExercise;

  SessionExecutionExerciseSummary? _summaryFor(String exerciseId) {
    for (final summary in linkedExercises) {
      if (summary.exerciseId == exerciseId) return summary;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exercise in blockDraft.exerciseResults) ...[
          Builder(
            builder: (context) {
              final summary = _summaryFor(exercise.sourceExerciseId);
              final label = AthleteExerciseLabelResolver.fromExerciseDraft(
                exercise,
                executionSummary: summary,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PerformanceExerciseTitle(
                    label: label,
                    summary: summary,
                    onOpenExercise: onOpenExercise,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  _ExerciseTargetComparison(summary: summary),
                  const SizedBox(height: CohortSpacing.sm),
                  for (final row in exercise.sets)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        DailyJourneyAccessibility.setCompletedLabel(
                          row.setNumber,
                        ),
                      ),
                      value: row.completed,
                      onChanged: (value) => onUpdateSet(
                        exercise.sourceExerciseId,
                        row.setResultId,
                        (current) =>
                            current.copyWith(completed: value ?? false),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: CohortSpacing.md),
        ],
      ],
    );
  }
}

class _StrengthEditor extends StatefulWidget {
  const _StrengthEditor({
    super.key,
    required this.blockDraft,
    required this.linkedExercises,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onDuplicateSet,
    required this.onRemoveSet,
    required this.previousPerformanceResolver,
    this.onOpenExercise,
    this.previousStrengthHistory,
    this.onRetryPreviousStrength,
  });

  final BlockPerformanceDraft blockDraft;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final void Function(String exerciseId) onAddSet;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  )
  onUpdateSet;
  final void Function(String exerciseId, String setResultId) onDuplicateSet;
  final void Function(String exerciseId, String setResultId) onRemoveSet;
  final PreviousPerformanceResolver previousPerformanceResolver;
  final ValueChanged<SessionExecutionExerciseSummary>? onOpenExercise;
  final PreviousStrengthHistoryState? previousStrengthHistory;
  final VoidCallback? onRetryPreviousStrength;

  @override
  State<_StrengthEditor> createState() => _StrengthEditorState();
}

class _StrengthEditorState extends State<_StrengthEditor> {
  String? _expandedExerciseResultId;
  final Map<String, GlobalKey> _cardKeys = {};
  final Map<String, PreviousPerformanceSnapshot?> _previousByExerciseId = {};

  @override
  void initState() {
    super.initState();
    _expandedExerciseResultId = _earliestIncompleteId();
  }

  @override
  void didUpdateWidget(covariant _StrengthEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blockDraft.sourceBlockId != widget.blockDraft.sourceBlockId) {
      _previousByExerciseId.clear();
      _expandedExerciseResultId = _earliestIncompleteId();
      return;
    }
    final ids = widget.blockDraft.exerciseResults
        .map((exercise) => exercise.exerciseResultId)
        .toSet();
    if (_expandedExerciseResultId != null &&
        !ids.contains(_expandedExerciseResultId)) {
      _expandedExerciseResultId = _earliestIncompleteId();
    }
  }

  SessionExecutionExerciseSummary? _summaryFor(String exerciseId) {
    for (final summary in widget.linkedExercises) {
      if (summary.exerciseId == exerciseId) return summary;
    }
    return null;
  }

  String _exerciseLabel(ExercisePerformanceDraft exercise) {
    return AthleteExerciseLabelResolver.fromExerciseDraft(
      exercise,
      executionSummary: _summaryFor(exercise.sourceExerciseId),
    );
  }

  String? _earliestIncompleteId() {
    for (final exercise in widget.blockDraft.exerciseResults) {
      if (!StrengthExerciseCaptureCompletion.isComplete(
        exercise: exercise,
        prescription: _summaryFor(exercise.sourceExerciseId)?.prescription,
      )) {
        return exercise.exerciseResultId;
      }
    }
    return null;
  }

  PreviousStrengthExerciseEvidence? _hostedPrevious(
    SessionExecutionExerciseSummary? summary,
  ) {
    final history = widget.previousStrengthHistory;
    if (history == null || !history.isReady || summary == null) return null;
    return history.byExerciseId[summary.exerciseId];
  }

  PreviousPerformanceSnapshot? _cachedPrevious(
    SessionExecutionExerciseSummary? summary,
  ) {
    if (summary == null) return null;
    final hosted = _hostedPrevious(summary);
    if (hosted != null) {
      return PreviousPerformanceSnapshot(
        exerciseId: hosted.exerciseId,
        sessionType: PreviousPerformanceSessionType.strength,
        performedAt: hosted.performedAt,
        setSummary: hosted.summaryLine,
        loadSummary: hosted.topSet == null
            ? null
            : StrengthLoadDisplay.format(
                load: hosted.topSet!.load,
                loadUnit: hosted.topSet!.loadUnit,
                kind: hosted.topSet!.load == null || hosted.topSet!.load == 0
                    ? StrengthActualLoadKind.bodyweight
                    : StrengthActualLoadKind.external,
              ),
        repSummary: hosted.topSet?.reps == null
            ? null
            : '${hosted.topSet!.reps}',
      );
    }
    if (widget.previousStrengthHistory?.isReady == true) {
      return null;
    }
    if (_previousByExerciseId.containsKey(summary.exerciseId)) {
      return _previousByExerciseId[summary.exerciseId];
    }
    final resolved = widget.previousPerformanceResolver.resolveLatest(
      exerciseId: summary.exerciseId,
      requiredType: PreviousPerformanceSessionType.strength,
    );
    _previousByExerciseId[summary.exerciseId] = resolved;
    return resolved;
  }

  Duration _motionDuration(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
  }

  void _toggleExercise(String exerciseResultId) {
    final collapsing = _expandedExerciseResultId == exerciseResultId;
    setState(() {
      _expandedExerciseResultId = collapsing ? null : exerciseResultId;
    });
    if (!collapsing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cardContext = _cardKeys[exerciseResultId]?.currentContext;
        if (cardContext == null || !cardContext.mounted) return;
        Scrollable.ensureVisible(
          cardContext,
          alignment: 0.08,
          duration: _motionDuration(cardContext),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? previousGroupKey;
    String? previousGroupId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exercise in widget.blockDraft.exerciseResults) ...[
          Builder(
            builder: (context) {
              final summary = _summaryFor(exercise.sourceExerciseId);
              final groupKey = summary?.hasExecutionGroup == true
                  ? summary!.executionGroupKey
                  : null;
              final groupId = summary?.prescription?.groupId?.trim();
              final showExecutionGroup =
                  groupKey != null && groupKey != previousGroupKey;
              final showPaired =
                  groupId != null &&
                  groupId.isNotEmpty &&
                  groupId != previousGroupId &&
                  groupKey == null;
              previousGroupKey = groupKey ?? previousGroupKey;
              previousGroupId = groupId ?? previousGroupId;

              final expanded =
                  exercise.exerciseResultId == _expandedExerciseResultId;
              final complete = StrengthExerciseCaptureCompletion.isComplete(
                exercise: exercise,
                prescription: summary?.prescription,
              );
              final volume = StrengthPrescriptionFormatter.collapsedVolumeLine(
                summary?.prescription,
              );
              final status =
                  StrengthExerciseCaptureCompletion.collapsedStatusLine(
                    exercise: exercise,
                    prescription: summary?.prescription,
                  );
              final label = _exerciseLabel(exercise);
              final cardKey = _cardKeys.putIfAbsent(
                exercise.exerciseResultId,
                GlobalKey.new,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showExecutionGroup) ...[
                    Text(
                      '${summary!.executionGroupLabel} · '
                      '${summary.executionGroupRounds} rounds',
                      style: CohortTextStyles.eyebrow,
                    ),
                    const SizedBox(height: CohortSpacing.sm),
                  ] else if (showPaired) ...[
                    Text('Paired work', style: CohortTextStyles.eyebrow),
                    const SizedBox(height: CohortSpacing.sm),
                  ],
                  KeyedSubtree(
                    key: cardKey,
                    child: _StrengthExerciseAccordionCard(
                      label: label,
                      volume: volume,
                      statusLine: status,
                      isExpanded: expanded,
                      isComplete: complete,
                      reduceMotion: MediaQuery.disableAnimationsOf(context),
                      onToggle: () =>
                          _toggleExercise(exercise.exerciseResultId),
                      onOpenExercise:
                          summary != null && widget.onOpenExercise != null
                          ? () => widget.onOpenExercise!(summary)
                          : null,
                      expandedBody: expanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ExerciseTargetComparison(
                                  summary: summary,
                                  previous: _cachedPrevious(summary),
                                  hosted: _hostedPrevious(summary),
                                  history: widget.previousStrengthHistory,
                                  onRetry: widget.onRetryPreviousStrength,
                                  useProvidedPrevious: true,
                                ),
                                const SizedBox(height: CohortSpacing.sm),
                                for (final set in exercise.sets)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: CohortSpacing.sm,
                                    ),
                                    child: _ExerciseActualRow(
                                      exerciseId: exercise.sourceExerciseId,
                                      set: set,
                                      capture: summary
                                          ?.prescription
                                          ?.performanceCapture,
                                      loadKind:
                                          exercise.exerciseSnapshot.loadKind,
                                      captureRpe:
                                          summary
                                              ?.prescription
                                              ?.performanceCapture
                                              ?.rpe ==
                                          true,
                                      onUpdateSet: widget.onUpdateSet,
                                      previousSet: _hostedPrevious(
                                        summary,
                                      )?.setForNumber(set.setNumber),
                                    ),
                                  ),
                                CohortButton(
                                  label: exercise.sets.isEmpty
                                      ? 'Add first set'
                                      : 'Add set',
                                  onPressed: () => widget.onAddSet(
                                    exercise.sourceExerciseId,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.md),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _StrengthExerciseAccordionCard extends StatelessWidget {
  const _StrengthExerciseAccordionCard({
    required this.label,
    required this.volume,
    required this.isExpanded,
    required this.isComplete,
    required this.reduceMotion,
    required this.onToggle,
    this.statusLine,
    this.onOpenExercise,
    this.expandedBody,
  });

  final String label;
  final String volume;
  final String? statusLine;
  final bool isExpanded;
  final bool isComplete;
  final bool reduceMotion;
  final VoidCallback onToggle;
  final VoidCallback? onOpenExercise;
  final Widget? expandedBody;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = [
      label,
      volume,
      if (statusLine != null) statusLine,
    ].join('. ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isComplete
              ? CohortColors.success.withValues(alpha: 0.45)
              : CohortColors.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    expanded: isExpanded,
                    label: semanticsLabel,
                    hint: isExpanded ? 'Collapse exercise' : 'Expand exercise',
                    child: InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(8),
                      child: ExcludeSemantics(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: CohortSpacing.xs,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: CohortTextStyles.cardTitle,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        volume,
                                        style: CohortTextStyles.small,
                                      ),
                                      if (statusLine != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          statusLine!,
                                          style: CohortTextStyles.small
                                              .copyWith(
                                                color: CohortColors.success,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: CohortSpacing.sm,
                                ),
                                child: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: CohortColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isExpanded && onOpenExercise != null)
                  JourneyMinTap(
                    child: Semantics(
                      button: true,
                      label: 'Exercise info for $label',
                      child: IconButton(
                        tooltip: 'Exercise info',
                        icon: const Icon(Icons.info_outline),
                        onPressed: onOpenExercise,
                      ),
                    ),
                  ),
              ],
            ),
            if (reduceMotion)
              isExpanded && expandedBody != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: CohortSpacing.sm),
                      child: expandedBody,
                    )
                  : const SizedBox(width: double.infinity)
            else
              AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: isExpanded && expandedBody != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: CohortSpacing.sm),
                      child: expandedBody,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceExerciseTitle extends StatelessWidget {
  const _PerformanceExerciseTitle({
    required this.label,
    required this.summary,
    required this.onOpenExercise,
  });

  final String label;
  final SessionExecutionExerciseSummary? summary;
  final ValueChanged<SessionExecutionExerciseSummary>? onOpenExercise;

  @override
  Widget build(BuildContext context) {
    final canOpen = summary != null && onOpenExercise != null;
    return Row(
      children: [
        Expanded(child: Text(label, style: CohortTextStyles.cardTitle)),
        Semantics(
          button: canOpen,
          enabled: canOpen,
          label: 'Exercise info for $label',
          child: JourneyMinTap(
            child: IconButton(
              tooltip: 'Exercise info',
              icon: const Icon(Icons.info_outline),
              onPressed: canOpen ? () => onOpenExercise!(summary!) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseTargetComparison extends StatelessWidget {
  const _ExerciseTargetComparison({
    required this.summary,
    this.previous,
    this.hosted,
    this.history,
    this.onRetry,
    this.useProvidedPrevious = false,
  });

  final SessionExecutionExerciseSummary? summary;
  final PreviousPerformanceSnapshot? previous;
  final PreviousStrengthExerciseEvidence? hosted;
  final PreviousStrengthHistoryState? history;
  final VoidCallback? onRetry;
  final bool useProvidedPrevious;

  @override
  Widget build(BuildContext context) {
    final prescription = summary?.prescription;
    final lastTimeBody = _lastTimeBody();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today', style: CohortTextStyles.eyebrow),
        Text(
          prescription == null
              ? 'No authored target available.'
              : [
                  StrengthPrescriptionFormatter.summaryLine(prescription),
                  if (StrengthPrescriptionFormatter.detailLine(
                    prescription,
                  ).isNotEmpty)
                    StrengthPrescriptionFormatter.detailLine(prescription),
                ].join(' · '),
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: CohortSpacing.xs),
        Text('Previous performance', style: CohortTextStyles.eyebrow),
        lastTimeBody,
      ],
    );
  }

  Widget _lastTimeBody() {
    if (history != null && history!.isLoading) {
      return Text(
        'Loading previous performance…',
        style: CohortTextStyles.small,
      );
    }
    if (history != null && history!.isFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn’t load previous performance',
            style: CohortTextStyles.small,
          ),
          Text(
            'You can still record this set.',
            style: CohortTextStyles.small,
          ),
          JourneyMinTap(
            child: TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    if (hosted != null) {
      final extra = hosted!.completedSetCount > 0
          ? hosted!.summaryLine
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCompletedDate(hosted!.performedAt),
            style: CohortTextStyles.small,
          ),
          if (extra != null)
            Text(extra, style: CohortTextStyles.small),
        ],
      );
    }
    if (history != null && history!.isReady) {
      return Text(
        'First recorded performance',
        style: CohortTextStyles.small,
      );
    }
    final resolvedPrevious = useProvidedPrevious
        ? previous
        : summary == null
        ? null
        : const PreviousPerformanceResolver().resolveLatest(
            exerciseId: summary!.exerciseId,
            requiredType: PreviousPerformanceSessionType.strength,
          );
    final previousParts = resolvedPrevious == null
        ? const <String>[]
        : <String>[
            ?_text(resolvedPrevious.repSummary),
            ?_text(resolvedPrevious.loadSummary),
            ?_text(resolvedPrevious.distanceSummary),
            ?_text(resolvedPrevious.durationSummary),
            if (resolvedPrevious.rpe case final value?) 'RPE $value',
          ];
    return Text(
      previousParts.isEmpty
          ? 'First recorded performance'
          : previousParts.join(' · '),
      style: CohortTextStyles.small,
    );
  }

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _ExerciseActualRow extends StatelessWidget {
  const _ExerciseActualRow({
    required this.exerciseId,
    required this.set,
    required this.capture,
    required this.loadKind,
    required this.onUpdateSet,
    this.captureRpe = false,
    this.previousSet,
  });

  final String exerciseId;
  final SetPerformanceDraft set;
  final ExercisePerformanceCapture? capture;
  final StrengthActualLoadKind loadKind;
  final bool captureRpe;
  final PreviousStrengthSetEvidence? previousSet;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  )
  onUpdateSet;

  @override
  Widget build(BuildContext context) {
    final showDistance =
        set.distanceUnit?.trim().isNotEmpty == true ||
        capture?.distanceUnit?.trim().isNotEmpty == true;
    final showLoad =
        loadKind.expectsExternalLoad ||
        capture?.loadUnit?.trim().isNotEmpty == true;
    final showReps = !showDistance;
    final loadUnit = set.loadUnit ?? capture?.loadUnit ?? 'kg';
    final loadField = showLoad
        ? PerformanceNumericField(
            key: ValueKey('${set.setResultId}-load'),
            label: _label(
              capture?.loadLabel,
              DailyJourneyAccessibility.setLoadLabel(set.setNumber, loadUnit),
            ),
            semanticLabel: DailyJourneyAccessibility.setLoadLabel(
              set.setNumber,
              loadUnit,
            ),
            value: set.load?.toString() ?? '',
            allowDecimal: true,
            autofocus: set.setNumber == 1 && !set.completed && !showReps,
            onChanged: (value) {
              final parsed = double.tryParse(value);
              onUpdateSet(
                exerciseId,
                set.setResultId,
                (current) => current.copyWith(
                  load: parsed,
                  loadUnit: current.loadUnit ?? loadUnit,
                  clearLoad: parsed == null,
                ),
              );
            },
          )
        : null;
    final distanceField = showDistance
        ? PerformanceNumericField(
            key: ValueKey('${set.setResultId}-distance'),
            label:
                'Completed distance (${set.distanceUnit ?? capture?.distanceUnit ?? 'm'})',
            semanticLabel: DailyJourneyAccessibility.setDistanceLabel(
              set.setNumber,
              set.distanceUnit ?? capture?.distanceUnit,
            ),
            value: set.distance?.toString() ?? '',
            allowDecimal: true,
            onChanged: (value) {
              final parsed = double.tryParse(value);
              onUpdateSet(
                exerciseId,
                set.setResultId,
                (current) => current.copyWith(
                  distance: parsed,
                  distanceUnit:
                      current.distanceUnit ?? capture?.distanceUnit ?? 'm',
                  clearDistance: parsed == null,
                ),
              );
            },
          )
        : null;
    final repsField = showReps
        ? PerformanceNumericField(
            key: ValueKey('${set.setResultId}-reps'),
            label: DailyJourneyAccessibility.setRepsLabel(set.setNumber),
            value: set.reps?.toString() ?? '',
            autofocus: set.setNumber == 1 && !set.completed && loadField == null,
            onChanged: (value) {
              final parsed = int.tryParse(value);
              onUpdateSet(
                exerciseId,
                set.setResultId,
                (current) =>
                    current.copyWith(reps: parsed, clearReps: parsed == null),
              );
            },
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDistance)
          Text('Set ${set.setNumber}', style: CohortTextStyles.small),
        if (previousSet != null)
          Text(previousSet!.ghostLine, style: CohortTextStyles.small),
        _SetCaptureFields(
          stackedChildren: [
            ?repsField,
            ?distanceField,
            ?loadField,
            if (loadKind == StrengthActualLoadKind.bodyweight)
              const Text('Bodyweight'),
          ],
        ),
        if (capture?.durationOptional == true)
          EnduranceDurationField(
            key: ValueKey('${set.setResultId}-duration'),
            label: 'Duration (optional)',
            durationSeconds: set.durationSeconds,
            onDurationSecondsChanged: (seconds) => onUpdateSet(
              exerciseId,
              set.setResultId,
              (current) => current.copyWith(
                durationSeconds: seconds,
                clearDurationSeconds: seconds == null,
              ),
            ),
          ),
        if (captureRpe) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text('RPE', style: CohortTextStyles.small),
          Wrap(
            spacing: CohortSpacing.sm,
            children: [
              for (var rpe = 1; rpe <= 10; rpe++)
                ChoiceChip(
                  label: Text('$rpe'),
                  selected: set.rpe == rpe,
                  onSelected: (_) => onUpdateSet(
                    exerciseId,
                    set.setResultId,
                    (current) => current.copyWith(
                      rpe: current.rpe == rpe ? null : rpe,
                      clearRpe: current.rpe == rpe,
                    ),
                  ),
                ),
            ],
          ),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            showDistance
                ? 'Completed'
                : DailyJourneyAccessibility.setCompletedLabel(set.setNumber),
          ),
          value: set.completed,
          onChanged: (value) => onUpdateSet(
            exerciseId,
            set.setResultId,
            (current) => current.copyWith(completed: value ?? false),
          ),
        ),
      ],
    );
  }

  static String _label(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }
}

class _SetCaptureFields extends StatelessWidget {
  const _SetCaptureFields({required this.stackedChildren});

  final List<Widget> stackedChildren;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = DailyJourneyAccessibility.shouldStackFields(
          context,
          constraints.maxWidth,
        );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in stackedChildren) ...[
                child,
                const SizedBox(height: CohortSpacing.sm),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stackedChildren.length; i++) ...[
              if (i > 0) const SizedBox(width: CohortSpacing.sm),
              Expanded(child: stackedChildren[i]),
            ],
          ],
        );
      },
    );
  }
}

class TrainingHistoryCard extends StatelessWidget {
  const TrainingHistoryCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  final TrainingSessionRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = record.completedAt ?? record.startedAt;
    return CohortCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.sessionSnapshot.sessionTitle,
            style: CohortTextStyles.cardTitle,
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            '${record.status.displayLabel} · ${_formatDate(date)}',
            style: CohortTextStyles.small,
          ),
          if (record.sessionSnapshot.programmeContextLabel != null)
            Text(
              record.sessionSnapshot.programmeContextLabel!,
              style: CohortTextStyles.small,
            ),
          if (record.durationSeconds != null)
            Text(
              'Duration ${_formatDuration(record.durationSeconds!)}',
              style: CohortTextStyles.small,
            ),
          if (record.overallRpe != null)
            Text('RPE ${record.overallRpe}', style: CohortTextStyles.small),
          Text(
            '${record.completedBlockCount}/${record.blockResults.length} blocks completed',
            style: CohortTextStyles.small,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes}m ${remainder}s';
  }
}

class HistoricalBlockResultCard extends StatelessWidget {
  const HistoricalBlockResultCard({super.key, required this.block});

  final TrainingBlockResult block;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.blockSnapshot.title, style: CohortTextStyles.cardTitle),
          Text(block.status.displayLabel, style: CohortTextStyles.small),
          if (block.exerciseResults.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text('Exercises', style: CohortTextStyles.eyebrow),
            for (final exercise in block.exerciseResults) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                AthleteExerciseLabelResolver.fromExerciseResult(
                  exercise,
                  historical: true,
                ),
                style: CohortTextStyles.body,
              ),
            ],
          ],
          const SizedBox(height: CohortSpacing.sm),
          PrescribedPerformedSection(
            prescribed: block.blockSnapshot.content,
            performed: PerformanceResultSummaryFormatter.formatBlock(block),
          ),
        ],
      ),
    );
  }
}

class PrescribedPerformedSection extends StatelessWidget {
  const PrescribedPerformedSection({
    super.key,
    required this.prescribed,
    required this.performed,
  });

  final String prescribed;
  final String performed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prescribed', style: CohortTextStyles.eyebrow),
        Text(prescribed, style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.sm),
        Text('Performed', style: CohortTextStyles.eyebrow),
        Text(performed, style: CohortTextStyles.body),
      ],
    );
  }
}
