import '../models/knowledge_ontology_models.dart';

/// Deterministic validation for loaded [KnowledgeOntologyBundle].
class KnowledgeOntologyValidator {
  const KnowledgeOntologyValidator();

  static final RegExp _idPattern = RegExp(
    r'^cohort\.[a-z0-9_]+(\.[a-z0-9_]+)*$',
  );
  static final RegExp _semverPattern = RegExp(r'^\d+\.\d+\.\d+$');

  KnowledgeOntologyValidationResult validate(KnowledgeOntologyBundle bundle) {
    final errors = <String>[];

    if (!_semverPattern.hasMatch(bundle.ontologyVersion)) {
      errors.add('Invalid ontology version: ${bundle.ontologyVersion}');
    }

    _validateCapabilities(bundle, errors);
    _validateGoals(bundle, errors);
    _validateExercises(bundle, errors);
    _validateSubstitutions(bundle, errors);
    _validateTrainingIntentEngine(bundle, errors);
    _validateProgrammeSemantics(bundle, errors);

    return KnowledgeOntologyValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  void _validateExercises(KnowledgeOntologyBundle bundle, List<String> errors) {
    for (final exercise in bundle.exercises) {
      _validateMeta(exercise.meta, errors);
      _validateIdRef(exercise.id, exercise.movementPatternIds, bundle, errors);
      _validateIdRef(exercise.id, exercise.jointActionIds, bundle, errors);
      _validateIdRef(exercise.id, exercise.primaryMuscleIds, bundle, errors);
      _validateIdRef(exercise.id, exercise.secondaryMuscleIds, bundle, errors);
      _validateIdRef(
        exercise.id,
        exercise.requiredEquipmentIds,
        bundle,
        errors,
      );
      _validateIdRef(
        exercise.id,
        exercise.optionalEquipmentIds,
        bundle,
        errors,
      );
      _validateIdRef(
        exercise.id,
        exercise.suitableEnvironmentIds,
        bundle,
        errors,
      );
      _validateCapabilityRefs(
        exercise.id,
        [
          ...exercise.primaryCapabilityIds,
          ...exercise.secondaryCapabilityIds,
          ...exercise.supportingCapabilityIds,
        ],
        bundle,
        errors,
      );
      _validateIdRef(
        exercise.id,
        exercise.supportsTrainingIntentIds,
        bundle,
        errors,
      );
      if (exercise.energySystemPrimaryId != null) {
        _validateIdRef(
          exercise.id,
          [exercise.energySystemPrimaryId!],
          bundle,
          errors,
        );
      }
      if (exercise.energySystemSecondaryId != null) {
        _validateIdRef(
          exercise.id,
          [exercise.energySystemSecondaryId!],
          bundle,
          errors,
        );
      }

      final required = exercise.requiredEquipmentIds.toSet();
      final optional = exercise.optionalEquipmentIds.toSet();
      final overlap = required.intersection(optional);
      if (overlap.isNotEmpty) {
        errors.add(
          'Exercise ${exercise.id} lists equipment in both required and optional: $overlap',
        );
      }
    }
  }

  void _validateSubstitutions(
    KnowledgeOntologyBundle bundle,
    List<String> errors,
  ) {
    for (final rule in bundle.substitutions) {
      _validateMeta(rule.meta, errors);
      if (rule.sourceExerciseId == rule.candidateExerciseId) {
        errors.add('Substitution ${rule.id} self-references exercise');
      }
      if (!bundle.entityIds.contains(rule.sourceExerciseId)) {
        errors.add(
          'Substitution ${rule.id} orphan source ${rule.sourceExerciseId}',
        );
      }
      if (!bundle.entityIds.contains(rule.candidateExerciseId)) {
        errors.add(
          'Substitution ${rule.id} orphan candidate ${rule.candidateExerciseId}',
        );
      }
      _validateIdRef(rule.id, rule.preservedMovementPatternIds, bundle, errors);
      _validateIdRef(rule.id, rule.preservedTrainingIntentIds, bundle, errors);
      _validateCapabilityRefs(
        rule.id,
        rule.preservedCapabilityIds,
        bundle,
        errors,
      );
      _validateIdRef(rule.id, rule.equipmentRemovedIds, bundle, errors);
      _validateIdRef(rule.id, rule.equipmentAddedIds, bundle, errors);
      _validateIdRef(rule.id, rule.environmentCompatibilityIds, bundle, errors);
      if (rule.suitabilityScore != null) {
        final score = rule.suitabilityScore!;
        if (score < 0 || score > 1) {
          errors.add('Substitution ${rule.id} suitability_score out of range');
        }
      }
    }
  }

  void _validateCapabilities(
    KnowledgeOntologyBundle bundle,
    List<String> errors,
  ) {
    final byId = {for (final c in bundle.capabilities) c.id: c};
    for (final capability in bundle.capabilities) {
      _validateMeta(capability.meta, errors);
      _validateCapabilityRefs(
        capability.id,
        capability.parentIds,
        bundle,
        errors,
      );
      _validateCapabilityRefs(
        capability.id,
        capability.prerequisiteIds,
        bundle,
        errors,
      );
      _validateCapabilityRefs(
        capability.id,
        capability.supportingCapabilityIds,
        bundle,
        errors,
      );
      _validateCapabilityRefs(
        capability.id,
        capability.conflictingCapabilityIds,
        bundle,
        errors,
      );
      _validateIdRef(
        capability.id,
        capability.relatedMovementPatternIds,
        bundle,
        errors,
      );
      _validateIdRef(
        capability.id,
        capability.relatedEnergySystemIds,
        bundle,
        errors,
      );
      _validateIdRef(
        capability.id,
        capability.relatedTrainingIntentIds,
        bundle,
        errors,
      );
    }

    for (final capability in bundle.capabilities) {
      if (_hasParentCycle(capability.id, byId, {})) {
        errors.add('Capability parent cycle detected at ${capability.id}');
      }
      if (_hasPrerequisiteCycle(capability.id, byId, {})) {
        errors.add(
          'Capability prerequisite cycle detected at ${capability.id}',
        );
      }
    }

    final reachable = <String>{};
    void visit(String id) {
      if (reachable.contains(id)) return;
      reachable.add(id);
      for (final child in bundle.capabilities) {
        if (child.parentIds.contains(id)) visit(child.id);
      }
    }

    for (final root in bundle.capabilities) {
      if (root.parentIds.isEmpty) visit(root.id);
    }

    for (final capability in bundle.capabilities) {
      if (capability.meta.status != 'active') continue;
      if (!reachable.contains(capability.id)) {
        errors.add(
          'Orphan active capability (not reachable from root): ${capability.id}',
        );
      }
    }
  }

  bool _hasParentCycle(
    String id,
    Map<String, CapabilityKnowledge> byId,
    Set<String> visiting,
  ) {
    if (visiting.contains(id)) return true;
    final capability = byId[id];
    if (capability == null) return false;
    visiting.add(id);
    for (final parentId in capability.parentIds) {
      if (_hasParentCycle(parentId, byId, visiting)) return true;
    }
    visiting.remove(id);
    return false;
  }

  bool _hasPrerequisiteCycle(
    String id,
    Map<String, CapabilityKnowledge> byId,
    Set<String> visiting,
  ) {
    if (visiting.contains(id)) return true;
    final capability = byId[id];
    if (capability == null) return false;
    visiting.add(id);
    for (final prereqId in capability.prerequisiteIds) {
      if (_hasPrerequisiteCycle(prereqId, byId, visiting)) return true;
    }
    visiting.remove(id);
    return false;
  }

  void _validateCapabilityRefs(
    String ownerId,
    List<String> refs,
    KnowledgeOntologyBundle bundle,
    List<String> errors,
  ) {
    for (final ref in refs) {
      if (!_idPattern.hasMatch(ref)) {
        errors.add('Owner $ownerId invalid capability ref: $ref');
        continue;
      }
      if (!ref.startsWith('cohort.capability.')) {
        errors.add(
          'Owner $ownerId capability ref must be cohort.capability.*: $ref',
        );
        continue;
      }
      if (!bundle.entityIds.contains(ref)) {
        errors.add('Owner $ownerId orphan capability reference: $ref');
      }
    }
  }

  void _validateGoals(KnowledgeOntologyBundle bundle, List<String> errors) {
    for (final goal in bundle.goals) {
      _validateMeta(goal.meta, errors);
      _validateCapabilityRefs(
        goal.id,
        goal.requiredCapabilityIds,
        bundle,
        errors,
      );
      _validateCapabilityRefs(
        goal.id,
        goal.optionalCapabilityIds,
        bundle,
        errors,
      );
    }
  }

  void _validateTrainingIntentEngine(
    KnowledgeOntologyBundle bundle,
    List<String> errors,
  ) {
    final intentIds = bundle.trainingIntents.map((i) => i.id).toSet();
    final linkedIntentIds = <String>{};

    for (final intent in bundle.trainingIntents) {
      _validateMeta(intent.meta, errors);
      _validateCapabilityRefs(
        intent.id,
        intent.applicableCapabilityIds,
        bundle,
        errors,
      );
      _validateIdRef(
        intent.id,
        intent.commonSessionArchetypeIds,
        bundle,
        errors,
      );
    }

    for (final archetype in bundle.sessionArchetypes) {
      _validateMeta(archetype.meta, errors);
      _validateIdRef(
        archetype.id,
        archetype.primaryTrainingIntentIds,
        bundle,
        errors,
      );
      linkedIntentIds.addAll(archetype.primaryTrainingIntentIds);
    }

    for (final capability in bundle.capabilities) {
      linkedIntentIds.addAll(capability.relatedTrainingIntentIds);
    }

    for (final exercise in bundle.exercises) {
      linkedIntentIds.addAll(exercise.supportsTrainingIntentIds);
    }

    for (final rule in bundle.substitutions) {
      linkedIntentIds.addAll(rule.preservedTrainingIntentIds);
    }

    for (final mapping in bundle.capabilityIntentMappings) {
      if (!mapping.id.startsWith('cohort.mapping.')) {
        errors.add('Invalid mapping id format: ${mapping.id}');
      }
      _validateCapabilityRefs(
        mapping.id,
        [mapping.capabilityId],
        bundle,
        errors,
      );
      if (!intentIds.contains(mapping.trainingIntentId)) {
        errors.add(
          'Mapping ${mapping.id} orphan training_intent ${mapping.trainingIntentId}',
        );
      }
      _validateCapabilityRefs(
        mapping.id,
        mapping.prerequisiteCapabilityIds,
        bundle,
        errors,
      );
      for (final prereqIntent in mapping.prerequisiteIntentIds) {
        if (!intentIds.contains(prereqIntent)) {
          errors.add(
            'Mapping ${mapping.id} orphan prerequisite intent $prereqIntent',
          );
        }
      }
      if (mapping.suitability < 0 || mapping.suitability > 1) {
        errors.add('Mapping ${mapping.id} suitability out of range');
      }
      linkedIntentIds.add(mapping.trainingIntentId);
      linkedIntentIds.addAll(mapping.prerequisiteIntentIds);
    }

    for (final intent in bundle.trainingIntents) {
      if (intent.meta.status != 'active') continue;
      if (!linkedIntentIds.contains(intent.id)) {
        errors.add('Orphan active training intent: ${intent.id}');
      }
    }

    for (final archetype in bundle.sessionArchetypes) {
      if (archetype.meta.status != 'active') continue;
      var referenced = archetype.primaryTrainingIntentIds.isNotEmpty;
      if (!referenced) {
        for (final intent in bundle.trainingIntents) {
          if (intent.commonSessionArchetypeIds.contains(archetype.id)) {
            referenced = true;
            break;
          }
        }
      }
      if (!referenced) {
        errors.add('Orphan active session archetype: ${archetype.id}');
      }
    }

    for (final intentId in intentIds) {
      if (_hasIntentPrerequisiteCycle(
        intentId,
        bundle.capabilityIntentMappings,
        {},
      )) {
        errors.add('Training intent prerequisite cycle at $intentId');
      }
    }
  }

  bool _hasIntentPrerequisiteCycle(
    String intentId,
    List<CapabilityIntentMappingKnowledge> mappings,
    Set<String> visiting,
  ) {
    if (visiting.contains(intentId)) return true;
    visiting.add(intentId);
    for (final mapping in mappings) {
      if (mapping.trainingIntentId != intentId) continue;
      for (final prereq in mapping.prerequisiteIntentIds) {
        if (_hasIntentPrerequisiteCycle(prereq, mappings, visiting)) {
          return true;
        }
      }
    }
    visiting.remove(intentId);
    return false;
  }

  void _validateProgrammeSemantics(
    KnowledgeOntologyBundle bundle,
    List<String> errors,
  ) {
    final phaseIds = bundle.programmePhases.map((p) => p.id).toSet();
    final intentIds = bundle.trainingIntents.map((i) => i.id).toSet();
    final referencedPhases = <String>{};

    for (final phase in bundle.programmePhases) {
      _validateMeta(phase.meta, errors);
      _validateCapabilityRefs(
        phase.id,
        phase.capabilityPriorityIds,
        bundle,
        errors,
      );
      for (final intentId in phase.trainingIntentPriorityIds) {
        _validateIdRef(phase.id, [intentId], bundle, errors);
        if (!intentIds.contains(intentId)) {
          errors.add('Phase ${phase.id} orphan intent priority $intentId');
        }
      }
      for (final nextId in phase.allowableNextPhaseIds) {
        if (!phaseIds.contains(nextId)) {
          errors.add('Phase ${phase.id} orphan allowable next $nextId');
        }
      }
      if (phase.typicalDurationWeeksMin != null &&
          phase.typicalDurationWeeksMax != null &&
          phase.typicalDurationWeeksMin! > phase.typicalDurationWeeksMax!) {
        errors.add('Phase ${phase.id} invalid duration range');
      }
    }

    for (final block in bundle.trainingBlocks) {
      _validateMeta(block.meta, errors);
      _validateCapabilityRefs(
        block.id,
        [...block.primaryCapabilityIds, ...block.secondaryCapabilityIds],
        bundle,
        errors,
      );
      for (final phaseId in block.suitableProgrammePhaseIds) {
        if (!phaseIds.contains(phaseId)) {
          errors.add('Block ${block.id} orphan suitable phase $phaseId');
        }
      }
      for (final intentId in block.supportedTrainingIntentIds) {
        if (!intentIds.contains(intentId)) {
          errors.add('Block ${block.id} orphan supported intent $intentId');
        }
      }
      if (block.meta.status == 'active' &&
          block.suitableProgrammePhaseIds.isEmpty) {
        errors.add('Block ${block.id} has no suitable programme phases');
      }
    }

    for (final weekType in bundle.weekTypes) {
      _validateMeta(weekType.meta, errors);
      _validateCapabilityRefs(
        weekType.id,
        weekType.capabilityEmphasisIds,
        bundle,
        errors,
      );
      for (final intentId in weekType.intentEmphasisIds) {
        if (!intentIds.contains(intentId)) {
          errors.add('Week type ${weekType.id} orphan intent $intentId');
        }
      }
      for (final phaseId in weekType.compatibleProgrammePhaseIds) {
        if (!phaseIds.contains(phaseId)) {
          errors.add(
            'Week type ${weekType.id} orphan compatible phase $phaseId',
          );
        }
      }
    }

    for (final path in bundle.programmeProgressionPaths) {
      if (!path.id.startsWith('cohort.progression_path.')) {
        errors.add('Invalid progression path id: ${path.id}');
      }
      ProgrammePhaseKnowledge? priorPhase;
      final seenInPath = <String>{};
      for (final step in path.steps) {
        if (seenInPath.contains(step.phaseId)) {
          errors.add('Path ${path.id} repeats phase ${step.phaseId}');
        }
        seenInPath.add(step.phaseId);
        referencedPhases.add(step.phaseId);
        referencedPhases.addAll(step.optionalAlternatePhaseIds);
        if (!phaseIds.contains(step.phaseId)) {
          errors.add('Path ${path.id} orphan step phase ${step.phaseId}');
        }
        if (step.recommendedDurationWeeksMin >
            step.recommendedDurationWeeksMax) {
          errors.add('Path ${path.id} invalid duration on ${step.phaseId}');
        }
        for (final alt in step.optionalAlternatePhaseIds) {
          if (!phaseIds.contains(alt)) {
            errors.add('Path ${path.id} orphan alternate phase $alt');
          }
        }
        if (priorPhase != null &&
            !priorPhase.allowableNextPhaseIds.contains(step.phaseId)) {
          errors.add(
            'Path ${path.id} transition ${priorPhase.id} -> ${step.phaseId} not allowable',
          );
        }
        priorPhase = bundle.programmePhases
            .where((p) => p.id == step.phaseId)
            .firstOrNull;
      }
    }

    if (bundle.defaultProgressionPathId != null &&
        !bundle.programmeProgressionPaths.any(
          (p) => p.id == bundle.defaultProgressionPathId,
        )) {
      errors.add('default_path_id not found in paths');
    }

    for (final phase in bundle.programmePhases) {
      if (phase.meta.status != 'active') continue;
      if (!referencedPhases.contains(phase.id)) {
        errors.add('Orphan active programme phase: ${phase.id}');
      }
    }
  }

  void _validateMeta(KnowledgeEntityMeta meta, List<String> errors) {
    if (!_idPattern.hasMatch(meta.id)) {
      errors.add('Invalid id format: ${meta.id}');
    }
    if (!_semverPattern.hasMatch(meta.ontologyVersion)) {
      errors.add('Invalid entity ontology_version on ${meta.id}');
    }
    const validStatus = {'draft', 'active', 'deprecated'};
    if (!validStatus.contains(meta.status)) {
      errors.add('Invalid status on ${meta.id}: ${meta.status}');
    }
    if (meta.status == 'deprecated' &&
        (meta.replacesId == null || meta.replacesId!.isEmpty)) {
      errors.add('Deprecated entity ${meta.id} missing replaces_id');
    }
    if (meta.confidence != null) {
      const validConfidence = {'curated', 'inferred', 'provisional', 'unknown'};
      if (!validConfidence.contains(meta.confidence)) {
        errors.add('Invalid confidence on ${meta.id}: ${meta.confidence}');
      }
    }
  }

  void _validateIdRef(
    String ownerId,
    List<String> refs,
    KnowledgeOntologyBundle bundle,
    List<String> errors,
  ) {
    for (final ref in refs) {
      if (!_idPattern.hasMatch(ref)) {
        errors.add('Owner $ownerId has invalid ref id: $ref');
        continue;
      }
      if (!bundle.entityIds.contains(ref)) {
        errors.add('Owner $ownerId orphan reference: $ref');
      }
    }
  }
}

class KnowledgeOntologyValidationResult {
  const KnowledgeOntologyValidationResult({
    required this.isValid,
    required this.errors,
  });

  final bool isValid;
  final List<String> errors;
}
