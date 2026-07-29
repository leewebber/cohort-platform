import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import '../../plans/models/plan.dart';
import '../../plans/models/plan_assignment.dart';
import '../models/athlete_profile.dart';
import 'athlete_profile_session.dart';

/// Runs Coach Brain for a profile (optionally under an active plan).
class AthleteProgrammeGenerationService {
  AthleteProgrammeGenerationService({
    CoachBrainWorkoutPlanService? planService,
  }) : _planService = planService ?? CoachBrainWorkoutPlanService();

  final CoachBrainWorkoutPlanService _planService;

  Future<AthleteGeneratedProgramme> generate(
    AthleteProfile profile, {
    Plan? activePlan,
    PlanAssignment? assignment,
  }) async {
    final plan = activePlan ?? AthleteProfileSession.activePlan;
    final activeAssignment = assignment ?? AthleteProfileSession.activeAssignment;

    final bundle = await _planService.resolveFromProfile(
      profile: profile,
      activePlan: plan,
      assignment: activeAssignment,
    );
    final phase =
        bundle.planningContext.recommendation?.selectedProgrammePhase?.label ??
        activeAssignment?.currentPhase ??
        bundle.planningContext.sessionBlueprint?.progressionContext
            .programmePhaseLabel ??
        bundle.brief.sessionDifficulty ??
        'Foundation';

    final programme = AthleteGeneratedProgramme(
      planBundle: bundle,
      programmeName: plan?.name ?? _programmeName(profile),
      phaseLabel: _humanizePhase(phase),
    );

    AthleteProfileSession.bind(
      profile: profile,
      programme: programme,
      activePlan: plan,
      assignment: activeAssignment,
    );
    return programme;
  }

  String _programmeName(AthleteProfile profile) {
    return '${profile.primaryGoal.label} Programme';
  }

  String _humanizePhase(String raw) {
    final leaf = raw.contains('.') ? raw.split('.').last : raw;
    return leaf
        .replaceAll('_', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }
}
