import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';

class MigrationSummaryRow extends StatelessWidget {
  const MigrationSummaryRow({
    super.key,
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: CohortTextStyles.body)),
          Text(
            count.toString(),
            style: CohortTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
