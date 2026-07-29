import '../../application/ports/exercise_policy_engine.dart';
import '../../application/ports/knowledge_graph_reader.dart';
import '../../knowledge/models/knowledge_ontology_models.dart';
import '../session_blueprint/models/session_blueprint.dart';
import 'exercise_policy_validator.dart';
import 'models/exercise_policy_models.dart';

/// Deterministic movement selection from [SessionBlueprint] (ADR-025).
class DeterministicExercisePolicyEngine implements ExercisePolicyEngine {
  DeterministicExercisePolicyEngine({
    required KnowledgeGraphReader knowledge,
    ExercisePolicyValidator? validator,
  }) : _knowledge = knowledge,
       _validator = validator ?? const ExercisePolicyValidator();

  final KnowledgeGraphReader _knowledge;
  final ExercisePolicyValidator _validator;

  @override
  ExercisePolicyResult evaluate(ExercisePolicyRequest request) {
    final factors = <PolicyExplainabilityFactor>[];
    final warnings = <String>[];
    final bp = request.blueprint;

    factors.add(
      PolicyExplainabilityFactor(
        layer: PolicyExplainabilityLayer.blueprint,
        code: 'blueprint_received',
        summary: 'Evaluating blueprint ${bp.blueprintId}',
        rationale: bp.objective.summary,
        sourceEntityIds: [bp.sessionArchetype.archetypeId],
      ),
    );

    final reqVal = _validator.validateRequest(request);
    if (!reqVal.isValid) {
      return _failure(
        request: request,
        status: MovementSelectionStatus.invalidBlueprint,
        factors: factors,
        warnings: reqVal.messages,
      );
    }

    if (bp.status == SessionBlueprintStatus.infeasible) {
      return _failure(
        request: request,
        status: MovementSelectionStatus.invalidBlueprint,
        factors: factors,
        warnings: const ['Blueprint status infeasible'],
      );
    }

    final tags = _resolvePolicyTags(request);
    final activeConstraints = _buildActiveConstraints(request, tags, factors);
    final primaryIntent = bp.primaryTrainingIntentId;
    final supportingIntents = bp.supportingTrainingIntentIds;

    final usedPatterns = <String>{};
    final usedExerciseIds = <String>{};
    final selections = <ExerciseSelection>[];
    var sequence = 0;
    var requiredGaps = 0;

    final components = [...bp.structuralComponents]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    for (final component in components) {
      if (selections.length >= request.maxTotalSelections) break;
      if (component.optionality == SessionComponentOptionality.optional &&
          bp.substitutionPolicyTags.contains(
            SessionSubstitutionPolicyTag.fatigueReduced,
          ) &&
          component.fatigueContribution == SessionFatigueContribution.high) {
        factors.add(
          PolicyExplainabilityFactor(
            layer: PolicyExplainabilityLayer.constraint,
            code: 'optional_high_fatigue_skipped',
            summary: 'Skipped optional high-fatigue component',
            rationale: component.purpose,
          ),
        );
        continue;
      }

      final slots = _slotsForComponent(component, request.maxSelectionsPerComponent);
      if (slots == 0) continue;

      final targetCaps = component.targetedCapabilityIds.isNotEmpty
          ? component.targetedCapabilityIds
          : bp.desiredAdaptations.map((a) => a.capabilityId).take(2).toList();

      final targetIntents = component.associatedIntentIds.isNotEmpty
          ? component.associatedIntentIds
          : [primaryIntent, ...supportingIntents];

      final picks = _selectForComponent(
        request: request,
        tags: tags,
        targetCapabilityIds: targetCaps,
        targetIntentIds: targetIntents,
        primaryIntentId: primaryIntent,
        component: component,
        maxPicks: slots,
        usedPatterns: usedPatterns,
        usedExerciseIds: usedExerciseIds,
        factors: factors,
      );

      if (component.optionality == SessionComponentOptionality.required &&
          picks.isEmpty) {
        requiredGaps++;
      }

      for (final pick in picks) {
        sequence++;
        final selection = pick.copyWithSequence(
          sequence: sequence,
          role: _roleForComponent(component.componentType),
          component: component,
        );
        selections.add(selection);
        usedExerciseIds.add(selection.exerciseId);
        usedPatterns.addAll(selection.movementPatternIds);
      }
    }

    var status = MovementSelectionStatus.complete;
    if (requiredGaps > 0) {
      status = MovementSelectionStatus.infeasible;
    } else if (selections.isEmpty ||
        bp.status == SessionBlueprintStatus.partial) {
      status = selections.isEmpty
          ? MovementSelectionStatus.infeasible
          : MovementSelectionStatus.partial;
    } else if (selections.length < components.where(
      (c) => c.optionality == SessionComponentOptionality.required,
    ).length) {
      status = MovementSelectionStatus.partial;
    }

    final componentMappings = _componentMappings(components, selections);

    final plan = SemanticSessionExecutionPlan(
      planId: computePolicyPlanId(bp.blueprintId),
      blueprintId: bp.blueprintId,
      athleteId: bp.athleteId,
      sessionArchetypeId: bp.sessionArchetype.archetypeId,
      primaryTrainingIntentId: primaryIntent,
      orderedSelections: selections,
      componentMappings: componentMappings,
      activeConstraints: activeConstraints,
      sessionObjectiveSummary: bp.objective.summary,
    );

    ExercisePolicyContract.assertSemanticPlanOnly(plan);

    factors.add(
      PolicyExplainabilityFactor(
        layer: PolicyExplainabilityLayer.outcome,
        code: 'selection_complete',
        summary: '${selections.length} movements selected',
        rationale: 'Status=${status.name}',
        confidence: bp.confidence,
      ),
    );

    final result = ExercisePolicyResult(
      status: status,
      blueprintId: bp.blueprintId,
      ontologyVersion: bp.ontologyVersion,
      selections: selections,
      executionPlan: plan,
      activeConstraints: activeConstraints,
      explainability: PolicyExplainability(
        factors: factors,
        narrativeSummary: _narrative(bp, selections, status, tags),
      ),
      warnings: warnings,
      primaryTrainingIntentId: primaryIntent,
      sessionArchetypeId: bp.sessionArchetype.archetypeId,
    );

    final outVal = _validator.validateResult(request: request, result: result);
    if (!outVal.isValid && status == MovementSelectionStatus.complete) {
      warnings.addAll(outVal.messages);
    }

    return result.copyWithWarnings(warnings);
  }

