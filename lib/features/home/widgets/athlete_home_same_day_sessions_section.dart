import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../presentation/athlete_home_today_presentation.dart';

/// Shared civil-date chrome for every session due on the same local date.
class AthleteHomeSameDaySessionsSection extends StatelessWidget {
  const AthleteHomeSameDaySessionsSection({
    super.key,
    required this.dateLabel,
    required this.sessionCount,
    required this.children,
  });

  final String dateLabel;
  final int sessionCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final countCopy = AthleteHomeTodayFormatter.sessionCountCopy(sessionCount);
    return Semantics(
      container: true,
      label: 'Today, $dateLabel, $countCopy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.xs),
          Text(dateLabel, style: CohortTextStyles.muted),
          const SizedBox(height: CohortSpacing.xs),
          Text(countCopy, style: CohortTextStyles.small),
          const SizedBox(height: CohortSpacing.md),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: CohortSpacing.md),
            children[index],
          ],
        ],
      ),
    );
  }
}
