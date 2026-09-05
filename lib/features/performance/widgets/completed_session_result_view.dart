import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import '../repositories/in_memory_performance_record_store.dart';
import '../repositories/performance_record_store.dart';
import '../services/completed_session_result_projection.dart';
import '../services/endurance_metrics_calculator.dart';
import '../models/circuit_station_actual.dart';
import '../services/circuit_set_sync.dart';
import '../services/interval_set_sync.dart';
import 'circuit_capture_editor.dart';
import '../services/performance_correction_service.dart';
import '../services/running_pace_plausibility.dart';
import 'endurance_duration_field.dart';
import 'implausible_running_pace_warning.dart';
import 'interval_pace_field.dart';
import 'performance_capture_widgets.dart';
import 'performance_numeric_field.dart';

class CompletedSessionResultView extends StatefulWidget {
  const CompletedSessionResultView({
    super.key,
    required this.record,
    this.athleteHistory = const [],
    this.programmePosition,
    this.statusMessage,
    this.performanceRecordStore,
    this.onRecordCorrected,
  });

  final TrainingSessionRecord record;
  final List<TrainingSessionRecord> athleteHistory;
  final String? programmePosition;
  final String? statusMessage;
  final PerformanceRecordStore? performanceRecordStore;
  final ValueChanged<TrainingSessionRecord>? onRecordCorrected;

  @override
  State<CompletedSessionResultView> createState() =>
      _CompletedSessionResultViewState();
}

