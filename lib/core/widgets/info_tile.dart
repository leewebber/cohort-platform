import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'section_title.dart';

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(label),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            value!,
            style: CohortTextStyles.body,
          ),
        ],
      ),
    );
  }
}