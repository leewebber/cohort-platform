import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/services/athlete_exercise_label_resolver.dart';
import '../models/active_performance_draft.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/training_block_result_status.dart';
import 'endurance_duration_field.dart';
import 'performance_numeric_field.dart';
import '../services/endurance_metrics_calculator.dart';
import '../services/performance_result_summary_formatter.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';

class PerformanceSaveIndicator extends StatelessWidget {
  const PerformanceSaveIndicator({
    super.key,
    required this.state,
    this.errorMessage,
  });

  final PerformanceSaveState state;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      PerformanceSaveState.idle => 'Ready to save',
      PerformanceSaveState.saving => 'Saving…',
      PerformanceSaveState.saved => 'Saved',
      PerformanceSaveState.error => errorMessage ?? 'Save failed',
    };

    return Text(label, style: CohortTextStyles.small);
  }
}

enum PerformanceSaveState { idle, saving, saved, error }

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
  });

  final BlockPerformanceDraft blockDraft;
  final ValueChanged<PerformanceResultData> onResultChanged;
  final void Function(String exerciseId) onAddSet;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  ) onUpdateSet;
  final void Function(String exerciseId, String setResultId) onDuplicateSet;
  final void Function(String exerciseId, String setResultId) onRemoveSet;
  final ValueChanged<int>? onApplyElapsedSeconds;
  final List<SessionExecutionExerciseSummary> linkedExercises;

  static bool showsCaptureFields(BlockPerformanceDraft blockDraft) {
    return _captureModeFor(blockDraft) != BlockCaptureMode.completion;
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
        Text('Performance', style: CohortTextStyles.eyebrow),
        const SizedBox(height: CohortSpacing.sm),
        _ResultEditorBody(
          blockDraft: blockDraft,
          linkedExercises: linkedExercises,
          onResultChanged: onResultChanged,
          onAddSet: onAddSet,
          onUpdateSet: onUpdateSet,
          onDuplicateSet: onDuplicateSet,
          onRemoveSet: onRemoveSet,
          onApplyElapsedSeconds: onApplyElapsedSeconds,
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
  });

  final BlockPerformanceDraft blockDraft;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final ValueChanged<PerformanceResultData> onResultChanged;
  final void Function(String exerciseId) onAddSet;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  ) onUpdateSet;
  final void Function(String exerciseId, String setResultId) onDuplicateSet;
  final void Function(String exerciseId, String setResultId) onRemoveSet;
  final ValueChanged<int>? onApplyElapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final mode = _effectiveCaptureMode(blockDraft);
    switch (mode) {
      case BlockCaptureMode.strength:
        return _StrengthEditor(
          blockDraft: blockDraft,
          linkedExercises: linkedExercises,
          onAddSet: onAddSet,
          onUpdateSet: onUpdateSet,
          onDuplicateSet: onDuplicateSet,
          onRemoveSet: onRemoveSet,
        );
      case BlockCaptureMode.amrap:
        return _AmrapEditor(
          result: blockDraft.resultData as AmrapResultData? ?? const AmrapResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.forTime:
        return _ForTimeEditor(
          result: blockDraft.resultData as ForTimeResultData? ??
              const ForTimeResultData(),
          onChanged: onResultChanged,
          onApplyElapsedSeconds: onApplyElapsedSeconds,
        );
      case BlockCaptureMode.interval:
        return _IntervalEditor(
          result: blockDraft.resultData as IntervalResultData? ??
              const IntervalResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.endurance:
        return _EnduranceEditor(
          result: blockDraft.resultData as EnduranceResultData? ??
              const EnduranceResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.rounds:
        return _RoundsEditor(
          result: blockDraft.resultData as RoundsResultData? ??
              const RoundsResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.customMetric:
        return _CustomMetricEditor(
          result: blockDraft.resultData as CustomMetricResultData? ??
              const CustomMetricResultData(),
          onChanged: onResultChanged,
        );
      case BlockCaptureMode.completion:
      case BlockCaptureMode.auto:
        return _CompletionEditor(
          result: blockDraft.resultData,
          onChanged: onResultChanged,
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
          onChanged: (value) => onChanged(
            result.copyWith(extraReps: int.tryParse(value) ?? 0),
          ),
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
          onChanged: (value) => onChanged(
            result.copyWith(elapsedSeconds: int.tryParse(value)),
          ),
        ),
        _MaterialSwitchListTile(
          title: 'Completed',
          value: result.completed,
          onChanged: (value) => onChanged(result.copyWith(completed: value)),
        ),
        if (onApplyElapsedSeconds != null)
          TextButton(
            onPressed: () =>
                onApplyElapsedSeconds!(result.elapsedSeconds ?? 0),
            child: const Text('Use timer elapsed time'),
          ),
      ],
    );
  }
}

class _IntervalEditor extends StatelessWidget {
  const _IntervalEditor({required this.result, required this.onChanged});
  final IntervalResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    return PerformanceNumericField(
      label:
          'Intervals completed${result.totalIntervals == null ? '' : ' / ${result.totalIntervals}'}',
      value: '${result.intervalsCompleted}',
      onChanged: (value) => onChanged(
        result.copyWith(intervalsCompleted: int.tryParse(value) ?? 0),
      ),
    );
  }
}

