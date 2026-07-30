import 'package:flutter/material.dart';

import '../../models/adaptation_decision.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';
import 'section_title.dart';

class AdaptationDecisionBottomSheet extends StatelessWidget {
  const AdaptationDecisionBottomSheet({super.key, required this.decision});

  final AdaptationDecision decision;

  @override
  Widget build(BuildContext context) {
    final isKeepOriginal =
        decision.decisionType == AdaptationDecisionType.keepOriginal;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Session Decision'),
            const SizedBox(height: CohortSpacing.md),
            Text(decision.protocol.name, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.lg),
            CohortCard(
              child: Text(decision.message, style: CohortTextStyles.body),
            ),
            if (decision.programmedSessionKey != null) ...[
              const SizedBox(height: CohortSpacing.md),
              Text(
                'Programmed session: ${decision.programmedSessionKey}',
                style: CohortTextStyles.muted,
              ),
            ],
            if (decision.changeSummary.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.md),
              Text('WHAT CHANGES', style: CohortTextStyles.sectionLabel),
              const SizedBox(height: CohortSpacing.sm),
              ...decision.changeSummary.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                  child: Text('• $line', style: CohortTextStyles.body),
                ),
              ),
            ],
            if (decision.preservedIntent != null) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Preserved intent: ${decision.preservedIntent}',
                style: CohortTextStyles.muted,
              ),
            ],
            const SizedBox(height: CohortSpacing.xl),
            if (isKeepOriginal)
              CohortButton(
                label: 'Keep Planned Session',
                onPressed: () => Navigator.of(context).pop(false),
              )
            else ...[
              CohortButton(
                label: 'Review Adaptation',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: CohortSpacing.md),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Keep Planned Session',
                  style: CohortTextStyles.body.copyWith(
                    color: CohortColors.textPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: CohortSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Dismiss',
                style: CohortTextStyles.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showAdaptationDecisionBottomSheet(
  BuildContext context,
  AdaptationDecision decision,
) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: CohortColors.surfaceRaised,
    isScrollControlled: true,
    builder: (_) => AdaptationDecisionBottomSheet(decision: decision),
  );
}
