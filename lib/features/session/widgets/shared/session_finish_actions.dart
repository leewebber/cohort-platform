import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_button.dart';

/// Shared finish / end-early action row for session execution views.
class SessionFinishActions extends StatelessWidget {
  const SessionFinishActions({
    super.key,
    this.showFinishSession = false,
    this.finishSessionEnabled = true,
    this.onFinishSession,
    this.showEndSessionEarly = false,
    this.endSessionEarlyEnabled = true,
    this.onEndSessionEarly,
    this.finishLabel = 'Finish Session',
    this.endEarlyLabel = 'End Session Early',
  });

  final bool showFinishSession;
  final bool finishSessionEnabled;
  final VoidCallback? onFinishSession;
  final bool showEndSessionEarly;
  final bool endSessionEarlyEnabled;
  final VoidCallback? onEndSessionEarly;
  final String finishLabel;
  final String endEarlyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFinishSession)
          CohortButton(
            label: finishLabel,
            onPressed: finishSessionEnabled
                ? (onFinishSession ?? () {})
                : () {},
          ),
        if (showFinishSession && showEndSessionEarly)
          const SizedBox(height: CohortSpacing.md),
        if (showEndSessionEarly)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: endSessionEarlyEnabled ? onEndSessionEarly : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: CohortColors.textSecondary,
                side: const BorderSide(color: CohortColors.border),
              ),
              child: Text(
                endEarlyLabel,
                style: CohortTextStyles.body,
              ),
            ),
          ),
      ],
    );
  }
}
