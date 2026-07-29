import '../../session_blueprint/models/session_blueprint.dart';

/// Policy-layer input: blueprint plus execution context (equipment, environment).
class ExercisePolicyRequest {
  const ExercisePolicyRequest({
    required this.blueprint,
    this.availableEquipmentIds = const [],
    this.environmentId,
    this.injuryFlags = const [],
    this.isTraveling = false,
    this.maxSelectionsPerComponent = 1,
    this.maxTotalSelections = 8,
  });

  final SessionBlueprint blueprint;
  final List<String> availableEquipmentIds;
  final String? environmentId;
  final List<String> injuryFlags;
  final bool isTraveling;
  final int maxSelectionsPerComponent;
  final int maxTotalSelections;
}

enum MovementSelectionStatus {
  /// All required components have viable selections; primary intent preserved.
  complete,

  /// Some selections made; gaps or optional components unfilled.
  partial,

  /// Hard constraints prevent intent-preserving selection.
  infeasible,

  /// Blueprint not eligible for policy (invalid/infeasible blueprint).
  invalidBlueprint,
}

enum ExerciseSelectionReasonCode {
  capabilityPrimaryMatch,
  capabilitySecondaryMatch,
  intentPrimaryMatch,
  intentSupportingMatch,
  movementPatternDiversity,
  substitutionRule,
  environmentMatch,
  equipmentDirect,
  fatigueCompatible,
  injuryCompatible,
  assessmentIntegrity,
  techniquePriority,
  fallbackCoverage,
}

class ExerciseSelectionReason {
  const ExerciseSelectionReason({
    required this.code,
    required this.summary,
    this.capabilityId,
    this.trainingIntentId,
    this.policyCode,
    this.constraintCode,
    this.substitutionRuleId,
    this.confidence,
  });

  final ExerciseSelectionReasonCode code;
  final String summary;
  final String? capabilityId;
  final String? trainingIntentId;
  final String? policyCode;
  final String? constraintCode;
  final String? substitutionRuleId;
  final double? confidence;
}

enum MovementConstraintKind {
  equipment,
  environment,
  injury,
  fatigue,
  travel,
  technique,
  assessment,
  diversity,
  policyTag,
}

class MovementConstraint {
  const MovementConstraint({
    required this.kind,
    required this.code,
    required this.description,
    this.applied = true,
  });

  final MovementConstraintKind kind;
  final String code;
  final String description;
  final bool applied;
}

enum ExerciseMovementRole {
  preparation,
  primary,
  secondary,
  accessory,
  assessment,
  recovery,
  transition,
}

class ExerciseSelection {
  const ExerciseSelection({
    required this.sequence,
    required this.exerciseId,
    required this.exerciseLabel,
    required this.movementRole,
    required this.structuralComponentSequence,
    required this.structuralComponentType,
    required this.reasons,
    this.movementPatternIds = const [],
    this.matchedCapabilityIds = const [],
    this.matchedTrainingIntentIds = const [],
    this.substitutedFromExerciseId,
  });

  final int sequence;
  final String exerciseId;
  final String exerciseLabel;
  final ExerciseMovementRole movementRole;
  final int structuralComponentSequence;
  final SessionStructuralComponentType structuralComponentType;
  final List<ExerciseSelectionReason> reasons;
  final List<String> movementPatternIds;
  final List<String> matchedCapabilityIds;
  final List<String> matchedTrainingIntentIds;
  final String? substitutedFromExerciseId;
}

enum PolicyExplainabilityLayer {
  blueprint,
  constraint,
  candidatePool,
  scoring,
  substitution,
  diversity,
  outcome,
}

class PolicyExplainabilityFactor {
  const PolicyExplainabilityFactor({
    required this.layer,
    required this.code,
    required this.summary,
    required this.rationale,
    this.sourceEntityIds = const [],
    this.confidence,
  });

  final PolicyExplainabilityLayer layer;
  final String code;
  final String summary;
  final String rationale;
  final List<String> sourceEntityIds;
  final double? confidence;
}

class PolicyExplainability {
  const PolicyExplainability({
    required this.factors,
    required this.narrativeSummary,
  });

  final List<PolicyExplainabilityFactor> factors;
  final String narrativeSummary;
}

class ExercisePolicyResult {
  const ExercisePolicyResult({
    required this.status,
    required this.blueprintId,
    required this.ontologyVersion,
    required this.selections,
    required this.executionPlan,
    required this.activeConstraints,
    required this.explainability,
    this.warnings = const [],
    required this.primaryTrainingIntentId,
    required this.sessionArchetypeId,
  });

  final MovementSelectionStatus status;
  final String blueprintId;
  final String ontologyVersion;
  final List<ExerciseSelection> selections;
  final SemanticSessionExecutionPlan executionPlan;
  final List<MovementConstraint> activeConstraints;
  final PolicyExplainability explainability;
  final List<String> warnings;
  final String primaryTrainingIntentId;
  final String sessionArchetypeId;
}

/// Ordered semantic movement plan — policy output (no prescriptions).
///
/// Distinct from [SessionExecutionPlan] in `features/session` (Workout Player).
class SemanticSessionExecutionPlan {
  const SemanticSessionExecutionPlan({
    required this.planId,
    required this.blueprintId,
    required this.athleteId,
    required this.sessionArchetypeId,
    required this.primaryTrainingIntentId,
    required this.orderedSelections,
    required this.componentMappings,
    this.activeConstraints = const [],
    this.sessionObjectiveSummary,
  });

  final String planId;
  final String blueprintId;
  final String athleteId;
  final String sessionArchetypeId;
  final String primaryTrainingIntentId;
  final List<ExerciseSelection> orderedSelections;
  final List<SemanticComponentExerciseMapping> componentMappings;
  final List<MovementConstraint> activeConstraints;
  final String? sessionObjectiveSummary;
}

class SemanticComponentExerciseMapping {
  const SemanticComponentExerciseMapping({
    required this.componentSequence,
    required this.componentType,
    required this.exerciseIds,
    required this.purpose,
  });

  final int componentSequence;
  final SessionStructuralComponentType componentType;
  final List<String> exerciseIds;
  final String purpose;
}

String computePolicyPlanId(String blueprintId) => '$blueprintId.policy_plan';

/// Prescription-free invariant check for policy outputs.
class ExercisePolicyContract {
  const ExercisePolicyContract._();

  static void assertSemanticPlanOnly(SemanticSessionExecutionPlan plan) {
    for (final s in plan.orderedSelections) {
      if (!s.exerciseId.startsWith('cohort.exercise.')) {
        throw StateError('Unexpected exercise id shape: ${s.exerciseId}');
      }
    }
  }
}
