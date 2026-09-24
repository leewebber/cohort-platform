import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/athlete_programme_decision_facts.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

class AthleteProgrammeGlanceTiles extends StatelessWidget {
  const AthleteProgrammeGlanceTiles({
    super.key,
    required this.facts,
    this.showHeading = true,
    this.includeEquipment = true,
    this.sessionsLabel = 'Sessions / week',
    this.uppercaseLabels = true,
  });

  final AthleteProgrammeDecisionFacts facts;
  final bool showHeading;
  final bool includeEquipment;
  final String sessionsLabel;
  final bool uppercaseLabels;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String)>[
      ('Duration', facts.glanceValue(facts.durationDisplay)),
      (sessionsLabel, facts.glanceValue(facts.frequencyDisplay)),
      ('Intended level', facts.glanceValue(facts.intendedLevel)),
      if (includeEquipment)
        ('Equipment', facts.glanceValue(facts.equipment)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Semantics(
            header: true,
            child: Text(
              AthleteProgrammeDecisionCopy.atAGlance,
              style: CohortTextStyles.h2,
            ),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final stacked = constraints.maxWidth < 360 || scale >= 1.6;
            final gap = 8.0;
            final width = stacked
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tile in tiles)
                  SizedBox(
                    width: width,
                    child: _GlanceTile(
                      label: uppercaseLabels ? tile.$1.toUpperCase() : tile.$1,
                      value: tile.$2,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GlanceTile extends StatelessWidget {
  const _GlanceTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label, $value',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CohortColors.surfaceRaised,
            border: Border.all(color: CohortColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CohortTextStyles.tileLabel),
                const SizedBox(height: 6),
                Text(value, style: CohortTextStyles.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
