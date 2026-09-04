import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../models/training_session_record.dart';
import '../services/completed_session_result_projection.dart';

class CompletedSessionResultView extends StatelessWidget {
  const CompletedSessionResultView({
    super.key,
    required this.record,
    this.athleteHistory = const [],
    this.programmePosition,
    this.statusMessage,
  });

  final TrainingSessionRecord record;
  final List<TrainingSessionRecord> athleteHistory;
  final String? programmePosition;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final projection = CompletedSessionResultProjection.fromRecords(
      record: record,
      athleteHistory: athleteHistory,
    );
    return ListView(
      key: const ValueKey('completed-session-result'),
      padding: const EdgeInsets.all(CohortSpacing.lg),
      children: [
        Text('COMPLETED SESSION', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        Text(projection.sessionTitle, style: CohortTextStyles.h1),
        if (programmePosition != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(programmePosition!, style: CohortTextStyles.muted),
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
              if (statusMessage != null) ...[
                const SizedBox(height: CohortSpacing.md),
                Text(statusMessage!, style: CohortTextStyles.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: CohortSpacing.xl),
        const SectionTitle('Results'),
        const SizedBox(height: CohortSpacing.md),
        for (final block in projection.blocks) ...[
          _CompletedBlockCard(block: block),
          const SizedBox(height: CohortSpacing.md),
        ],
      ],
    );
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
          Text(
            block.isSimpleCompletion
                ? block.summary
                : '${block.statusLabel} · ${block.summary}',
            style: CohortTextStyles.small,
          ),
          if (!block.isSimpleCompletion) ...[
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
