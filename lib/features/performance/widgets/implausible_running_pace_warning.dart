import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../services/running_pace_plausibility.dart';

class ImplausibleRunningPaceWarning extends StatelessWidget {
  const ImplausibleRunningPaceWarning({super.key, required this.warning});

  final RunningPaceWarning warning;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: warning.message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CohortColors.warning.withValues(alpha: 0.12),
          border: Border.all(color: CohortColors.warning),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: CohortColors.warning,
                semanticLabel: 'Warning',
              ),
              const SizedBox(width: CohortSpacing.sm),
              Expanded(
                child: Text(warning.message, style: CohortTextStyles.body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmImplausibleRunningPace({
  required BuildContext context,
  required RunningPaceWarning warning,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Check this result'),
        content: ImplausibleRunningPaceWarning(warning: warning),
        actions: [
          TextButton(
            key: const ValueKey('implausible-pace-edit'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Edit result'),
          ),
          TextButton(
            key: const ValueKey('implausible-pace-save-anyway'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save anyway'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
