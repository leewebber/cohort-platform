import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/cohort_card.dart';

class ProgrammeCatalogueSkeleton extends StatelessWidget {
  const ProgrammeCatalogueSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: CohortSpacing.md),
      itemBuilder: (context, index) {
        return const CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonLine(width: 72, height: 12),
              SizedBox(height: CohortSpacing.sm),
              _SkeletonLine(width: 220, height: 18),
              SizedBox(height: CohortSpacing.xs),
              _SkeletonLine(width: 180, height: 12),
              SizedBox(height: CohortSpacing.xs),
              _SkeletonLine(width: 140, height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: CohortColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
