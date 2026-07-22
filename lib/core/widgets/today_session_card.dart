import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';

class TodaySessionCard extends StatelessWidget {
  const TodaySessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.weekLabel,
    required this.duration,
    this.programmeName,
    this.sessionGoal,
    this.progressLabel,
    this.adaptationNotice,
    this.status = 'Planned Session',
    this.buttonLabel = 'START SESSION',
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String weekLabel;
  final String duration;
  final String? programmeName;
  final String? sessionGoal;
  final String? progressLabel;
  final String? adaptationNotice;
  final String status;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S TRAINING",
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.lg),
          Text(
            title,
            style: CohortTextStyles.h2,
          ),
          if (programmeName != null && programmeName!.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(programmeName!, style: CohortTextStyles.cardTitle),
          ],
          const SizedBox(height: CohortSpacing.xs),
          Text(
            subtitle,
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.lg),
          Text(
            weekLabel,
            style: CohortTextStyles.small,
          ),
          if (duration.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              duration,
              style: CohortTextStyles.small,
            ),
          ],
          if (sessionGoal != null && sessionGoal!.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(sessionGoal!, style: CohortTextStyles.body),
          ],
          if (progressLabel != null && progressLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(progressLabel!, style: CohortTextStyles.small),
          ],
          if (adaptationNotice != null &&
              adaptationNotice!.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(
              adaptationNotice!,
              style: CohortTextStyles.small,
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          Row(
            children: [
              const Icon(
                Icons.circle,
                size: 10,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: CohortTextStyles.body,
              ),
            ],
          ),
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(
            label: buttonLabel,
            onPressed: onPressed ?? () {},
          ),
        ],
      ),
    );
  }
}
