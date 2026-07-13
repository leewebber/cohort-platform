import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_card.dart';
import '../../../../models/exercise_history.dart';

class ExerciseHistorySessionCard extends StatelessWidget {
  const ExerciseHistorySessionCard({
    super.key,
    required this.session,
  });

  final ExerciseHistorySession session;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(session.performedAt),
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            session.protocolLabel,
            style: CohortTextStyles.cardTitle,
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            session.summaryLine,
            style: CohortTextStyles.small,
          ),
          if (session.endedEarly) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Session ended early',
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.olive,
              ),
            ),
          ],
          if (session.completionReason != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Reason: ${session.completionReason}',
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: CohortSpacing.md),
          for (final line in session.setLines) ...[
            Text(
              line.displayLine,
              style: CohortTextStyles.body.copyWith(
                color: line.isExtraSet
                    ? CohortColors.warning
                    : null,
              ),
            ),
            const SizedBox(height: CohortSpacing.xs),
          ],
          if (session.athleteNote != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(CohortSpacing.md),
              decoration: BoxDecoration(
                color: CohortColors.surfaceRaised,
                borderRadius: CohortRadius.smallRadius,
                border: Border.all(color: CohortColors.border),
              ),
              child: Text(
                session.athleteNote!,
                style: CohortTextStyles.small,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'DATE UNKNOWN';
    }

    final local = value.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[local.weekday - 1];
    final month = months[local.month - 1];

    return '$weekday ${local.day} $month ${local.year}';
  }
}
