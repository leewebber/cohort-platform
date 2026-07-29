import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../models/previous_performance_snapshot.dart';

class WorkoutProgressBar extends StatelessWidget {
  const WorkoutProgressBar({
    super.key,
    required this.progress,
    this.label,
  });

  final double progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: CohortTextStyles.small),
          const SizedBox(height: CohortSpacing.sm),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: CohortColors.surfaceRaised,
            color: CohortColors.phosphor,
          ),
        ),
      ],
    );
  }
}

/// Reserved for future media. Hidden when [mediaUrl] is null/empty.
class ExerciseMediaSlot extends StatelessWidget {
  const ExerciseMediaSlot({super.key, this.mediaUrl});

  final String? mediaUrl;

  bool get hasMedia => mediaUrl != null && mediaUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hasMedia) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        mediaUrl!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}

@Deprecated('Use ExerciseMediaSlot — placeholders must not show without media')
class ExerciseVideoPlaceholder extends StatelessWidget {
  const ExerciseVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class WorkoutMetaRow extends StatelessWidget {
  const WorkoutMetaRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.xs),
          Text(value, style: CohortTextStyles.body),
        ],
      ),
    );
  }
}

/// Calm previous-performance block under prescription.
class PreviousPerformanceSection extends StatelessWidget {
  const PreviousPerformanceSection({
    super.key,
    required this.snapshot,
  });

  final PreviousPerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasDisplayableContent) return const SizedBox.shrink();

    final lines = <String>[
      if (snapshot.loadSummary != null && snapshot.loadSummary!.isNotEmpty)
        snapshot.loadSummary!,
      if (snapshot.setSummary != null && snapshot.setSummary!.isNotEmpty)
        snapshot.setSummary!,
      if (snapshot.repSummary != null &&
          snapshot.repSummary!.isNotEmpty &&
          (snapshot.setSummary == null || snapshot.setSummary!.isEmpty))
        snapshot.repSummary!,
      if (snapshot.paceSummary != null && snapshot.paceSummary!.isNotEmpty)
        snapshot.paceSummary!,
      if (snapshot.distanceSummary != null &&
          snapshot.distanceSummary!.isNotEmpty)
        snapshot.distanceSummary!,
      if (snapshot.durationSummary != null &&
          snapshot.durationSummary!.isNotEmpty)
        snapshot.durationSummary!,
      if (snapshot.rpe != null) 'RPE ${snapshot.rpe}',
    ];
    if (lines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST TIME', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.sm),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
