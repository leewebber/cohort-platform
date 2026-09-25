import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../features/programme/presentation/athlete_programme_decision_facts.dart';
import '../../../features/programme/widgets/athlete_programme_fact_list.dart';
import '../domain/programme_review_models.dart';
import 'programme_studio_copy.dart';
import 'programme_studio_labels.dart';

class ProgrammeStudioAthleteView extends StatelessWidget {
  const ProgrammeStudioAthleteView({super.key, required this.programme});

  final ProgrammeReviewProgramme programme;

  @override
  Widget build(BuildContext context) {
    final facts = AthleteProgrammeDecisionFacts(
      versionId: programme.programmeVersionId ?? programme.catalogId,
      title: programme.title,
      catalogueAvailable: false,
      isCurrentProgramme: false,
      primaryGoal: programme.primaryGoal,
      intendedLevel: programme.intendedLevel,
      durationWeeks: programme.durationWeeks,
      sessionsPerWeek: programme.sessionsPerWeek,
      equipment: programme.equipment,
      summary: programme.description,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          ProgrammeStudioCopy.athletePreviewBanner,
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: CohortSpacing.lg),
        Text(programme.title, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          'Goal: ${authoredOrUnspecified(programme.primaryGoal)}',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.md),
        AthleteProgrammeGlanceTiles(facts: facts),
        const SizedBox(height: CohortSpacing.lg),
        Text(facts.summaryLabel, style: CohortTextStyles.body),
      ],
    );
  }
}
