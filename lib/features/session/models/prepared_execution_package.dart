import '../../adaptation/models/accepted_adaptation_decision.dart';
import '../../plans/models/programmed_session_key.dart';
import '../../workout_player/models/workout_session_brief.dart';
import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import 'session_execution_plan.dart';

/// Athlete-facing prepared execution for today.
///
/// Retains an immutable [programmedSessionKey] linking to the coach-authored
/// programmed session. Accepted adaptations are derived decisions — they do
/// not mutate the programmed source.
class PreparedExecutionPackage {
  const PreparedExecutionPackage({
    required this.programmedSessionKey,
    required this.plan,
    required this.brief,
    required this.preparedAt,
    this.planId,
    this.planVersion,
    this.assignmentId,
    this.acceptedAdaptation,
    this.coachBrainPlan,
  });

  final ProgrammedSessionKey programmedSessionKey;
  final SessionExecutionPlan plan;
  final WorkoutSessionBrief brief;
  final DateTime preparedAt;
  final String? planId;
  final String? planVersion;
  final String? assignmentId;
  final AcceptedAdaptationDecision? acceptedAdaptation;
  final CoachBrainWorkoutPlan? coachBrainPlan;

  bool get hasAcceptedAdaptation => acceptedAdaptation != null;

  PreparedExecutionPackage withAcceptedAdaptation(
    AcceptedAdaptationDecision decision,
  ) {
    return PreparedExecutionPackage(
      programmedSessionKey: programmedSessionKey,
      plan: plan,
      brief: brief,
      preparedAt: preparedAt,
      planId: planId,
      planVersion: planVersion,
      assignmentId: assignmentId,
      acceptedAdaptation: decision,
      coachBrainPlan: coachBrainPlan,
    );
  }

  PreparedExecutionPackage withoutAdaptation() {
    return PreparedExecutionPackage(
      programmedSessionKey: programmedSessionKey,
      plan: plan,
      brief: brief,
      preparedAt: preparedAt,
      planId: planId,
      planVersion: planVersion,
      assignmentId: assignmentId,
      coachBrainPlan: coachBrainPlan,
    );
  }
}

/// Domain guard: previous performance must never become a load prescription.
class LoadSelectionPolicy {
  const LoadSelectionPolicy();

  /// Always null — Cohort never computes a next / forced load.
  double? suggestedNextLoadKg({
    double? previousLoadKg,
    double? programmedLoadKg,
  }) =>
      null;

  bool get allowsAutomaticProgression => false;
  bool get allowsForcedLoadFromPrevious => false;
}