  Set<String> _resolvePolicyTags(ExercisePolicyRequest request) {
    final tags = <String>{};
    for (final t in request.blueprint.substitutionPolicyTags) {
      tags.addAll(_tagToConstraintCodes(t));
    }
    for (final c in request.blueprint.constraints) {
      tags.add(c.code);
    }
    if (request.isTraveling) {
      tags.add('travel');
      tags.add('hotel_gym');
    }
    if (request.availableEquipmentIds.length <= 3) {
      tags.add('limited_equipment');
    }
    return tags;
  }

  List<String> _tagToConstraintCodes(SessionSubstitutionPolicyTag tag) {
    return switch (tag) {
      SessionSubstitutionPolicyTag.limitedEquipment => [
        'limited_equipment',
        'no_barbell',
      ],
      SessionSubstitutionPolicyTag.travelCompatible => [
        'travel',
        'hotel_gym',
        'hotel_room',
      ],
      SessionSubstitutionPolicyTag.noOverheadLoading => ['no_overhead'],
      SessionSubstitutionPolicyTag.lowImpactRequired => ['low_impact'],
      SessionSubstitutionPolicyTag.fatigueReduced => ['fatigue_reduced'],
      SessionSubstitutionPolicyTag.assessmentIntegrityRequired => [
        'assessment_integrity',
      ],
      SessionSubstitutionPolicyTag.techniquePriority => ['technique_priority'],
      _ => [tag.name],
    };
  }

