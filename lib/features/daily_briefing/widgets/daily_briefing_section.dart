import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../workout_player/models/workout_player_result.dart';
import '../../workout_player/services/workout_player_launcher.dart';
import '../models/daily_briefing.dart';
import '../services/daily_briefing_service.dart';

/// Home daily coaching briefing — not a dashboard.
class DailyBriefingSection extends StatelessWidget {
  const DailyBriefingSection({
    super.key,
    this.briefing,
    this.briefingService = const DailyBriefingService(),
    this.onSessionReturned,
  });

  final DailyBriefing? briefing;
  final DailyBriefingService briefingService;
  final ValueChanged<WorkoutPlayerResult?>? onSessionReturned;

  @override
  Widget build(BuildContext context) {
    final resolved = briefing ?? briefingService.build();
    if (!resolved.hasActivePlan) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(resolved.greeting, style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.md),
        Text(resolved.sessionHeadline, style: CohortTextStyles.body),
        const SizedBox(height: CohortSpacing.xl),
        _BriefRow(
          label: 'Estimated duration',
          value: resolved.durationLabel,
        ),
        _BriefRow(label: 'Training focus', value: resolved.trainingFocus),
        if (resolved.planName != null)
          _BriefRow(label: 'Current Plan', value: resolved.planName!),
        if (resolved.weekDayLabel != null)
          _BriefRow(
            label: 'Position',
            value: [
              if (resolved.phaseLabel != null) resolved.phaseLabel!,
              resolved.weekDayLabel!,
            ].join(' · '),
          ),
        if (resolved.yesterday != null) ...[
          const SizedBox(height: CohortSpacing.xl),
          Text('YESTERDAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.md),
          _YesterdayCard(yesterday: resolved.yesterday!),
        ],
        const SizedBox(height: CohortSpacing.xl),
        Text("TODAY'S FOCUS", style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        Text(resolved.trainingFocus, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.xl),
        Text("TODAY'S STANDARDS", style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        for (final standard in resolved.standards)
          _StandardRow(standard: standard),
        const SizedBox(height: CohortSpacing.xl),
        Text(
          resolved.motivation,
          style: CohortTextStyles.body.copyWith(
            fontStyle: FontStyle.italic,
            color: CohortColors.textPrimary,
          ),
        ),
        const SizedBox(height: CohortSpacing.xl),
        if (resolved.isRestDay)
          _RestDayCard(briefing: resolved)
        else
          CohortButton(
            label: "EXECUTE TODAY'S TRAINING",
            showTrailingArrow: true,
            onPressed: () async {
              final profile = AthleteProfileSession.profile;
              final programme = AthleteProfileSession.programme;
              if (profile == null || programme == null) return;
              final result = await WorkoutPlayerLauncher().launchWithPlan(
                context: context,
                athleteId: profile.athleteId,
                plan: programme.planBundle,
              );
              onSessionReturned?.call(result);
            },
          ),
      ],
    );
  }
}

class _BriefRow extends StatelessWidget {
  const _BriefRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: CohortTextStyles.small),
          ),
          Expanded(
            child: Text(
              value,
              style: CohortTextStyles.body.copyWith(
                color: CohortColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YesterdayCard extends StatelessWidget {
  const _YesterdayCard({required this.yesterday});

  final YesterdayBriefing yesterday;

  String _duration(Duration? d) {
    if (d == null) return '—';
    final m = d.inMinutes;
    return m <= 0 ? '${d.inSeconds}s' : '$m min';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.lg),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CohortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(yesterday.sessionName, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            'Completed · ${_duration(yesterday.duration)} · '
            'RPE ${yesterday.sessionRpe ?? '—'}',
            style: CohortTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _StandardRow extends StatelessWidget {
  const _StandardRow({required this.standard});

  final BriefingStandard standard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_box_outline_blank_rounded,
            size: 18,
            color: CohortColors.phosphor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: CohortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(standard.label, style: CohortTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text(standard.detail, style: CohortTextStyles.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({required this.briefing});

  final DailyBriefing briefing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.xl),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CohortColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rest day', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'No hard session today. Protect recovery — your next training day '
            'will meet you when you are ready.',
            style: CohortTextStyles.body,
          ),
          if (briefing.planName != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(
              '${briefing.planName} · ${briefing.weekDayLabel ?? ''}',
              style: CohortTextStyles.small,
            ),
          ],
        ],
      ),
    );
  }
}
