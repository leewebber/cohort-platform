import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/session_revision_vocabulary.dart';
import '../governance_copy.dart';

class GovernanceStatusBadge extends StatelessWidget {
  const GovernanceStatusBadge({
    super.key,
    required this.lifecycleStatus,
  });

  final SessionRevisionLifecycleStatus lifecycleStatus;

  @override
  Widget build(BuildContext context) {
    final label = GovernanceCopy.lifecycleLabel(lifecycleStatus);
    final colors = _colorsFor(lifecycleStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: CohortTextStyles.small.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _BadgeColors _colorsFor(SessionRevisionLifecycleStatus status) {
    return switch (status) {
      SessionRevisionLifecycleStatus.draft => const _BadgeColors(
          background: CohortColors.oliveSoft,
          border: CohortColors.olive,
          text: CohortColors.olive,
        ),
      SessionRevisionLifecycleStatus.published => const _BadgeColors(
          background: CohortColors.surfaceRaised,
          border: CohortColors.border,
          text: CohortColors.textPrimary,
        ),
      SessionRevisionLifecycleStatus.archived => const _BadgeColors(
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
