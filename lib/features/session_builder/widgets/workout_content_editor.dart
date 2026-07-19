import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';

/// Reusable plain-text workout editor (M6).
///
/// Isolated so rich text can replace this widget later without changing domain models.
class WorkoutContentEditor extends StatelessWidget {
  const WorkoutContentEditor({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.minLines = 6,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: null,
            style: CohortTextStyles.body,
            decoration: const InputDecoration(
              isDense: true,
              alignLabelWithHint: true,
              hintText: 'Write the workout naturally — sets, reps, and pacing stay in your words.',
            ),
          ),
        ],
      ),
    );
  }
}
