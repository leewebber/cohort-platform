import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

class AthleteSessionHeader extends StatelessWidget {
  const AthleteSessionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CohortTextStyles.h1),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.xs),
                Text(subtitle!, style: CohortTextStyles.body),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SessionProgressIndicator extends StatelessWidget {
  const SessionProgressIndicator({
    super.key,
    required this.current,
    required this.total,
    required this.completed,
  });

  final int current;
  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return Semantics(
      label: 'Block $current of $total, $completed complete',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Block $current of $total',
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            '$completed / $total complete',
            style: CohortTextStyles.small,
          ),
          const SizedBox(height: CohortSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: CohortColors.border,
              color: CohortColors.olive,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutFormatBadge extends StatelessWidget {
  const WorkoutFormatBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CohortSpacing.sm,
        vertical: CohortSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CohortColors.border),
      ),
      child: Text(label, style: CohortTextStyles.small),
    );
  }
}

class TimerSummaryText extends StatelessWidget {
  const TimerSummaryText({super.key, required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 16, color: CohortColors.olive),
        const SizedBox(width: CohortSpacing.xs),
        Expanded(child: Text(summary, style: CohortTextStyles.small)),
      ],
    );
  }
}

class LinkedExerciseChip extends StatelessWidget {
  const LinkedExerciseChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open exercise $label',
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: CohortColors.surfaceRaised,
      ),
    );
  }
}

class WorkoutContentText extends StatelessWidget {
  const WorkoutContentText({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      content,
      style: CohortTextStyles.body.copyWith(
        color: CohortColors.textPrimary,
        height: 1.6,
      ),
    );
  }
}

class AthleteFeedbackState extends StatelessWidget {
  const AthleteFeedbackState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.sm),
        Text(message, style: CohortTextStyles.body),
        if (actionLabel != null) ...[
          const SizedBox(height: CohortSpacing.lg),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
