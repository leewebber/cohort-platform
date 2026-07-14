import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_card.dart';

enum ProgressResultCardVariant {
  container,
  card,
}

/// Shared visual shell for in-session progress comparison cards.
class ProgressResultCard extends StatelessWidget {
  const ProgressResultCard({
    super.key,
    this.eyebrow,
    required this.title,
    required this.message,
    this.reasons = const [],
    required this.accentColor,
    this.variant = ProgressResultCardVariant.container,
  });

  final String? eyebrow;
  final String title;
  final String message;
  final List<String> reasons;
  final Color accentColor;
  final ProgressResultCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: CohortTextStyles.eyebrow.copyWith(color: accentColor),
          ),
          const SizedBox(height: CohortSpacing.sm),
        ],
        Text(
          title,
          style: variant == ProgressResultCardVariant.card
              ? CohortTextStyles.cardTitle.copyWith(color: accentColor)
              : CohortTextStyles.small.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
        ),
        if (message.trim().isNotEmpty) ...[
          SizedBox(
            height: variant == ProgressResultCardVariant.card
                ? CohortSpacing.xs
                : CohortSpacing.xs,
          ),
          Text(
            message,
            style: CohortTextStyles.small,
          ),
        ],
        for (final reason in reasons)
          Padding(
            padding: const EdgeInsets.only(top: CohortSpacing.xs),
            child: Text(
              '• $reason',
              style: CohortTextStyles.small,
            ),
          ),
      ],
    );

    return switch (variant) {
      ProgressResultCardVariant.card => CohortCard(child: body),
      ProgressResultCardVariant.container => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CohortSpacing.md),
          decoration: BoxDecoration(
            color: CohortColors.surfaceRaised,
            borderRadius: CohortRadius.smallRadius,
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: body,
        ),
    };
  }
}
