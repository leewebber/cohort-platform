import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../models/training_session_record.dart';
import '../services/completed_session_result_projection.dart';

class CompletedSessionResultView extends StatelessWidget {
  const CompletedSessionResultView({
    super.key,
    required this.record,
    this.athleteHistory = const [],
    this.programmePosition,
    this.statusMessage,
  });

  final TrainingSessionRecord record;
  final List<TrainingSessionRecord> athleteHistory;
  final String? programmePosition;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final projection = CompletedSessionResultProjection.fromRecords(
      record: record,
      athleteHistory: athleteHistory,
    );
    return ListView(
      key: const ValueKey('completed-session-result'),
      padding: const EdgeInsets.all(CohortSpacing.lg),
      children: [
        Text('COMPLETED SESSION', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        Text(projection.sessionTitle, style: CohortTextStyles.h1),
        if (programmePosition != null) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(programmePosition!, style: CohortTextStyles.muted),
        ],
        const SizedBox(height: CohortSpacing.lg),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Session summary', style: CohortTextStyles.cardTitle),
              if (projection.completedAt case final completedAt?) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  'Completed ${formatCompletedClock(completedAt)}',
                  style: CohortTextStyles.body,
                ),
              ],
              if (projection.durationSeconds case final duration?) ...[
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  'Duration ${formatCompletedDuration(duration)}',
                  style: CohortTextStyles.body,
                ),
              ],
              if (projection.overallRpe case final rpe?) ...[
                const SizedBox(height: CohortSpacing.xs),
                Text('RPE $rpe', style: CohortTextStyles.body),
              ],
              const SizedBox(height: CohortSpacing.xs),
              Text(
                '${projection.completedBlockCount} completed · '
                '${projection.skippedBlockCount} skipped · '
                '${projection.incompleteBlockCount} incomplete',
                style: CohortTextStyles.small,
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: CohortSpacing.md),
                Text(statusMessage!, style: CohortTextStyles.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: CohortSpacing.xl),
        const SectionTitle('Results'),
        const SizedBox(height: CohortSpacing.md),
        for (final block in projection.blocks) ...[
          _CompletedBlockCard(block: block),
          const SizedBox(height: CohortSpacing.md),
        ],
      ],
    );
  }
}

class _CompletedBlockCard extends StatelessWidget {
  const _CompletedBlockCard({required this.block});

  final CompletedBlockResultProjection block;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.title, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            '${block.statusLabel} · ${block.summary}',
            style: CohortTextStyles.small,
          ),
          if (block.isSimpleCompletion) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(block.summary, style: CohortTextStyles.body),
          ] else ...[
            for (final exercise in block.exercises) ...[
              const SizedBox(height: CohortSpacing.md),
              Text(exercise.displayName, style: CohortTextStyles.body),
              const SizedBox(height: CohortSpacing.xs),
              for (final set in exercise.sets)
                Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                  child: Text(
                    [
                      'Set ${set.setNumber}',
                      if (set.repsLabel != null) set.repsLabel,
                      if (set.loadLabel != null) set.loadLabel,
                      set.stateLabel,
                    ].join(' · '),
                    style: CohortTextStyles.small,
                  ),
                ),
              if (exercise.bestSetLabel != null)
                Text(exercise.bestSetLabel!, style: CohortTextStyles.small),
              if (exercise.volumeLabel != null)
                Text(exercise.volumeLabel!, style: CohortTextStyles.small),
              Text(exercise.comparisonLabel, style: CohortTextStyles.small),
            ],
          ],
          if (block.prescriptionContext != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Text('Prescription', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.xs),
            Text(block.prescriptionContext!, style: CohortTextStyles.muted),
          ],
        ],
      ),
    );
  }
}
