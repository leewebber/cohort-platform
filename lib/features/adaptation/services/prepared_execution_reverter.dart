import '../../athlete_profile/models/athlete_profile.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../athlete_profile/services/athlete_programme_generation_service.dart';
import '../../plans/models/plan_assignment.dart';
import '../../plans/models/plan_definition.dart';

/// Clears an accepted adaptation and restores the programmed prepared execution.
///
/// Does not mutate the Plan or programmed session source — only the derived
/// prepared execution bound in [AthleteProfileSession].
class PreparedExecutionReverter {
  PreparedExecutionReverter({
    AthleteProgrammeGenerationService? generation,
  }) : _generation = generation ?? AthleteProgrammeGenerationService();

  final AthleteProgrammeGenerationService _generation;

  /// Returns the restored programme, or null when there is nothing to revert.
  Future<AthleteGeneratedProgramme?> revertToProgrammed({
    AthleteProfile? profile,
    PlanDefinition? activePlan,
    PlanAssignment? assignment,
  }) async {
    final current = AthleteProfileSession.programme;
    if (current?.acceptedAdaptation == null) return current;

    final resolvedProfile = profile ?? AthleteProfileSession.profile;
    final plan = activePlan ?? AthleteProfileSession.activePlan;
    final activeAssignment = assignment ?? AthleteProfileSession.activeAssignment;
    if (resolvedProfile == null || plan == null || activeAssignment == null) {
      return null;
    }

    return _generation.prepareExecution(
      resolvedProfile,
      activePlan: plan,
      assignment: activeAssignment,
    );
  }
}
