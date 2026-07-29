import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/models/knowledge_ontology_models.dart';

/// In-memory [KnowledgeGraphReader] backed by a validated [KnowledgeOntologyBundle].
class InMemoryKnowledgeGraphReader implements KnowledgeGraphReader {
  InMemoryKnowledgeGraphReader(this._bundle)
    : _exercisesById = {for (final e in _bundle.exercises) e.id: e},
      _capabilitiesById = {for (final c in _bundle.capabilities) c.id: c},
      _goalsById = {for (final g in _bundle.goals) g.id: g},
      _phasesById = {for (final p in _bundle.programmePhases) p.id: p},
      _blocksById = {for (final b in _bundle.trainingBlocks) b.id: b},
      _weekTypesById = {for (final w in _bundle.weekTypes) w.id: w},
      _trainingIntentsById = {for (final i in _bundle.trainingIntents) i.id: i},
      _archetypesById = {for (final a in _bundle.sessionArchetypes) a.id: a},
      _mappingsByCapability = _indexMappings(_bundle.capabilityIntentMappings),
      _blocksByPhase = _indexBlocksByPhase(_bundle.trainingBlocks),
      _subsBySource = _indexSubstitutions(_bundle.substitutions),
      _childrenByParent = _indexChildren(_bundle.capabilities),
      _capabilityToExercises = _indexCapabilityExercises(_bundle.exercises);

  final KnowledgeOntologyBundle _bundle;
  final Map<String, ExerciseKnowledge> _exercisesById;
  final Map<String, CapabilityKnowledge> _capabilitiesById;
  final Map<String, GoalRequirementKnowledge> _goalsById;
  final Map<String, ProgrammePhaseKnowledge> _phasesById;
  final Map<String, TrainingBlockKnowledge> _blocksById;
  final Map<String, WeekTypeKnowledge> _weekTypesById;
  final Map<String, TrainingIntentKnowledge> _trainingIntentsById;
  final Map<String, SessionArchetypeKnowledge> _archetypesById;
  final Map<String, List<CapabilityIntentMappingKnowledge>>
  _mappingsByCapability;
  final Map<String, List<TrainingBlockKnowledge>> _blocksByPhase;
  final Map<String, List<SubstitutionRuleKnowledge>> _subsBySource;
  final Map<String, List<CapabilityKnowledge>> _childrenByParent;
  final Map<String, List<ExerciseKnowledge>> _capabilityToExercises;

