import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/knowledge_ontology_models.dart';

/// Loads [KnowledgeOntologyBundle] from on-disk `knowledge/` directory.
class YamlKnowledgeOntologyLoader {
  const YamlKnowledgeOntologyLoader();

  Future<KnowledgeOntologyBundle> loadFromDirectory(String rootPath) async {
    final manifestFile = File('$rootPath/manifest.yaml');
    if (!manifestFile.existsSync()) {
      throw KnowledgeOntologyLoadException(
        'Missing manifest.yaml at $rootPath',
      );
    }
    final manifest = loadYaml(await manifestFile.readAsString());
    if (manifest is! YamlMap) {
      throw KnowledgeOntologyLoadException('Invalid manifest.yaml');
    }
    final ontology = manifest['ontology'];
    if (ontology is! YamlMap) {
      throw KnowledgeOntologyLoadException('Missing ontology section');
    }
    final version = ontology['version']?.toString();
    if (version == null || version.isEmpty) {
      throw KnowledgeOntologyLoadException('Missing ontology.version');
    }

    final reference = manifest['reference'] as YamlMap?;
    if (reference == null) {
      throw KnowledgeOntologyLoadException('Missing reference section');
    }

    final entityIds = <String>{};
    final aliasIndex = <String, String>{};

    void indexEntity(KnowledgeEntityMeta meta, {required bool indexAliases}) {
      if (entityIds.contains(meta.id)) {
        throw KnowledgeOntologyLoadException('Duplicate entity id: ${meta.id}');
      }
      entityIds.add(meta.id);
      if (!indexAliases) return;
      _registerAlias(aliasIndex, meta.namespace, meta.canonicalName, meta.id);
      for (final alias in meta.aliases) {
        _registerAlias(aliasIndex, meta.namespace, alias, meta.id);
      }
    }

    for (final entry in reference.entries) {
      if (entry.key == 'exercises' ||
          entry.key == 'substitutions' ||
          entry.key == 'capabilities' ||
          entry.key == 'goal_requirements' ||
          entry.key == 'training_intents' ||
          entry.key == 'session_archetypes' ||
          entry.key == 'capability_intent_mappings' ||
          entry.key == 'programme_phases' ||
          entry.key == 'training_blocks' ||
          entry.key == 'week_types' ||
          entry.key == 'programme_progression') {
        continue;
      }
      final path = entry.value?.toString();
      if (path == null) continue;
      final file = File('$rootPath/$path');
      final doc = loadYaml(await file.readAsString());
      if (doc is! YamlMap) continue;
      final entities = doc['entities'];
      if (entities is! YamlList) continue;
      for (final raw in entities) {
        if (raw is! YamlMap) continue;
        final meta = _parseMeta(raw, expectedVersion: version);
        indexEntity(meta, indexAliases: false);
      }
    }

    final capabilities = await _loadCapabilities(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
    );

    final goals = await _loadGoals(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
    );

    final exercises = <ExerciseKnowledge>[];
    final exercisesPath = reference['exercises']?.toString();
    if (exercisesPath != null) {
      final doc = loadYaml(
        await File('$rootPath/$exercisesPath').readAsString(),
      );
      if (doc is YamlMap && doc['entities'] is YamlList) {
        for (final raw in doc['entities'] as YamlList) {
          if (raw is! YamlMap) continue;
          final exercise = _parseExercise(raw, expectedVersion: version);
          indexEntity(exercise.meta, indexAliases: true);
          exercises.add(exercise);
        }
      }
    }

    final substitutions = <SubstitutionRuleKnowledge>[];
    final subsPath = reference['substitutions']?.toString();
    if (subsPath != null) {
      final doc = loadYaml(await File('$rootPath/$subsPath').readAsString());
      if (doc is YamlMap && doc['entities'] is YamlList) {
        for (final raw in doc['entities'] as YamlList) {
          if (raw is! YamlMap) continue;
          final rule = _parseSubstitution(raw, expectedVersion: version);
          indexEntity(rule.meta, indexAliases: false);
          substitutions.add(rule);
        }
      }
    }

    final trainingIntents = await _loadTrainingIntents(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
    );

    final sessionArchetypes = await _loadSessionArchetypes(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
    );

    final capabilityIntentMappings = await _loadCapabilityIntentMappings(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
    );

    final programmePhases = await _loadProgrammePhases(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
    );

    final trainingBlocks = await _loadTrainingBlocks(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
    );

    final weekTypes = await _loadWeekTypes(
      rootPath: rootPath,
      reference: reference,
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
    );

    final progressionLoad = await _loadProgrammeProgression(
      rootPath: rootPath,
      reference: reference,
      entityIds: entityIds,
    );

    return KnowledgeOntologyBundle(
      ontologyVersion: version,
      entityIds: entityIds,
      capabilities: capabilities,
      goals: goals,
      exercises: exercises,
      substitutions: substitutions,
      trainingIntents: trainingIntents,
      sessionArchetypes: sessionArchetypes,
      capabilityIntentMappings: capabilityIntentMappings,
      programmePhases: programmePhases,
      trainingBlocks: trainingBlocks,
      weekTypes: weekTypes,
      programmeProgressionPaths: progressionLoad.paths,
      defaultProgressionPathId: progressionLoad.defaultPathId,
      aliasIndex: aliasIndex,
    );
  }