class _CompletedSessionResultViewState
    extends State<CompletedSessionResultView> {
  late TrainingSessionRecord _record = widget.record;
  late List<TrainingSessionRecord> _history = widget.athleteHistory;
  PerformanceCorrectionDraft? _draft;
  bool _saving = false;
  String? _confirmation;

  @override
  void didUpdateWidget(covariant CompletedSessionResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.recordId != widget.record.recordId ||
        oldWidget.record.lastCorrectedAt != widget.record.lastCorrectedAt ||
        oldWidget.record.updatedAt != widget.record.updatedAt) {
      _record = widget.record;
      _history = widget.athleteHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projection = CompletedSessionResultProjection.fromRecords(
      record: _record,
      athleteHistory: _history,
    );
    final editing = _draft != null;
    return ListView(
      key: const ValueKey('completed-session-result'),
      padding: const EdgeInsets.all(CohortSpacing.lg),
      children: [
        Text(
          editing ? 'EDIT RESULTS' : 'COMPLETED SESSION',
          style: CohortTextStyles.sectionLabel,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(projection.sessionTitle, style: CohortTextStyles.h1),
        if (widget.programmePosition != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(widget.programmePosition!, style: CohortTextStyles.muted),
        ],
        const SizedBox(height: CohortSpacing.lg),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Session summary', style: CohortTextStyles.cardTitle),
              if (projection.completedAt case final completedAt?) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  'Completed ${formatCompletedClock(completedAt)}',
                  style: CohortTextStyles.body,
                ),
              ],
              if (projection.lastCorrectedAt case final correctedAt?) ...[
                const SizedBox(height: CohortSpacing.xs),
                Semantics(
                  label:
                      'Edited ${formatCompletedClock(correctedAt)}',
                  child: Text(
                    'Edited · ${formatCompletedClock(correctedAt)}',
                    style: CohortTextStyles.small,
                  ),
                ),
              ],
              if (projection.durationSeconds case final duration?) ...[
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  'Duration ${formatCompletedDuration(duration)}',
                  style: CohortTextStyles.body,
                ),
              ],
              if (projection.overallRpe case final rpe?) ...[
                const SizedBox(height: CohortSpacing.xs),
                Text('RPE $rpe', style: CohortTextStyles.body),
              ],
              const SizedBox(height: CohortSpacing.xs),
              Text(
                '${projection.completedBlockCount} completed · '
                '${projection.skippedBlockCount} skipped · '
                '${projection.incompleteBlockCount} incomplete',
                style: CohortTextStyles.small,
              ),
              if (widget.statusMessage != null) ...[
                const SizedBox(height: CohortSpacing.md),
                Text(widget.statusMessage!, style: CohortTextStyles.body),
              ],
              if (_confirmation != null) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  _confirmation!,
                  key: const ValueKey('correction-confirmation'),
                  style: CohortTextStyles.body,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CohortSpacing.xl),
        const SectionTitle('Results'),
        const SizedBox(height: CohortSpacing.md),
        if (editing)
          ..._editChildren(_draft!)
        else ...[
          for (final block in projection.blocks) ...[
            _CompletedBlockCard(block: block),
            const SizedBox(height: CohortSpacing.md),
          ],
          TextButton(
            key: const ValueKey('edit-results'),
            onPressed: _enterCorrection,
            child: const Text('Edit results'),
          ),
        ],
      ],
    );
  }

  List<Widget> _editChildren(PerformanceCorrectionDraft draft) {
    final warning = draft.runningWarning();
    return [
      if (warning != null) ...[
        ImplausibleRunningPaceWarning(warning: warning),
        const SizedBox(height: CohortSpacing.md),
      ],
      for (final block in draft.blockResults) ...[
        _CorrectionBlockEditor(
          block: block,
          onResultChanged: (data) => _replaceBlockResult(block.blockResultId, data),
          onSetChanged: _replaceSet,
        ),
        const SizedBox(height: CohortSpacing.md),
      ],
      SessionRpeSelector(
        value: draft.overallRpe,
        onChanged: (value) => setState(() => draft.overallRpe = value),
      ),
      const SizedBox(height: CohortSpacing.md),
      TextFormField(
        key: const ValueKey('correction-athlete-note'),
        initialValue: draft.athleteNote ?? '',
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Athlete note (optional)'),
        onChanged: (value) =>
            draft.athleteNote = value.trim().isEmpty ? null : value.trim(),
      ),
      const SizedBox(height: CohortSpacing.lg),
      CohortButton(
        key: const ValueKey('save-corrected-results'),
        label: _saving ? 'Saving…' : 'Save results',
        onPressed: _saving ? null : _saveCorrection,
      ),
      const SizedBox(height: CohortSpacing.sm),
      TextButton(
        key: const ValueKey('cancel-edit-results'),
        onPressed: _saving ? null : _cancelCorrection,
        child: const Text('Cancel'),
      ),
    ];
  }

  void _enterCorrection() {
    setState(() {
      _draft = PerformanceCorrectionDraft(_record);
      _confirmation = null;
    });
  }

  void _cancelCorrection() {
    setState(() => _draft = null);
  }

  void _replaceBlockResult(String blockResultId, PerformanceResultData data) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      draft.blockResults = [
        for (final block in draft.blockResults)
          block.blockResultId == blockResultId
              ? block.copyWith(
                  resultData: data,
                  exerciseResults: data is IntervalResultData
                      ? [
                          for (final exercise in block.exerciseResults)
                            exercise.copyWith(
                              setResults: [
                                for (final set in exercise.setResults)
                                  data.intervals
                                          .where(
                                            (row) =>
                                                row.ordinal == set.setNumber,
                                          )
                                          .isEmpty
                                      ? set
                                      : IntervalSetSync.applyToRecordedSet(
                                          set,
                                          data.intervals.firstWhere(
                                            (row) =>
                                                row.ordinal == set.setNumber,
                                          ),
                                        ),
                              ],
                            ),
                        ]
                      : data is CircuitResultData
                      ? [
                          for (final exercise in block.exerciseResults)
                            exercise.copyWith(
                              setResults: [
                                for (final set in exercise.setResults)
                                  data.stations
                                          .where(
                                            (row) =>
                                                row.stationId ==
                                                    exercise.sourceExerciseId &&
                                                row.round == set.setNumber,
                                          )
                                          .isEmpty
                                      ? set
                                      : CircuitSetSync.applyToRecordedSet(
                                          set,
                                          data.stations.firstWhere(
                                            (row) =>
                                                row.stationId ==
                                                    exercise.sourceExerciseId &&
                                                row.round == set.setNumber,
                                          ),
                                        ),
                              ],
                            ),
                        ]
                      : block.exerciseResults,
                )
              : block,
      ];
    });
  }

  void _replaceSet(
    String exerciseResultId,
    String setResultId,
    TrainingSetResult Function(TrainingSetResult) update,
  ) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      draft.blockResults = [
        for (final block in draft.blockResults)
          block.copyWith(
            exerciseResults: [
              for (final exercise in block.exerciseResults)
                exercise.exerciseResultId == exerciseResultId
                    ? exercise.copyWith(
                        setResults: [
                          for (final set in exercise.setResults)
                            set.setResultId == setResultId
                                ? update(set)
                                : set,
                        ],
                      )
                    : exercise,
            ],
          ),
      ];
    });
  }

  Future<void> _saveCorrection() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final warning = draft.runningWarning();
    if (warning != null && !draft.acknowledgeImplausibleRunningPace) {
      final confirmed = await confirmImplausibleRunningPace(
        context: context,
        warning: warning,
      );
      if (!confirmed) return;
      draft.acknowledgeImplausibleRunningPace = true;
    }
    setState(() => _saving = true);
    try {
      final store =
          widget.performanceRecordStore ?? InMemoryPerformanceRecordStore();
      if (store is InMemoryPerformanceRecordStore &&
          await store.getById(_record.recordId) == null) {
        store.put(_record);
      }
      final corrected = await store.correctCompleted(draft);
      if (!mounted) return;
      setState(() {
        _record = corrected;
        _history = [
          for (final item in _history)
            item.recordId == corrected.recordId ? corrected : item,
        ];
        _draft = null;
        _saving = false;
        _confirmation = 'Results updated';
      });
      widget.onRecordCorrected?.call(corrected);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _CompletedBlockCard extends StatelessWidget {
  const _CompletedBlockCard({required this.block});

  final CompletedBlockResultProjection block;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      key: ValueKey('completed-block-${block.title}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.title, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          Text(block.summary, style: CohortTextStyles.small),
          if (block.interval != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            _CompletedIntervalAccordion(interval: block.interval!),
          ] else if (block.circuit != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            _CompletedCircuitAccordion(circuit: block.circuit!),
          ] else if (!block.isSimpleCompletion) ...[
            for (final exercise in block.exercises) ...[
              const SizedBox(height: CohortSpacing.sm),
              _CompletedExerciseAccordion(
                key: ValueKey(
                  'completed-exercise-${exercise.sourceExerciseId}',
                ),
                exercise: exercise,
              ),
            ],
          ],
          if (block.prescriptionContext != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Text('Prescription', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.xs),
            Text(block.prescriptionContext!, style: CohortTextStyles.muted),
          ],
        ],
      ),
    );
  }
}

