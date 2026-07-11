import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/session_progress_bar.dart';
import '../../../models/session_step.dart';

/// Dedicated execution view for structured strength sessions (v0.1).
///
/// Shows ordered exercise blocks with prescription, placeholder logging fields,
/// and per-exercise completion. Set-by-set persistence is not yet implemented.
class StrengthSessionView extends StatefulWidget {
  const StrengthSessionView({
    super.key,
    required this.sessionTitle,
    required this.steps,
    required this.onFinishSession,
  });

  final String sessionTitle;
  final List<SessionStep> steps;
  final VoidCallback onFinishSession;

  @override
  State<StrengthSessionView> createState() => _StrengthSessionViewState();
}

class _StrengthSessionViewState extends State<StrengthSessionView> {
  final Set<int> _completedStepNumbers = {};

  bool get _allExercisesComplete =>
      widget.steps.isNotEmpty &&
      _completedStepNumbers.length == widget.steps.length;

  int get _completedCount => _completedStepNumbers.length;

  void _completeExercise(int stepNumber) {
    setState(() {
      _completedStepNumbers.add(stepNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STRUCTURED STRENGTH',
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          widget.sessionTitle,
          style: CohortTextStyles.h2,
        ),
        const SizedBox(height: CohortSpacing.xl),
        SessionProgressBar(
          currentStep: _completedCount == 0 ? 1 : _completedCount,
          totalSteps: widget.steps.length,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          '$_completedCount of ${widget.steps.length} exercises complete',
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: CohortSpacing.xl),
        for (var index = 0; index < widget.steps.length; index++) ...[
          if (index > 0) const SizedBox(height: CohortSpacing.md),
          _StrengthExerciseCard(
            step: widget.steps[index],
            isComplete: _completedStepNumbers.contains(
              widget.steps[index].stepNumber,
            ),
            onComplete: () => _completeExercise(widget.steps[index].stepNumber),
          ),
        ],
        if (_allExercisesComplete) ...[
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(
            label: 'Finish Session',
            onPressed: widget.onFinishSession,
          ),
        ],
      ],
    );
  }
}

class _StrengthExerciseCard extends StatelessWidget {
  const _StrengthExerciseCard({
    required this.step,
    required this.isComplete,
    required this.onComplete,
  });

  final SessionStep step;
  final bool isComplete;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (isComplete) {
      return CohortCard(
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: CohortColors.success,
            ),
            const SizedBox(width: CohortSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXERCISE ${step.stepNumber} COMPLETE',
                    style: CohortTextStyles.eyebrow,
                  ),
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    step.title,
                    style: CohortTextStyles.cardTitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXERCISE ${step.stepNumber}',
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.lg),
          Text(
            step.title,
            style: CohortTextStyles.h2,
          ),
          if (step.prescription != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              step.prescription!,
              style: CohortTextStyles.body,
            ),
          ],
          if (step.coachCue != null) ...[
            const SizedBox(height: CohortSpacing.xl),
            Text(
              'Coach Cue',
              style: CohortTextStyles.eyebrow,
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              step.coachCue!,
              style: CohortTextStyles.body,
            ),
          ],
          const SizedBox(height: CohortSpacing.xl),
          Row(
            children: [
              Expanded(child: _PlaceholderField(label: 'Load')),
              const SizedBox(width: CohortSpacing.md),
              Expanded(child: _PlaceholderField(label: 'Actual reps')),
            ],
          ),
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(
            label: 'Complete Exercise',
            onPressed: onComplete,
          ),
        ],
      ),
    );
  }
}

class _PlaceholderField extends StatelessWidget {
  const _PlaceholderField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CohortTextStyles.muted,
        ),
        const SizedBox(height: CohortSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: CohortSpacing.md,
            vertical: CohortSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: CohortColors.border),
            borderRadius: CohortRadius.smallRadius,
          ),
          child: Text(
            '—',
            style: CohortTextStyles.muted,
          ),
        ),
      ],
    );
  }
}