  Future<List<CapabilityKnowledge>> _loadCapabilities({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
  }) async {
    final path = reference['capabilities']?.toString();
    if (path == null) return const [];
    final doc = loadYaml(await File('$rootPath/$path').readAsString());
    if (doc is! YamlMap || doc['entities'] is! YamlList) return const [];
    final capabilities = <CapabilityKnowledge>[];
    for (final raw in doc['entities'] as YamlList) {
      if (raw is! YamlMap) continue;
      final capability = _parseCapability(raw, expectedVersion: version);
      indexEntity(capability.meta, indexAliases: false);
      capabilities.add(capability);
    }
    return capabilities;
  }

  Future<List<GoalRequirementKnowledge>> _loadGoals({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
  }) async {
    final path = reference['goal_requirements']?.toString();
    if (path == null) return const [];
    final doc = loadYaml(await File('$rootPath/$path').readAsString());
    if (doc is! YamlMap || doc['entities'] is! YamlList) return const [];
    final goals = <GoalRequirementKnowledge>[];
    for (final raw in doc['entities'] as YamlList) {
      if (raw is! YamlMap) continue;
      final goal = _parseGoal(raw, expectedVersion: version);
      indexEntity(goal.meta, indexAliases: false);
      goals.add(goal);
    }
    return goals;
  }

  Future<List<TrainingIntentKnowledge>> _loadTrainingIntents({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
  }) async {
    final path = reference['training_intents']?.toString();
    if (path == null) return const [];
    final doc = loadYaml(await File('$rootPath/$path').readAsString());
    if (doc is! YamlMap || doc['entities'] is! YamlList) return const [];
    final intents = <TrainingIntentKnowledge>[];
    for (final raw in doc['entities'] as YamlList) {
      if (raw is! YamlMap) continue;
      final intent = _parseTrainingIntent(raw, expectedVersion: version);
      indexEntity(intent.meta, indexAliases: false);
      intents.add(intent);
    }
    return intents;
  }

  Future<List<SessionArchetypeKnowledge>> _loadSessionArchetypes({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
  }) async {
    final path = reference['session_archetypes']?.toString();
    if (path == null) return const [];
    final doc = loadYaml(await File('$rootPath/$path').readAsString());
    if (doc is! YamlMap || doc['entities'] is! YamlList) return const [];
    final archetypes = <SessionArchetypeKnowledge>[];
    for (final raw in doc['entities'] as YamlList) {
      if (raw is! YamlMap) continue;
      final archetype = _parseSessionArchetype(raw, expectedVersion: version);
      indexEntity(archetype.meta, indexAliases: false);
      archetypes.add(archetype);
    }
    return archetypes;
  }