class _CompletedCircuitAccordion extends StatefulWidget {
  const _CompletedCircuitAccordion({required this.circuit});

  final CompletedCircuitBlockProjection circuit;

  @override
  State<_CompletedCircuitAccordion> createState() =>
      _CompletedCircuitAccordionState();
}

class _CompletedCircuitAccordionState extends State<_CompletedCircuitAccordion> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final circuit = widget.circuit;
    final grouped = <int, List<CircuitStationActual>>{};
    for (final row in circuit.result.stations) {
      grouped.putIfAbsent(row.round, () => []).add(row);
    }
    final rounds = grouped.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  circuit.result.format == 'emom'
                      ? 'EMOM performance'
                      : 'Circuit performance',
                  style: CohortTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _ComparisonBadge(status: circuit.comparisonStatus),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        if (circuit.primaryLabel != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(circuit.primaryLabel!, style: CohortTextStyles.small),
        ],
        if (_expanded)
          for (final round in rounds) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              circuit.result.format == 'emom' ? 'Minute $round' : 'Round $round',
              style: CohortTextStyles.body,
            ),
            for (final row in grouped[round]!)
              Text(
                '${row.displayName}: ${_stationActualLabel(row)}',
                style: CohortTextStyles.small,
              ),
          ],
      ],
    );
  }

  static String _stationActualLabel(CircuitStationActual row) {
    if (!row.hasRecordedActual) return 'Not recorded';
    return switch (row.primaryMetric) {
      CircuitStationMetric.calories => '${row.calories} cal',
      CircuitStationMetric.reps => '${row.reps} reps',
      CircuitStationMetric.distance =>
        '${row.distance} ${row.distanceUnit}'
            '${row.load == null ? '' : ' · ${row.load} ${row.loadUnit ?? 'kg'}'}'
            '${row.durationSeconds == null ? '' : ' · ${row.durationSeconds}s'}'
            '${row.calories == null ? '' : ' · ${row.calories} cal'}',
      CircuitStationMetric.duration => '${row.durationSeconds}s',
      CircuitStationMetric.load => '${row.load} ${row.loadUnit ?? 'kg'}',
      CircuitStationMetric.completion => 'Completed',
    };
  }
}

