import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';

class CohortSearchBar extends StatelessWidget {
  const CohortSearchBar({
    super.key,
    required this.onChanged,
  });

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: CohortColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search protocols...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: CohortColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CohortRadius.large),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}