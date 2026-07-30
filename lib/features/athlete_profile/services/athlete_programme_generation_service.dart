import '../../../core/persistence/athlete_persistence.dart';
import '../../adaptation/models/accepted_adaptation_decision.dart';
import '../../plans/models/plan_assignment.dart';
import '../../plans/models/plan_definition.dart';
import '../../plans/models/programmed_session_key.dart';
import '../../plans/services/programmed_session_resolver.dart';
import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import '../models/athlete_profile.dart';
import 'athlete_profile_session.dart';

/// Prepares today's execution from the coach-authored programmed session when
/// a Plan is active; otherwise resolves a profile-only session.
class AthleteProgrammeGenerationService {
  AthleteProgrammeGenerationService({
    CoachBrainWorkoutPlanService? planService,
    ProgrammedSessionResolver? programmedResolver,
  }) : _planService = planService ?? CoachBrainWorkoutPlanService(),
       _programmedResolver = programmedResolver ??
           ProgrammedSessionResolver(
             planService: planService ?? CoachBrainWorkoutPlanService(),
           );

  final CoachBrainWorkoutPlanService _planService;
  final ProgrammedSessionResolver _programmedResolver;

  /// Prefer [prepareExecution]. Name retained for call-site compatibility.
  Future<AthleteGeneratedProgramme> generate(
    AthleteProfile profile, {
    PlanDefinition? activePlan,
    PlanAssignment? assignment,
    AcceptedAdaptationDecision? acceptedAdaptation,
  }) =>
      prepareExecution(
        profile,
        activePlan: activePlan,
        assignment: assignment,
        acceptedAdaptation: acceptedAdaptation,
      );

  Future<AthleteGeneratedProgramme> prepareExecution(
    AthleteProfile profile, {
    PlanDefinition? activePlan,
    PlanAssignment? assignment,
    AcceptedAdaptationDecision? acceptedAdaptation,
  }) async {
    final plan = activePlan ?? AthleteProfileSession.activePlan;
    final activeAssignment = assignment ?? AthleteProfileSession.activeAssignment;

    final CoachBrainWorkoutPlan bundle;
    ProgrammedSessionKey? programmedKey;
    String phaseLabel;

    if (plan != null && activeAssignment != null) {
      final prepared = await _programmedResolver.resolve(
        plan: plan,
        assignment: activeAssignment,
      );
      final brain = prepared.coachBrainPlan;
      if (brain == null) {
        throw StateError('Programmed session missing execution package.');
      }
      bundle = brain;
      programmedKey = prepared.programmedSessionKey;
      phaseLabel = _humanizePhase(activeAssignment.currentPhase);
    } else {
      bundle = await _planService.resolveFromProfile(
        profile: profile,
        activePlan: plan,
        assignment: activeAssignment,
      );
      phaseLabel = _humanizePhase(
        bundle.planningContext.recommendation?.selectedProgrammePhase?.label ??
            activeAssignment?.currentPhase ??
            bundle.planningContext.sessionBlueprint?.progressionContext
                .programmePhaseLabel ??
            bundle.brief.sessionDifficulty ??
            'Foundation',
      );
    }

    final programme = AthleteGeneratedProgramme(
      planBundle: bundle,
      programmeName: plan?.name ?? _planName(profile),
      phaseLabel: phaseLabel,
      programmedSessionKey: programmedKey,
      acceptedAdaptation: acceptedAdaptation,
    );

    AthleteProfileSession.bind(
      profile: profile,
      programme: programme,
      activePlan: plan,
      assignment: activeAssignment,
    );

    if (AthletePersistence.isInitialized) {
      await AthletePersistence.persistBoundSession();
    }
    return programme;
  }

  String _planName(AthleteProfile profile) {
    return '${profile.primaryGoal.label} Plan';
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
