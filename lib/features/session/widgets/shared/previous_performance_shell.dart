import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_card.dart';

/// Visual shell for previous-performance sections in session execution views.
///
/// Mode-specific views supply content and opportunity widgets; this shell only
/// handles loading, empty, and layout framing.
class PreviousPerformanceShell extends StatelessWidget {
  const PreviousPerformanceShell({
    super.key,
    required this.isLoading,
    this.visible = true,
    this.loadingMessage = 'Loading previous performance...',
    this.loadingTextStyle,
    this.emptyState,
    this.content,
    this.opportunitySection,
    this.wrapInCard = false,
  });

  final bool isLoading;
  final bool visible;
  final String loadingMessage;
  final TextStyle? loadingTextStyle;
  final Widget? emptyState;
  final Widget? content;
  final Widget? opportunitySection;
  final bool wrapInCard;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    if (isLoading) {
      return Text(
        loadingMessage,
        style: loadingTextStyle ?? CohortTextStyles.small,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content != null) _maybeWrap(content!),
        if (content == null && emptyState != null) _maybeWrap(emptyState!),
        if (opportunitySection != null) ...[
          if (content != null || emptyState != null)
            const SizedBox(height: CohortSpacing.xl),
          opportunitySection!,
        ],
      ],
    );
  }

  Widget _maybeWrap(Widget child) {
    if (!wrapInCard) {
      return child;
    }

    return CohortCard(child: child);
  }
}

/// Shared "Today's Opportunity" block used by previous-performance sections.
class TodaysOpportunitySection extends StatelessWidget {
  const TodaysOpportunitySection({
    super.key,
    required this.items,
    this.title = "Today's Opportunity",
    this.useUppercaseEyebrow = false,
  });

  final String title;
  final List<String> items;
  final bool useUppercaseEyebrow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          useUppercaseEyebrow ? "TODAY'S OPPORTUNITY" : title,
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
            child: Text(
              '• $item',
              style: useUppercaseEyebrow
                  ? CohortTextStyles.small
                  : CohortTextStyles.body,
            ),
          ),
      ],
    );
  }
}
