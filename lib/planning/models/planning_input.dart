import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_recommendation_models.dart';

import 'planning_goal_context.dart';

/// Ephemeral equipment availability (no exercise ids).
class PlanningEquipmentContext {
  const PlanningEquipmentContext({this.availableEquipmentIds = const []});

  final List<String> availableEquipmentIds;

  @override
  bool operator ==(Object other) {
    return other is PlanningEquipmentContext &&
        _listEquals(other.availableEquipmentIds, availableEquipmentIds);
  }

  @override
  int get hashCode => Object.hashAll(availableEquipmentIds);
}

class PlanningEnvironmentContext {
  const PlanningEnvironmentContext({this.environmentId});

  final String? environmentId;

  @override
  bool operator ==(Object other) {
    return other is PlanningEnvironmentContext &&
        other.environmentId == environmentId;
  }

  @override
  int get hashCode => environmentId.hashCode;
}

enum PlanningRecoveryLevel { poor, moderate, good, unknown }

class PlanningRecoverySummary {
  const PlanningRecoverySummary({
    this.level = PlanningRecoveryLevel.unknown,
    this.notes,
  });

  final PlanningRecoveryLevel level;
  final String? notes;

  @override
  bool operator ==(Object other) {
    return other is PlanningRecoverySummary &&
        other.level == level &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(level, notes);
}

/// Athlete preference tags for downstream policy (planning records only).
class PlanningAthletePreferences {
  const PlanningAthletePreferences({this.tags = const []});

  final List<String> tags;

  @override
  bool operator ==(Object other) {
    return other is PlanningAthletePreferences && _listEquals(other.tags, tags);
  }

  @override
  int get hashCode => Object.hashAll(tags);
}

class PlanningPolicyOverrides {
  const PlanningPolicyOverrides({
    this.forceProgrammePhaseId,
    this.forceTrainingBlockId,
    this.forceWeekTypeId,
  });

  final String? forceProgrammePhaseId;
  final String? forceTrainingBlockId;
  final String? forceWeekTypeId;

  @override
  bool operator ==(Object other) {
    return other is PlanningPolicyOverrides &&
        other.forceProgrammePhaseId == forceProgrammePhaseId &&
        other.forceTrainingBlockId == forceTrainingBlockId &&
        other.forceWeekTypeId == forceWeekTypeId;
  }

  @override
  int get hashCode =>
      Object.hash(forceProgrammePhaseId, forceTrainingBlockId, forceWeekTypeId);
}

class PlanningTravelContext {
  const PlanningTravelContext({this.isTraveling = false, this.notes});

  final bool isTraveling;
  final String? notes;

  @override
  bool operator ==(Object other) {
    return other is PlanningTravelContext &&
        other.isTraveling == isTraveling &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(isTraveling, notes);
}

/// Reusable ranked gaps when goal and ontology version match [PlanningInput].
class PrecomputedCapabilityGaps {
  const PrecomputedCapabilityGaps({
    required this.goalId,
    required this.ontologyVersion,
    required this.rankedGaps,
  });

  final String goalId;
  final String ontologyVersion;
  final List<CapabilityGap> rankedGaps;

  @override
  bool operator ==(Object other) {
    return other is PrecomputedCapabilityGaps &&
        other.goalId == goalId &&
        other.ontologyVersion == ontologyVersion &&
        _listEquals(other.rankedGaps, rankedGaps);
  }

  @override
  int get hashCode =>
      Object.hash(goalId, ontologyVersion, Object.hashAll(rankedGaps));
}

class PrecomputedTrainingIntents {
  const PrecomputedTrainingIntents({
    required this.goalId,
    required this.ontologyVersion,
    required this.recommendations,
  });

  final String goalId;
  final String ontologyVersion;
  final List<TrainingIntentRecommendation> recommendations;

  @override
  bool operator ==(Object other) {
    return other is PrecomputedTrainingIntents &&
        other.goalId == goalId &&
        other.ontologyVersion == ontologyVersion &&
        _listEquals(other.recommendations, recommendations);
  }

  @override
  int get hashCode =>
      Object.hash(goalId, ontologyVersion, Object.hashAll(recommendations));
}

/// Canonical planning input (ADR-026); no exercises or calendar dates.
class PlanningInput {
  const PlanningInput({
    required this.athleteId,
    required this.goalContext,
    required this.capabilityEvidence,
    required this.knowledgeOntologyVersion,
    required this.asOf,
    this.activeProgrammePhaseId,
    this.activeTrainingBlockId,
    this.activeWeekTypeId,
    this.progressionPathId,
    this.precomputedCapabilityGaps,
    this.precomputedTrainingIntents,
    this.equipmentContext,
    this.environmentContext,
    this.availableTimeMinutes,
    this.recoverySummary,
    this.injuryFlags = const [],
    this.travelContext,
    this.athletePreferences,
    this.policyOverrides,
  });

  final String athleteId;
  final PlanningGoalContext goalContext;
  final AthleteCapabilityEvidenceProfile capabilityEvidence;
  final String knowledgeOntologyVersion;
  final DateTime asOf;
  final String? activeProgrammePhaseId;
  final String? activeTrainingBlockId;
  final String? activeWeekTypeId;
  final String? progressionPathId;
  final PrecomputedCapabilityGaps? precomputedCapabilityGaps;
  final PrecomputedTrainingIntents? precomputedTrainingIntents;
  final PlanningEquipmentContext? equipmentContext;
  final PlanningEnvironmentContext? environmentContext;
  final int? availableTimeMinutes;
  final PlanningRecoverySummary? recoverySummary;
  final List<String> injuryFlags;
  final PlanningTravelContext? travelContext;
  final PlanningAthletePreferences? athletePreferences;
  final PlanningPolicyOverrides? policyOverrides;

  @override
  bool operator ==(Object other) {
    return other is PlanningInput &&
        other.athleteId == athleteId &&
        other.goalContext == goalContext &&
        other.capabilityEvidence == capabilityEvidence &&
        other.knowledgeOntologyVersion == knowledgeOntologyVersion &&
        other.asOf == asOf &&
        other.activeProgrammePhaseId == activeProgrammePhaseId &&
        other.activeTrainingBlockId == activeTrainingBlockId &&
        other.activeWeekTypeId == activeWeekTypeId &&
        other.progressionPathId == progressionPathId &&
        other.precomputedCapabilityGaps == precomputedCapabilityGaps &&
        other.precomputedTrainingIntents == precomputedTrainingIntents &&
        other.equipmentContext == equipmentContext &&
        other.environmentContext == environmentContext &&
        other.availableTimeMinutes == availableTimeMinutes &&
        other.recoverySummary == recoverySummary &&
        _listEquals(other.injuryFlags, injuryFlags) &&
        other.travelContext == travelContext &&
        other.athletePreferences == athletePreferences &&
        other.policyOverrides == policyOverrides;
  }

  @override
  int get hashCode => Object.hash(
    athleteId,
    goalContext,
    capabilityEvidence,
    knowledgeOntologyVersion,
    asOf,
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
