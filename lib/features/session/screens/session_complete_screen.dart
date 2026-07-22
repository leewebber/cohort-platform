import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../performance/models/training_session_record.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../../programme/models/programme_progression_result.dart';
import '../../programme/models/resolved_today_session.dart';
import '../models/active_session_state.dart';
import '../widgets/athlete/athlete_block_card.dart';

class SessionCompleteScreen extends StatelessWidget {
  const SessionCompleteScreen({
    super.key,
    required this.state,
    this.savedRecord,
    this.adaptationMessage,
    this.progressionResult,
    this.programmeProgress,
    this.onDone,
  });

  final ActiveSessionState state;
  final TrainingSessionRecord? savedRecord;
  final String? adaptationMessage;
  final ProgrammeProgressionResult? progressionResult;
  final ProgrammeProgressSummary? programmeProgress;
  final VoidCallback? onDone;

  String? _elapsedLabel() {
    final started = state.startedAt;
    final ended = state.endedAt ?? DateTime.now();
    if (started == null) return null;
    final duration = ended.difference(started);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) return '$minutes min ${seconds}s';
    return '${seconds}s';
  }

  String get _adaptationLine =>
      adaptationMessage?.trim().isNotEmpty == true
          ? adaptationMessage!.trim()
          : 'Programme continues as planned.';

  ResolvedTodaySession? get _nextSession =>
      progressionResult?.nextResolvedSession;

  void _handleDone(BuildContext context) {
    if (onDone != null) {
      onDone!();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final executableBlocks = state.plan.blocks
        .where((block) => block.hasAthleteVisibleContent)
        .length;
    final skipped = executableBlocks - state.completedCount;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESSION COMPLETE',
                style: CohortTextStyles.eyebrow,
              ),
              const SizedBox(height: CohortSpacing.sm),
              SessionCompletionSummary(
                sessionTitle: state.plan.sessionTitle,
                completedCount: state.completedCount,
                totalCount: executableBlocks,
                skippedCount: skipped.clamp(0, executableBlocks),
                elapsedLabel: _elapsedLabel(),
                contextLabel: state.plan.programmeContextLabel,
              ),
              const SizedBox(height: CohortSpacing.lg),
              CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session saved', style: CohortTextStyles.cardTitle),
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      savedRecord != null
                          ? 'Your work is saved to training history.'
                          : 'Session marked complete.',
                      style: CohortTextStyles.body,
                    ),
                  ],
                ),
              ),
              if (programmeProgress != null) ...[
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Programme progress',
                        style: CohortTextStyles.cardTitle,
                      ),
                      const SizedBox(height: CohortSpacing.sm),
                      Text(
                        programmeProgress!.displayLabel,
                        style: CohortTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: CohortSpacing.md),
              CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adaptation', style: CohortTextStyles.cardTitle),
                    const SizedBox(height: CohortSpacing.sm),
                    Text(_adaptationLine, style: CohortTextStyles.body),
                  ],
                ),
              ),
              if (_nextSession != null) ...[
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next scheduled session',
                        style: CohortTextStyles.cardTitle,
                      ),
                      const SizedBox(height: CohortSpacing.sm),
                      Text(
                        _nextPreview(_nextSession!),
                        style: CohortTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: CohortSpacing.xl),
              CohortButton(
                label: 'Done',
                onPressed: () => _handleDone(context),
              ),
              const SizedBox(height: CohortSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  String _nextPreview(ResolvedTodaySession next) {
    final slot = next.slotTitle?.trim();
    if (next.kind == ResolvedTodaySessionKind.programmeComplete) {
      return 'Programme complete — no further sessions scheduled.';
    }
    if (next.kind == ResolvedTodaySessionKind.restDay) {
      return 'Rest day • Week ${next.weekNumber ?? ''}';
    }

    final title = (slot != null && slot.isNotEmpty)
        ? slot
        : next.effectiveProtocolId ?? 'Training session';
    final week = next.weekNumber;
    final day = next.dayKey;
    final location = [
      if (week != null) 'Week $week',
      if (day != null) day,
    ].join(' • ');

    if (location.isEmpty) return title;
    return '$title • $location';
  }
}
