import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../models/programme_vocabulary.dart';
import '../../intelligence/programme_intelligence_copy.dart';

class ProgrammeLifecycleBadge extends StatelessWidget {
  const ProgrammeLifecycleBadge({
    super.key,
    required this.lifecycleStatus,
  });

  final ProgrammeLifecycleStatus lifecycleStatus;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(lifecycleStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        ProgrammeIntelligenceCopy.lifecycleLabel(lifecycleStatus),
        style: CohortTextStyles.small.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _BadgeColors _colorsFor(ProgrammeLifecycleStatus status) {
    return switch (status) {
      ProgrammeLifecycleStatus.draft => const _BadgeColors(
          background: CohortColors.oliveSoft,
          border: CohortColors.olive,
          text: CohortColors.olive,
        ),
      ProgrammeLifecycleStatus.published => const _BadgeColors(
          background: CohortColors.surfaceRaised,
          border: CohortColors.border,
          text: CohortColors.textPrimary,
        ),
      ProgrammeLifecycleStatus.archived => const _BadgeColors(
          background: CohortColors.surfaceRaised,
          border: CohortColors.border,
          text: CohortColors.textSecondary,
        ),
    };
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}
