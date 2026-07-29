/// Parsed knowledge ontology bundle (persistence-independent).
class KnowledgeOntologyBundle {
  const KnowledgeOntologyBundle({
    required this.ontologyVersion,
    required this.entityIds,
    required this.capabilities,
    required this.goals,
    required this.exercises,
    required this.substitutions,
    required this.trainingIntents,
    required this.sessionArchetypes,
    required this.capabilityIntentMappings,
    required this.programmePhases,
    required this.trainingBlocks,
    required this.weekTypes,
    required this.programmeProgressionPaths,
    required this.defaultProgressionPathId,
    required this.aliasIndex,
  });

  final String ontologyVersion;
  final Set<String> entityIds;
  final List<CapabilityKnowledge> capabilities;
  final List<GoalRequirementKnowledge> goals;
  final List<ExerciseKnowledge> exercises;
  final List<SubstitutionRuleKnowledge> substitutions;
  final List<TrainingIntentKnowledge> trainingIntents;
  final List<SessionArchetypeKnowledge> sessionArchetypes;
  final List<CapabilityIntentMappingKnowledge> capabilityIntentMappings;
  final List<ProgrammePhaseKnowledge> programmePhases;
  final List<TrainingBlockKnowledge> trainingBlocks;
  final List<WeekTypeKnowledge> weekTypes;
  final List<ProgrammeProgressionPathKnowledge> programmeProgressionPaths;
  final String? defaultProgressionPathId;

  /// Lowercase alias → canonical entity id (namespace-scoped keys).
  final Map<String, String> aliasIndex;

  Set<String> get activeCapabilityIds => capabilities
      .where((c) => c.meta.status == 'active')
      .map((c) => c.id)
      .toSet();
}

class KnowledgeEntityMeta {
  const KnowledgeEntityMeta({
    required this.id,
    required this.canonicalName,
    required this.label,
    required this.ontologyVersion,
    required this.status,
    this.description,
    this.aliases = const [],
    this.namespace = 'core',
    this.replacesId,
    this.provenance,
    this.confidence,
  });

  final String id;
  final String canonicalName;
  final String label;
  final String ontologyVersion;
  final String status;
  final String? description;
  final List<String> aliases;
  final String namespace;
  final String? replacesId;
  final String? provenance;
  final String? confidence;
}

class CapabilityKnowledge {
  const CapabilityKnowledge({
    required this.meta,
    this.parentIds = const [],
    this.prerequisiteIds = const [],
    this.supportingCapabilityIds = const [],
    this.conflictingCapabilityIds = const [],
    this.relatedMovementPatternIds = const [],
    this.relatedEnergySystemIds = const [],
    this.relatedTrainingIntentIds = const [],
    this.typicalAssessmentMethods = const [],
  });

  final KnowledgeEntityMeta meta;
  final List<String> parentIds;
  final List<String> prerequisiteIds;
  final List<String> supportingCapabilityIds;
  final List<String> conflictingCapabilityIds;
  final List<String> relatedMovementPatternIds;
  final List<String> relatedEnergySystemIds;
  final List<String> relatedTrainingIntentIds;
  final List<String> typicalAssessmentMethods;

  String get id => meta.id;
}

class GoalRequirementKnowledge {
  const GoalRequirementKnowledge({
    required this.meta,
    required this.requiredCapabilityIds,
    this.optionalCapabilityIds = const [],
  });

  final KnowledgeEntityMeta meta;
  final List<String> requiredCapabilityIds;
  final List<String> optionalCapabilityIds;

  String get id => meta.id;
}

class ExerciseCapabilityMapping {
  const ExerciseCapabilityMapping({
    required this.exerciseId,
    required this.primaryCapabilityIds,
    required this.secondaryCapabilityIds,
    required this.supportingCapabilityIds,
  });

  final String exerciseId;
  final List<String> primaryCapabilityIds;
  final List<String> secondaryCapabilityIds;
  final List<String> supportingCapabilityIds;

  List<String> get allCapabilityIds => [
    ...primaryCapabilityIds,
    ...secondaryCapabilityIds,
    ...supportingCapabilityIds,
  ];
}

