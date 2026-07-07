import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class AttributeGrid extends StatelessWidget {
  const AttributeGrid({
    super.key,
    required this.attributes,
  });

  final Map<String, String?> attributes;

  @override
  Widget build(BuildContext context) {
    final entries = attributes.entries
        .where((entry) => entry.value != null && entry.value!.trim().isNotEmpty)
        .toList();

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: CohortSpacing.md,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CohortColors.border,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  entry.key,
                  style: CohortTextStyles.eyebrow,
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(
                  entry.value!,
                  style: CohortTextStyles.body,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}