  static Map<String, List<CapabilityIntentMappingKnowledge>> _indexMappings(
    List<CapabilityIntentMappingKnowledge> mappings,
  ) {
    final map = <String, List<CapabilityIntentMappingKnowledge>>{};
    for (final mapping in mappings) {
      if (mapping.status != 'active') continue;
      map.putIfAbsent(mapping.capabilityId, () => []).add(mapping);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) => b.suitability.compareTo(a.suitability));
    }
    return map;
  }

  static Map<String, List<TrainingBlockKnowledge>> _indexBlocksByPhase(
    List<TrainingBlockKnowledge> blocks,
  ) {
    final map = <String, List<TrainingBlockKnowledge>>{};
    for (final block in blocks) {
      if (block.meta.status != 'active') continue;
      for (final phaseId in block.suitableProgrammePhaseIds) {
        map.putIfAbsent(phaseId, () => []).add(block);
      }
    }
    return map;
  }

  static Map<String, List<SubstitutionRuleKnowledge>> _indexSubstitutions(
    List<SubstitutionRuleKnowledge> rules,
  ) {
    final map = <String, List<SubstitutionRuleKnowledge>>{};
    for (final rule in rules) {
      map.putIfAbsent(rule.sourceExerciseId, () => []).add(rule);
    }
    return map;
  }

  static Map<String, List<CapabilityKnowledge>> _indexChildren(
    List<CapabilityKnowledge> capabilities,
  ) {
    final map = <String, List<CapabilityKnowledge>>{};
    for (final capability in capabilities) {
      for (final parentId in capability.parentIds) {
        map.putIfAbsent(parentId, () => []).add(capability);
      }
    }
    return map;
  }

  static Map<String, List<ExerciseKnowledge>> _indexCapabilityExercises(
    List<ExerciseKnowledge> exercises,
  ) {
    final map = <String, List<ExerciseKnowledge>>{};
    for (final exercise in exercises) {
      for (final capId in exercise.capabilityMapping.allCapabilityIds) {
        map.putIfAbsent(capId, () => []).add(exercise);
      }
    }
    return map;
  }

  @override
  String get ontologyVersion => _bundle.ontologyVersion;

  @override
  List<ExerciseKnowledge> get allExercises => _bundle.exercises;

  @override
  List<GoalRequirementKnowledge> get allGoals => _bundle.goals;

  @override
  ExerciseKnowledge? exerciseById(String id) => _exercisesById[id];

  @override
  ExerciseKnowledge? exerciseByAlias(
    String alias, {
    String namespace = 'core',
  }) {
    final resolved = _bundle.aliasIndex['$namespace:${alias.toLowerCase()}'];
    if (resolved == null) return null;
    return _exercisesById[resolved];
  }

  @override
  CapabilityKnowledge? capabilityById(String id) => _capabilitiesById[id];

  @override
  List<CapabilityKnowledge> childrenOf(String capabilityId) {
    return List<CapabilityKnowledge>.unmodifiable(
      _childrenByParent[capabilityId] ?? const [],
    );
  }

  @override
  List<CapabilityKnowledge> parentsOf(String capabilityId) {
    final capability = _capabilitiesById[capabilityId];
    if (capability == null) return const [];
    return capability.parentIds
        .map((id) => _capabilitiesById[id])
        .whereType<CapabilityKnowledge>()
        .toList(growable: false);
  }

  @override
  List<CapabilityKnowledge> supportingCapabilities(String capabilityId) {
    final capability = _capabilitiesById[capabilityId];
    if (capability == null) return const [];
    return capability.supportingCapabilityIds
        .map((id) => _capabilitiesById[id])
        .whereType<CapabilityKnowledge>()
        .toList(growable: false);
  }

  @override
  ExerciseCapabilityMapping? capabilitiesForExercise(String exerciseId) {
    final exercise = _exercisesById[exerciseId];
    return exercise?.capabilityMapping;
  }

  @override
  List<ExerciseKnowledge> exercisesDevelopingCapability(String capabilityId) {
    return List<ExerciseKnowledge>.unmodifiable(
      _capabilityToExercises[capabilityId] ?? const [],
    );
  }

  @override
  GoalRequirementKnowledge? goalRequirements(String goalId) =>
      _goalsById[goalId];

  @override
  List<SubstitutionRuleKnowledge> substitutionsForSource(
    String sourceExerciseId,
  ) {
    return List<SubstitutionRuleKnowledge>.unmodifiable(
      _subsBySource[sourceExerciseId] ?? const [],
    );
  }

  @override
  List<SubstitutionRuleKnowledge> querySubstitutions(SubstitutionQuery query) {
    final candidates = substitutionsForSource(query.sourceExerciseId);
    if (candidates.isEmpty) return const [];

    return candidates
        .where((rule) {
          if (query.constraintTags.isEmpty && query.trainingIntentId == null) {
            return true;
          }
          var matches = true;
          if (query.constraintTags.isNotEmpty) {
            matches = query.constraintTags.every(
              rule.applicableConstraints.contains,
            );
          }
          if (matches && query.trainingIntentId != null) {
            matches = rule.preservedTrainingIntentIds.contains(
              query.trainingIntentId,
            );
          }
          return matches;
        })
        .toList(growable: false);
  }

  @override
  TrainingIntentKnowledge? trainingIntentById(String id) =>
      _trainingIntentsById[id];

  @override
  List<TrainingIntentKnowledge> get allTrainingIntents =>
      List<TrainingIntentKnowledge>.unmodifiable(_bundle.trainingIntents);

  @override
  SessionArchetypeKnowledge? sessionArchetypeById(String id) =>
      _archetypesById[id];

  @override
  List<SessionArchetypeKnowledge> get allSessionArchetypes =>
      List<SessionArchetypeKnowledge>.unmodifiable(_bundle.sessionArchetypes);

  @override
  List<CapabilityIntentMappingKnowledge> intentsForCapability(
    String capabilityId,
  ) {
    return List<CapabilityIntentMappingKnowledge>.unmodifiable(
      _mappingsByCapability[capabilityId] ?? const [],
    );
  }

  @override
  List<SessionArchetypeKnowledge> archetypesForIntent(String trainingIntentId) {
    final intent = _trainingIntentsById[trainingIntentId];
    final ids = <String>{...?intent?.commonSessionArchetypeIds};
    for (final archetype in _bundle.sessionArchetypes) {
      if (archetype.primaryTrainingIntentIds.contains(trainingIntentId)) {
        ids.add(archetype.id);
      }
    }
    return ids
        .map((id) => _archetypesById[id])
        .whereType<SessionArchetypeKnowledge>()
        .toList(growable: false);
  }

  @override
  List<CapabilityIntentMappingKnowledge> intentsForGoal(String goalId) {
    final goal = _goalsById[goalId];
    if (goal == null) return const [];
    final capabilityIds = {
      ...goal.requiredCapabilityIds,
      ...goal.optionalCapabilityIds,
    };
    final byIntent = <String, CapabilityIntentMappingKnowledge>{};
    for (final capabilityId in capabilityIds) {
      for (final mapping in intentsForCapability(capabilityId)) {
        final existing = byIntent[mapping.trainingIntentId];
        if (existing == null || mapping.suitability > existing.suitability) {
          byIntent[mapping.trainingIntentId] = mapping;
        }
      }
    }
    final merged = byIntent.values.toList()
      ..sort((a, b) => b.suitability.compareTo(a.suitability));
    return merged;
  }

  @override
  List<CapabilityIntentMappingKnowledge> progressionOptions(
    String capabilityId, {
    String? progressionStage,
  }) {
    final mappings = intentsForCapability(capabilityId);
    if (progressionStage == null) return mappings;
    return mappings
        .where((m) => m.progressionStage == progressionStage)
        .toList(growable: false);
  }

  @override
  List<ProgrammePhaseKnowledge> programmePhases() =>
      List<ProgrammePhaseKnowledge>.unmodifiable(_bundle.programmePhases);

  @override
  ProgrammePhaseKnowledge? programmePhaseById(String id) => _phasesById[id];

  @override
  TrainingBlockKnowledge? trainingBlockById(String id) => _blocksById[id];

  @override
  WeekTypeKnowledge? weekTypeById(String id) => _weekTypesById[id];

  @override
  List<TrainingBlockKnowledge> blocksForPhase(String programmePhaseId) {
    return List<TrainingBlockKnowledge>.unmodifiable(
      _blocksByPhase[programmePhaseId] ?? const [],
    );
  }

  @override
  List<TrainingBlockKnowledge> recommendedBlocks(String programmePhaseId) {
    final phase = _phasesById[programmePhaseId];
    final blocks = blocksForPhase(programmePhaseId);
    if (phase == null || blocks.isEmpty) return blocks;
    final priorities = phase.capabilityPriorityIds.toSet();
    int score(TrainingBlockKnowledge block) {
      var overlap = 0;
      for (final capId in block.primaryCapabilityIds) {
        if (priorities.contains(capId)) overlap += 2;
      }
      for (final capId in block.secondaryCapabilityIds) {
        if (priorities.contains(capId)) overlap += 1;
      }
      return overlap;
    }

    final sorted = [...blocks]
      ..sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        if (byScore != 0) return byScore;
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  @override
  List<WeekTypeKnowledge> weekTypes() =>
      List<WeekTypeKnowledge>.unmodifiable(_bundle.weekTypes);

  @override
  List<WeekTypeKnowledge> weekTypesForPhase(String programmePhaseId) {
    return _bundle.weekTypes
        .where((w) => w.compatibleProgrammePhaseIds.contains(programmePhaseId))
        .toList(growable: false);
  }

  @override
  ProgrammeProgressionPathKnowledge? progressionPath({String? pathId}) {
    final id = pathId ?? _bundle.defaultProgressionPathId;
    if (id == null) return null;
    for (final path in _bundle.programmeProgressionPaths) {
      if (path.id == id) return path;
    }
    return null;
  }

  @override
  List<String> phaseCapabilities(String programmePhaseId) {
    return List<String>.unmodifiable(
      _phasesById[programmePhaseId]?.capabilityPriorityIds ?? const [],
    );
  }

  @override
  List<String> phaseTrainingIntents(String programmePhaseId) {
    return List<String>.unmodifiable(
      _phasesById[programmePhaseId]?.trainingIntentPriorityIds ?? const [],
    );
  }
}

/// Default resolver using bundle alias index.
class KnowledgeEntityResolverImpl implements KnowledgeEntityResolver {
  const KnowledgeEntityResolverImpl(this._bundle);

  final KnowledgeOntologyBundle _bundle;

  @override
  String? resolveExerciseId(String aliasOrId, {String namespace = 'core'}) {
    if (_bundle.entityIds.contains(aliasOrId) &&
        aliasOrId.startsWith('cohort.exercise.')) {
      return aliasOrId;
    }
    return _bundle.aliasIndex['$namespace:${aliasOrId.toLowerCase()}'];
  }
}