  Future<List<CapabilityIntentMappingKnowledge>> _loadCapabilityIntentMappings({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
  }) async {
    final path = reference['capability_intent_mappings']?.toString();
    if (path == null) return const [];
    final doc = loadYaml(await File('$rootPath/$path').readAsString());
    if (doc is! YamlMap || doc['mappings'] is! YamlList) return const [];
    final mappings = <CapabilityIntentMappingKnowledge>[];
    for (final raw in doc['mappings'] as YamlList) {
      if (raw is! YamlMap) continue;
      final mapping = _parseCapabilityIntentMapping(raw);
      if (entityIds.contains(mapping.id)) {
        throw KnowledgeOntologyLoadException(
          'Duplicate mapping id: ${mapping.id}',
        );
      }
      entityIds.add(mapping.id);
      mappings.add(mapping);
    }
    return mappings;
  }

  Future<List<ProgrammePhaseKnowledge>> _loadProgrammePhases({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
  }) async {
    return _loadEntityList<ProgrammePhaseKnowledge>(
      rootPath: rootPath,
      reference: reference,
      key: 'programme_phases',
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
      parse: (raw) => _parseProgrammePhase(raw, expectedVersion: version),
    );
  }

  Future<List<TrainingBlockKnowledge>> _loadTrainingBlocks({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
  }) async {
    return _loadEntityList<TrainingBlockKnowledge>(
      rootPath: rootPath,
      reference: reference,
      key: 'training_blocks',
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
      parse: (raw) => _parseTrainingBlock(raw, expectedVersion: version),
    );
  }

  Future<List<WeekTypeKnowledge>> _loadWeekTypes({
    required String rootPath,
    required YamlMap reference,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
  }) async {
    return _loadEntityList<WeekTypeKnowledge>(
      rootPath: rootPath,
      reference: reference,
      key: 'week_types',
      version: version,
      entityIds: entityIds,
      indexEntity: indexEntity,
      parse: (raw) => _parseWeekType(raw, expectedVersion: version),
    );
  }

  Future<
    ({List<ProgrammeProgressionPathKnowledge> paths, String? defaultPathId})
  >
  _loadProgrammeProgression({
    required String rootPath,
    required YamlMap reference,
    required Set<String> entityIds,
  }) async {
    final path = reference['programme_progression']?.toString();
    if (path == null) {
      return (
        paths: const <ProgrammeProgressionPathKnowledge>[],
        defaultPathId: null,
      );
    }
    final doc = loadYaml(await File('$rootPath/$path').readAsString());
    if (doc is! YamlMap || doc['paths'] is! YamlList) {
      return (
        paths: const <ProgrammeProgressionPathKnowledge>[],
        defaultPathId: null,
      );
    }
    final defaultPathId = doc['default_path_id']?.toString();
    final paths = <ProgrammeProgressionPathKnowledge>[];
    for (final rawPath in doc['paths'] as YamlList) {
      if (rawPath is! YamlMap) continue;
      final id = rawPath['id']?.toString();
      final label = rawPath['label']?.toString();
      final description = rawPath['description']?.toString();
      if (id == null || label == null || description == null) {
        throw KnowledgeOntologyLoadException(
          'Progression path missing id/label/description',
        );
      }
      if (entityIds.contains(id)) {
        throw KnowledgeOntologyLoadException('Duplicate progression path: $id');
      }
      entityIds.add(id);
      final steps = <ProgrammeProgressionStepKnowledge>[];
      final rawSteps = rawPath['steps'];
      if (rawSteps is YamlList) {
        for (final rawStep in rawSteps) {
          if (rawStep is! YamlMap) continue;
          steps.add(_parseProgressionStep(rawStep));
        }
      }
      paths.add(
        ProgrammeProgressionPathKnowledge(
          id: id,
          label: label,
          description: description.trim(),
          steps: steps,
        ),
      );
    }
    return (paths: paths, defaultPathId: defaultPathId);
  }

  Future<List<T>> _loadEntityList<T>({
    required String rootPath,
    required YamlMap reference,
    required String key,
    required String version,
    required Set<String> entityIds,
    required void Function(
      KnowledgeEntityMeta meta, {
      required bool indexAliases,
    })
    indexEntity,
    required T Function(YamlMap raw) parse,
  }) async {
    final filePath = reference[key]?.toString();
    if (filePath == null) return const [];
    final doc = loadYaml(await File('$rootPath/$filePath').readAsString());
    if (doc is! YamlMap || doc['entities'] is! YamlList) return const [];
    final items = <T>[];
    for (final raw in doc['entities'] as YamlList) {
      if (raw is! YamlMap) continue;
      final item = parse(raw);
      if (item is ProgrammePhaseKnowledge) {
        indexEntity(item.meta, indexAliases: false);
      } else if (item is TrainingBlockKnowledge) {
        indexEntity(item.meta, indexAliases: false);
      } else if (item is WeekTypeKnowledge) {
        indexEntity(item.meta, indexAliases: false);
      }
      items.add(item);
    }
    return items;
  }