  List<MovementConstraint> _buildActiveConstraints(
    ExercisePolicyRequest request,
    Set<String> tags,
    List<PolicyExplainabilityFactor> factors,
  ) {
    final list = <MovementConstraint>[];
    if (request.environmentId != null) {
      list.add(
        MovementConstraint(
          kind: MovementConstraintKind.environment,
          code: 'environment',
          description: request.environmentId!,
        ),
      );
    }
    if (request.availableEquipmentIds.isNotEmpty) {
      list.add(
        MovementConstraint(
          kind: MovementConstraintKind.equipment,
          code: 'equipment_available',
          description: request.availableEquipmentIds.join(', '),
        ),
      );
    }
    for (final flag in request.injuryFlags) {
      list.add(
        MovementConstraint(
          kind: MovementConstraintKind.injury,
          code: 'injury_flag',
          description: flag,
        ),
      );
    }
    if (tags.contains('fatigue_reduced')) {
      list.add(
        const MovementConstraint(
          kind: MovementConstraintKind.fatigue,
          code: 'fatigue_reduced',
          description: 'Exclude high-fatigue movements where possible',
        ),
      );
    }
    factors.add(
      PolicyExplainabilityFactor(
        layer: PolicyExplainabilityLayer.constraint,
        code: 'constraints_active',
        summary: '${list.length} active movement constraints',
        rationale: tags.join(', '),
      ),
    );
    return list;
  }

  int _slotsForComponent(
    SessionStructuralComponent component,
    int maxPerComponent,
  ) {
    if (component.componentType == SessionStructuralComponentType.recoveryOrCooldown &&
        component.relativeEmphasis == SessionComponentEmphasis.minimal) {
      return 1;
    }
    if (component.componentType == SessionStructuralComponentType.preparation ||
        component.componentType == SessionStructuralComponentType.movementPreparation) {
      return 1;
    }
    if (component.componentType == SessionStructuralComponentType.primaryDevelopment) {
      return maxPerComponent.clamp(1, 2);
    }
    if (component.componentType == SessionStructuralComponentType.assessment) {
      return 1;
    }
    if (component.optionality == SessionComponentOptionality.optional) {
      return 1;
    }
    return maxPerComponent;
  }

