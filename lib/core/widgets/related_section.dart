import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class RelatedSection extends StatelessWidget {
  const RelatedSection({
    super.key,
    required this.title,
    required this.items,
    this.onTap,
  });

  final String title;
  final List<String> items;
  final void Function(String item)? onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: CohortTextStyles.eyebrow,
        ),

        const SizedBox(height: CohortSpacing.md),

        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(
              bottom: CohortSpacing.sm,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap == null
                  ? null
                  : () => onTap!(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CohortSpacing.md,
                  vertical: CohortSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: CohortColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CohortColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link,
                      size: 18,
                    ),

                    const SizedBox(
                      width: CohortSpacing.md,
                    ),

                    Expanded(
                      child: Text(
                        item,
                        style: CohortTextStyles.body,
                      ),
                    ),

                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}