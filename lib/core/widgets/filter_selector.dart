import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class FilterSelector extends StatelessWidget {
  const FilterSelector({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CohortRadius.large),
      child: Ink(
        decoration: BoxDecoration(
          color: CohortColors.surface,
          borderRadius: BorderRadius.circular(CohortRadius.large),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: CohortTextStyles.eyebrow,
                    ),
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      value,
                      style: CohortTextStyles.body,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CohortColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}