import 'package:flutter/material.dart';

import '../theme/colors.dart';
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
    this.status = 'Planned Session',
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String weekLabel;
  final String duration;
  final String status;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY',
            style: CohortTextStyles.eyebrow,
          ),

          const SizedBox(height: CohortSpacing.lg),

          Text(
            title,
            style: CohortTextStyles.h2,
          ),

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

          const SizedBox(height: CohortSpacing.xs),

          Text(
            duration,
            style: CohortTextStyles.small,
          ),

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
            label: 'Begin',
            onPressed: onPressed ?? () {},
          ),
        ],
      ),
    );
  }
}