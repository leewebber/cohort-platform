import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/strength_prescription_formatter.dart';
import '../../session/models/session_execution_plan.dart';

class StrengthPrescriptionDisplay extends StatelessWidget {
  const StrengthPrescriptionDisplay({
    super.key,
    required this.exerciseName,
    required this.prescription,
    this.coachCue,
  });

  StrengthPrescriptionDisplay.fromSummary({
    super.key,
    required SessionExecutionExerciseSummary summary,
  })  : exerciseName = summary.athleteLabel,
        prescription = summary.prescription,
        coachCue = summary.prescription?.coachCue;

  final String exerciseName;
  final StrengthExercisePrescription? prescription;
  final String? coachCue;

  @override
  Widget build(BuildContext context) {
    if (prescription == null || !prescription!.hasStructuredData) {
      return Text(exerciseName, style: CohortTextStyles.body);
    }

    final summary = StrengthPrescriptionFormatter.summaryLine(prescription!);
    final details = StrengthPrescriptionFormatter.detailLine(prescription!);
    final cue = coachCue?.trim().isNotEmpty == true ? coachCue!.trim() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exerciseName, style: CohortTextStyles.cardTitle),
        const SizedBox(height: CohortSpacing.xs),
        Text(summary, style: CohortTextStyles.body),
        if (details.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            details,
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textSecondary,
            ),
          ),
        ],
        if (cue != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(cue, style: CohortTextStyles.body),
        ],
      ],
    );
  }
}

class StrengthPrescriptionList extends StatelessWidget {
  const StrengthPrescriptionList({
    super.key,
    required this.exercises,
  });

  final List<SessionExecutionExerciseSummary> exercises;

  @override
  Widget build(BuildContext context) {
    final structured = exercises
        .where((exercise) => exercise.prescription?.hasStructuredData == true)
        .toList(growable: false);

    if (structured.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final exercise in exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
              child: Text(exercise.athleteLabel, style: CohortTextStyles.body),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < structured.length; index++) ...[
          if (index > 0) const SizedBox(height: CohortSpacing.md),
          StrengthPrescriptionDisplay.fromSummary(summary: structured[index]),
        ],
      ],
    );
  }
}
