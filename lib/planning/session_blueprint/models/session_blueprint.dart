import '../../models/planning_input.dart';
import 'session_blueprint_semantics.dart';

export 'session_blueprint_semantics.dart';

enum SessionBlueprintStatus {
  /// Required semantic fields and structural components resolved.
  complete,

  /// Valid blueprint; supporting intents or optional components omitted.
  partial,

  /// Cannot represent recommendation safely under hard constraints.
  infeasible,

  /// Source recommendation or ontology reference invalid.
  invalidRecommendation,
}

enum SessionBlueprintExplainabilityLayer {
  planningRecommendation,
  sessionObjective,
  desiredAdaptation,
  archetype,
  intensity,
  volume,
  density,
  structure,
  constraintPolicy,
  substitutionPolicy,
}

enum SessionBlueprintFactorSeverity { info, notice, warning, critical }

class SessionBlueprintExplainabilityFactor {
  const SessionBlueprintExplainabilityFactor({
    required this.layer,
    required this.code,
    required this.summary,
    required this.rationale,
    this.sourceEntityIds = const [],
    this.confidence,
    this.severity = SessionBlueprintFactorSeverity.info,
  });

  final SessionBlueprintExplainabilityLayer layer;
  final String code;
  final String summary;
  final String rationale;
  final List<String> sourceEntityIds;
  final double? confidence;
  final SessionBlueprintFactorSeverity severity;
}

class SessionBlueprintExplainability {
  const SessionBlueprintExplainability({
    required this.factors,
    required this.narrativeSummary,
  });

  final List<SessionBlueprintExplainabilityFactor> factors;
  final String narrativeSummary;
}

class SessionBlueprintWarning {
  const SessionBlueprintWarning({required this.code, required this.message});

  final String code;
  final String message;
}

class SessionBlueprintSourceReference {
  const SessionBlueprintSourceReference({
    required this.athleteId,
    required this.goalId,
    required this.recommendationGeneratedAt,
    required this.ontologyVersion,
  });

  final String athleteId;
  final String goalId;
  final DateTime recommendationGeneratedAt;
  final String ontologyVersion;

  @override
  bool operator ==(Object other) {
    return other is SessionBlueprintSourceReference &&
        other.athleteId == athleteId &&
        other.goalId == goalId &&
        other.recommendationGeneratedAt == recommendationGeneratedAt &&
        other.ontologyVersion == ontologyVersion;
  }

  @override
  int get hashCode => Object.hash(
    athleteId,
    goalId,
    recommendationGeneratedAt,
    ontologyVersion,
  );
}

class SessionArchetypeReference {
  const SessionArchetypeReference({
    required this.archetypeId,
    required this.label,
    required this.primaryTrainingIntentId,
  });

  final String archetypeId;
  final String label;
  final String primaryTrainingIntentId;
}

class SessionObjective {
  const SessionObjective({
    required this.summary,
    this.focusCapabilityId,
    this.focusIntentId,
  });

  final String summary;
  final String? focusCapabilityId;
  final String? focusIntentId;
}

enum DesiredAdaptationRole { primary, secondary, supporting }

class DesiredAdaptation {
  const DesiredAdaptation({
    required this.capabilityId,
    required this.capabilityLabel,
    required this.role,
    required this.sourceTrainingIntentIds,
    required this.importance,
    required this.confidence,
    required this.rationale,
  });

  final String capabilityId;
  final String capabilityLabel;
  final DesiredAdaptationRole role;
  final List<String> sourceTrainingIntentIds;
  final double importance;
  final double confidence;
  final String rationale;
}

class SessionCapabilityRequirement {
  const SessionCapabilityRequirement({
    required this.capabilityId,
    required this.capabilityLabel,
    required this.requirementKind,
  });

  final String capabilityId;
  final String capabilityLabel;
  final String requirementKind;
}

enum SessionStructuralComponentType {
  preparation,
  movementPreparation,
  skillOrTechnique,
  primaryDevelopment,
  secondaryDevelopment,
  supportingCapacity,
  trunkOrStability,
  recoveryOrCooldown,
  assessment,
  transitionPractice,
}

enum SessionComponentEmphasis { minimal, low, moderate, high, primary }

enum SessionComponentOptionality { required, recommended, optional }

enum SessionFatigueContribution { none, low, moderate, high }

class SessionStructuralComponent {
  const SessionStructuralComponent({
    required this.sequence,
    required this.componentType,
    required this.purpose,
    this.targetedCapabilityIds = const [],
    this.associatedIntentIds = const [],
    required this.relativeEmphasis,
    required this.optionality,
    required this.fatigueContribution,
    this.orderingConstraint,
    this.rationale,
  });