class ExerciseKnowledge {
  const ExerciseKnowledge({
    required this.meta,
    required this.curationStatus,
    this.movementPatternIds = const [],
    this.jointActionIds = const [],
    this.primaryMuscleIds = const [],
    this.secondaryMuscleIds = const [],
    this.requiredEquipmentIds = const [],
    this.optionalEquipmentIds = const [],
    this.suitableEnvironmentIds = const [],
    this.primaryCapabilityIds = const [],
    this.secondaryCapabilityIds = const [],
    this.supportingCapabilityIds = const [],
    this.supportsTrainingIntentIds = const [],
    this.energySystemPrimaryId,
    this.energySystemSecondaryId,
    this.technicalDemand,
    this.localFatigue,
    this.systemicFatigue,
    this.recoveryCost,
    this.platformExerciseId,
  });

  final KnowledgeEntityMeta meta;
  final String curationStatus;
  final List<String> movementPatternIds;
  final List<String> jointActionIds;
  final List<String> primaryMuscleIds;
  final List<String> secondaryMuscleIds;
  final List<String> requiredEquipmentIds;
  final List<String> optionalEquipmentIds;
  final List<String> suitableEnvironmentIds;
  final List<String> primaryCapabilityIds;
  final List<String> secondaryCapabilityIds;
  final List<String> supportingCapabilityIds;
  final List<String> supportsTrainingIntentIds;
  final String? energySystemPrimaryId;
  final String? energySystemSecondaryId;
  final String? technicalDemand;
  final String? localFatigue;
  final String? systemicFatigue;
  final String? recoveryCost;
  final String? platformExerciseId;

  String get id => meta.id;

  ExerciseCapabilityMapping get capabilityMapping => ExerciseCapabilityMapping(
    exerciseId: id,
    primaryCapabilityIds: primaryCapabilityIds,
    secondaryCapabilityIds: secondaryCapabilityIds,
    supportingCapabilityIds: supportingCapabilityIds,
  );
}

class SubstitutionRuleKnowledge {
  const SubstitutionRuleKnowledge({
    required this.meta,
    required this.sourceExerciseId,
    required this.candidateExerciseId,
    required this.explanation,
    this.substitutionKind,
    this.applicableConstraints = const [],
    this.preservedMovementPatternIds = const [],
    this.preservedTrainingIntentIds = const [],
    this.preservedCapabilityIds = const [],
    this.compromisedQualities = const [],
    this.equipmentRemovedIds = const [],
    this.equipmentAddedIds = const [],
    this.environmentCompatibilityIds = const [],
    this.suitabilityBand,
    this.suitabilityScore,
    this.prescriptionAdjustmentGuidance,
  });

  final KnowledgeEntityMeta meta;
  final String sourceExerciseId;
  final String candidateExerciseId;
  final String explanation;
  final String? substitutionKind;
  final List<String> applicableConstraints;
  final List<String> preservedMovementPatternIds;
  final List<String> preservedTrainingIntentIds;
  final List<String> preservedCapabilityIds;
  final List<String> compromisedQualities;
  final List<String> equipmentRemovedIds;
  final List<String> equipmentAddedIds;
  final List<String> environmentCompatibilityIds;
  final String? suitabilityBand;
  final double? suitabilityScore;
  final String? prescriptionAdjustmentGuidance;

  String get id => meta.id;
}

class SubstitutionQuery {
  const SubstitutionQuery({
    required this.sourceExerciseId,
    this.constraintTags = const [],
    this.trainingIntentId,
  });

  final String sourceExerciseId;
  final List<String> constraintTags;
  final String? trainingIntentId;
}

class TrainingIntentKnowledge {
  const TrainingIntentKnowledge({
    required this.meta,
    this.applicableCapabilityIds = const [],
    this.commonSessionArchetypeIds = const [],
    this.typicalProgressionCharacteristics = const [],
    this.fatigueCharacteristics,
    this.recoveryCharacteristics,
  });

  final KnowledgeEntityMeta meta;
  final List<String> applicableCapabilityIds;
  final List<String> commonSessionArchetypeIds;
  final List<String> typicalProgressionCharacteristics;
  final String? fatigueCharacteristics;
  final String? recoveryCharacteristics;

  String get id => meta.id;
}

