import '../contracts/block_adaptation_policy.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_confidence.dart';
import '../vocabulary/adaptation_fidelity.dart';
import '../vocabulary/block_priority.dart';
import '../vocabulary/impact_level.dart';
import '../vocabulary/movement_pattern.dart';
import '../vocabulary/session_intent.dart';

/// Stable read-only evaluation outcomes (Task 2 may consume these).
enum AdaptationEvaluationOutcome {
  noAdaptationRequired,
  adaptable,
  adaptableWithReducedFidelity,
  insufficientInformation,
  notAdaptable,
}

/// Machine-readable finding codes for explainability and UI mapping.
enum AdaptationEvaluationFindingCode {
  insufficientDuration,
  missingMinimumViableDuration,
  essentialBlockAtRisk,
  equipmentMismatch,
  equipmentCompatible,
  equipmentMetadataMissing,
  environmentMismatch,
  environmentCompatible,
  environmentMetadataMissing,
  movementRestrictionConflict,
  movementMetadataMissing,
  impactConflict,
  impactMetadataMissing,
  missingSessionIntent,
  adaptationPolicyPreventsRemoval,
  noConstraintConflict,
  timeFeasibleWithoutShortening,
  derivedPolicyInUse,
  explicitPolicyInUse,
}

/// Structured signals explaining [AdaptationConfidence] assignment.
enum AdaptationConfidenceFindingCode {
  primarySessionIntentPresent,
  primarySessionIntentMissing,
  minimumViableDurationPresentForTimeDecision,
  minimumViableDurationMissingForTimeDecision,
  plannedDurationMissingForTimeDecision,
  activeConstraintMetadataComplete,
  activeConstraintMetadataIncomplete,
  derivedBlockAdaptationDefaultsInUse,
  explicitBlockAdaptationMetadataInUse,
  sessionImpactInferredFromPhysiologicalDemandLabel,
  environmentCompatibilityUsesLabelHeuristic,
  evaluationConclusionsFullySupported,
  multipleMaterialUnknowns,
}

enum AdaptationPolicySource {
  explicit,
  derived,
}

/// Smallest likely adaptation scope required to satisfy constraints.
enum AdaptationMinimumScope {
  none,
  prescriptionAdjustment,
  blockReduction,
  blockRemoval,
  sessionReplacement,
}

enum AdaptationFindingConfidence {
  confirmedIncompatible,
  confirmedCompatible,
  unknown,
}

class AdaptationEvaluationFinding {
  const AdaptationEvaluationFinding({
    required this.code,
    required this.confidence,
    this.message,
    this.blockLocalId,
    this.exerciseId,
  });

  final AdaptationEvaluationFindingCode code;
  final AdaptationFindingConfidence confidence;
  final String? message;
  final String? blockLocalId;
  final String? exerciseId;
}

class BlockAdaptationEvaluation {
  const BlockAdaptationEvaluation({
    required this.blockLocalId,
    required this.effectivePriority,
    required this.effectivePolicy,
    required this.policySource,
    this.explicitPriority,
    this.explicitPolicy,
    this.removalPermittedByPolicy = false,
    this.removalBlockedByEssentialPriority = false,
    this.findings = const [],
  });

  final String blockLocalId;
  final BlockPriority effectivePriority;
  final BlockPriority? explicitPriority;
  final BlockAdaptationPolicy effectivePolicy;
  final BlockAdaptationPolicy? explicitPolicy;
  final AdaptationPolicySource policySource;
  final bool removalPermittedByPolicy;
  final bool removalBlockedByEssentialPriority;
  final List<AdaptationEvaluationFinding> findings;
}

class SessionAdaptationEvaluationResult {
  const SessionAdaptationEvaluationResult({
    required this.outcome,
    required this.primaryIntentKnown,
    required this.primaryIntentPreservable,
    required this.minimumScope,
    required this.expectedFidelity,
    required this.adaptationConfidence,
    required this.permittedAdaptationActions,
    required this.blockedAdaptationActions,
    required this.findings,
    required this.missingMetadata,
    required this.confidenceFindings,
    required this.blockResults,
  });

  final AdaptationEvaluationOutcome outcome;
  final bool primaryIntentKnown;
  final bool primaryIntentPreservable;
  final AdaptationMinimumScope minimumScope;
  final AdaptationFidelity expectedFidelity;
  final AdaptationConfidence adaptationConfidence;
  final List<AdaptationActionType> permittedAdaptationActions;
  final List<AdaptationActionType> blockedAdaptationActions;
  final List<AdaptationEvaluationFinding> findings;
  final List<AdaptationEvaluationFindingCode> missingMetadata;
  final List<AdaptationConfidenceFindingCode> confidenceFindings;
  final List<BlockAdaptationEvaluation> blockResults;
}

/// Normalized planned session snapshot for evaluation (no mutation).
class PlannedSessionAdaptationInput {
  const PlannedSessionAdaptationInput({
    required this.protocolId,
    required this.blocks,
    this.primarySessionIntent,
    this.secondarySessionIntents = const [],
    this.plannedDurationMin,
    this.minimumViableDurationMin,
    this.requiredEquipmentTokens = const {},
    this.sessionEnvironmentLabel,
    this.hotelFriendly,
    this.indoorFriendly,
    this.physiologicalDemandLabel,
    this.sessionImpact,
    this.exerciseMetadataById = const {},
  });

  final String protocolId;
  final SessionIntent? primarySessionIntent;
  final List<SessionIntent> secondarySessionIntents;
  final int? plannedDurationMin;
  final int? minimumViableDurationMin;
  final Set<String> requiredEquipmentTokens;
  final String? sessionEnvironmentLabel;
  final bool? hotelFriendly;
  final bool? indoorFriendly;
  final String? physiologicalDemandLabel;
  final ImpactLevel? sessionImpact;
  final List<PlannedBlockAdaptationInput> blocks;
  final Map<String, ExerciseAdaptationMetadataForEvaluation>
      exerciseMetadataById;
}

class PlannedBlockAdaptationInput {
  const PlannedBlockAdaptationInput({
    required this.localId,
    required this.blockTypeDbValue,
    required this.position,
    this.explicitPriority,
    this.explicitPolicy,
    this.linkedExerciseIds = const [],
  });

  final String localId;
  final String blockTypeDbValue;
  final int position;
  final BlockPriority? explicitPriority;
  final BlockAdaptationPolicy? explicitPolicy;
  final List<String> linkedExerciseIds;
}

/// Minimal exercise metadata used by the read-only evaluator.
class ExerciseAdaptationMetadataForEvaluation {
  const ExerciseAdaptationMetadataForEvaluation({
    required this.exerciseId,
    this.movementPatterns = const [],
    this.bodyRegion,
    this.impact,
    this.equipment = const {},
  });

  final String exerciseId;
  final List<MovementPattern> movementPatterns;
  final String? bodyRegion;
  final ImpactLevel? impact;
  final Set<String> equipment;
}