  List<_ScoredPick> _selectForComponent({
    required ExercisePolicyRequest request,
    required Set<String> tags,
    required List<String> targetCapabilityIds,
    required List<String> targetIntentIds,
    required String primaryIntentId,
    required SessionStructuralComponent component,
    required int maxPicks,
    required Set<String> usedPatterns,
    required Set<String> usedExerciseIds,
    required List<PolicyExplainabilityFactor> factors,
  }) {
    final candidates = <_ScoredPick>[];

    for (final cap in targetCapabilityIds) {
      for (final exercise in _knowledge.exercisesDevelopingCapability(cap)) {
        _tryAddCandidate(
          exercise: exercise,
          request: request,
          tags: tags,
          targetCapabilityIds: targetCapabilityIds,
          targetIntentIds: targetIntentIds,
          primaryIntentId: primaryIntentId,
          component: component,
          usedExerciseIds: usedExerciseIds,
          usedPatterns: usedPatterns,
          candidates: candidates,
        );
      }
    }

    for (final exercise in _knowledge.allExercises) {
      _tryAddCandidate(
        exercise: exercise,
        request: request,
        tags: tags,
        targetCapabilityIds: targetCapabilityIds,
        targetIntentIds: targetIntentIds,
        primaryIntentId: primaryIntentId,
        component: component,
        usedExerciseIds: usedExerciseIds,
        usedPatterns: usedPatterns,
        candidates: candidates,
      );
    }

    // Substitution expansion: for top ideal failures, try rule candidates
    _expandWithSubstitutions(
      request: request,
      tags: tags,
      primaryIntentId: primaryIntentId,
      targetCapabilityIds: targetCapabilityIds,
      component: component,
      usedExerciseIds: usedExerciseIds,
      candidates: candidates,
    );

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.exercise.id.compareTo(b.exercise.id);
    });

    factors.add(
      PolicyExplainabilityFactor(
        layer: PolicyExplainabilityLayer.candidatePool,
        code: 'component_pool',
        summary:
            '${candidates.length} candidates for component ${component.sequence}',
        rationale: component.purpose,
        sourceEntityIds: targetCapabilityIds,
      ),
    );

    return candidates
        .where(
          (c) =>
              _equipmentSatisfied(c.exercise, request.availableEquipmentIds) ||
              c.substitutedFrom != null,
        )
        .take(maxPicks)
        .toList();
  }

  void _tryAddCandidate({
    required ExerciseKnowledge exercise,
    required ExercisePolicyRequest request,
    required Set<String> tags,
    required List<String> targetCapabilityIds,
    required List<String> targetIntentIds,
    required String primaryIntentId,
    required SessionStructuralComponent component,
    required Set<String> usedExerciseIds,
    required Set<String> usedPatterns,
    required List<_ScoredPick> candidates,
  }) {
    if (usedExerciseIds.contains(exercise.id)) return;
    if (!_passesHardFilters(exercise, request, tags, component)) return;

    var score = _scoreExercise(
      exercise: exercise,
      targetCapabilityIds: targetCapabilityIds,
      targetIntentIds: targetIntentIds,
      primaryIntentId: primaryIntentId,
      usedPatterns: usedPatterns,
      tags: tags,
      component: component,
    );
    if (!_equipmentSatisfied(exercise, request.availableEquipmentIds)) {
      score -= 5;
    }
    if (score < 0) return;

    if (candidates.any((c) => c.exercise.id == exercise.id)) return;

    candidates.add(
      _ScoredPick(
        exercise: exercise,
        score: score,
        reasons: _reasonsFor(
          exercise: exercise,
          targetCapabilityIds: targetCapabilityIds,
          primaryIntentId: primaryIntentId,
          score: score,
        ),
        substitutedFrom: null,
      ),
    );
  }

  void _expandWithSubstitutions({
    required ExercisePolicyRequest request,
    required Set<String> tags,
    required String primaryIntentId,
    required List<String> targetCapabilityIds,
    required SessionStructuralComponent component,
    required Set<String> usedExerciseIds,
    required List<_ScoredPick> candidates,
  }) {
    final existingIds = candidates.map((c) => c.exercise.id).toSet();
    for (final seed in candidates.take(3)) {
      if (_equipmentSatisfied(seed.exercise, request.availableEquipmentIds)) {
        continue;
      }
      final rules = _knowledge.querySubstitutions(
        SubstitutionQuery(
          sourceExerciseId: seed.exercise.id,
          constraintTags: tags.toList(),
          trainingIntentId: primaryIntentId,
        ),
      );
      for (final rule in rules) {
        final candidate = _knowledge.exerciseById(rule.candidateExerciseId);
        if (candidate == null || usedExerciseIds.contains(candidate.id)) {
          continue;
        }
        if (existingIds.contains(candidate.id)) continue;
        if (!_passesHardFilters(candidate, request, tags, component)) continue;

        final score =
            _scoreExercise(
              exercise: candidate,
              targetCapabilityIds: targetCapabilityIds,
              targetIntentIds: [primaryIntentId],
              primaryIntentId: primaryIntentId,
              usedPatterns: const {},
              tags: tags,
              component: component,
            ) +
            (rule.suitabilityScore ?? 0.5);

        candidates.add(
          _ScoredPick(
            exercise: candidate,
            score: score,
            reasons: [
              ExerciseSelectionReason(
                code: ExerciseSelectionReasonCode.substitutionRule,
                summary: rule.explanation.trim(),
                trainingIntentId: primaryIntentId,
                substitutionRuleId: rule.id,
                confidence: rule.suitabilityScore,
              ),
            ],
            substitutedFrom: seed.exercise.id,
          ),
        );
        existingIds.add(candidate.id);
      }
    }
  }

  bool _passesHardFilters(
    ExerciseKnowledge exercise,
    ExercisePolicyRequest request,
    Set<String> tags,
    SessionStructuralComponent component,
  ) {
    if (request.environmentId != null &&
        exercise.suitableEnvironmentIds.isNotEmpty &&
        !exercise.suitableEnvironmentIds.contains(request.environmentId)) {
      return false;
    }

    if (tags.contains('fatigue_reduced') ||
        request.blueprint.substitutionPolicyTags.contains(
          SessionSubstitutionPolicyTag.fatigueReduced,
        )) {
      if (exercise.localFatigue == 'high' &&
          component.fatigueContribution != SessionFatigueContribution.high) {
        return false;
      }
      if (exercise.systemicFatigue == 'very_high') return false;
    }

    if (tags.contains('low_impact') ||
        request.blueprint.substitutionPolicyTags.contains(
          SessionSubstitutionPolicyTag.lowImpactRequired,
        )) {
      if (exercise.localFatigue == 'high' &&
          exercise.movementPatternIds.any((p) => p.contains('jump'))) {
        return false;
      }
    }

    if (tags.contains('no_overhead') ||
        request.blueprint.substitutionPolicyTags.contains(
          SessionSubstitutionPolicyTag.noOverheadLoading,
        )) {
      if (exercise.id.contains('overhead') ||
          exercise.id.contains('bench_press') ||
          exercise.movementPatternIds.any((p) => p.contains('vertical_push'))) {
        return false;
      }
    }

    if (tags.contains('assessment_integrity') &&
        component.componentType == SessionStructuralComponentType.assessment) {
      if (exercise.technicalDemand == 'advanced') return false;
    }

    if (tags.contains('technique_priority') &&
        component.componentType == SessionStructuralComponentType.skillOrTechnique) {
      if (exercise.technicalDemand == 'advanced') return false;
    }

    return true;
  }

  bool _equipmentSatisfied(
    ExerciseKnowledge exercise,
    List<String> available,
  ) {
    if (exercise.requiredEquipmentIds.isEmpty) return true;
    if (available.isEmpty) {
      return exercise.requiredEquipmentIds.every(
        (id) => id == 'cohort.equipment.bodyweight',
      );
    }
    return exercise.requiredEquipmentIds.every(available.contains);
  }

  double _scoreExercise({
    required ExerciseKnowledge exercise,
    required List<String> targetCapabilityIds,
    required List<String> targetIntentIds,
    required String primaryIntentId,
    required Set<String> usedPatterns,
    required Set<String> tags,
    required SessionStructuralComponent component,
  }) {
    var score = 0.0;
    for (final cap in targetCapabilityIds) {
      if (exercise.primaryCapabilityIds.contains(cap)) {
        score += 3;
      } else if (exercise.secondaryCapabilityIds.contains(cap)) {
        score += 2;
      } else if (exercise.supportingCapabilityIds.contains(cap)) {
        score += 1;
      }
    }

    if (exercise.supportsTrainingIntentIds.contains(primaryIntentId)) {
      score += 2;
    }
    for (final intent in targetIntentIds) {
      if (intent != primaryIntentId &&
          exercise.supportsTrainingIntentIds.contains(intent)) {
        score += 1;
      }
    }

    for (final pattern in exercise.movementPatternIds) {
      if (usedPatterns.contains(pattern)) {
        score -= 1.0;
      }
    }

    if (tags.contains('technique_priority') &&
        component.componentType == SessionStructuralComponentType.skillOrTechnique) {
      if (exercise.technicalDemand == 'beginner') score += 0.5;
    }

    return score;
  }

  List<ExerciseSelectionReason> _reasonsFor({
    required ExerciseKnowledge exercise,
    required List<String> targetCapabilityIds,
    required String primaryIntentId,
    required double score,
  }) {
    final reasons = <ExerciseSelectionReason>[];
    for (final cap in targetCapabilityIds) {
      if (exercise.primaryCapabilityIds.contains(cap)) {
        reasons.add(
          ExerciseSelectionReason(
            code: ExerciseSelectionReasonCode.capabilityPrimaryMatch,
            summary: 'Primary capability match',
            capabilityId: cap,
            confidence: score,
          ),
        );
      }
    }
    if (exercise.supportsTrainingIntentIds.contains(primaryIntentId)) {
      reasons.add(
        ExerciseSelectionReason(
          code: ExerciseSelectionReasonCode.intentPrimaryMatch,
          summary: 'Supports primary training intent',
          trainingIntentId: primaryIntentId,
        ),
      );
    }
    reasons.add(
      ExerciseSelectionReason(
        code: ExerciseSelectionReasonCode.equipmentDirect,
        summary: 'Equipment and environment compatible',
        policyCode: 'constraint_pass',
      ),
    );
    return reasons;
  }

  List<SemanticComponentExerciseMapping> _componentMappings(
    List<SessionStructuralComponent> components,
    List<ExerciseSelection> selections,
  ) {
    return components.map((c) {
      final ids = selections
          .where((s) => s.structuralComponentSequence == c.sequence)
          .map((s) => s.exerciseId)
          .toList();
      return SemanticComponentExerciseMapping(
        componentSequence: c.sequence,
        componentType: c.componentType,
        exerciseIds: ids,
        purpose: c.purpose,
      );
    }).toList();
  }

  String _narrative(
    SessionBlueprint bp,
    List<ExerciseSelection> selections,
    MovementSelectionStatus status,
    Set<String> tags,
  ) {
    return 'Policy selected ${selections.length} movements for ${bp.sessionArchetype.label} '
        'preserving ${bp.primaryTrainingIntentLabel}. Status=$status. '
        'Tags=${tags.take(5).join(", ")}.';
  }

  ExercisePolicyResult _failure({
    required ExercisePolicyRequest request,
    required MovementSelectionStatus status,
    required List<PolicyExplainabilityFactor> factors,
    required List<String> warnings,
  }) {
    final bp = request.blueprint;
    final plan = SemanticSessionExecutionPlan(
      planId: computePolicyPlanId(bp.blueprintId),
      blueprintId: bp.blueprintId,
      athleteId: bp.athleteId,
      sessionArchetypeId: bp.sessionArchetype.archetypeId,
      primaryTrainingIntentId: bp.primaryTrainingIntentId,
      orderedSelections: const [],
      componentMappings: const [],
      sessionObjectiveSummary: bp.objective.summary,
    );
    return ExercisePolicyResult(
      status: status,
      blueprintId: bp.blueprintId,
      ontologyVersion: bp.ontologyVersion,
      selections: const [],
      executionPlan: plan,
      activeConstraints: const [],
      explainability: PolicyExplainability(
        factors: factors,
        narrativeSummary: warnings.isEmpty
            ? 'Policy could not run.'
            : warnings.first,
      ),
      warnings: warnings,
      primaryTrainingIntentId: bp.primaryTrainingIntentId,
      sessionArchetypeId: bp.sessionArchetype.archetypeId,
    );
  }
}

