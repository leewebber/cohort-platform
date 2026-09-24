import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/athlete_programme_continuity.dart';
import '../domain/enrolment_iana_timezone.dart';
import '../presentation/athlete_completion_journey_copy.dart';
import '../presentation/athlete_programme_continuity_copy.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/enrolment_date_presentation.dart';
import 'athlete_programme_fact_list.dart';

/// Compact status composition: badge, headline, explanation, optional detail.
class AthleteProgrammeStatusState extends StatelessWidget {
  const AthleteProgrammeStatusState({
    super.key,
    required this.badge,
    required this.headline,
    required this.explanation,
    this.technical,
    this.action,
    this.icon = Icons.info_outline,
  });

  final String badge;
  final String headline;
  final String explanation;
  final String? technical;
  final Widget? action;
  final IconData icon;

  factory AthleteProgrammeStatusState.fromContinuity(
    AthleteProgrammeContinuity continuity, {
    Widget? action,
    String? completedProgrammeTitle,
  }) {
    if (continuity.needsTimezoneRepair) {
      return AthleteProgrammeStatusState(
        badge: 'Action needed',
        headline: AthleteProgrammeContinuityCopy.timezoneRepairHeadline,
        explanation: AthleteProgrammeContinuityCopy.timezoneRepairRequired,
        technical:
            '${AthleteProgrammeContinuityCopy.scheduleUnresolved} '
            '${AthleteProgrammeContinuityCopy.repairNotApplied}',
        icon: Icons.schedule,
        action: action,
      );
    }
    switch (continuity.status) {
      case AthleteProgrammeContinuityStatus.currentDefault:
        return AthleteProgrammeStatusState(
          badge: AthleteProgrammeContinuityCopy.currentProgramme,
          headline: _currentHeadline(continuity, completedProgrammeTitle),
          explanation: _currentExplanation(continuity, completedProgrammeTitle),
          action: action,
        );
      case AthleteProgrammeContinuityStatus.currentPinned:
        return AthleteProgrammeStatusState(
          badge: AthleteProgrammeContinuityCopy.currentProgramme,
          headline: completedProgrammeTitle == null
              ? AthleteProgrammeContinuityCopy.programmeUnchangedHeadline
              : _currentHeadline(continuity, completedProgrammeTitle),
          explanation: completedProgrammeTitle == null
              ? AthleteProgrammeContinuityCopy.continuingStartedVersion
              : _currentExplanation(continuity, completedProgrammeTitle),
          action: action,
        );
      case AthleteProgrammeContinuityStatus.currentPinnedWithDifferentAvailable:
        return AthleteProgrammeStatusState(
          badge: AthleteProgrammeContinuityCopy.currentProgramme,
          headline: completedProgrammeTitle == null
              ? AthleteProgrammeContinuityCopy.programmeUnchangedHeadline
              : _currentHeadline(continuity, completedProgrammeTitle),
          explanation: completedProgrammeTitle == null
              ? '${AthleteProgrammeContinuityCopy.continuingStartedVersion} '
                    '${AthleteProgrammeContinuityCopy.differentVersionAvailable}'
              : _currentExplanation(continuity, completedProgrammeTitle),
          action: action,
        );
      case AthleteProgrammeContinuityStatus.pinnedUnavailable:
        return AthleteProgrammeStatusState(
          badge: 'Unavailable',
          headline: AthleteProgrammeContinuityCopy.pinnedUnavailableHeadline,
          explanation: AthleteProgrammeContinuityCopy.pinnedUnavailable,
          action: action,
          icon: Icons.cloud_off_outlined,
        );
      case AthleteProgrammeContinuityStatus.completed:
        return AthleteProgrammeStatusState(
          badge: AthleteCompletionJourneyCopy.complete,
          headline: AthleteCompletionJourneyCopy.completedProgrammesHeadline(
            AthleteCompletionJourneyCopy.displayTitle(
              continuity.pinnedTitle,
              fallback: continuity.lineageCode,
            ),
          ),
          explanation:
              AthleteCompletionJourneyCopy.completedProgrammesSupporting,
          action: action,
        );
      case AthleteProgrammeContinuityStatus.none:
        return AthleteProgrammeStatusState(
          badge: 'Available',
          headline: 'You are not enrolled in a programme yet.',
          explanation: AthleteProgrammeContinuityCopy.overviewMessage(
            continuity,
          ),
          action: action,
        );
    }
  }

  static String _currentHeadline(
    AthleteProgrammeContinuity continuity,
    String? completedProgrammeTitle,
  ) {
    if (completedProgrammeTitle == null) {
      return AthleteProgrammeContinuityCopy.currentProgrammeHeadline;
    }
    return AthleteCompletionJourneyCopy.currentAfterCompletedHeadline(
      AthleteCompletionJourneyCopy.displayTitle(
        continuity.pinnedTitle,
        fallback: continuity.lineageCode,
      ),
    );
  }

  static String _currentExplanation(
    AthleteProgrammeContinuity continuity,
    String? completedProgrammeTitle,
  ) {
    if (completedProgrammeTitle == null) {
      return AthleteProgrammeContinuityCopy.currentProgramme;
    }
    return AthleteCompletionJourneyCopy.currentAfterCompletedSupporting(
      AthleteCompletionJourneyCopy.displayTitle(completedProgrammeTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$badge. $headline. $explanation',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CohortColors.surfaceRaised,
          border: Border.all(color: CohortColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: CohortColors.phosphor),
                  const SizedBox(width: 8),
                  AthleteProgrammeStatusChip(label: badge),
                ],
              ),
              const SizedBox(height: CohortSpacing.sm),
              Text(headline, style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.xs),
              Text(explanation, style: CohortTextStyles.body),
              if (technical != null) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(technical!, style: CohortTextStyles.muted),
              ],
              if (action != null) ...[
                const SizedBox(height: CohortSpacing.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EnrolmentSuccessState extends StatelessWidget {
  const EnrolmentSuccessState({
    super.key,
    required this.programmeTitle,
    required this.startDate,
    required this.timezoneIana,
    this.action,
  });

  final String programmeTitle;
  final DateTime startDate;
  final String timezoneIana;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final date = EnrolmentDatePresentation.athleteFacing(startDate);
    final friendly = EnrolmentIanaLabels.labelFor(timezoneIana);
    return AthleteProgrammeStatusState(
      badge: 'Enrolled',
      headline: AthleteProgrammeContinuityCopy.enrolledHeadline,
      explanation: programmeTitle,
      icon: Icons.check_circle_outline,
      action:
          action ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AthleteProgrammeContinuityCopy.confirmedStartDate,
                style: CohortTextStyles.tileLabel,
              ),
              const SizedBox(height: 4),
              Text(date, style: CohortTextStyles.body),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                AthleteProgrammeContinuityCopy.trainingTimezone,
                style: CohortTextStyles.tileLabel,
              ),
              const SizedBox(height: 4),
              Text(friendly, style: CohortTextStyles.body),
              Text(timezoneIana, style: CohortTextStyles.muted),
            ],
          ),
    );
  }
}

class EnrolmentContinuityPanel extends StatelessWidget {
  const EnrolmentContinuityPanel({super.key, required this.programmeTitle});

  final String programmeTitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CohortColors.oliveSoft,
        border: Border.all(color: CohortColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Continuity', style: CohortTextStyles.sectionLabel),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              AthleteProgrammeDecisionCopy.enrolReviewBody(programmeTitle),
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              AthleteProgrammeContinuityCopy.travelAnchor,
              style: CohortTextStyles.muted,
            ),
          ],
        ),
      ),
    );
  }
}