class _EnduranceEditor extends StatefulWidget {
  const _EnduranceEditor({required this.result, required this.onChanged});

  final EnduranceResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

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
          value: _units.contains(result.distanceUnit) ? result.distanceUnit : 'km',
          decoration: const InputDecoration(labelText: 'Distance unit'),
          items: _units
              .map(
                (unit) => DropdownMenuItem(value: unit, child: Text(unit)),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            widget.onChanged(result.copyWith(distanceUnit: value));
          },
        ),
        EnduranceDurationField(
          durationSeconds: result.durationSeconds,
          onDurationSecondsChanged: (seconds) => widget.onChanged(
            result.copyWith(durationSeconds: seconds),
          ),
        ),
        if (liveMetric != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(liveMetric.label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Text(liveMetric.value, style: CohortTextStyles.body),
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
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
          ),
          onChanged: (value) => widget.onChanged(
            result.copyWith(note: value.trim().isEmpty ? null : value.trim()),
          ),
        ),
      ],
    );
  }
}

class _DistanceEditor extends StatelessWidget {
  const _DistanceEditor({required this.result, required this.onChanged});
  final DistanceResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PerformanceNumericField(
          label: 'Distance (${result.distanceUnit})',
          value: result.distance?.toString() ?? '',
          allowDecimal: true,
          onChanged: (value) =>
              onChanged(result.copyWith(distance: double.tryParse(value))),
        ),
        PerformanceNumericField(
          label: 'Duration (seconds)',
          value: result.durationSeconds?.toString() ?? '',
          onChanged: (value) => onChanged(
            result.copyWith(durationSeconds: int.tryParse(value)),
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
          onChanged: (value) => onChanged(
            result.copyWith(extraReps: int.tryParse(value) ?? 0),
          ),
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
          onChanged: (value) => onChanged(
            result.copyWith(numericValue: double.tryParse(value)),
          ),
        ),
      ],
    );
  }
}

class _CompletionEditor extends StatelessWidget {
  const _CompletionEditor({required this.result, required this.onChanged});

  final PerformanceResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _StrengthEditor extends StatelessWidget {
  const _StrengthEditor({
    required this.blockDraft,
    required this.linkedExercises,
    required this.onAddSet,
    required this.onUpdateSet,
    required this.onDuplicateSet,
    required this.onRemoveSet,
  });

  final BlockPerformanceDraft blockDraft;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final void Function(String exerciseId) onAddSet;
  final void Function(
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft) update,
  ) onUpdateSet;
  final void Function(String exerciseId, String setResultId) onDuplicateSet;
  final void Function(String exerciseId, String setResultId) onRemoveSet;

  SessionExecutionExerciseSummary? _summaryFor(String exerciseId) {
    for (final summary in linkedExercises) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exercise in blockDraft.exerciseResults) ...[
          Text(_exerciseLabel(exercise), style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.sm),
          for (final set in exercise.sets)
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: PerformanceNumericField(
                      key: ValueKey('${set.setResultId}-reps'),
                      label: 'Set ${set.setNumber} reps',
                      value: set.reps?.toString() ?? '',
                      onChanged: (value) => onUpdateSet(
                        exercise.sourceExerciseId,
                        set.setResultId,
                        (current) =>
                            current.copyWith(reps: int.tryParse(value)),
                      ),
                    ),
                  ),
                  const SizedBox(width: CohortSpacing.sm),
                  Expanded(
                    child: PerformanceNumericField(
                      key: ValueKey('${set.setResultId}-load'),
                      label: 'Load (${set.loadUnit})',
                      value: set.load?.toString() ?? '',
                      allowDecimal: true,
                      onChanged: (value) => onUpdateSet(
                        exercise.sourceExerciseId,
                        set.setResultId,
                        (current) =>
                            current.copyWith(load: double.tryParse(value)),
                      ),
                    ),
                  ),
                  Checkbox(
                    value: set.completed,
                    onChanged: (value) => onUpdateSet(
                      exercise.sourceExerciseId,
                      set.setResultId,
                      (current) => current.copyWith(completed: value ?? false),
                    ),
                  ),
                ],
              ),
            ),
          CohortButton(
            label: exercise.sets.isEmpty ? 'Add first set' : 'Add set',
            onPressed: () => onAddSet(exercise.sourceExerciseId),
          ),
          const SizedBox(height: CohortSpacing.md),
        ],
      ],
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
          Text(record.sessionSnapshot.sessionTitle,
              style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            '${record.status.displayLabel} · ${_formatDate(date)}',
            style: CohortTextStyles.small,
          ),
          if (record.sessionSnapshot.programmeContextLabel != null)
            Text(record.sessionSnapshot.programmeContextLabel!,
                style: CohortTextStyles.small),
          if (record.durationSeconds != null)
            Text('Duration ${_formatDuration(record.durationSeconds!)}',
                style: CohortTextStyles.small),
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
