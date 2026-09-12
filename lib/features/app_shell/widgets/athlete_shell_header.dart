import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_brand_lockup.dart';

/// Shared compact header for authenticated athlete destinations.
class AthleteShellHeader extends StatelessWidget {
  const AthleteShellHeader({
    super.key,
    this.greeting,
    this.trailing,
  });

  final String? greeting;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CohortBrandLockup(),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        if (greeting != null && greeting!.trim().isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.md),
          Text(
            greeting!,
            key: const ValueKey('athlete-greeting'),
            style: CohortTextStyles.h2.copyWith(fontSize: 22),
          ),
        ],
      ],
    );
  }
}