class _CompletedIntervalAccordion extends StatefulWidget {
  const _CompletedIntervalAccordion({required this.interval});

  final CompletedIntervalBlockProjection interval;

  @override
  State<_CompletedIntervalAccordion> createState() =>
      _CompletedIntervalAccordionState();
}

class _CompletedIntervalAccordionState
    extends State<_CompletedIntervalAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final interval = widget.interval;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Semantics(
            button: true,
            expanded: _expanded,
            label:
                'Interval performance, ${interval.comparisonStatus.semanticLabel}',
            hint: _expanded
                ? 'Collapse interval detail'
                : 'Expand interval detail',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Interval performance',
                    style: CohortTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _ComparisonBadge(status: interval.comparisonStatus),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: CohortSpacing.sm),
          for (final row in interval.rows)
            DecoratedBox(
              decoration: BoxDecoration(
                color: row.isFastest
                    ? CohortColors.oliveSoft
                    : Colors.transparent,
                borderRadius: CohortRadius.smallRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CohortSpacing.xs,
                  vertical: CohortSpacing.sm,
                ),
                child: Semantics(
                  label: [
                    'Interval ${row.ordinal}',
                    row.paceLabel,
                    if (row.isFastest) 'Fastest interval',
                    if (row.previousPaceLabel != null)
                      'Previous ${row.previousPaceLabel}',
                  ].join(', '),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Interval ${row.ordinal}',
                          style: CohortTextStyles.muted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.paceLabel,
                          style: CohortTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.previousPaceLabel == null
                              ? ''
                              : row.previousPaceLabel!,
                          style: CohortTextStyles.small,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (interval.metrics.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            _PerformanceMetricsRow(metrics: interval.metrics),
          ],
          if (interval.personalRecordLabel != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'PR · ${interval.personalRecordLabel}',
              key: const ValueKey('interval-pr-label'),
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.phosphorHighlight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _CompletedExerciseAccordion extends StatefulWidget {
  const _CompletedExerciseAccordion({super.key, required this.exercise});

  final CompletedExerciseResultProjection exercise;

  @override
  State<_CompletedExerciseAccordion> createState() =>
      _CompletedExerciseAccordionState();
}

class _CompletedExerciseAccordionState
    extends State<_CompletedExerciseAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusableActionDetector(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          mouseCursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(8),
              child: Semantics(
                button: true,
                expanded: _expanded,
                explicitChildNodes: true,
                label:
                    '${exercise.displayName}, ${exercise.comparisonStatus.semanticLabel}',
                hint: _expanded ? 'Collapse exercise' : 'Expand exercise',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CohortSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise.displayName,
                          style: CohortTextStyles.body.copyWith(
                            color: CohortColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: CohortSpacing.sm),
                      _ComparisonBadge(status: exercise.comparisonStatus),
                      const SizedBox(width: CohortSpacing.xs),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: CohortColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_expanded) _CompletedExerciseDetail(exercise: exercise),
      ],
    );
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }
}

class _ComparisonBadge extends StatelessWidget {
  const _ComparisonBadge({required this.status});

  final StrengthExerciseComparisonStatus status;