  ProgrammeProgressionStepKnowledge _parseProgressionStep(YamlMap raw) {
    final phaseId = raw['phase_id']?.toString();
    final rationale = raw['rationale']?.toString();
    if (phaseId == null || rationale == null) {
      throw KnowledgeOntologyLoadException('Progression step missing fields');
    }
    return ProgrammeProgressionStepKnowledge(
      phaseId: phaseId,
      recommendedDurationWeeksMin:
          _readInt(raw['recommended_duration_weeks_min']) ?? 1,
      recommendedDurationWeeksMax:
          _readInt(raw['recommended_duration_weeks_max']) ?? 1,
      rationale: rationale.trim(),
      optionalAlternatePhaseIds: _stringList(
        raw['optional_alternate_phase_ids'],
      ),
    );
  }

  ProgrammePhaseKnowledge _parseProgrammePhase(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    return ProgrammePhaseKnowledge(
      meta: meta,
      typicalDurationWeeksMin: _readInt(raw['typical_duration_weeks_min']),
      typicalDurationWeeksMax: _readInt(raw['typical_duration_weeks_max']),
      capabilityPriorityIds: _stringList(raw['capability_priority_ids']),
      trainingIntentPriorityIds: _stringList(
        raw['training_intent_priority_ids'],
      ),
      fatigueExpectations: raw['fatigue_expectations']?.toString(),
      recoveryExpectations: raw['recovery_expectations']?.toString(),
      progressionCharacteristics: _stringList(
        raw['progression_characteristics'],
      ),
      allowableNextPhaseIds: _stringList(raw['allowable_next_phase_ids']),
    );
  }

  TrainingBlockKnowledge _parseTrainingBlock(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    return TrainingBlockKnowledge(
      meta: meta,
      primaryCapabilityIds: _stringList(raw['primary_capability_ids']),
      secondaryCapabilityIds: _stringList(raw['secondary_capability_ids']),
      supportedTrainingIntentIds: _stringList(
        raw['supported_training_intent_ids'],
      ),
      suitableProgrammePhaseIds: _stringList(
        raw['suitable_programme_phase_ids'],
      ),
      expectedAdaptations: _stringList(raw['expected_adaptations']),
      entryCriteria: raw['entry_criteria']?.toString(),
      exitCriteria: raw['exit_criteria']?.toString(),
    );
  }