  final int sequence;
  final SessionStructuralComponentType componentType;
  final String purpose;
  final List<String> targetedCapabilityIds;
  final List<String> associatedIntentIds;
  final SessionComponentEmphasis relativeEmphasis;
  final SessionComponentOptionality optionality;
  final SessionFatigueContribution fatigueContribution;
  final String? orderingConstraint;
  final String? rationale;
}

enum SessionConstraintKind {
  recovery,
  injury,
  time,
  environment,
  equipment,
  travel,
  assessment,
  prerequisite,
  fatigueReduction,
  policy,
}

class SessionConstraint {
  const SessionConstraint({
    required this.kind,
    required this.code,
    required this.description,
    this.semanticConsequence,
  });

  final SessionConstraintKind kind;
  final String code;
  final String description;
  final String? semanticConsequence;
}

enum SessionSubstitutionPolicyTag {
  preservePrimaryIntent,
  preserveMovementPattern,
  preserveEnergySystem,
  preserveCapabilityTarget,
  lowImpactRequired,
  noOverheadLoading,
  limitedEquipment,
  travelCompatible,
  fatigueReduced,
  techniquePriority,
  assessmentIntegrityRequired,
}

enum SessionProgressionEmphasis {
  accumulation,
  intensification,
  realisation,
  assessment,
  recovery,
  deload,
  general,
}

enum SemanticFatiguePosture { restorative, low, moderate, elevated, high }

class SessionProgressionContext {
  const SessionProgressionContext({
    this.programmePhaseId,
    this.programmePhaseLabel,
    this.trainingBlockId,
    this.trainingBlockLabel,
    this.weekTypeId,
    this.weekTypeLabel,
    required this.progressionEmphasis,
    required this.adaptationEmphasis,
    required this.expectedFatiguePosture,
  });

  final String? programmePhaseId;
  final String? programmePhaseLabel;
  final String? trainingBlockId;
  final String? trainingBlockLabel;
  final String? weekTypeId;
  final String? weekTypeLabel;
  final SessionProgressionEmphasis progressionEmphasis;
  final String adaptationEmphasis;
  final SemanticFatiguePosture expectedFatiguePosture;
}

/// Semantic session description (ADR-027). No exercises or prescriptions.
class SessionBlueprint {
  const SessionBlueprint({
    required this.blueprintId,
    required this.athleteId,
    required this.sourceRecommendation,
    required this.ontologyVersion,
    required this.generatedAt,
    required this.status,
    required this.objective,
    required this.desiredAdaptations,
    required this.sessionArchetype,
    required this.primaryTrainingIntentId,
    required this.primaryTrainingIntentLabel,
    this.supportingTrainingIntentIds = const [],
    this.supportingTrainingIntentLabels = const [],
    required this.requiredCapabilities,
    required this.semanticIntensity,
    required this.semanticVolume,
    required this.semanticDensity,
    required this.structuralComponents,
    this.constraints = const [],
    this.substitutionPolicyTags = const [],
    required this.progressionContext,
    required this.confidence,
    required this.explainability,
    this.warnings = const [],
  });

  final String blueprintId;
  final String athleteId;
  final SessionBlueprintSourceReference sourceRecommendation;
  final String ontologyVersion;
  final DateTime generatedAt;
  final SessionBlueprintStatus status;
  final SessionObjective objective;
  final List<DesiredAdaptation> desiredAdaptations;
  final SessionArchetypeReference sessionArchetype;
  final String primaryTrainingIntentId;
  final String primaryTrainingIntentLabel;
  final List<String> supportingTrainingIntentIds;
  final List<String> supportingTrainingIntentLabels;
  final List<SessionCapabilityRequirement> requiredCapabilities;
  final SemanticIntensityTarget semanticIntensity;
  final SemanticVolumeTarget semanticVolume;
  final SemanticDensityTarget semanticDensity;
  final List<SessionStructuralComponent> structuralComponents;
  final List<SessionConstraint> constraints;
  final List<SessionSubstitutionPolicyTag> substitutionPolicyTags;
  final SessionProgressionContext progressionContext;
  final double confidence;
  final SessionBlueprintExplainability explainability;
  final List<SessionBlueprintWarning> warnings;
}

/// Optional context not carried on [PlanningRecommendation].
class SessionBlueprintGenerationContext {
  const SessionBlueprintGenerationContext({
    this.recoverySummary,
    this.equipmentContext,
    this.environmentContext,
  });

  final PlanningRecoverySummary? recoverySummary;
  final PlanningEquipmentContext? equipmentContext;
  final PlanningEnvironmentContext? environmentContext;
}

String computeSessionBlueprintId(SessionBlueprintSourceReference source) {
  final stamp = source.recommendationGeneratedAt.toUtc().millisecondsSinceEpoch;
  return 'cohort.session_blueprint.${source.athleteId}.${source.goalId}.$stamp';
}
