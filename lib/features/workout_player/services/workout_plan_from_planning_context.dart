import '../../../planning/orchestration/models/planning_context.dart';
import '../../../planning/session_blueprint/models/session_blueprint.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/workout_session_brief.dart';

/// Maps planning orchestration output → athlete overview brief + plan.
///
/// Does not run engines — read-only projection from [PlanningContext].
class WorkoutPlanFromPlanningContext {
  const WorkoutPlanFromPlanningContext();

  WorkoutSessionBrief briefFrom(PlanningContext context) {
    final plan = context.sessionExecutionPlan;
    final blueprint = context.sessionBlueprint;
    final recommendation = context.recommendation;

    final objectiveSummary = blueprint?.objective.summary.trim();
    final objective =
        (objectiveSummary != null && objectiveSummary.isNotEmpty)
        ? objectiveSummary
        : (recommendation?.adaptationRationale.isNotEmpty == true
              ? recommendation!.adaptationRationale.join(' ').trim()
              : null);

    final focus = blueprint?.desiredAdaptations.isNotEmpty == true
        ? blueprint!.desiredAdaptations.first.capabilityLabel
        : recommendation?.capabilityPriorities.firstOrNull?.capabilityLabel;

    final intentLabel =
        blueprint?.primaryTrainingIntentLabel.trim().isNotEmpty == true
        ? blueprint!.primaryTrainingIntentLabel.trim()
        : recommendation
              ?.trainingIntentRecommendations
              .firstOrNull
              ?.trainingIntentLabel;

    final difficulty = _difficultyFromBlueprint(blueprint);

    final sessionNotes = context.aggregatedExplainability.combinedNarrative
        .trim();
    final coachNotes = plan?.coachNotes?.trim().isNotEmpty == true
        ? plan!.coachNotes!.trim()
        : blueprint?.explainability.narrativeSummary.trim();

    final archetypeLabel = blueprint?.sessionArchetype.label.trim();

    return WorkoutSessionBrief(
      sessionName: plan?.sessionTitle.trim().isNotEmpty == true
          ? plan!.sessionTitle.trim()
          : (archetypeLabel != null && archetypeLabel.isNotEmpty
                ? archetypeLabel
                : 'Today\'s Training'),
      objective: (objective == null || objective.isEmpty) ? null : objective,
      estimatedDurationMinutes:
          plan?.durationMin ??
          context.prescriptionResult?.estimatedDurationMinutesMax,
      primaryFocus: focus,
      trainingIntent: intentLabel,
      sessionDifficulty: difficulty,
      sessionNotes: sessionNotes.isEmpty ? null : sessionNotes,
      coachNotes: (coachNotes == null || coachNotes.isEmpty)
          ? null
          : coachNotes,
    );
  }

  SessionExecutionPlan? planFrom(PlanningContext context) =>
      context.sessionExecutionPlan;

  String? _difficultyFromBlueprint(SessionBlueprint? blueprint) {
    if (blueprint == null) return null;
    final intensity = _intensityLabel(blueprint.semanticIntensity.level);
    final volume = _volumeLabel(blueprint.semanticVolume.level);
    return '$intensity intensity · $volume volume';
  }

  String _intensityLabel(SemanticIntensityLevel level) {
    return switch (level) {
      SemanticIntensityLevel.restorative => 'Restorative',
      SemanticIntensityLevel.low => 'Low',
      SemanticIntensityLevel.moderate => 'Moderate',
      SemanticIntensityLevel.moderatelyHigh => 'Moderately high',
      SemanticIntensityLevel.high => 'High',
      SemanticIntensityLevel.maximal => 'Maximal',
      SemanticIntensityLevel.variable => 'Variable',
    };
  }

  String _volumeLabel(SemanticVolumeLevel level) {
    return switch (level) {
      SemanticVolumeLevel.minimal => 'Minimal',
      SemanticVolumeLevel.low => 'Low',
      SemanticVolumeLevel.moderate => 'Moderate',
      SemanticVolumeLevel.high => 'High',
      SemanticVolumeLevel.veryHigh => 'Very high',
    };
  }
}
