import 'package:flutter/material.dart';

import '../../programme/presentation/athlete_completion_journey_copy.dart';
import '../../programme/widgets/athlete_programme_status_state.dart';

/// Distinct missing-athlete versus coach-only athlete-surface copy.
class AthleteIdentityAccessState extends StatelessWidget {
  const AthleteIdentityAccessState.missingProfile({super.key})
    : coachOnly = false;

  const AthleteIdentityAccessState.coachOnly({super.key}) : coachOnly = true;

  final bool coachOnly;

  @override
  Widget build(BuildContext context) {
    return AthleteProgrammeStatusState(
      badge: coachOnly
          ? AthleteCompletionJourneyCopy.athleteProfileRequired
          : AthleteCompletionJourneyCopy.accessRequired,
      headline: coachOnly
          ? AthleteCompletionJourneyCopy.coachOnlyHeadline
          : AthleteCompletionJourneyCopy.missingAthleteHeadline,
      explanation: coachOnly
          ? AthleteCompletionJourneyCopy.coachOnlySupporting
          : AthleteCompletionJourneyCopy.missingAthleteSupporting,
      icon: Icons.lock_outline,
    );
  }
}