  WeekTypeKnowledge _parseWeekType(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    return WeekTypeKnowledge(
      meta: meta,
      capabilityEmphasisIds: _stringList(raw['capability_emphasis_ids']),
      intentEmphasisIds: _stringList(raw['intent_emphasis_ids']),
      fatigueTarget: raw['fatigue_target']?.toString(),
      recoveryTarget: raw['recovery_target']?.toString(),
      compatibleProgrammePhaseIds: _stringList(
        raw['compatible_programme_phase_ids'],
      ),
    );
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  TrainingIntentKnowledge _parseTrainingIntent(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    return TrainingIntentKnowledge(
      meta: meta,
      applicableCapabilityIds: _stringList(raw['applicable_capability_ids']),
      commonSessionArchetypeIds: _stringList(
        raw['common_session_archetype_ids'],
      ),
      typicalProgressionCharacteristics: _stringList(
        raw['typical_progression_characteristics'],
      ),
      fatigueCharacteristics: raw['fatigue_characteristics']?.toString(),
      recoveryCharacteristics: raw['recovery_characteristics']?.toString(),
    );
  }

  SessionArchetypeKnowledge _parseSessionArchetype(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    return SessionArchetypeKnowledge(
      meta: meta,
      primaryTrainingIntentIds: _stringList(raw['primary_training_intent_ids']),
      typicalProgressionCharacteristics: _stringList(
        raw['typical_progression_characteristics'],
      ),
      fatigueCharacteristics: raw['fatigue_characteristics']?.toString(),
      recoveryCharacteristics: raw['recovery_characteristics']?.toString(),
    );
  }

  CapabilityIntentMappingKnowledge _parseCapabilityIntentMapping(YamlMap raw) {
    final id = raw['id']?.toString();
    final capabilityId = raw['capability_id']?.toString();
    final trainingIntentId = raw['training_intent_id']?.toString();
    final rationale = raw['rationale']?.toString();
    final progressionStage = raw['progression_stage']?.toString();
    if (id == null ||
        capabilityId == null ||
        trainingIntentId == null ||
        rationale == null ||
        progressionStage == null) {
      throw KnowledgeOntologyLoadException('Mapping missing required fields');
    }
    final suitability = raw['suitability'];
    if (suitability is! num) {
      throw KnowledgeOntologyLoadException('Mapping $id missing suitability');
    }
    return CapabilityIntentMappingKnowledge(
      id: id,
      capabilityId: capabilityId,
      trainingIntentId: trainingIntentId,
      suitability: suitability.toDouble(),
      progressionStage: progressionStage,
      rationale: rationale.trim(),
      prerequisiteIntentIds: _stringList(raw['prerequisite_intent_ids']),
      prerequisiteCapabilityIds: _stringList(
        raw['prerequisite_capability_ids'],
      ),
      status: raw['status']?.toString() ?? 'active',
      confidence: raw['confidence']?.toString(),
      provenance: raw['provenance']?.toString(),
    );
  }

  CapabilityKnowledge _parseCapability(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    return CapabilityKnowledge(
      meta: meta,
      parentIds: _stringList(raw['parent_ids']),
      prerequisiteIds: _stringList(raw['prerequisite_ids']),
      supportingCapabilityIds: _stringList(raw['supporting_capability_ids']),
      conflictingCapabilityIds: _stringList(raw['conflicting_capability_ids']),
      relatedMovementPatternIds: _stringList(
        raw['related_movement_pattern_ids'],
      ),
      relatedEnergySystemIds: _stringList(raw['related_energy_system_ids']),
      relatedTrainingIntentIds: _stringList(raw['related_training_intent_ids']),
      typicalAssessmentMethods: _stringList(raw['typical_assessment_methods']),
    );
  }

  GoalRequirementKnowledge _parseGoal(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    return GoalRequirementKnowledge(
      meta: meta,
      requiredCapabilityIds: _stringList(raw['required_capability_ids']),
      optionalCapabilityIds: _stringList(raw['optional_capability_ids']),
    );
  }

  void _registerAlias(
    Map<String, String> index,
    String namespace,
    String alias,
    String entityId,
  ) {
    final key = '$namespace:${alias.trim().toLowerCase()}';
    if (key.endsWith(':')) return;
    if (index.containsKey(key) && index[key] != entityId) {
      throw KnowledgeOntologyLoadException('Duplicate alias key: $key');
    }
    index[key] = entityId;
  }

  KnowledgeEntityMeta _parseMeta(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final id = raw['id']?.toString();
    final canonicalName = raw['canonical_name']?.toString();
    final label = raw['label']?.toString();
    final ontologyVersion = raw['ontology_version']?.toString();
    final status = raw['status']?.toString();
    if (id == null ||
        canonicalName == null ||
        label == null ||
        ontologyVersion == null ||
        status == null) {
      throw KnowledgeOntologyLoadException(
        'Entity missing required meta fields',
      );
    }
    if (ontologyVersion != expectedVersion) {
      throw KnowledgeOntologyLoadException(
        'Entity $id ontology_version $ontologyVersion != manifest $expectedVersion',
      );
    }
    return KnowledgeEntityMeta(
      id: id,
      canonicalName: canonicalName,
      label: label,
      ontologyVersion: ontologyVersion,
      status: status,
      description: raw['description']?.toString(),
      aliases: _stringList(raw['aliases']),
      namespace: raw['namespace']?.toString() ?? 'core',
      replacesId: raw['replaces_id']?.toString(),
      provenance: raw['provenance']?.toString(),
      confidence: raw['confidence']?.toString(),
    );
  }

  ExerciseKnowledge _parseExercise(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    final curationStatus = raw['curation_status']?.toString() ?? 'unknown';

    String? readEnergy(YamlMap? map, String key) {
      if (map == null) return null;
      return map[key]?.toString();
    }

    YamlMap? energyMap;
    final energy = raw['energy_system_contribution'];
    if (energy is YamlMap) energyMap = energy;

    return ExerciseKnowledge(
      meta: meta,
      curationStatus: curationStatus,
      movementPatternIds: _refIds(raw['movement_patterns'], key: 'id'),
      jointActionIds: _refIds(raw['joint_actions'], key: 'id'),
      primaryMuscleIds: _stringList(raw['primary_muscles']),
      secondaryMuscleIds: _stringList(raw['secondary_muscles']),
      requiredEquipmentIds: _stringList(raw['required_equipment']),
      optionalEquipmentIds: _stringList(raw['optional_equipment']),
      suitableEnvironmentIds: _stringList(raw['suitable_environments']),
      primaryCapabilityIds: _stringList(raw['primary_capabilities']),
      secondaryCapabilityIds: _stringList(raw['secondary_capabilities']),
      supportingCapabilityIds: _stringList(raw['supporting_capabilities']),
      supportsTrainingIntentIds: _stringList(raw['supports_training_intents']),
      energySystemPrimaryId: readEnergy(energyMap, 'primary_id'),
      energySystemSecondaryId: readEnergy(energyMap, 'secondary_id'),
      technicalDemand: raw['technical_demand']?.toString(),
      localFatigue: raw['local_fatigue']?.toString(),
      systemicFatigue: raw['systemic_fatigue']?.toString(),
      recoveryCost: raw['recovery_cost']?.toString(),
      platformExerciseId: raw['platform_exercise_id']?.toString(),
    );
  }

  SubstitutionRuleKnowledge _parseSubstitution(
    YamlMap raw, {
    required String expectedVersion,
  }) {
    final meta = _parseMeta(raw, expectedVersion: expectedVersion);
    final source = raw['source_exercise_id']?.toString();
    final candidate = raw['candidate_exercise_id']?.toString();
    final explanation = raw['explanation']?.toString();
    if (source == null || candidate == null || explanation == null) {
      throw KnowledgeOntologyLoadException(
        'Substitution ${meta.id} missing source/candidate/explanation',
      );
    }

    YamlMap? delta;
    final d = raw['equipment_delta'];
    if (d is YamlMap) delta = d;

    return SubstitutionRuleKnowledge(
      meta: meta,
      sourceExerciseId: source,
      candidateExerciseId: candidate,
      explanation: explanation.trim(),
      substitutionKind: raw['substitution_kind']?.toString(),
      applicableConstraints: _stringList(raw['applicable_constraints']),
      preservedMovementPatternIds: _stringList(
        raw['preserved_movement_patterns'],
      ),
      preservedTrainingIntentIds: _stringList(
        raw['preserved_training_intents'],
      ),
      preservedCapabilityIds: _stringList(raw['preserved_capabilities']),
      compromisedQualities: _stringList(raw['compromised_qualities']),
      equipmentRemovedIds: _stringList(delta?['removed']),
      equipmentAddedIds: _stringList(delta?['added']),
      environmentCompatibilityIds: _stringList(
        raw['environment_compatibility'],
      ),
      suitabilityBand: raw['suitability_band']?.toString(),
      suitabilityScore: (raw['suitability_score'] is num)
          ? (raw['suitability_score'] as num).toDouble()
          : null,
      prescriptionAdjustmentGuidance: raw['prescription_adjustment_guidance']
          ?.toString(),
    );
  }

  List<String> _stringList(Object? value) {
    if (value is! YamlList) return const [];
    return value.map((e) => e.toString()).toList(growable: false);
  }

  List<String> _refIds(Object? value, {required String key}) {
    if (value is! YamlList) return const [];
    final ids = <String>[];
    for (final item in value) {
      if (item is YamlMap && item[key] != null) {
        ids.add(item[key].toString());
      }
    }
    return ids;
  }
}

class KnowledgeOntologyLoadException implements Exception {
  KnowledgeOntologyLoadException(this.message);
  final String message;
  @override
  String toString() => 'KnowledgeOntologyLoadException: $message';
}
