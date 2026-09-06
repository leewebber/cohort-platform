import 'package:flutter/material.dart';

import '../config/app_build_provenance.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class LocalPreviewBanner extends StatelessWidget {
  const LocalPreviewBanner({super.key});

  static bool get shouldShow =>
      AppBuildProvenance.current.environment?.showsLocalPreviewIndicator ??
      false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LOCAL PREVIEW',
      child: Material(
        color: CohortColors.oliveDark,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CohortSpacing.md,
              vertical: CohortSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.computer,
                  size: 16,
                  color: CohortColors.textPrimary,
                ),
                const SizedBox(width: CohortSpacing.sm),
                Text(
                  'LOCAL PREVIEW',
                  style: CohortTextStyles.sectionLabel.copyWith(
                    color: CohortColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
