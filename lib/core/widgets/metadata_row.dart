import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class MetadataRow extends StatelessWidget {
  const MetadataRow({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: CohortColors.olive,
          ),

          const SizedBox(width: CohortSpacing.md),

          Expanded(
            child: Text(
              text!,
              style: CohortTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}