import 'package:flutter/material.dart';

import '../../../core/accessibility/journey_interaction.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';

/// Today rest-day card. Guidance only — no Begin or result capture.
class AthleteHomeRestDayCard extends StatelessWidget {
  const AthleteHomeRestDayCard({
    super.key,
    this.programmeName,
    this.dateLabel,
    this.guidance,
    this.nextSessionHint,
    this.onOpenCalendar,
  });

  final String? programmeName;
  final String? dateLabel;
  final String? guidance;
  final String? nextSessionHint;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (programmeName != null && programmeName!.trim().isNotEmpty) ...[
            Text(programmeName!, style: CohortTextStyles.small),
            const SizedBox(height: CohortSpacing.sm),
          ],
          Semantics(
            header: true,
            label: 'Rest day. Guidance only. No workout to begin',
            child: const Text('Rest day', style: CohortTextStyles.h2),
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            (guidance != null && guidance!.trim().isNotEmpty)
                ? guidance!.trim()
                : 'No training session is scheduled for this programme date.',
            style: CohortTextStyles.body,
          ),
          if (nextSessionHint != null && onOpenCalendar != null) ...[
            const SizedBox(height: CohortSpacing.md),
            JourneyMinTap(
              child: TextButton(
                key: const ValueKey('rest-day-next-session'),
                onPressed: onOpenCalendar,
                child: Text(nextSessionHint!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
