import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';

/// Shared chrome for linear athlete onboarding screens.
class AthleteOnboardingScaffold extends StatelessWidget {
  const AthleteOnboardingScaffold({
    super.key,
    required this.stepIndex,
    required this.stepCount,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryEnabled = true,
    this.onBack,
  });

  final int stepIndex;
  final int stepCount;
  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CohortColors.background,
      appBar: AppBar(
        backgroundColor: CohortColors.background,
        elevation: 0,
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              ),
        title: Text(
          'STEP ${stepIndex + 1} OF $stepCount',
          style: CohortTextStyles.eyebrow,
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CohortSpacing.xl,
                CohortSpacing.sm,
                CohortSpacing.xl,
                0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (stepIndex + 1) / stepCount,
                  minHeight: 4,
                  backgroundColor: CohortColors.surfaceRaised,
                  color: CohortColors.phosphor,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  CohortSpacing.xl,
                  CohortSpacing.xl,
                  CohortSpacing.xl,
                  CohortSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: CohortTextStyles.h1),
                    const SizedBox(height: CohortSpacing.md),
                    Text(subtitle, style: CohortTextStyles.body),
                    const SizedBox(height: CohortSpacing.xl),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CohortSpacing.xl,
                CohortSpacing.md,
                CohortSpacing.xl,
                CohortSpacing.xl,
              ),
              child: CohortButton(
                label: primaryLabel,
                showTrailingArrow: true,
                onPressed: primaryEnabled && onPrimary != null
                    ? onPrimary!
                    : () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AthleteChoiceCard extends StatelessWidget {
  const AthleteChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? CohortColors.oliveSoft
                  : CohortColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? CohortColors.phosphor
                    : CohortColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: CohortTextStyles.cardTitle.copyWith(
                            color: CohortColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CohortSpacing.xs),
                        Text(description, style: CohortTextStyles.body),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: selected
                        ? CohortColors.phosphor
                        : CohortColors.textMuted,
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
