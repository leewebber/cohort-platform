import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../models/coach_athlete_daily_snapshot.dart';

class CoachAthleteOperationalCard extends StatelessWidget {
  const CoachAthleteOperationalCard({
    super.key,
    required this.snapshot,
    required this.onOpenAthlete,
    required this.onAssignProgramme,
  });

  final CoachAthleteDailySnapshot snapshot;
  final VoidCallback onOpenAthlete;
  final VoidCallback onAssignProgramme;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      onTap: onOpenAthlete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  snapshot.displayName,
                  style: CohortTextStyles.cardTitle,
                ),
              ),
              _StatusChip(status: snapshot.todayStatus),
            ],
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            snapshot.programmeName ?? 'No active programme',
            style: CohortTextStyles.body,
          ),
          if (snapshot.weekDayLabel != null &&
              snapshot.weekDayLabel!.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              snapshot.weekDayLabel!,
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textSecondary,
              ),
            ),
          ],
          if (snapshot.progressLabel != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              snapshot.progressLabel!,
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: CohortSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _InfoLine(
                  label: 'Compliance',
                  value: snapshot.complianceLabel,
                  highlight: snapshot.needsAttention,
                ),
              ),
              if (snapshot.lastActivityLabel != null)
                Expanded(
                  child: _InfoLine(
                    label: 'Last activity',
                    value: snapshot.lastActivityLabel!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: CohortSpacing.md),
          Row(
            children: [
              TextButton(
                onPressed: onOpenAthlete,
                child: const Text('Open athlete'),
              ),
              TextButton(
                onPressed: onAssignProgramme,
                child: Text(
                  snapshot.todayStatus ==
                          CoachAthleteTodayStatus.noActiveProgramme
                      ? 'Assign programme'
                      : 'Replace programme',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CoachAthleteTodayStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      CoachAthleteTodayStatus.trainingToday =>
        (CohortColors.oliveSoft, CohortColors.olive),
      CoachAthleteTodayStatus.completedToday ||
      CoachAthleteTodayStatus.dayComplete =>
        (CohortColors.oliveSoft, CohortColors.success),
      CoachAthleteTodayStatus.restDay =>
        (CohortColors.surfaceRaised, CohortColors.textSecondary),
      CoachAthleteTodayStatus.behindSchedule =>
        (const Color(0xFF2A2118), CohortColors.warning),
      CoachAthleteTodayStatus.noActiveProgramme =>
        (const Color(0xFF2A1C18), CohortColors.danger),
      CoachAthleteTodayStatus.paused =>
        (const Color(0xFF2A2118), CohortColors.warning),
      CoachAthleteTodayStatus.programmeComplete =>
        (CohortColors.oliveSoft, CohortColors.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CohortSpacing.sm,
        vertical: CohortSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CohortColors.border),
      ),
      child: Text(
        status.displayLabel,
        style: CohortTextStyles.small.copyWith(color: foreground),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CohortTextStyles.small.copyWith(
            color: CohortColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: CohortTextStyles.small.copyWith(
            color: highlight ? CohortColors.warning : CohortColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