  @override
  Widget build(BuildContext context) {
    final visual = _badgeVisual(status);
    return Semantics(
      container: true,
      label: status.semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visual.foreground.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CohortSpacing.sm,
            vertical: 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(visual.icon, size: 14, color: visual.foreground),
              const SizedBox(width: 4),
              Text(
                status.label,
                style: CohortTextStyles.small.copyWith(
                  color: visual.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({IconData icon, Color foreground, Color background}) _badgeVisual(
    StrengthExerciseComparisonStatus status,
  ) {
    return switch (status) {
      StrengthExerciseComparisonStatus.improved => (
        icon: Icons.trending_up,
        foreground: CohortColors.phosphorHighlight,
        background: CohortColors.oliveDark,
      ),
      StrengthExerciseComparisonStatus.maintained => (
        icon: Icons.trending_flat,
        foreground: CohortColors.olive,
        background: CohortColors.oliveSoft,
      ),
      StrengthExerciseComparisonStatus.belowPrevious => (
        icon: Icons.trending_down,
        foreground: CohortColors.warning,
        background: const Color(0xFF22180C),
      ),
      StrengthExerciseComparisonStatus.baseline => (
        icon: Icons.flag_outlined,
        foreground: CohortColors.textSecondary,
        background: CohortColors.surfaceRaised,
      ),
      StrengthExerciseComparisonStatus.notComparable => (
        icon: Icons.compare_arrows,
        foreground: CohortColors.textMuted,
        background: CohortColors.surfaceRaised,
      ),
    };
  }
}

class _CompletedExerciseDetail extends StatelessWidget {
  const _CompletedExerciseDetail({required this.exercise});

  final CompletedExerciseResultProjection exercise;

  static const _wideBreakpoint = 560.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < _wideBreakpoint;
          final today = _SetHistoryPanel(
            key: ValueKey('today-panel-${exercise.sourceExerciseId}'),
            title: 'TODAY',
            sets: exercise.sets,
            exerciseId: exercise.sourceExerciseId,
            panelKey: 'today',
          );
          final previous = exercise.previousSets.isEmpty
              ? null
              : _SetHistoryPanel(
                  key: ValueKey(
                    'last-time-panel-${exercise.sourceExerciseId}',
                  ),
                  title: 'LAST TIME',
                  subtitle: exercise.previousCompletedAt == null
                      ? null
                      : formatCompletedDate(exercise.previousCompletedAt!),
                  sets: exercise.previousSets,
                  exerciseId: exercise.sourceExerciseId,
                  panelKey: 'last-time',
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (previous == null || stacked) ...[
                today,
                if (previous != null) ...[
                  const SizedBox(height: CohortSpacing.md),
                  previous,
                ],
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: today),
                    const SizedBox(width: CohortSpacing.md),
                    Expanded(child: previous),
                  ],
                ),
              if (exercise.metrics.isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.md),
                _PerformanceMetricsRow(metrics: exercise.metrics),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SetHistoryPanel extends StatelessWidget {
  const _SetHistoryPanel({
    super.key,
    required this.title,
    required this.sets,
    required this.exerciseId,
    required this.panelKey,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<CompletedSetResultProjection> sets;
  final String exerciseId;
  final String panelKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CohortTextStyles.sectionLabel),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: CohortTextStyles.muted),
        ],
        const SizedBox(height: CohortSpacing.sm),
        for (final set in sets) ...[
          _RecordedSetRow(
            key: ValueKey('$panelKey-set-$exerciseId-${set.setNumber}'),
            set: set,
          ),
          const SizedBox(height: CohortSpacing.xs),
        ],
      ],
    );
  }
}

class _RecordedSetRow extends StatelessWidget {
  const _RecordedSetRow({super.key, required this.set});

