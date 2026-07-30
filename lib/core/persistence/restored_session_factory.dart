import '../../features/adaptation/models/accepted_adaptation_decision.dart';
import '../../features/athlete_profile/models/athlete_profile.dart';
import '../../features/athlete_profile/services/athlete_profile_session.dart';
import '../../features/plans/models/programmed_session_key.dart';
import '../../features/workout_player/services/coach_brain_workout_plan_service.dart';
import '../../knowledge/gap_analysis/capability_evidence_models.dart';
import '../../planning/models/planning_goal_context.dart';
import '../../planning/models/planning_input.dart';
import '../../planning/orchestration/models/planning_context.dart';
import 'session_execution_plan_codec.dart';

/// Builds session bindings from persisted [GeneratedSessionRecord] without Coach Brain.
class RestoredSessionFactory {
  const RestoredSessionFactory();

  AthleteGeneratedProgramme toProgramme({
    required GeneratedSessionRecord record,
    required AthleteProfile profile,
  }) {
    final stamp = record.generatedAt;
    final input = PlanningInput(
      athleteId: profile.athleteId,
      goalContext: PlanningGoalContext(
        goalId: profile.planningGoalId,
        goalLabel: profile.planningGoalLabel,
      ),
      capabilityEvidence: const AthleteCapabilityEvidenceProfile(items: []),
      knowledgeOntologyVersion: record.ontologyVersion ?? 'restored.v1',
      asOf: stamp,
    );

    final context = PlanningContext(
      orchestrationId: record.orchestrationId ??
          'restored.${record.assignmentId}.${stamp.millisecondsSinceEpoch}',
      startedAt: stamp,
      completedAt: stamp,
      orchestrationStatus: OrchestrationStatus.complete,
      input: input,
      sessionExecutionPlan: record.plan,
      diagnostics: const PipelineDiagnostics(outcome: PipelineOutcome.success),
    );

    ProgrammedSessionKey? key;
    final keyRaw = record.programmedSessionKey;
    if (keyRaw != null && keyRaw.isNotEmpty) {
      try {
        key = ProgrammedSessionKey.parse(keyRaw);
      } catch (_) {
        key = null;
      }
    }

    AcceptedAdaptationDecision? adaptation;
    final adaptationMap = record.acceptedAdaptation;
    if (adaptationMap != null) {
      adaptation = AcceptedAdaptationDecision.fromPersistenceMap(adaptationMap);
    }

    return AthleteGeneratedProgramme(
      planBundle: CoachBrainWorkoutPlan(
        planningContext: context,
        plan: record.plan,
        brief: record.brief,
      ),
      programmeName: record.programmeName ?? profile.planningGoalLabel,
      phaseLabel: record.phaseLabel,
      programmedSessionKey: key,
      acceptedAdaptation: adaptation,
    );
  }
}

/// Restore / reconstruct policy (see Local_Persistence_v1 + Session_Authority_Model_v1).
///
/// Restore persisted prepared execution when valid.
/// Otherwise reconstruct from the same Plan version programmed session key —
/// never invent materially different training from athlete history.
class GeneratedSessionRestorePolicy {
  const GeneratedSessionRestorePolicy();

  bool shouldRestore({
    required GeneratedSessionRecord? record,
    required String? activePlanId,
    required String? activeAssignmentId,
    String? expectedProgrammedSessionKey,
    DateTime? now,
  }) {
    if (record == null) return false;
    if (!record.isIntendedForToday(now)) return false;
    if (!record.plan.hasExecutableBlocks) return false;

    if (activePlanId != null && activeAssignmentId != null) {
      if (record.planId != activePlanId) return false;
      if (record.assignmentId != activeAssignmentId) return false;
      if (expectedProgrammedSessionKey != null &&
          record.programmedSessionKey != null &&
          record.programmedSessionKey != expectedProgrammedSessionKey) {
        return false;
      }
      return true;
    }

    return record.planId == null && record.assignmentId == null;
  }
}
