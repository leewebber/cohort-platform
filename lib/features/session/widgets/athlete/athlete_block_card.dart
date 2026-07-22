import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_button.dart';
import '../../../../core/widgets/cohort_card.dart';
import '../../models/session_execution_plan.dart';
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
    this.performanceSection,
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
  final Widget? performanceSection;
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
                    color: isComplete ? CohortColors.success : CohortColors.textSecondary,
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
              if (block.linkedExercises.isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.md),
                Text('Exercises', style: CohortTextStyles.eyebrow),
                const SizedBox(height: CohortSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final exercise in block.linkedExercises)
                      Semantics(
                        button: true,
                        label: 'Open exercise ${exercise.athleteLabel}',
                        child: InkWell(
                          onTap: () => onOpenExercise(exercise),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: CohortSpacing.xs,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: CohortTextStyles.body.copyWith(
                                    color: CohortColors.textSecondary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    exercise.athleteLabel,
                                    style: CohortTextStyles.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (block.coachNotes != null) ...[
                const SizedBox(height: CohortSpacing.md),
                Text('Coach notes', style: CohortTextStyles.eyebrow),
                const SizedBox(height: CohortSpacing.xs),
                Text(block.coachNotes!, style: CohortTextStyles.body),
              ],
              if (performanceSection != null) ...[
                const SizedBox(height: CohortSpacing.lg),
                performanceSection!,
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
                    TextButton(
                      onPressed: onNext,
                      child: const Text('Next >'),
                    ),
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
                        label: isComplete ? 'Reopen block' : 'Mark block complete',
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

class SessionOverviewBlockSummary extends StatelessWidget {
  const SessionOverviewBlockSummary({
    super.key,
    required this.block,
  });

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
                  Text(
                    block.coachNotes!.trim(),
                    style: CohortTextStyles.small,
                  ),
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
              Text('$completedCount of $totalCount blocks completed',
                  style: CohortTextStyles.cardTitle),
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
