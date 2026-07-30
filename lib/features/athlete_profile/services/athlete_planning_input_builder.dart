import '../../../knowledge/gap_analysis/capability_evidence_models.dart';
import '../../../planning/models/planning_goal_context.dart';
import '../../../planning/models/planning_input.dart';
import '../../athlete_profile/models/athlete_profile.dart';
import '../../plans/models/plan_assignment.dart';
import '../../plans/models/plan_definition.dart';

/// Maps [AthleteProfile] (+ optional active [PlanDefinition]) → [PlanningInput].
///
/// Plan context is carried via preferences tags and existing PlanningInput fields
/// so Coach Brain / engines remain unchanged.
class AthletePlanningInputBuilder {
  const AthletePlanningInputBuilder();

  static const _seedCapabilityIds = [
    'cohort.capability.relative_strength',
    'cohort.capability.aerobic_capacity',
    'cohort.capability.work_capacity',
    'cohort.capability.movement_competency',
    'cohort.capability.pushing_strength',
    'cohort.capability.pulling_strength',
    'cohort.capability.strength_endurance',
    'cohort.capability.grip_strength',
  ];

  /// Preference tag prefix for active plan id (asserted in tests).
  static const planIdTagPrefix = 'plan_id:';
  static const assignmentIdTagPrefix = 'plan_assignment:';
  static const progressionModelTagPrefix = 'progression_model:';
  static const coachingFocusTagPrefix = 'coaching_focus:';

  PlanningInput build({
    required AthleteProfile profile,
    required String knowledgeOntologyVersion,
    PlanDefinition? activePlan,
    PlanAssignment? assignment,
    DateTime? asOf,
  }) {
    final days = activePlan?.recommendedDaysPerWeek ?? profile.trainingDaysPerWeek;
    final duration = activePlan?.typicalSessionDurationMinutes ??
        profile.preferredSessionDurationMinutes;
    final goal = activePlan?.primaryGoal ?? profile.primaryGoal;

    final preferences = <String>[
      if (activePlan != null) '$planIdTagPrefix${activePlan.planId}',
      if (assignment != null) '$assignmentIdTagPrefix${assignment.assignmentId}',
      if (activePlan != null)
        '$progressionModelTagPrefix${activePlan.progressionModel}',
      if (activePlan != null)
        '$coachingFocusTagPrefix${activePlan.coachingFocus}',
      if (activePlan != null)
        for (final cap in activePlan.capabilityPriorities) 'priority_$cap',
      if (goal.preferenceTag != null) goal.preferenceTag!,
      if (profile.preferredTrainingStyle != null)
        profile.preferredTrainingStyle!,
      'days_$days',
      'duration_$duration',
      'experience_${profile.experienceLevel.name}',
      if (assignment != null) 'week_${assignment.currentWeek}',
      if (assignment != null) 'day_${assignment.currentDay}',
    ];

    return PlanningInput(
      athleteId: profile.athleteId,
      goalContext: PlanningGoalContext(
        goalId: goal.ontologyGoalId,
        goalLabel: goal.label,
      ),
      capabilityEvidence: _evidenceFromProfile(profile),
      knowledgeOntologyVersion: knowledgeOntologyVersion,
      asOf: asOf ?? DateTime.now().toUtc(),
      equipmentContext: PlanningEquipmentContext(
        availableEquipmentIds: profile.availableEquipment,
      ),
      environmentContext: PlanningEnvironmentContext(
        environmentId: profile.environmentId,
      ),
      availableTimeMinutes: duration,
      injuryFlags: profile.injuries,
      athletePreferences: PlanningAthletePreferences(tags: preferences),
      // Do not set progressionPathId to planId — engine validates ontology paths only.
      // Plan identity travels via preference tags (plan_id: / plan_assignment:).
    );
  }