class SessionArchetypeKnowledge {
  const SessionArchetypeKnowledge({
    required this.meta,
    this.primaryTrainingIntentIds = const [],
    this.typicalProgressionCharacteristics = const [],
    this.fatigueCharacteristics,
    this.recoveryCharacteristics,
  });

  final KnowledgeEntityMeta meta;
  final List<String> primaryTrainingIntentIds;
  final List<String> typicalProgressionCharacteristics;
  final String? fatigueCharacteristics;
  final String? recoveryCharacteristics;

  String get id => meta.id;
}

class CapabilityIntentMappingKnowledge {
  const CapabilityIntentMappingKnowledge({
    required this.id,
    required this.capabilityId,
    required this.trainingIntentId,
    required this.suitability,
    required this.progressionStage,
    required this.rationale,
    this.prerequisiteIntentIds = const [],
    this.prerequisiteCapabilityIds = const [],
    this.status = 'active',
    this.confidence,
    this.provenance,
  });

  final String id;
  final String capabilityId;
  final String trainingIntentId;
  final double suitability;
  final String progressionStage;
  final String rationale;
  final List<String> prerequisiteIntentIds;
  final List<String> prerequisiteCapabilityIds;
  final String status;
  final String? confidence;
  final String? provenance;
}

class ProgrammePhaseKnowledge {
  const ProgrammePhaseKnowledge({
    required this.meta,
    this.typicalDurationWeeksMin,
    this.typicalDurationWeeksMax,
    this.capabilityPriorityIds = const [],
    this.trainingIntentPriorityIds = const [],
    this.fatigueExpectations,
    this.recoveryExpectations,
    this.progressionCharacteristics = const [],
    this.allowableNextPhaseIds = const [],
  });

  final KnowledgeEntityMeta meta;
  final int? typicalDurationWeeksMin;
  final int? typicalDurationWeeksMax;
  final List<String> capabilityPriorityIds;
  final List<String> trainingIntentPriorityIds;
  final String? fatigueExpectations;
  final String? recoveryExpectations;
  final List<String> progressionCharacteristics;
  final List<String> allowableNextPhaseIds;

  String get id => meta.id;
}

class TrainingBlockKnowledge {
  const TrainingBlockKnowledge({
    required this.meta,
    this.primaryCapabilityIds = const [],
    this.secondaryCapabilityIds = const [],
    this.supportedTrainingIntentIds = const [],
    this.suitableProgrammePhaseIds = const [],
    this.expectedAdaptations = const [],
    this.entryCriteria,
    this.exitCriteria,
  });

  final KnowledgeEntityMeta meta;
  final List<String> primaryCapabilityIds;
  final List<String> secondaryCapabilityIds;
  final List<String> supportedTrainingIntentIds;
  final List<String> suitableProgrammePhaseIds;
  final List<String> expectedAdaptations;
  final String? entryCriteria;
  final String? exitCriteria;

  String get id => meta.id;
}

class WeekTypeKnowledge {
  const WeekTypeKnowledge({
    required this.meta,
    this.capabilityEmphasisIds = const [],
    this.intentEmphasisIds = const [],
    this.fatigueTarget,
    this.recoveryTarget,
    this.compatibleProgrammePhaseIds = const [],
  });

  final KnowledgeEntityMeta meta;
  final List<String> capabilityEmphasisIds;
  final List<String> intentEmphasisIds;
  final String? fatigueTarget;
  final String? recoveryTarget;
  final List<String> compatibleProgrammePhaseIds;

  String get id => meta.id;
}

class ProgrammeProgressionStepKnowledge {
  const ProgrammeProgressionStepKnowledge({
    required this.phaseId,
    required this.recommendedDurationWeeksMin,
    required this.recommendedDurationWeeksMax,
    required this.rationale,
    this.optionalAlternatePhaseIds = const [],
  });

  final String phaseId;
  final int recommendedDurationWeeksMin;
  final int recommendedDurationWeeksMax;
  final String rationale;
  final List<String> optionalAlternatePhaseIds;
}

class ProgrammeProgressionPathKnowledge {
  const ProgrammeProgressionPathKnowledge({
    required this.id,
    required this.label,
    required this.description,
    required this.steps,
  });

  final String id;
  final String label;
  final String description;
  final List<ProgrammeProgressionStepKnowledge> steps;
}
