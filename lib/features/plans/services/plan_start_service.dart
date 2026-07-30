import '../../../core/persistence/athlete_persistence.dart';
import '../../athlete_profile/models/athlete_profile.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../athlete_profile/services/athlete_programme_generation_service.dart';
import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import '../models/plan_assignment.dart';
import '../models/plan_definition.dart';
import 'plan_assignment_service.dart';
import 'programmed_session_resolver.dart';

/// Starts a plan: assignment + prepare today's programmed execution.
class PlanStartService {
  PlanStartService({
    PlanAssignmentService? assignmentService,
    AthleteProgrammeGenerationService? generationService,
    CoachBrainWorkoutPlanService? planService,
  }) : _assignments = assignmentService ?? PlanAssignmentService(),
       _generation = generationService ??
           AthleteProgrammeGenerationService(
             planService: planService,
             programmedResolver: planService == null
                 ? null
                 : ProgrammedSessionResolver(planService: planService),
           );

  final PlanAssignmentService _assignments;
  final AthleteProgrammeGenerationService _generation;

  Future<
    ({
      PlanDefinition plan,
      PlanAssignment assignment,
      AthleteGeneratedProgramme programme,
    })
  >
  startPlan({
    required String planId,
    required String athleteId,
    AthleteProfile? existingProfile,
    String? displayName,
  }) async {
    final plan = _assignments.requirePlan(planId);
    final profile = _assignments.ensureProfile(
      existing: existingProfile ?? AthleteProfileSession.profile,
      plan: plan,
      athleteId: athleteId,
      displayName: displayName ?? AthleteProfileSession.profile?.displayName,
    );
    final assignment = _assignments.assign(athleteId: athleteId, plan: plan);

    final programme = await _generation.prepareExecution(
      profile,
      activePlan: plan,
      assignment: assignment,
    );

    final updatedAssignment =
        _assignments.updateProgress(currentPhase: programme.phaseLabel) ??
        assignment.copyWith(currentPhase: programme.phaseLabel);

    AthleteProfileSession.bind(
      profile: profile,
      programme: programme.copyWith(),
      activePlan: plan,
      assignment: updatedAssignment,
    );

    if (AthletePersistence.isInitialized) {
      await AthletePersistence.persistBoundSession();
    }

    return (plan: plan, assignment: updatedAssignment, programme: programme);
  }
}
