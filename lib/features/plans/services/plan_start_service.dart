import '../../athlete_profile/models/athlete_profile.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import '../models/plan.dart';
import '../models/plan_assignment.dart';
import 'plan_assignment_service.dart';

/// Starts a plan: assignment + Coach Brain today's session.
class PlanStartService {
  PlanStartService({
    PlanAssignmentService? assignmentService,
    CoachBrainWorkoutPlanService? planService,
  }) : _assignments = assignmentService ?? PlanAssignmentService(),
       _planService = planService ?? CoachBrainWorkoutPlanService();

  final PlanAssignmentService _assignments;
  final CoachBrainWorkoutPlanService _planService;

  Future<({Plan plan, PlanAssignment assignment, AthleteGeneratedProgramme programme})>
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

    final bundle = await _planService.resolveFromProfile(
      profile: profile,
      activePlan: plan,
      assignment: assignment,
    );

    final phase =
        bundle.planningContext.recommendation?.selectedProgrammePhase?.label ??
        assignment.currentPhase;

    final programme = AthleteGeneratedProgramme(
      planBundle: bundle,
      programmeName: plan.name,
      phaseLabel: phase,
    );

    final updatedAssignment = assignment.copyWith(currentPhase: phase);

    AthleteProfileSession.bind(
      profile: profile,
      programme: programme,
      activePlan: plan,
      assignment: updatedAssignment,
    );

    return (plan: plan, assignment: updatedAssignment, programme: programme);
  }
}
