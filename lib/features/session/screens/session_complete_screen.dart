import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/models/training_session_record_status.dart';
import '../models/active_session_state.dart';
import '../widgets/athlete/athlete_block_card.dart';

class SessionCompleteScreen extends StatelessWidget {
  const SessionCompleteScreen({
    super.key,
    required this.state,
    this.savedRecord,
    this.onDone,
  });

  final ActiveSessionState state;
  final TrainingSessionRecord? savedRecord;
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SessionCompletionSummary(
                sessionTitle: state.plan.sessionTitle,
                completedCount: state.completedCount,
                totalCount: executableBlocks,
                skippedCount: skipped.clamp(0, executableBlocks),
                elapsedLabel: _elapsedLabel(),
                contextLabel: state.plan.programmeContextLabel,
              ),
              if (savedRecord != null) ...[
                const SizedBox(height: CohortSpacing.md),
                Text(
                  'Saved to training history (${savedRecord!.status.displayLabel}).',
                  style: CohortTextStyles.body,
                ),
              ],
              const Spacer(),
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
}
