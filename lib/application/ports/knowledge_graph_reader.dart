import '../../knowledge/models/knowledge_ontology_models.dart';

/// Read-only graph queries for substitutions and capability ontology.
abstract interface class KnowledgeGraphReader
    implements
        ExerciseKnowledgeReader,
        CapabilityGraphReader,
        TrainingIntentGraphReader,
        ProgrammeSemanticsGraphReader {
  List<SubstitutionRuleKnowledge> substitutionsForSource(
    String sourceExerciseId,
  );

  List<SubstitutionRuleKnowledge> querySubstitutions(SubstitutionQuery query);
}

/// Capability hierarchy and exercise/goal mappings (Coach Brain not wired).
abstract interface class CapabilityGraphReader {
  CapabilityKnowledge? capabilityById(String id);

  List<CapabilityKnowledge> childrenOf(String capabilityId);

  List<CapabilityKnowledge> parentsOf(String capabilityId);

  List<CapabilityKnowledge> supportingCapabilities(String capabilityId);

  ExerciseCapabilityMapping? capabilitiesForExercise(String exerciseId);

  List<ExerciseKnowledge> exercisesDevelopingCapability(String capabilityId);

  GoalRequirementKnowledge? goalRequirements(String goalId);

  List<GoalRequirementKnowledge> get allGoals;
}

/// Training intent taxonomy and capability → intent mappings (Sprint 5).
abstract interface class TrainingIntentGraphReader {
  TrainingIntentKnowledge? trainingIntentById(String id);

  List<TrainingIntentKnowledge> get allTrainingIntents;

  SessionArchetypeKnowledge? sessionArchetypeById(String id);

  List<SessionArchetypeKnowledge> get allSessionArchetypes;

  /// Contextual mappings for a capability, sorted by suitability descending.
  List<CapabilityIntentMappingKnowledge> intentsForCapability(
    String capabilityId,
  );

  /// Archetypes linked to an intent (primary list + common archetypes on intent).
  List<SessionArchetypeKnowledge> archetypesForIntent(String trainingIntentId);

  /// Union of [intentsForCapability] across goal required + optional capabilities.
  List<CapabilityIntentMappingKnowledge> intentsForGoal(String goalId);

  /// Filter mappings by capability and optional [progressionStage].
  List<CapabilityIntentMappingKnowledge> progressionOptions(
    String capabilityId, {
    String? progressionStage,
  });
}

/// Programme semantics — phases, blocks, week types, progression (Sprint 6).
abstract interface class ProgrammeSemanticsGraphReader {
  List<ProgrammePhaseKnowledge> programmePhases();

  ProgrammePhaseKnowledge? programmePhaseById(String id);

  TrainingBlockKnowledge? trainingBlockById(String id);

  WeekTypeKnowledge? weekTypeById(String id);

  List<TrainingBlockKnowledge> blocksForPhase(String programmePhaseId);

  /// Blocks for phase ranked by overlap with phase capability priorities.
  List<TrainingBlockKnowledge> recommendedBlocks(String programmePhaseId);

  List<WeekTypeKnowledge> weekTypes();

  List<WeekTypeKnowledge> weekTypesForPhase(String programmePhaseId);

  ProgrammeProgressionPathKnowledge? progressionPath({String? pathId});

  List<String> phaseCapabilities(String programmePhaseId);

  List<String> phaseTrainingIntents(String programmePhaseId);
}

/// Read-only access to curated exercise knowledge (persistence-independent).
abstract interface class ExerciseKnowledgeReader {
  String get ontologyVersion;

  ExerciseKnowledge? exerciseById(String id);

  ExerciseKnowledge? exerciseByAlias(String alias, {String namespace = 'core'});

  List<ExerciseKnowledge> get allExercises;
}

/// Resolves legacy or alias strings to canonical knowledge entity ids.
abstract interface class KnowledgeEntityResolver {
  String? resolveExerciseId(String aliasOrId, {String namespace = 'core'});
}
