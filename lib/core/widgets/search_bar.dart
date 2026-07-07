import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class CohortSearchBar extends StatelessWidget {
  const CohortSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search...',
  });

  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: CohortTextStyles.body,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: CohortTextStyles.body,
        prefixIcon: const Icon(
          Icons.search,
          color: CohortColors.textMuted,
        ),
        filled: true,
        fillColor: CohortColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CohortRadius.large),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(CohortSpacing.lg),
      ),
    );
  }
}