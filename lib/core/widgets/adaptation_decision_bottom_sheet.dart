import 'package:flutter/material.dart';

import '../../models/adaptation_decision.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';
import 'section_title.dart';

class AdaptationDecisionBottomSheet extends StatelessWidget {
  const AdaptationDecisionBottomSheet({
    super.key,
    required this.decision,
  });

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
            Text(
              decision.protocol.name,
              style: CohortTextStyles.h2,
            ),
            const SizedBox(height: CohortSpacing.lg),
            CohortCard(
              child: Text(
                decision.message,
                style: CohortTextStyles.body,
              ),
            ),
            const SizedBox(height: CohortSpacing.xl),
            CohortButton(
              label: isKeepOriginal
                  ? 'Continue Planned Session'
                  : 'Find Alternative',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAdaptationDecisionBottomSheet(
  BuildContext context,
  AdaptationDecision decision,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: CohortColors.surfaceRaised,
    isScrollControlled: true,
    builder: (_) => AdaptationDecisionBottomSheet(decision: decision),
  );
}
