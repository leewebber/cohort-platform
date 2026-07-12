import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../../models/session_win.dart';

/// Post-session summary for completed strength workouts.
class SessionReviewScreen extends StatelessWidget {
  const SessionReviewScreen({
    super.key,
    required this.wins,
    required this.onReturnHome,
    this.sessionTitle,
    this.sessionNote,
    this.endedEarly = false,
    this.completedExerciseCount,
    this.totalExerciseCount,
    this.endReasonLabel,
  });

  final String? sessionTitle;
  final List<SessionWin> wins;
  final String? sessionNote;
  final bool endedEarly;
  final int? completedExerciseCount;
  final int? totalExerciseCount;
  final String? endReasonLabel;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) {
    final trimmedNote = sessionNote?.trim();

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
              Text(
                'Session Complete',
                style: CohortTextStyles.h1,
              ),
              if (sessionTitle != null && sessionTitle!.trim().isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  sessionTitle!,
                  style: CohortTextStyles.body,
                ),
              ],
              if (endedEarly) ...[
                const SizedBox(height: CohortSpacing.lg),
                Text(
                  'SESSION ENDED EARLY',
                  style: CohortTextStyles.eyebrow.copyWith(
                    color: CohortColors.olive,
                  ),
                ),
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  'Completed ${completedExerciseCount ?? 0} of ${totalExerciseCount ?? 0} exercises',
                  style: CohortTextStyles.body,
                ),
                if (endReasonLabel != null && endReasonLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    'Reason: ${endReasonLabel!.trim()}',
                    style: CohortTextStyles.small,
                  ),
                ],
              ],
              const SizedBox(height: CohortSpacing.xl),
              Text(
                "Today's Wins",
                style: CohortTextStyles.h2,
              ),
              const SizedBox(height: CohortSpacing.md),
              for (var index = 0; index < wins.length; index++) ...[
                if (index > 0) const SizedBox(height: CohortSpacing.md),
                _SessionWinCard(win: wins[index]),
              ],
              if (trimmedNote != null && trimmedNote.isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.xl),
                Text(
                  'YOUR NOTE',
                  style: CohortTextStyles.eyebrow,
                ),
                const SizedBox(height: CohortSpacing.sm),
                CohortCard(
                  child: Text(
                    trimmedNote,
                    style: CohortTextStyles.body,
                  ),
                ),
              ],
              const SizedBox(height: CohortSpacing.xl),
              CohortButton(
                label: 'Return Home',
                onPressed: onReturnHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionWinCard extends StatelessWidget {
  const _SessionWinCard({required this.win});

  final SessionWin win;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (win.type) {
      SessionWinType.loadProgress ||
      SessionWinType.repProgress ||
      SessionWinType.volumeProgress ||
      SessionWinType.rpeProgress =>
        CohortColors.success,
      SessionWinType.matchedPerformance || SessionWinType.consistency =>
        CohortColors.olive,
      SessionWinType.firstPerformance => CohortColors.olive,
      SessionWinType.completedAsPlanned => CohortColors.textSecondary,
      SessionWinType.recoveryDecision => CohortColors.warning,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: CohortRadius.smallRadius,
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            win.title,
            style: CohortTextStyles.cardTitle.copyWith(
              color: accentColor,
            ),
          ),
          if (win.message.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              win.message,
              style: CohortTextStyles.small,
            ),
          ],
          if (win.supportingDetail != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              win.supportingDetail!,
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
