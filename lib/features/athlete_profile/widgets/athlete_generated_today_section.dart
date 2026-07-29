import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/today_session_card.dart';
import '../../workout_player/services/workout_player_launcher.dart';
import '../services/athlete_profile_session.dart';

/// Home "Today" card driven by active PlanAssignment + Coach Brain session.
class AthleteGeneratedTodaySection extends StatelessWidget {
  const AthleteGeneratedTodaySection({
    super.key,
    this.sessionComplete = false,
    this.onSessionReturned,
  });

  final bool sessionComplete;
  final VoidCallback? onSessionReturned;

  @override
  Widget build(BuildContext context) {
    final profile = AthleteProfileSession.profile;
    final programme = AthleteProfileSession.programme;
    final plan = AthleteProfileSession.activePlan;
    final assignment = AthleteProfileSession.activeAssignment;
    if (profile == null || programme == null) {
      return const SizedBox.shrink();
    }

    final duration = programme.durationMinutes;
    final durationLabel = duration == null
        ? 'Duration TBD'
        : '$duration min estimated';

    final weekLabel =
        assignment?.weekDayLabel ?? '${profile.trainingDaysPerWeek} days / week';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan != null && assignment != null) ...[
          Text('ACTIVE PLAN', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.sm),
          Text(plan.name, style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            '${assignment.currentPhase} · ${assignment.weekDayLabel}',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.xl),
        ],
        TodaySessionCard(
          title: sessionComplete ? 'Training Complete' : programme.sessionTitle,
          subtitle: sessionComplete
              ? 'Well done — today\'s session is finished.'
              : 'Today\'s Session · ${programme.goalLabel}',
          programmeName: plan?.name ?? programme.programmeName,
          weekLabel: weekLabel,
          duration: durationLabel,
          sessionGoal: 'Goal: ${plan?.goalLabel ?? profile.primaryGoal.label}',
          progressLabel: profile.displayName,
          status: sessionComplete ? 'Completed today' : 'Planned Session',
          statusDetail: sessionComplete
              ? 'Training complete for today.'
              : (plan != null
                    ? 'Active plan · personalised for today.'
                    : 'Built for you by Cohort.'),
          buttonLabel: sessionComplete
              ? 'TRAINING COMPLETE'
              : 'EXECUTE TODAY\'S SESSION',
          onPressed: sessionComplete
              ? null
              : () async {
                  await WorkoutPlayerLauncher().launchWithPlan(
                    context: context,
                    athleteId: profile.athleteId,
                    plan: programme.planBundle,
                  );
                  onSessionReturned?.call();
                },
        ),
      ],
    );
  }
}

/// Empty state when the athlete has no active plan.
class ChoosePlanEntryCard extends StatelessWidget {
  const ChoosePlanEntryCard({super.key, required this.onChoosePlan});

  final VoidCallback onChoosePlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.xl),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CohortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S TRAINING", style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.lg),
          Text('Choose a Plan', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Browse coaching plans and start one. Cohort will generate '
            'today\'s session from your active plan.',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(
            label: 'CHOOSE A PLAN',
            showTrailingArrow: true,
            onPressed: onChoosePlan,
          ),
        ],
      ),
    );
  }
}

/// Legacy onboarding entry (profile without plan).
class AthleteOnboardingEntryCard extends StatelessWidget {
  const AthleteOnboardingEntryCard({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ChoosePlanEntryCard(onChoosePlan: onStart);
  }
}
