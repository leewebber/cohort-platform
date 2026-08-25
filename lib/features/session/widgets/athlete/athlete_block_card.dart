import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_button.dart';
import '../../../../core/widgets/cohort_card.dart';
import '../../../../models/session_block_type.dart';
import '../../../../models/strength_exercise_prescription.dart';
import '../../../../models/strength_prescription_formatter.dart';
import '../../models/session_execution_plan.dart';
import '../strength_prescription_display.dart';
import 'athlete_session_components.dart';

class AthleteBlockCard extends StatelessWidget {
  const AthleteBlockCard({
    super.key,
    required this.block,
    required this.isExpanded,
    required this.isActive,
    required this.isComplete,
    required this.onToggleExpanded,
    required this.onMarkComplete,
    required this.onReopen,
    required this.onLaunchTimer,
    required this.onOpenExercise,
    this.showActions = true,
    this.exerciseInfoOpensDetail = false,
    this.performanceSection,
    this.performanceReplacesExerciseList = false,
    this.recordedResultSummary,
    this.showBlockNavigation = false,
    this.onPrevious,
    this.onNext,
  });

  final SessionExecutionBlock block;
  final bool isExpanded;
  final bool isActive;
  final bool isComplete;
  final VoidCallback onToggleExpanded;
  final VoidCallback onMarkComplete;
  final VoidCallback onReopen;
  final VoidCallback? onLaunchTimer;
  final ValueChanged<SessionExecutionExerciseSummary> onOpenExercise;
  final bool showActions;
  final bool exerciseInfoOpensDetail;
  final Widget? performanceSection;

  /// Active per-exercise controls include the movement and prescription, so
  /// rendering the structured summary list as well would duplicate each row.
  final bool performanceReplacesExerciseList;

  /// A completed occurrence may attach its recorded block result without
  /// rendering a second exercise list.
  final String? recordedResultSummary;
  final bool showBlockNavigation;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? CohortColors.olive
        : isComplete
        ? CohortColors.success.withValues(alpha: 0.5)
        : CohortColors.border;

