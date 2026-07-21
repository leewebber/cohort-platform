import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

class GovernanceCountRow extends StatelessWidget {
  const GovernanceCountRow({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: CohortTextStyles.body),
          Expanded(
            child: Text(
              label,
              style: CohortTextStyles.body.copyWith(
                color: CohortColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
