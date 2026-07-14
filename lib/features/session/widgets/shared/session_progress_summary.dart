import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

/// Shared progress summary for session execution views.
///
/// Supports optional step-style progress bar plus a flexible completion label.
class SessionProgressSummary extends StatelessWidget {
  const SessionProgressSummary({
    super.key,
    required this.completedCount,
    required this.totalCount,
    required this.summaryLabel,
    this.showProgressBar = false,
    this.progressBarCurrentStep,
    this.summaryTextStyle,
  });

  final int completedCount;
  final int totalCount;

  /// Full summary line, e.g. `3 of 5 exercises complete`.
  final String summaryLabel;

  /// When true, renders the step-style bar used by strength sessions.
  final bool showProgressBar;

  /// Bar position when [showProgressBar] is true. Defaults to [completedCount]
  /// with a minimum of 1 to match existing strength behaviour.
  final int? progressBarCurrentStep;

  final TextStyle? summaryTextStyle;

  @override
  Widget build(BuildContext context) {
    final barStep = progressBarCurrentStep ??
        (completedCount == 0 ? 1 : completedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showProgressBar) ...[
          Text(
            'Step $barStep of $totalCount',
            style: CohortTextStyles.small,
          ),
          const SizedBox(height: CohortSpacing.sm),
          ClipRRect(
            borderRadius: CohortRadius.largeRadius,
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    color: CohortColors.border,
                  ),
                  FractionallySizedBox(
                    widthFactor: (barStep / totalCount).clamp(0.0, 1.0),
                    child: Container(
                      color: CohortColors.olive,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.sm),
        ],
        Text(
          summaryLabel,
          style: summaryTextStyle ?? CohortTextStyles.small,
        ),
      ],
    );
  }
}