    return CohortCard(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(CohortSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggleExpanded,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(block.title, style: CohortTextStyles.cardTitle),
                        Text(
                          block.blockTypeLabel,
                          style: CohortTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                  if (block.workoutFormatLabel != null)
                    WorkoutFormatBadge(label: block.workoutFormatLabel!),
                  const SizedBox(width: CohortSpacing.sm),
                  Icon(
                    isComplete
                        ? Icons.check_circle
                        : isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: isComplete
                        ? CohortColors.success
                        : CohortColors.textSecondary,
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: CohortSpacing.md),
              WorkoutContentText(content: block.content),
              if (block.timerSummary != null) ...[
                const SizedBox(height: CohortSpacing.sm),
                TimerSummaryText(summary: block.timerSummary!),
              ],
              if (block.linkedExercises.isNotEmpty &&
                  !performanceReplacesExerciseList) ...[
                const SizedBox(height: CohortSpacing.md),
                _ExecutionExerciseList(
                  exercises: block.linkedExercises,
                  onOpenExercise: onOpenExercise,
                  exerciseInfoOpensDetail: exerciseInfoOpensDetail,
                ),
              ],
              if (block.coachNotes != null &&
                  !block.blockType.supportsStructuredStrengthPrescription) ...[
                const SizedBox(height: CohortSpacing.md),
                Text('Coach notes', style: CohortTextStyles.eyebrow),
                const SizedBox(height: CohortSpacing.xs),
                Text(block.coachNotes!, style: CohortTextStyles.body),
              ],
              if (performanceSection != null) ...[
                const SizedBox(height: CohortSpacing.lg),
                performanceSection!,
              ],
              if (recordedResultSummary?.trim().isNotEmpty == true) ...[
                const SizedBox(height: CohortSpacing.md),
                Text('Recorded', style: CohortTextStyles.eyebrow),
                const SizedBox(height: CohortSpacing.xs),
                Text(recordedResultSummary!, style: CohortTextStyles.body),
              ],
              if (showBlockNavigation) ...[
                const SizedBox(height: CohortSpacing.md),
                Row(
                  children: [
                    TextButton(
                      onPressed: onPrevious,
                      child: const Text('< Previous'),
                    ),
                    const Spacer(),
                    TextButton(onPressed: onNext, child: const Text('Next >')),
                  ],
                ),
              ],
              if (showActions) ...[
                const SizedBox(height: CohortSpacing.lg),
                Row(
                  children: [
                    if (block.hasTimer && onLaunchTimer != null)
                      Expanded(
                        child: CohortButton(
                          label: 'Start timer',
                          onPressed: () => onLaunchTimer?.call(),
                        ),
                      ),
                    if (block.hasTimer && onLaunchTimer != null)
                      const SizedBox(width: CohortSpacing.sm),
                    Expanded(
                      child: CohortButton(
                        label: isComplete
                            ? 'Reopen block'
                            : 'Mark block complete',
                        onPressed: isComplete ? onReopen : onMarkComplete,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ExecutionExerciseList extends StatelessWidget {
  const _ExecutionExerciseList({
    required this.exercises,
    required this.onOpenExercise,
    required this.exerciseInfoOpensDetail,
  });

  final List<SessionExecutionExerciseSummary> exercises;
  final ValueChanged<SessionExecutionExerciseSummary> onOpenExercise;
  final bool exerciseInfoOpensDetail;

  @override
  Widget build(BuildContext context) {
    final ungrouped = exercises
        .where((exercise) => !exercise.hasExecutionGroup)
        .toList(growable: false);
    final grouped = <String, List<SessionExecutionExerciseSummary>>{};
    for (final exercise in exercises.where((item) => item.hasExecutionGroup)) {
      grouped.putIfAbsent(exercise.executionGroupKey!, () => []).add(exercise);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ungrouped.isNotEmpty) ...[
          Text('Exercises', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.sm),
          for (final exercise in ungrouped)
            _ExecutionExerciseRow(
              exercise: exercise,
              onOpenExercise: onOpenExercise,
              exerciseInfoOpensDetail: exerciseInfoOpensDetail,
            ),
        ],
        for (final entry in grouped.entries) ...[
          if (ungrouped.isNotEmpty || entry.key != grouped.keys.first)
            const SizedBox(height: CohortSpacing.md),
          Text(
            '${entry.value.first.executionGroupLabel} · '
            '${entry.value.first.executionGroupRounds} rounds',
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.sm),
          for (var index = 0; index < entry.value.length; index++)
            _ExecutionExerciseRow(
              exercise: entry.value[index],
              order: index + 1,
              onOpenExercise: onOpenExercise,
              exerciseInfoOpensDetail: exerciseInfoOpensDetail,
            ),
        ],
      ],
    );
  }
}

class _ExecutionExerciseRow extends StatelessWidget {
  const _ExecutionExerciseRow({
    required this.exercise,
    required this.onOpenExercise,
    required this.exerciseInfoOpensDetail,
    this.order,
  });

  final SessionExecutionExerciseSummary exercise;
  final ValueChanged<SessionExecutionExerciseSummary> onOpenExercise;
  final bool exerciseInfoOpensDetail;
  final int? order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order != null)
            Padding(
              padding: const EdgeInsets.only(
                top: CohortSpacing.xs,
                right: CohortSpacing.sm,
              ),
              child: Text('$order.', style: CohortTextStyles.small),
            ),
          Expanded(
            child: InkWell(
              onTap: () => onOpenExercise(exercise),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CohortSpacing.xs),
                child: StrengthPrescriptionDisplay.fromSummary(
                  summary: exercise,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Exercise info for ${exercise.athleteLabel}',
            child: IconButton(
              tooltip: 'Exercise info',
              icon: const Icon(Icons.info_outline),
              onPressed: exerciseInfoOpensDetail
                  ? () => onOpenExercise(exercise)
                  : () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _ExerciseInfoSheet(exercise: exercise),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseInfoSheet extends StatelessWidget {
  const _ExerciseInfoSheet({required this.exercise});

  final SessionExecutionExerciseSummary exercise;

  @override
  Widget build(BuildContext context) {
    final model = exercise.exercise;
    final prescription = exercise.prescription;
    final sections = <(String, String)>[
      if (_text(model?.purpose) case final value?) ('Description', value),
      if (_text(model?.execution) case final value?) ('Standard', value),
      if (_text(model?.coachingCues) case final value?) ('Cues', value),
      if (StrengthPrescriptionFormatter.formatRest(prescription?.restSeconds)
          case final value?)
        ('Rest', value.replaceFirst('Rest ', '')),
      if (_effort(prescription?.load) case final value?) ('Effort', value),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: CohortSpacing.lg,
          right: CohortSpacing.lg,
          top: CohortSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.athleteLabel, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.lg),
            if (sections.isEmpty)
              Text(
                'No additional exercise guidance is available.',
                style: CohortTextStyles.body,
              )
            else
              for (final section in sections) ...[
                Text(section.$1, style: CohortTextStyles.eyebrow),
                const SizedBox(height: CohortSpacing.xs),
                Text(section.$2, style: CohortTextStyles.body),
                const SizedBox(height: CohortSpacing.md),
              ],
          ],
        ),
      ),
    );
  }

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _effort(StrengthLoadPrescription? load) {
    if (load == null) return null;
    return switch (load.type) {
      StrengthLoadType.rpe when load.rpe != null => 'RPE ${load.rpe}',
      StrengthLoadType.rir when load.rir != null => '${load.rir} RIR',
      _ => null,
    };
  }
}

class SessionOverviewBlockSummary extends StatelessWidget {
  const SessionOverviewBlockSummary({super.key, required this.block});

  final SessionExecutionBlock block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${block.position}.', style: CohortTextStyles.small),
          const SizedBox(width: CohortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.title, style: CohortTextStyles.cardTitle),
                Text(block.blockTypeLabel, style: CohortTextStyles.small),
                if (block.workoutFormatLabel != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  WorkoutFormatBadge(label: block.workoutFormatLabel!),
                ],
                if (block.timerSummary != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  TimerSummaryText(summary: block.timerSummary!),
                ],
                if (block.linkedExercises.isNotEmpty)
                  Text(
                    '${block.linkedExercises.length} exercise${block.linkedExercises.length == 1 ? '' : 's'}',
                    style: CohortTextStyles.small,
                  ),
                if (block.coachNotes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(block.coachNotes!.trim(), style: CohortTextStyles.small),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SessionCompletionSummary extends StatelessWidget {
  const SessionCompletionSummary({
    super.key,
    required this.sessionTitle,
    required this.completedCount,
    required this.totalCount,
    required this.skippedCount,
    this.elapsedLabel,
    this.contextLabel,
  });

  final String sessionTitle;
  final int completedCount;
  final int totalCount;
  final int skippedCount;
  final String? elapsedLabel;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session complete', style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.sm),
        Text(sessionTitle, style: CohortTextStyles.body),
        if (contextLabel != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(contextLabel!, style: CohortTextStyles.small),
        ],
        const SizedBox(height: CohortSpacing.xl),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$completedCount of $totalCount blocks completed',
                style: CohortTextStyles.cardTitle,
              ),
              if (skippedCount > 0) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  '$skippedCount block${skippedCount == 1 ? '' : 's'} left incomplete',
                  style: CohortTextStyles.body,
                ),
              ],
              if (elapsedLabel != null) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text('Duration: $elapsedLabel', style: CohortTextStyles.small),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
