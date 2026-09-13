import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../session/services/block_timer_controller.dart';
import '../models/circuit_station_actual.dart';
import '../models/performance_result_data.dart';
import '../services/emom_score_contract.dart';
import 'performance_numeric_field.dart';

class EmomResultCapture extends StatefulWidget {
  const EmomResultCapture({
    super.key,
    required this.result,
    required this.onChanged,
    this.timer,
    this.showActions = true,
    this.saveLabel = 'Save result and complete block',
    this.secondaryLabel = 'Return to timer/review',
    this.onSave,
    this.onCancel,
    this.saving = false,
  });

  final CircuitResultData result;
  final ValueChanged<CircuitResultData> onChanged;
  final BlockTimerState? timer;
  final bool showActions;
  final String saveLabel;
  final String secondaryLabel;
  final ValueChanged<CircuitResultData>? onSave;
  final VoidCallback? onCancel;
  final bool saving;

  @override
  State<EmomResultCapture> createState() => _EmomResultCaptureState();
}

class _EmomResultCaptureState extends State<EmomResultCapture> {
  late int _completed;
  late bool? _prescribed;
  late bool _endedEarly;
  late final TextEditingController _noteController;
  late final TextEditingController _countController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.result.note ?? '');
    _countController = TextEditingController();
    _syncFrom(widget.result, initialize: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit(entered: false);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmomResultCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _syncFrom(widget.result);
    }
  }

  void _syncFrom(CircuitResultData result, {bool initialize = false}) {
    final total = result.targetRounds ?? 0;
    _completed = initialize && result.recordedCompletedRounds == null
        ? EmomScoreContract.suggestedCompletedIntervals(
            result: result,
            timer: widget.timer,
          )
        : (result.recordedCompletedRounds ?? 0).clamp(0, total == 0 ? 999 : total);
    _prescribed = result.prescribedTargetsUsed;
    _endedEarly = result.endedEarly ||
        (total > 0 && _completed < total);
    if (_noteController.text != (result.note ?? '')) {
      _noteController.text = result.note ?? '';
    }
    if (_countController.text != '$_completed') {
      _countController.text = '$_completed';
    }
  }

  int get _total => widget.result.targetRounds ?? 0;

  CircuitResultData _buildResult({required bool entered}) {
    var next = widget.result.copyWith(
      recordedCompletedRounds: _completed,
      prescribedTargetsUsed: _prescribed,
      endedEarly: _endedEarly || (_total > 0 && _completed < _total),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      scoreEntered: entered,
      clearEarlyEndReason: !(_endedEarly || (_total > 0 && _completed < _total)),
    );
    if (_prescribed == true) {
      next = next.copyWith(
        stations: [
          for (final row in next.stations)
            row.copyWith(
              clearCalories: true,
              clearReps: true,
              clearDistance: true,
              state: CircuitOccurrenceState.pending,
            ),
        ],
      );
    }
    return next;
  }

  void _emit({required bool entered}) {
    widget.onChanged(_buildResult(entered: entered));
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Semantics(
      container: true,
      label: 'EMOM result. $_completed of $_total intervals.',
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EMOM complete', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'How many intervals did you complete at the prescribed target?',
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.md),
            _IntervalStepper(
              completed: _completed,
              total: _total,
              controller: _countController,
              onChanged: (value) {
                setState(() {
                  _completed = value;
                  _endedEarly = _total > 0 && value < _total;
                  if (_countController.text != '$value') {
                    _countController.text = '$value';
                  }
                });
                _emit(entered: false);
              },
            ),
            const SizedBox(height: CohortSpacing.lg),
            Text(
              'Did you use the prescribed targets?',
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.sm),
            _ChoiceChip(
              label: 'Yes',
              selected: _prescribed == true,
              onTap: () {
                setState(() => _prescribed = true);
                _emit(entered: false);
              },
            ),
            const SizedBox(height: CohortSpacing.sm),
            _ChoiceChip(
              label: 'No, I adjusted them',
              selected: _prescribed == false,
              onTap: () {
                setState(() => _prescribed = false);
                _emit(entered: false);
              },
            ),
            if (_prescribed == true) ...[
              const SizedBox(height: CohortSpacing.md),
              for (final row in result.stations)
                Text(
                  EmomScoreContract.prescribedStationLine(row),
                  style: CohortTextStyles.small,
                ),
            ],
            if (_prescribed == false) ...[
              const SizedBox(height: CohortSpacing.md),
              for (final row in result.stations)
                if (EmomScoreContract.stationNeedsAdjustedActual(row))
                  Padding(
                    padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
                    child: PerformanceNumericField(
                      key: ValueKey('emom-adjusted-${row.stationId}'),
                      label:
                          '${row.displayName}: actual ${EmomScoreContract.stationMetricLabel(row)} per interval',
                      value: switch (row.primaryMetric) {
                        CircuitStationMetric.calories =>
                          row.calories?.toString() ?? '',
                        CircuitStationMetric.reps =>
                          row.reps?.toString() ?? '',
                        CircuitStationMetric.distance =>
                          row.distance?.toString() ?? '',
                        _ => '',
                      },
                      allowDecimal: row.primaryMetric != CircuitStationMetric.reps,
                      onChanged: (value) {
                        final parsedInt = int.tryParse(value);
                        final parsedDouble = double.tryParse(value);
                        final updated = switch (row.primaryMetric) {
                          CircuitStationMetric.calories => row.copyWith(
                            calories: parsedDouble,
                            clearCalories: parsedDouble == null,
                            state: parsedDouble == null
                                ? CircuitOccurrenceState.pending
                                : CircuitOccurrenceState.recorded,
                          ),
                          CircuitStationMetric.reps => row.copyWith(
                            reps: parsedInt,
                            clearReps: parsedInt == null,
                            state: parsedInt == null
                                ? CircuitOccurrenceState.pending
                                : CircuitOccurrenceState.recorded,
                          ),
                          CircuitStationMetric.distance => row.copyWith(
                            distance: parsedDouble,
                            clearDistance: parsedDouble == null,
                            state: parsedDouble == null
                                ? CircuitOccurrenceState.pending
                                : CircuitOccurrenceState.recorded,
                          ),
                          _ => row,
                        };
                        widget.onChanged(
                          _buildResult(entered: false).replaceStation(updated),
                        );
                      },
                    ),
                  ),
            ],
            const SizedBox(height: CohortSpacing.md),
            TextField(
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
              controller: _noteController,
              onChanged: (_) => _emit(entered: false),
            ),
            if (widget.showActions) ...[
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(
                label: widget.saveLabel,
                onPressed: widget.saving
                    ? null
                    : () {
                        final saved = _buildResult(entered: true);
                        widget.onChanged(saved);
                        widget.onSave?.call(saved);
                      },
              ),
              const SizedBox(height: CohortSpacing.sm),
              CohortButton(
                label: widget.secondaryLabel,
                variant: CohortButtonVariant.secondary,
                onPressed: widget.saving ? null : widget.onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({
    required this.completed,
    required this.total,
    required this.controller,
    required this.onChanged,
  });

  final int completed;
  final int total;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$completed of $total intervals',
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            onPressed: completed <= 0
                ? null
                : () => onChanged(completed - 1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$completed of $total',
                  style: CohortTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  width: 96,
                  child: TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '0',
                    ),
                    controller: controller,
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed == null) return;
                      onChanged(parsed.clamp(0, total == 0 ? parsed : total));
                    },
                  ),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onPressed: total > 0 && completed >= total
                ? null
                : () => onChanged(completed + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
      ),
    );
  }
}
