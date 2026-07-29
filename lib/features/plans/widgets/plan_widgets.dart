import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../models/plan_definition.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.onTap});

  final PlanDefinition plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  plan.colourTheme.withValues(alpha: 0.35),
                  CohortColors.surfaceRaised,
                ],
              ),
              border: Border.all(color: CohortColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CohortSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: plan.colourTheme.withValues(alpha: 0.25),
                      border: Border.all(
                        color: plan.colourTheme.withValues(alpha: 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.terrain_rounded,
                      size: 48,
                      color: CohortColors.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.lg),
                  Text(plan.name, style: CohortTextStyles.h2),
                  const SizedBox(height: CohortSpacing.xs),
                  Text(plan.subtitle, style: CohortTextStyles.body),
                  const SizedBox(height: CohortSpacing.lg),
                  Wrap(
                    spacing: CohortSpacing.sm,
                    runSpacing: CohortSpacing.sm,
                    children: [
                      _Chip(label: plan.goalLabel),
                      _Chip(label: plan.daysLabel),
                      _Chip(label: plan.weeksLabel),
                      _Chip(label: plan.durationLabel),
                      _Chip(label: plan.difficultyLabel),
                    ],
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    plan.equipmentSummary,
                    style: CohortTextStyles.small,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CohortColors.oliveSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CohortColors.borderAccent),
      ),
      child: Text(
        label.toUpperCase(),
        style: CohortTextStyles.sectionLabel.copyWith(fontSize: 9),
      ),
    );
  }
}

class PlanFilterChip extends StatelessWidget {
  const PlanFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: CohortSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: CohortColors.phosphorDeep,
        backgroundColor: CohortColors.surfaceRaised,
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF0C0E0B) : CohortColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        side: BorderSide(color: CohortColors.border),
      ),
    );
  }
}