class _ScoredPick {
  _ScoredPick({
    required this.exercise,
    required this.score,
    required this.reasons,
    required this.substitutedFrom,
  });

  final ExerciseKnowledge exercise;
  final double score;
  final List<ExerciseSelectionReason> reasons;
  final String? substitutedFrom;

  ExerciseSelection copyWithSequence({
    required int sequence,
    required ExerciseMovementRole role,
    required SessionStructuralComponent component,
  }) {
    return ExerciseSelection(
      sequence: sequence,
      exerciseId: exercise.id,
      exerciseLabel: exercise.meta.label,
      movementRole: role,
      structuralComponentSequence: component.sequence,
      structuralComponentType: component.componentType,
      reasons: reasons,
      movementPatternIds: exercise.movementPatternIds,
      matchedCapabilityIds: [
        ...exercise.primaryCapabilityIds,
        ...exercise.secondaryCapabilityIds,
      ],
      matchedTrainingIntentIds: exercise.supportsTrainingIntentIds,
      substitutedFromExerciseId: substitutedFrom,
    );
  }
}

ExerciseMovementRole _roleForComponent(SessionStructuralComponentType type) {
  return switch (type) {
    SessionStructuralComponentType.primaryDevelopment => ExerciseMovementRole.primary,
    SessionStructuralComponentType.secondaryDevelopment => ExerciseMovementRole.secondary,
    SessionStructuralComponentType.assessment => ExerciseMovementRole.assessment,
    SessionStructuralComponentType.recoveryOrCooldown => ExerciseMovementRole.recovery,
    SessionStructuralComponentType.transitionPractice => ExerciseMovementRole.transition,
    SessionStructuralComponentType.skillOrTechnique => ExerciseMovementRole.primary,
    _ => ExerciseMovementRole.accessory,
  };
}

extension on ExercisePolicyResult {
  ExercisePolicyResult copyWithWarnings(List<String> warnings) {
    return ExercisePolicyResult(
      status: status,
      blueprintId: blueprintId,
      ontologyVersion: ontologyVersion,
      selections: selections,
      executionPlan: executionPlan,
      activeConstraints: activeConstraints,
      explainability: explainability,
      warnings: warnings,
      primaryTrainingIntentId: primaryTrainingIntentId,
      sessionArchetypeId: sessionArchetypeId,
    );
  }
}
