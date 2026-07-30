import '../../../core/persistence/athlete_persistence.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../athlete_profile/services/athlete_programme_generation_service.dart';
import '../../plans/services/plan_assignment_service.dart';
import '../../workout_player/models/workout_player_result.dart';
import '../models/capability_timeline.dart';
import '../models/session_completion.dart';
import 'plan_progression_service.dart';
import 'training_evidence_update_service.dart';
import '../../athlete_profile/models/athlete_profile.dart';
import '../../plans/models/plan_assignment.dart';
import '../../plans/models/plan_definition.dart';

/// Result of one adaptive progression cycle after workout completion.
class AdaptiveProgressionResult {
  const AdaptiveProgressionResult({
    required this.completion,
    required this.profile,
    required this.assignment,
    required this.programme,
    required this.plan,
  });

  final SessionCompletion completion;
  final AthleteProfile profile;
  final PlanAssignment assignment;
  final AthleteGeneratedProgramme programme;
  final PlanDefinition plan;
}

/// Orchestrates: completion → evidence → plan advance → prepare next execution.
///
/// Next day's package is resolved from the programmed session key (plan-canonical),
/// not invented from athlete history. Does not modify Coach Brain engines.
class AdaptiveProgressionCoordinator {
  AdaptiveProgressionCoordinator({
    TrainingEvidenceUpdateService evidenceService =
        const TrainingEvidenceUpdateService(),
    PlanProgressionService progressionService = const PlanProgressionService(),
    AthleteProgrammeGenerationService? generationService,
    PlanAssignmentService? assignmentService,
  }) : _evidence = evidenceService,
       _progression = progressionService,
       _generation = generationService ?? AthleteProgrammeGenerationService(),
       _assignments = assignmentService;

  final TrainingEvidenceUpdateService _evidence;
  final PlanProgressionService _progression;
  final AthleteProgrammeGenerationService _generation;
  final PlanAssignmentService? _assignments;

  /// Builds [SessionCompletion] from a finished player result.
  SessionCompletion buildCompletion({
    required WorkoutPlayerResult result,
    required String athleteId,
    String? sessionId,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    final plan = AthleteProfileSession.activePlan;
    final programme = AthleteProfileSession.programme;
    return SessionCompletion(
      completionId: 'completion.$athleteId.${stamp.millisecondsSinceEpoch}',
      athleteId: athleteId,
      sessionId: sessionId ?? programme?.planBundle.plan.sessionId,
      planId: plan?.planId,
      assignmentId: AthleteProfileSession.activeAssignment?.assignmentId,
      planName: plan?.name,
      sessionName: programme?.sessionTitle,
      completedAt: stamp,
      duration: result.duration,
      exercisesCompleted: result.exercisesCompleted,
      totalExercises: result.totalExercises,
      sessionRpe: result.sessionRpe,
      notes: result.notes,
      programmedSessionKey: programme?.programmedSessionKey?.value,
      planVersion: programme?.programmedSessionKey?.planVersion ?? plan?.version,
      acceptedAdaptationId: programme?.acceptedAdaptation?.decisionId,
    );
  }

  /// Full adaptive loop. Requires an active plan + profile in session.
  Future<AdaptiveProgressionResult> runAfterCompletion({
    required WorkoutPlayerResult result,
    required String athleteId,
    DateTime? now,
  }) async {
    final profile = AthleteProfileSession.profile;
    final plan = AthleteProfileSession.activePlan;
    final assignment = AthleteProfileSession.activeAssignment;
    if (profile == null || plan == null || assignment == null) {
      throw StateError(
        'Adaptive progression requires profile, active plan, and assignment.',
      );
    }

    final completion = buildCompletion(
      result: result,
      athleteId: athleteId,
      now: now,
    );
    SessionCompletionStore.add(completion);

    final evidence = _evidence.applyWithEvents(
      profile: profile,
      completion: completion,
      activePlan: plan,
      now: now,
    );
    CapabilityTimelineStore.addAll(evidence.events);
    final updatedProfile = evidence.profile;

    final advanced = _progression.advance(
      assignment: assignment,
      plan: plan,
    );

    _assignments?.updateProgress(
      currentPhase: advanced.currentPhase,
      currentWeek: advanced.currentWeek,
      currentDay: advanced.currentDay,
    );

    final programme = await _generation.prepareExecution(
      updatedProfile,
      activePlan: plan,
      assignment: advanced,
    );

    AthleteProfileSession.bind(
      profile: updatedProfile,
      programme: programme,
      activePlan: plan,
      assignment: advanced,
    );

    if (AthletePersistence.isInitialized) {
      await AthletePersistence.persistBoundSession(now: now);
    }

    return AdaptiveProgressionResult(
      completion: completion,
      profile: updatedProfile,
      assignment: advanced,
      programme: programme,
      plan: plan,
    );
  }
}
