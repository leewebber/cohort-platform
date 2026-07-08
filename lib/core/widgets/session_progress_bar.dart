import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class SessionProgressBar extends StatelessWidget {
  const SessionProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $currentStep of $totalSteps',
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
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    color: CohortColors.olive,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
