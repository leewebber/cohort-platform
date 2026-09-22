import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../presentation/athlete_programme_decision_facts.dart';

class AthleteProgrammeFactList extends StatelessWidget {
  const AthleteProgrammeFactList({
    super.key,
    required this.facts,
    this.includeSummary = true,
  });

  final AthleteProgrammeDecisionFacts facts;
  final bool includeSummary;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Goal', facts.goalLabel),
      ('Intended level', facts.levelLabel),
      ('Duration', facts.durationLabel),
      ('Sessions per week', facts.frequencyLabel),
      ('Equipment', facts.equipmentLabel),
      ('Training emphasis', facts.emphasisLabel),
      ('Session formats', facts.formatsLabel),
      ('Progression', facts.progressionLabel),
      ('Recovery', facts.recoveryLabel),
      ('Status', facts.statusLabel),
      if (includeSummary) ('Summary', facts.summaryLabel),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          Text(row.$1, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Text(row.$2, style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.md),
        ],
      ],
    );
  }
}

class AthleteProgrammeStatusChip extends StatelessWidget {
  const AthleteProgrammeStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: CohortColors.olive),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: CohortTextStyles.eyebrow.copyWith(
              color: CohortColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