  final CompletedSetResultProjection set;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: [
        'Set ${set.setNumber}',
        if (set.reps != null) '${set.reps} reps',
        if (set.loadLabel != null) set.loadLabel,
        set.stateLabel,
        if (set.isBestSet) 'Best completed set',
      ].join(', '),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: set.isBestSet ? CohortColors.oliveSoft : Colors.transparent,
          borderRadius: CohortRadius.smallRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CohortSpacing.xs,
            vertical: CohortSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Set ${set.setNumber}',
                  style: CohortTextStyles.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  set.reps == null ? '—' : '${set.reps} ×',
                  style: CohortTextStyles.body.copyWith(
                    color: CohortColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  set.loadLabel ?? '—',
                  style: CohortTextStyles.body.copyWith(
                    color: CohortColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  set.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: set.completed
                      ? CohortColors.olive
                      : CohortColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceMetricsRow extends StatelessWidget {
  const _PerformanceMetricsRow({required this.metrics});

  final List<CompletedPerformanceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 400;
        final children = [
          for (final metric in metrics)
            KeyedSubtree(
              key: ValueKey('metric-${metric.key}'),
              child: _PerformanceMetricTile(metric: metric),
            ),
        ];
        if (stacked) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: CohortSpacing.sm),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: CohortSpacing.sm),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PerformanceMetricTile extends StatelessWidget {
  const _PerformanceMetricTile({required this.metric});

  final CompletedPerformanceMetric metric;

  @override
  Widget build(BuildContext context) {
    final tone = _toneColor(metric.tone);
    return Semantics(
      container: true,
      label: [
        metric.title,
        metric.value,
        if (metric.deltaLabel != null) metric.deltaLabel,
      ].join(', '),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CohortColors.surfaceRaised,
          borderRadius: CohortRadius.smallRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(metric.title.toUpperCase(), style: CohortTextStyles.tileLabel),
              const SizedBox(height: CohortSpacing.xs),
              Text(
                metric.value,
                style: CohortTextStyles.tileValue.copyWith(fontSize: 15),
              ),
              if (metric.deltaLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  metric.deltaLabel!,
                  style: CohortTextStyles.muted.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _toneColor(StrengthMetricTone tone) {
    return switch (tone) {
      StrengthMetricTone.positive => CohortColors.phosphorHighlight,
      StrengthMetricTone.neutral => CohortColors.olive,
      StrengthMetricTone.negative => CohortColors.warning,
      StrengthMetricTone.none => CohortColors.textMuted,
    };
  }
}

class _CorrectionBlockEditor extends StatelessWidget {
  const _CorrectionBlockEditor({
    required this.block,
    required this.onResultChanged,
    required this.onSetChanged,
  });

  final TrainingBlockResult block;
  final ValueChanged<PerformanceResultData> onResultChanged;
  final void Function(
    String exerciseResultId,
    String setResultId,
    TrainingSetResult Function(TrainingSetResult),
  )
  onSetChanged;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.blockSnapshot.title, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.sm),
          if (block.resultData is EnduranceResultData)
            _CorrectionEnduranceFields(
              result: block.resultData! as EnduranceResultData,
              blockTitle: block.blockSnapshot.title,
              workoutFormat: block.blockSnapshot.workoutFormat.name,
              onChanged: onResultChanged,
            )
          else if (block.resultData is DistanceResultData)
            _CorrectionDistanceFields(
              result: block.resultData! as DistanceResultData,
              onChanged: onResultChanged,
            )
          else if (block.resultData is IntervalResultData)
            _CorrectionIntervalFields(
              result: block.resultData! as IntervalResultData,
              onChanged: onResultChanged,
            )
          else if (block.resultData is CircuitResultData)
            CircuitCaptureEditor(
              result: block.resultData! as CircuitResultData,
              onChanged: onResultChanged,
            ),
          if ((block.resultData is! IntervalResultData ||
                  !(block.resultData! as IntervalResultData)
                      .usesPerIntervalCapture) &&
              block.resultData is! CircuitResultData)
            for (final exercise in block.exerciseResults) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(
                exercise.exerciseSnapshot.displayName,
                style: CohortTextStyles.body,
              ),
              for (final set in exercise.setResults)
                _CorrectionSetRow(
                  set: set,
                  loadKind: exercise.exerciseSnapshot.loadKind,
                  onChanged: (update) => onSetChanged(
                    exercise.exerciseResultId,
                    set.setResultId,
                    update,
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _CorrectionIntervalFields extends StatelessWidget {
  const _CorrectionIntervalFields({
    required this.result,
    required this.onChanged,
  });

  final IntervalResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!result.usesPerIntervalCapture) {
      return PerformanceNumericField(
        label: 'Intervals completed',
        value: '${result.intervalsCompleted}',
        onChanged: (value) => onChanged(
          result.copyWith(intervalsCompleted: int.tryParse(value) ?? 0),
        ),
      );
    }
    return Column(
      children: [
        for (final row in result.intervals) ...[
          Text('Interval ${row.ordinal}', style: CohortTextStyles.small),
          IntervalPaceField(
            secondsPerKm: row.paceSecondsPerKm,
            enabled: row.state != IntervalWorkState.paceUnavailable,
            onChanged: (pace) => onChanged(
              result.replaceInterval(
                row.copyWith(
                  paceSecondsPerKm: pace,
                  clearPace: pace == null,
                  state: pace == null &&
                          row.state == IntervalWorkState.completed
                      ? IntervalWorkState.pending
                      : row.state,
                ),
              ),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pace unavailable'),
            value: row.state == IntervalWorkState.paceUnavailable,
            onChanged: (value) => onChanged(
              result.replaceInterval(
                row.copyWith(
                  state: value == true
                      ? IntervalWorkState.paceUnavailable
                      : IntervalWorkState.pending,
                  clearPace: value == true,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CorrectionEnduranceFields extends StatelessWidget {
  const _CorrectionEnduranceFields({
    required this.result,
    required this.onChanged,
    required this.blockTitle,
    required this.workoutFormat,
  });

  final EnduranceResultData result;
  final ValueChanged<PerformanceResultData> onChanged;
  final String blockTitle;
  final String workoutFormat;

  @override
  Widget build(BuildContext context) {
    final liveMetric = EnduranceMetricsCalculator.liveMetric(
      distance: result.distance,
      distanceUnit: result.distanceUnit,
      durationSeconds: result.durationSeconds,
    );
    final warning = RunningPacePlausibility.warning(
      distance: result.distance,
      distanceUnit: result.distanceUnit,
      durationSeconds: result.durationSeconds,
      workoutFormat: workoutFormat,
      blockTitle: blockTitle,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PerformanceNumericField(
          label: 'Distance',
          value: result.distance?.toString() ?? '',
          allowDecimal: true,
          onChanged: (value) =>
              onChanged(result.copyWith(distance: double.tryParse(value))),
        ),
        EnduranceDurationField(
          key: const ValueKey('correction-duration'),
          durationSeconds: result.durationSeconds,
          onDurationSecondsChanged: (seconds) =>
              onChanged(result.copyWith(durationSeconds: seconds)),
        ),
        if (liveMetric != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text('${liveMetric.label}: ${liveMetric.value}', style: CohortTextStyles.body),
        ],
        if (warning != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          ImplausibleRunningPaceWarning(warning: warning),
        ],
        PerformanceNumericField(
          label: 'Average heart rate',
          value: result.averageHeartRate?.toString() ?? '',
          onChanged: (value) => onChanged(
            result.copyWith(averageHeartRate: int.tryParse(value)),
          ),
        ),
      ],
    );
  }
}

class _CorrectionDistanceFields extends StatelessWidget {
  const _CorrectionDistanceFields({
    required this.result,
    required this.onChanged,
  });

  final DistanceResultData result;
  final ValueChanged<PerformanceResultData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PerformanceNumericField(
          label: 'Distance',
          value: result.distance?.toString() ?? '',
          allowDecimal: true,
          onChanged: (value) =>
              onChanged(result.copyWith(distance: double.tryParse(value))),
        ),
        EnduranceDurationField(
          durationSeconds: result.durationSeconds,
          onDurationSecondsChanged: (seconds) =>
              onChanged(result.copyWith(durationSeconds: seconds)),
        ),
      ],
    );
  }
}

class _CorrectionSetRow extends StatelessWidget {
  const _CorrectionSetRow({
    required this.set,
    required this.loadKind,
    required this.onChanged,
  });

  final TrainingSetResult set;
  final StrengthActualLoadKind loadKind;
  final ValueChanged<TrainingSetResult Function(TrainingSetResult)> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CohortSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set ${set.setNumber}', style: CohortTextStyles.eyebrow),
          PerformanceNumericField(
            label: 'Reps',
            value: set.reps?.toString() ?? '',
            onChanged: (value) => onChanged(
              (current) => current.copyWith(reps: int.tryParse(value)),
            ),
          ),
          if (loadKind.expectsExternalLoad)
            PerformanceNumericField(
              label: 'Load',
              value: set.load?.toString() ?? '',
              allowDecimal: true,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                onChanged(
                  (current) => current.copyWith(
                    load: parsed,
                    loadUnit: current.loadUnit ?? 'kg',
                    clearLoad: parsed == null,
                  ),
                );
              },
            )
          else
            Text(
              loadKind == StrengthActualLoadKind.bodyweight
                  ? 'Bodyweight'
                  : 'No external load',
              style: CohortTextStyles.muted,
            ),
        ],
      ),
    );
  }
}
