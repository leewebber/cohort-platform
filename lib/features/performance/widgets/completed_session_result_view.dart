import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.title, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            '${block.statusLabel} · ${block.summary}',
            style: CohortTextStyles.small,
          ),
          if (block.isSimpleCompletion) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(block.summary, style: CohortTextStyles.body),
          ] else ...[
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

  @override
  Widget build(BuildContext context) {
    final setNumbers = <int>{
      for (final set in exercise.sets) set.setNumber,
      for (final set in exercise.previousSets) set.setNumber,
    }.toList()..sort();
    final todayByNumber = {
      for (final set in exercise.sets) set.setNumber: set,
    };
    final previousByNumber = {
      for (final set in exercise.previousSets) set.setNumber: set,
    };

    return Padding(
      padding: const EdgeInsets.only(
        left: CohortSpacing.xs,
        bottom: CohortSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: Text('Today', style: CohortTextStyles.eyebrow)),
              Expanded(
                child: Text('Previous', style: CohortTextStyles.eyebrow),
              ),
            ],
          ),
          const SizedBox(height: CohortSpacing.xs),
          for (final number in setNumbers) ...[
            _SetComparisonRow(
              setNumber: number,
              today: todayByNumber[number],
              previous: previousByNumber[number],
            ),
            const SizedBox(height: CohortSpacing.xs),
          ],
          if (exercise.bestSetLabel != null)
            Text(exercise.bestSetLabel!, style: CohortTextStyles.small),
          if (exercise.estimated1RmLabel != null)
            Text(exercise.estimated1RmLabel!, style: CohortTextStyles.small),
          if (exercise.volumeLabel != null)
            Text(exercise.volumeLabel!, style: CohortTextStyles.small),
          if (exercise.deltaLabels.isNotEmpty)
            Text(
              exercise.deltaLabels.join(' · '),
              style: CohortTextStyles.muted,
            ),
        ],
      ),
    );
  }
}

class _SetComparisonRow extends StatelessWidget {
  const _SetComparisonRow({
    required this.setNumber,
    required this.today,
    required this.previous,
  });

  final int setNumber;
  final CompletedSetResultProjection? today;
  final CompletedSetResultProjection? previous;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text('Set $setNumber', style: CohortTextStyles.muted),
        ),
        Expanded(child: Text(_format(today), style: CohortTextStyles.small)),
        Expanded(child: Text(_format(previous), style: CohortTextStyles.small)),
      ],
    );
  }

  static String _format(CompletedSetResultProjection? set) {
    if (set == null) return '—';
    final parts = <String>[
      if (set.repsLabel != null) set.repsLabel!,
      if (set.loadLabel != null) set.loadLabel!,
      set.stateLabel,
    ];
    return parts.join(' · ');
  }
}
