import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

/// Shared non-persistent preview banner for execution previews.
class PreviewModeBanner extends StatelessWidget {
  const PreviewModeBanner({
    super.key,
    this.message = 'No progress will be saved.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        color: CohortColors.oliveSoft,
        border: Border.all(color: CohortColors.borderStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW MODE',
            style: CohortTextStyles.eyebrow.copyWith(
              color: CohortColors.olive,
            ),
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            message,
            style: CohortTextStyles.small,
          ),
        ],
      ),
    );
  }
}