  /// Plan-canonical input for programmed session resolve.
  ///
  /// Ignores athlete-specific capability history, injuries, and equipment so
  /// two athletes on the same Plan version + week + day share structure.
  PlanningInput buildPlanCanonical({
    required PlanDefinition plan,
    required PlanAssignment assignment,
    required String knowledgeOntologyVersion,
  }) {
    final days = plan.recommendedDaysPerWeek;
    final duration = plan.typicalSessionDurationMinutes;
    final goal = plan.primaryGoal;
    final presetId = plan.equipmentPresetIds.isNotEmpty
        ? plan.equipmentPresetIds.first
        : 'minimal';
    final preset = AthleteEquipmentCatalog.byId(presetId);
    final preferences = <String>[
      '$planIdTagPrefix${plan.planId}',
      '$progressionModelTagPrefix${plan.progressionModel}',
      '$coachingFocusTagPrefix${plan.coachingFocus}',
      for (final cap in plan.capabilityPriorities) 'priority_$cap',
      if (goal.preferenceTag != null) goal.preferenceTag!,
      'days_$days',
      'duration_$duration',
      'experience_${plan.experienceLevel.name}',
      'week_${assignment.currentWeek}',
      'day_${assignment.currentDay}',
      'programmed_canonical',
    ];

    // Deterministic asOf from plan cursor — not wall clock.
    final asOf = DateTime.utc(
      2026,
      1,
      1,
    ).add(Duration(days: assignment.currentWeek * 7 + assignment.currentDay));

    return PlanningInput(
      athleteId: 'programmed.${plan.planId}.${plan.version}',
      goalContext: PlanningGoalContext(
        goalId: goal.ontologyGoalId,
        goalLabel: goal.label,
      ),
      capabilityEvidence: _canonicalEvidence(plan),
      knowledgeOntologyVersion: knowledgeOntologyVersion,
      asOf: asOf,
      equipmentContext: PlanningEquipmentContext(
        availableEquipmentIds: preset.equipmentIds,
      ),
      environmentContext: PlanningEnvironmentContext(
        environmentId: preset.environmentId,
      ),
      availableTimeMinutes: duration,
      injuryFlags: const [],
      athletePreferences: PlanningAthletePreferences(tags: preferences),
    );
  }

  AthleteCapabilityEvidenceProfile _canonicalEvidence(PlanDefinition plan) {
    final confidenceBase = switch (plan.experienceLevel) {
      AthleteExperienceLevel.beginner => 0.45,
      AthleteExperienceLevel.intermediate => 0.65,
      AthleteExperienceLevel.advanced => 0.8,
    };
    final items = <CapabilityEvidenceItem>[
      for (final capabilityId in _seedCapabilityIds)
        CapabilityEvidenceItem(
          capabilityId: capabilityId,
          state: CapabilityEvidenceState.estimated,
          confidence: confidenceBase * 0.7,
          source: 'plan_canonical',
        ),
    ];
    return AthleteCapabilityEvidenceProfile.fromItems(items);
  }

  AthleteCapabilityEvidenceProfile _evidenceFromProfile(AthleteProfile profile) {
    final byId = {
      for (final c in profile.baselineCapabilities) c.capabilityId: c,
    };

    final confidenceBase = switch (profile.experienceLevel) {
      AthleteExperienceLevel.beginner => 0.45,
      AthleteExperienceLevel.intermediate => 0.65,
      AthleteExperienceLevel.advanced => 0.8,
    };

    final items = <CapabilityEvidenceItem>[];
    for (final capabilityId in _seedCapabilityIds) {
      final baseline = byId[capabilityId];
      final relative = baseline?.relativeLevel;
      final confidence = relative == null
          ? confidenceBase * 0.7
          : (0.4 + relative * 0.5).clamp(0.35, 0.9);

      items.add(
        CapabilityEvidenceItem(
          capabilityId: capabilityId,
          state: CapabilityEvidenceState.estimated,
          confidence: confidence,
          source: 'athlete_onboarding_self_report',
          notes: profile.currentActivity,
          recordedAt: profile.updatedAt,
        ),
      );
    }

    if (profile.planningGoalId == 'cohort.goal.hyrox_sub_60') {
      for (final id in const [
        'cohort.capability.threshold',
        'cohort.capability.running_economy',
        'cohort.capability.pacing',
        'cohort.capability.burpee_efficiency',
      ]) {
        if (items.any((e) => e.capabilityId == id)) continue;
        items.add(
          CapabilityEvidenceItem(
            capabilityId: id,
            state: CapabilityEvidenceState.unknown,
            confidence: 0.3,
            source: 'athlete_onboarding_pending_assessment',
          ),
        );
      }
    }

    if (profile.planningGoalId == 'cohort.goal.military_selection') {
      for (final id in const [
        'cohort.capability.loaded_carry_capacity',
        'cohort.capability.resilience',
      ]) {
        if (items.any((e) => e.capabilityId == id)) continue;
        items.add(
          CapabilityEvidenceItem(
            capabilityId: id,
            state: CapabilityEvidenceState.unknown,
            confidence: 0.3,
            source: 'athlete_onboarding_pending_assessment',
          ),
        );
      }
    }

    return AthleteCapabilityEvidenceProfile.fromItems(items);
  }
}
