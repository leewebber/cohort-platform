import '../../knowledge/models/knowledge_ontology_models.dart';
import '../../application/ports/knowledge_graph_reader.dart';
import '../../application/ports/session_blueprint_generator.dart';
import '../models/planning_input.dart';
import '../models/planning_recommendation.dart';
import 'models/session_blueprint.dart';
import 'session_archetype_semantic_profiles.dart';
import 'session_blueprint_validator.dart';
import 'week_type_semantic_modifiers.dart';

/// Deterministic PlanningRecommendation → SessionBlueprint (ADR-027).
class DeterministicSessionBlueprintGenerator implements SessionBlueprintGenerator {
  DeterministicSessionBlueprintGenerator({
    required KnowledgeGraphReader knowledge,
    SessionBlueprintValidator? validator,
  }) : _knowledge = knowledge,
       _validator = validator ?? const SessionBlueprintValidator();

  final KnowledgeGraphReader _knowledge;
  final SessionBlueprintValidator _validator;

  static const _maxSupportingIntents = 2;

  @override
  SessionBlueprint generate(
    PlanningRecommendation recommendation, {
    SessionBlueprintGenerationContext context =
        const SessionBlueprintGenerationContext(),
  }) {
    final factors = <SessionBlueprintExplainabilityFactor>[];
    final warnings = <SessionBlueprintWarning>[];

    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.planningRecommendation,
        code: 'recommendation_received',
        summary: 'Blueprint derived from planning recommendation',
        rationale:
            'Status=${recommendation.status.name}; confidence=${recommendation.confidence.toStringAsFixed(2)}',
        sourceEntityIds: [recommendation.goalId],
        confidence: recommendation.confidence,
      ),
    );

    final recValidation = _validator.validateRecommendation(
      recommendation: recommendation,
      bundleOntologyVersion: _knowledge.ontologyVersion,
    );
    if (!recValidation.isValid) {
      return _invalidBlueprint(
        recommendation,
        recValidation.messages,
        factors,
      );
    }

    if (recommendation.status == PlanningRecommendationStatus.infeasible) {
      return _infeasibleBlueprint(recommendation, factors, warnings);
    }

    final archetypeSel = recommendation.recommendedSessionArchetype;
    if (archetypeSel == null) {
      warnings.add(
        const SessionBlueprintWarning(
          code: 'missing_archetype',
          message: 'Recommendation did not include a session archetype.',
        ),
      );
      return _partialShell(
        recommendation,
        context,
        factors,
        warnings,
        reason: 'missing_archetype',
      );
    }

    final archetypeRef = SessionArchetypeReference(
      archetypeId: archetypeSel.archetypeId,
      label: archetypeSel.label,
      primaryTrainingIntentId: archetypeSel.primaryTrainingIntentId,
    );

    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.archetype,
        code: 'archetype_preserved',
        summary: 'Session archetype preserved from recommendation',
        rationale: archetypeSel.label,
        sourceEntityIds: [archetypeSel.archetypeId],
      ),
    );

    final primaryIntentId = _resolvePrimaryIntent(recommendation, archetypeSel);
    final primaryIntent = _knowledge.trainingIntentById(primaryIntentId);
    if (primaryIntent == null) {
      return _invalidBlueprint(
        recommendation,
        ['Unknown primary training intent: $primaryIntentId'],
        factors,
      );
    }

    if (!_intentSupportsArchetype(primaryIntentId, archetypeSel.archetypeId)) {
      return _invalidBlueprint(
        recommendation,
        [
          'Primary intent $primaryIntentId is not compatible with archetype ${archetypeSel.archetypeId}',
        ],
        factors,
      );
    }

    final profile = SessionArchetypeProfileRegistry.profileFor(
      archetypeSel.archetypeId,
    );
    if (profile == null) {
      return _invalidBlueprint(
        recommendation,
        ['No semantic profile for archetype ${archetypeSel.archetypeId}'],
        factors,
      );
    }

    final supporting = _resolveSupportingIntents(
      recommendation: recommendation,
      primaryIntentId: primaryIntentId,
      archetypeId: archetypeSel.archetypeId,
      phaseId: recommendation.selectedProgrammePhase?.phaseId,
      blockId: recommendation.recommendedTrainingBlock?.blockId,
      weekTypeId: recommendation.selectedWeekType?.weekTypeId,
      factors: factors,
    );

    final adaptations = _buildDesiredAdaptations(
      recommendation,
      primaryIntentId,
      supporting,
      factors,
    );

    final weekAdj = WeekTypeSemanticModifierRegistry.adjustmentFor(
      recommendation.selectedWeekType?.weekTypeId,
    );

    var intensity = WeekTypeSemanticModifierRegistry.applyIntensity(
      profile.intensity,
      weekAdj,
    );
    var volume = WeekTypeSemanticModifierRegistry.applyVolume(
      profile.volume,
      weekAdj,
    );
    var density = WeekTypeSemanticModifierRegistry.applyDensity(
      profile.density,
      weekAdj,
    );

    final sessionConstraints = _propagateConstraints(
      recommendation: recommendation,
      context: context,
      factors: factors,
      warnings: warnings,
    );

    final tags = {...profile.baseSubstitutionTags};

    _applyRecoveryPolicy(
      context: context,
      recommendation: recommendation,
      intensity: intensity,
      volume: volume,
      density: density,
      tags: tags,
      factors: factors,
      onIntensity: (v) => intensity = v,
      onVolume: (v) => volume = v,
      onDensity: (v) => density = v,
    );

    _applyInjuryPolicy(
      recommendation: recommendation,
      tags: tags,
      factors: factors,
      warnings: warnings,
      archetypeId: archetypeSel.archetypeId,
      primaryIntentId: primaryIntentId,
    );

    if (weekAdj.addAssessmentIntegrityTag) {
      tags.add(SessionSubstitutionPolicyTag.assessmentIntegrityRequired);
    }

    var components = _buildComponents(
      profile: profile,
      adaptations: adaptations,
      primaryIntentId: primaryIntentId,
      supportingIntentIds: supporting.map((s) => s.id).toList(),
      weekAdj: weekAdj,
      factors: factors,
    );

    if (sessionConstraints.any((c) => c.kind == SessionConstraintKind.time)) {
      volume = SemanticVolumeTarget(
        level: volume.level.reduce(),
        descriptors: volume.descriptors,
        rationale: 'Time budget reduces semantic volume',
      );
      factors.add(
        const SessionBlueprintExplainabilityFactor(
          layer: SessionBlueprintExplainabilityLayer.constraintPolicy,
          code: 'time_volume_cap',
          summary: 'Available time reduced semantic volume',
          rationale: 'Planning time constraint propagated to blueprint.',
        ),
      );
    }

    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.intensity,
        code: 'intensity_resolved',
        summary: 'Semantic intensity ${intensity.level.name}',
        rationale: intensity.rationale ?? profile.intensity.level.name,
        sourceEntityIds: [archetypeSel.archetypeId],
      ),
    );
    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.volume,
        code: 'volume_resolved',
        summary: 'Semantic volume ${volume.level.name}',
        rationale: volume.rationale ?? volume.level.name,
      ),
    );
    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.density,
        code: 'density_resolved',
        summary: 'Semantic density ${density.level.name}',
        rationale: density.rationale ?? density.level.name,
      ),
    );

    final progression = _buildProgressionContext(recommendation, weekAdj, profile);

    final leadingCap = recommendation.capabilityPriorities.isNotEmpty
        ? recommendation.capabilityPriorities.first
        : null;
    final objective = _buildObjective(
      leadingCapLabel: leadingCap?.capabilityLabel,
      leadingCapId: leadingCap?.capabilityId,
      primaryIntentLabel: primaryIntent.meta.label,
      primaryIntentId: primaryIntentId,
      archetypeLabel: archetypeSel.label,
      phaseLabel: recommendation.selectedProgrammePhase?.label,
      blockLabel: recommendation.recommendedTrainingBlock?.label,
      weekLabel: recommendation.selectedWeekType?.label,
      constraints: sessionConstraints,
    );

    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.sessionObjective,
        code: 'objective_generated',
        summary: 'Session objective composed from recommendation context',
        rationale: objective.summary,
        sourceEntityIds: [
          if (leadingCap != null) leadingCap.capabilityId,
          primaryIntentId,
          archetypeSel.archetypeId,
        ],
      ),
    );

    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.substitutionPolicy,
        code: 'substitution_tags',
        summary: '${tags.length} substitution policy tags attached',
        rationale: tags.map((t) => t.name).join(', '),
      ),
    );

    var status = SessionBlueprintStatus.complete;
    if (recommendation.status == PlanningRecommendationStatus.partial ||
        recommendation.status == PlanningRecommendationStatus.insufficientEvidence ||
        supporting.length < recommendation.trainingIntentRecommendations.length - 1) {
      status = SessionBlueprintStatus.partial;
    }
    if (components.isEmpty) {
      status = SessionBlueprintStatus.partial;
      warnings.add(
        const SessionBlueprintWarning(
          code: 'structure_partial',
          message: 'Structural components could not be fully resolved.',
        ),
      );
    }

    if (warnings.any((w) => w.code == 'injury_archetype_tension')) {
      status = SessionBlueprintStatus.partial;
    }

    final source = SessionBlueprintSourceReference(
      athleteId: recommendation.athleteId,
      goalId: recommendation.goalId,
      recommendationGeneratedAt: recommendation.generatedAt,
      ontologyVersion: recommendation.ontologyVersion,
    );

    final sortedTags = tags.toList()..sort((a, b) => a.name.compareTo(b.name));

    final blueprint = SessionBlueprint(
      blueprintId: computeSessionBlueprintId(source),
      athleteId: recommendation.athleteId,
      sourceRecommendation: source,
      ontologyVersion: recommendation.ontologyVersion,
      generatedAt: recommendation.generatedAt,
      status: status,
      objective: objective,
      desiredAdaptations: adaptations,
      sessionArchetype: archetypeRef,
      primaryTrainingIntentId: primaryIntentId,
      primaryTrainingIntentLabel: primaryIntent.meta.label,
      supportingTrainingIntentIds: supporting.map((s) => s.id).toList(),
      supportingTrainingIntentLabels:
          supporting.map((s) => s.meta.label).toList(),
      requiredCapabilities: _requiredCapabilities(adaptations),
      semanticIntensity: intensity,
      semanticVolume: volume,
      semanticDensity: density,
      structuralComponents: components,
      constraints: sessionConstraints,
      substitutionPolicyTags: sortedTags,
      progressionContext: progression,
      confidence: recommendation.confidence,
      explainability: SessionBlueprintExplainability(
        factors: factors,
        narrativeSummary: _narrative(
          objective: objective,
          intensity: intensity,
          volume: volume,
          archetypeLabel: archetypeSel.label,
          primaryIntentLabel: primaryIntent.meta.label,
          factors: factors,
        ),
      ),
      warnings: warnings,
    );

    final outValidation = _validator.validateBlueprint(blueprint);
    if (!outValidation.isValid) {
      warnings.addAll(
        outValidation.messages.map(
          (m) => SessionBlueprintWarning(code: 'validation_notice', message: m),
        ),
      );
    }

    return blueprint;
  }

  String _resolvePrimaryIntent(
    PlanningRecommendation recommendation,
    PlanningArchetypeSelection archetypeSel,
  ) {
    if (recommendation.trainingIntentRecommendations.isNotEmpty) {
      final top = recommendation.trainingIntentRecommendations.first;
      if (_intentSupportsArchetype(top.trainingIntentId, archetypeSel.archetypeId)) {
        return top.trainingIntentId;
      }
    }
    return archetypeSel.primaryTrainingIntentId;
  }

  bool _intentSupportsArchetype(String intentId, String archetypeId) {
    final archetype = _knowledge.sessionArchetypeById(archetypeId);
    if (archetype == null) return false;
    if (archetype.primaryTrainingIntentIds.contains(intentId)) {
      return true;
    }
    final linked = _knowledge.archetypesForIntent(intentId);
    return linked.any((a) => a.id == archetypeId);
  }

  List<TrainingIntentKnowledge> _resolveSupportingIntents({
    required PlanningRecommendation recommendation,
    required String primaryIntentId,
    required String archetypeId,
    required String? phaseId,
    required String? blockId,
    required String? weekTypeId,
    required List<SessionBlueprintExplainabilityFactor> factors,
  }) {
    final block = blockId != null ? _knowledge.trainingBlockById(blockId) : null;
    final candidates = recommendation.trainingIntentRecommendations
        .where((i) => i.trainingIntentId != primaryIntentId)
        .toList()
      ..sort((a, b) {
        final byScore = b.priorityScore.compareTo(a.priorityScore);
        if (byScore != 0) return byScore;
        final bySuit = b.suitability.compareTo(a.suitability);
        if (bySuit != 0) return bySuit;
        return a.trainingIntentId.compareTo(b.trainingIntentId);
      });

    final selected = <TrainingIntentKnowledge>[];
    for (final c in candidates) {
      if (selected.length >= _maxSupportingIntents) break;
      if (!_intentSupportsArchetype(c.trainingIntentId, archetypeId)) {
        continue;
      }
      if (block != null &&
          block.supportedTrainingIntentIds.isNotEmpty &&
          !block.supportedTrainingIntentIds.contains(c.trainingIntentId)) {
        continue;
      }
      final intent = _knowledge.trainingIntentById(c.trainingIntentId);
      if (intent != null) {
        selected.add(intent);
      }
    }

    if (selected.isNotEmpty) {
      factors.add(
        SessionBlueprintExplainabilityFactor(
          layer: SessionBlueprintExplainabilityLayer.desiredAdaptation,
          code: 'supporting_intents',
          summary: '${selected.length} supporting intents attached',
          rationale: selected.map((s) => s.meta.label).join('; '),
          sourceEntityIds: selected.map((s) => s.id).toList(),
        ),
      );
    }
    return selected;
  }

  List<DesiredAdaptation> _buildDesiredAdaptations(
    PlanningRecommendation recommendation,
    String primaryIntentId,
    List<TrainingIntentKnowledge> supporting,
    List<SessionBlueprintExplainabilityFactor> factors,
  ) {
    final intentsByCap = <String, List<String>>{};
    intentsByCap[recommendation.trainingIntentRecommendations.firstOrNull?.capabilityId ?? ''] =
        [primaryIntentId];
    for (final s in supporting) {
      final cap = recommendation.trainingIntentRecommendations
          .where((r) => r.trainingIntentId == s.id)
          .map((r) => r.capabilityId)
          .firstOrNull;
      if (cap != null) {
        intentsByCap.putIfAbsent(cap, () => []).add(s.id);
      }
    }

    final list = <DesiredAdaptation>[];
    for (var i = 0; i < recommendation.capabilityPriorities.length; i++) {
      final cap = recommendation.capabilityPriorities[i];
      final role = i == 0
          ? DesiredAdaptationRole.primary
          : i == 1
          ? DesiredAdaptationRole.secondary
          : DesiredAdaptationRole.supporting;
      final intentIds = intentsByCap[cap.capabilityId] ?? const [];
      list.add(
        DesiredAdaptation(
          capabilityId: cap.capabilityId,
          capabilityLabel: cap.capabilityLabel,
          role: role,
          sourceTrainingIntentIds: intentIds.isEmpty && i == 0
              ? [primaryIntentId]
              : intentIds,
          importance: cap.priorityScore,
          confidence: recommendation.confidence,
          rationale: cap.rationale,
        ),
      );
      if (i >= 4) break;
    }

    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.desiredAdaptation,
        code: 'adaptations_mapped',
        summary: '${list.length} desired adaptations from planning priorities',
        rationale: 'No gap recomputation; mapped from recommendation.',
      ),
    );
    return list;
  }

  List<SessionCapabilityRequirement> _requiredCapabilities(
    List<DesiredAdaptation> adaptations,
  ) {
    return adaptations
        .map(
          (a) => SessionCapabilityRequirement(
            capabilityId: a.capabilityId,
            capabilityLabel: a.capabilityLabel,
            requirementKind: a.role.name,
          ),
        )
        .toList(growable: false);
  }

  List<SessionStructuralComponent> _buildComponents({
    required SessionArchetypeSemanticProfile profile,
    required List<DesiredAdaptation> adaptations,
    required String primaryIntentId,
    required List<String> supportingIntentIds,
    required WeekTypeSemanticAdjustment weekAdj,
    required List<SessionBlueprintExplainabilityFactor> factors,
  }) {
    final capIds = adaptations.map((a) => a.capabilityId).toList();
    final primaryCap = capIds.isNotEmpty ? capIds.first : null;
    final secondaryCap = capIds.length > 1 ? capIds[1] : null;

    var templates = [...profile.componentTemplates];
    if (weekAdj.stripOptionalHighFatigue) {
      templates = templates
          .where(
            (t) =>
                t.optionality != SessionComponentOptionality.optional ||
                t.fatigueContribution != SessionFatigueContribution.high,
          )
          .toList();
    }

    if (weekAdj.requireAssessmentComponent &&
        !templates.any(
          (t) => t.componentType == SessionStructuralComponentType.assessment,
        )) {
      templates = [
        ...templates,
        const SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.assessment,
          purpose: 'Structured assessment of priority capabilities',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.low,
          orderingConstraint: 'before_primary_or_integrated',
        ),
      ];
    }

    if (weekAdj.requireRecoveryComponent &&
        !templates.any(
          (t) =>
              t.componentType ==
              SessionStructuralComponentType.recoveryOrCooldown,
        )) {
      templates = [
        ...templates,
        const SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.recoveryOrCooldown,
          purpose: 'Recovery-oriented session closure',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.none,
        ),
      ];
    }

    final components = <SessionStructuralComponent>[];
    for (var i = 0; i < templates.length; i++) {
      final t = templates[i];
      var emphasis = t.relativeEmphasis;
      if (weekAdj.primaryEmphasisBoost &&
          t.componentType == SessionStructuralComponentType.primaryDevelopment) {
        emphasis = SessionComponentEmphasis.primary;
      }
      components.add(
        SessionStructuralComponent(
          sequence: i + 1,
          componentType: t.componentType,
          purpose: t.purpose,
          targetedCapabilityIds: switch (t.componentType) {
            SessionStructuralComponentType.primaryDevelopment => [
              if (primaryCap != null) primaryCap,
            ],
            SessionStructuralComponentType.secondaryDevelopment => [
              if (secondaryCap != null) secondaryCap,
            ],
            _ => capIds.take(2).toList(),
          },
          associatedIntentIds: switch (t.componentType) {
            SessionStructuralComponentType.primaryDevelopment => [
              primaryIntentId,
            ],
            SessionStructuralComponentType.secondaryDevelopment =>
              supportingIntentIds,
            _ => [primaryIntentId, ...supportingIntentIds],
          },
          relativeEmphasis: emphasis,
          optionality: t.optionality,
          fatigueContribution: t.fatigueContribution,
          orderingConstraint: t.orderingConstraint,
          rationale: t.purpose,
        ),
      );
    }

    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.structure,
        code: 'structure_built',
        summary: '${components.length} structural components ordered',
        rationale: 'Derived from archetype profile and week-type modifiers.',
      ),
    );
    return components;
  }

  List<SessionConstraint> _propagateConstraints({
    required PlanningRecommendation recommendation,
    required SessionBlueprintGenerationContext context,
    required List<SessionBlueprintExplainabilityFactor> factors,
    required List<SessionBlueprintWarning> warnings,
  }) {
    final list = <SessionConstraint>[];
    for (final c in recommendation.constraints) {
      final kind = switch (c.kind) {
        PlanningConstraintKind.injury => SessionConstraintKind.injury,
        PlanningConstraintKind.time => SessionConstraintKind.time,
        PlanningConstraintKind.travel => SessionConstraintKind.travel,
        PlanningConstraintKind.equipment => SessionConstraintKind.equipment,
        PlanningConstraintKind.environment => SessionConstraintKind.environment,
        PlanningConstraintKind.policy => SessionConstraintKind.policy,
      };
      list.add(
        SessionConstraint(
          kind: kind,
          code: c.code,
          description: c.description,
          semanticConsequence: _semanticConsequenceForPlanningConstraint(c),
        ),
      );
    }

    if (context.recoverySummary?.level == PlanningRecoveryLevel.poor) {
      list.add(
        const SessionConstraint(
          kind: SessionConstraintKind.recovery,
          code: 'poor_recovery',
          description: 'Poor recovery context',
          semanticConsequence:
              'Intensity capped; volume reduced; density softened; optional high-fatigue work removed.',
        ),
      );
    }

    if (context.equipmentContext != null &&
        context.equipmentContext!.availableEquipmentIds.isEmpty) {
      list.add(
        const SessionConstraint(
          kind: SessionConstraintKind.equipment,
          code: 'limited_equipment',
          description: 'No equipment ids supplied',
          semanticConsequence: 'Exercise policy should prefer limited-equipment options.',
        ),
      );
    }

    if (context.environmentContext?.environmentId != null) {
      list.add(
        SessionConstraint(
          kind: SessionConstraintKind.environment,
          code: 'environment',
          description: context.environmentContext!.environmentId!,
          semanticConsequence: 'Environment limits exercise selection downstream.',
        ),
      );
    }

    if (list.isNotEmpty) {
      factors.add(
        SessionBlueprintExplainabilityFactor(
          layer: SessionBlueprintExplainabilityLayer.constraintPolicy,
          code: 'constraints_propagated',
          summary: '${list.length} session constraints propagated',
          rationale: 'Translated from planning recommendation and context.',
        ),
      );
    }
    return list;
  }

  String? _semanticConsequenceForPlanningConstraint(PlanningConstraint c) {
    return switch (c.kind) {
      PlanningConstraintKind.injury =>
        'Preserve strategic intent where possible; apply injury policy tags; no exercise substitution in blueprint layer.',
      PlanningConstraintKind.time =>
        'Semantic volume should stay within available-time category.',
      PlanningConstraintKind.travel => 'Prefer travel-compatible exercise policy tags.',
      _ => 'Downstream exercise policy must honour planning constraint.',
    };
  }

  void _applyRecoveryPolicy({
    required SessionBlueprintGenerationContext context,
    required PlanningRecommendation recommendation,
    required SemanticIntensityTarget intensity,
    required SemanticVolumeTarget volume,
    required SemanticDensityTarget density,
    required Set<SessionSubstitutionPolicyTag> tags,
    required List<SessionBlueprintExplainabilityFactor> factors,
    required void Function(SemanticIntensityTarget) onIntensity,
    required void Function(SemanticVolumeTarget) onVolume,
    required void Function(SemanticDensityTarget) onDensity,
  }) {
    final poorRecovery =
        context.recoverySummary?.level == PlanningRecoveryLevel.poor ||
        recommendation.selectedWeekType?.weekTypeId.contains('recovery') ==
            true;
    if (!poorRecovery) return;

    onIntensity(
      SemanticIntensityTarget(
        level: intensity.level.cap(2),
        domainEmphasis: intensity.domainEmphasis,
        rationale: 'Recovery context caps semantic intensity',
      ),
    );
    onVolume(
      SemanticVolumeTarget(
        level: volume.level.reduce(),
        descriptors: volume.descriptors,
        rationale: 'Recovery context reduces semantic volume',
      ),
    );
    onDensity(
      SemanticDensityTarget(
        level: density.level.soften(),
        rationale: 'Recovery context softens work density',
      ),
    );
    tags.add(SessionSubstitutionPolicyTag.fatigueReduced);
    factors.add(
      const SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.constraintPolicy,
        code: 'recovery_semantic_cap',
        summary: 'Recovery context adjusted intensity, volume, and density',
        rationale: 'Poor recovery or recovery week policy applied.',
        severity: SessionBlueprintFactorSeverity.notice,
      ),
    );
  }

  void _applyInjuryPolicy({
    required PlanningRecommendation recommendation,
    required Set<SessionSubstitutionPolicyTag> tags,
    required List<SessionBlueprintExplainabilityFactor> factors,
    required List<SessionBlueprintWarning> warnings,
    required String archetypeId,
    required String primaryIntentId,
  }) {
    for (final flag in recommendation.constraints
        .where((c) => c.kind == PlanningConstraintKind.injury)) {
      tags.add(SessionSubstitutionPolicyTag.lowImpactRequired);
      final lower = flag.description.toLowerCase();
      if (lower.contains('shoulder') || lower.contains('overhead')) {
        tags.add(SessionSubstitutionPolicyTag.noOverheadLoading);
      }
      factors.add(
        SessionBlueprintExplainabilityFactor(
          layer: SessionBlueprintExplainabilityLayer.constraintPolicy,
          code: 'injury_policy_tags',
          summary: 'Injury constraint translated to policy tags',
          rationale: flag.description,
          severity: SessionBlueprintFactorSeverity.warning,
        ),
      );
    }

    if (recommendation.constraints.any((c) => c.kind == PlanningConstraintKind.travel)) {
      tags.add(SessionSubstitutionPolicyTag.travelCompatible);
    }

    if (recommendation.constraints.any((c) => c.kind == PlanningConstraintKind.equipment)) {
      tags.add(SessionSubstitutionPolicyTag.limitedEquipment);
    }

    final heavyArchetypes = {
      'cohort.session_archetype.heavy_lower',
      'cohort.session_archetype.heavy_upper',
      'cohort.session_archetype.carry_session',
    };
    if (heavyArchetypes.contains(archetypeId) &&
        recommendation.constraints.any((c) => c.kind == PlanningConstraintKind.injury)) {
      warnings.add(
        const SessionBlueprintWarning(
          code: 'injury_archetype_tension',
          message:
              'Injury flags present with a high-local-fatigue archetype; exercise policy must constrain loading.',
        ),
      );
    }
  }

  SessionProgressionContext _buildProgressionContext(
    PlanningRecommendation recommendation,
    WeekTypeSemanticAdjustment weekAdj,
    SessionArchetypeSemanticProfile profile,
  ) {
    final weekId = recommendation.selectedWeekType?.weekTypeId;
    final adaptation = recommendation.adaptationRationale.isNotEmpty
        ? recommendation.adaptationRationale.first
        : 'Semantic emphasis from planning recommendation';
    return SessionProgressionContext(
      programmePhaseId: recommendation.selectedProgrammePhase?.phaseId,
      programmePhaseLabel: recommendation.selectedProgrammePhase?.label,
      trainingBlockId: recommendation.recommendedTrainingBlock?.blockId,
      trainingBlockLabel: recommendation.recommendedTrainingBlock?.label,
      weekTypeId: weekId,
      weekTypeLabel: recommendation.selectedWeekType?.label,
      progressionEmphasis: weekAdj.progressionEmphasis,
      adaptationEmphasis: adaptation,
      expectedFatiguePosture: profile.expectedFatiguePosture,
    );
  }

  SessionObjective _buildObjective({
    required String? leadingCapLabel,
    required String? leadingCapId,
    required String primaryIntentLabel,
    required String primaryIntentId,
    required String archetypeLabel,
    required String? phaseLabel,
    required String? blockLabel,
    required String? weekLabel,
    required List<SessionConstraint> constraints,
  }) {
    final capPhrase = leadingCapLabel ?? 'priority capabilities';
    final weekPhrase = weekLabel != null ? ' during $weekLabel' : '';
    final phasePhrase = phaseLabel != null ? ' in $phaseLabel' : '';
    final blockPhrase = blockLabel != null ? ' within $blockLabel' : '';
    var summary =
        'Develop $capPhrase through a $archetypeLabel-oriented session emphasising $primaryIntentLabel$weekPhrase$phasePhrase$blockPhrase.';
    if (constraints.any((c) => c.code == 'poor_recovery')) {
      summary =
          '$summary Preserve accumulated fatigue with controlled semantic intensity and volume.';
    }
    return SessionObjective(
      summary: summary,
      focusCapabilityId: leadingCapId,
      focusIntentId: primaryIntentId,
    );
  }

  String _narrative({
    required SessionObjective objective,
    required SemanticIntensityTarget intensity,
    required SemanticVolumeTarget volume,
    required String archetypeLabel,
    required String primaryIntentLabel,
    required List<SessionBlueprintExplainabilityFactor> factors,
  }) {
    final recoveryNote = factors.any((f) => f.code == 'recovery_semantic_cap')
        ? ' Recovery constraints reduced density and optional secondary work.'
        : '';
    return 'This $archetypeLabel blueprint prioritises $primaryIntentLabel because it aligns with the leading planning emphasis. '
        'Semantic intensity is ${intensity.level.name} with ${volume.level.name} volume.${recoveryNote} '
        '${objective.summary}';
  }

  SessionBlueprint _invalidBlueprint(
    PlanningRecommendation recommendation,
    List<String> messages,
    List<SessionBlueprintExplainabilityFactor> factors,
  ) {
    factors.add(
      SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.planningRecommendation,
        code: 'invalid_recommendation',
        summary: 'Blueprint generation rejected recommendation',
        rationale: messages.join('; '),
        severity: SessionBlueprintFactorSeverity.critical,
      ),
    );
    final source = SessionBlueprintSourceReference(
      athleteId: recommendation.athleteId,
      goalId: recommendation.goalId,
      recommendationGeneratedAt: recommendation.generatedAt,
      ontologyVersion: recommendation.ontologyVersion,
    );
    return SessionBlueprint(
      blueprintId: computeSessionBlueprintId(source),
      athleteId: recommendation.athleteId,
      sourceRecommendation: source,
      ontologyVersion: recommendation.ontologyVersion,
      generatedAt: recommendation.generatedAt,
      status: SessionBlueprintStatus.invalidRecommendation,
      objective: const SessionObjective(summary: 'Blueprint could not be generated.'),
      desiredAdaptations: const [],
      sessionArchetype: SessionArchetypeReference(
        archetypeId: recommendation.recommendedSessionArchetype?.archetypeId ?? '',
        label: recommendation.recommendedSessionArchetype?.label ?? '',
        primaryTrainingIntentId:
            recommendation.recommendedSessionArchetype?.primaryTrainingIntentId ??
            '',
      ),
      primaryTrainingIntentId: '',
      primaryTrainingIntentLabel: '',
      requiredCapabilities: const [],
      semanticIntensity: const SemanticIntensityTarget(
        level: SemanticIntensityLevel.moderate,
      ),
      semanticVolume: const SemanticVolumeTarget(level: SemanticVolumeLevel.moderate),
      semanticDensity: const SemanticDensityTarget(level: SemanticDensityLevel.moderate),
      structuralComponents: const [],
      progressionContext: const SessionProgressionContext(
        progressionEmphasis: SessionProgressionEmphasis.general,
        adaptationEmphasis: 'n/a',
        expectedFatiguePosture: SemanticFatiguePosture.moderate,
      ),
      confidence: 0,
      explainability: SessionBlueprintExplainability(
        factors: factors,
        narrativeSummary: messages.isEmpty
            ? 'Invalid recommendation.'
            : 'Blueprint invalid: ${messages.first}',
      ),
      warnings: messages
          .map((m) => SessionBlueprintWarning(code: 'invalid_recommendation', message: m))
          .toList(),
    );
  }

  SessionBlueprint _infeasibleBlueprint(
    PlanningRecommendation recommendation,
    List<SessionBlueprintExplainabilityFactor> factors,
    List<SessionBlueprintWarning> warnings,
  ) {
    warnings.addAll(
      recommendation.warnings.map(
        (w) => SessionBlueprintWarning(code: w.code, message: w.message),
      ),
    );
    factors.add(
      const SessionBlueprintExplainabilityFactor(
        layer: SessionBlueprintExplainabilityLayer.planningRecommendation,
        code: 'recommendation_infeasible',
        summary: 'Planning recommendation marked infeasible',
        rationale: 'Blueprint reflects infeasible planning outcome without changing archetype.',
        severity: SessionBlueprintFactorSeverity.critical,
      ),
    );
    final source = SessionBlueprintSourceReference(
      athleteId: recommendation.athleteId,
      goalId: recommendation.goalId,
      recommendationGeneratedAt: recommendation.generatedAt,
      ontologyVersion: recommendation.ontologyVersion,
    );
    return SessionBlueprint(
      blueprintId: computeSessionBlueprintId(source),
      athleteId: recommendation.athleteId,
      sourceRecommendation: source,
      ontologyVersion: recommendation.ontologyVersion,
      generatedAt: recommendation.generatedAt,
      status: SessionBlueprintStatus.infeasible,
      objective: const SessionObjective(
        summary: 'Session blueprint cannot be safely represented under current hard constraints.',
      ),
      desiredAdaptations: const [],
      sessionArchetype: SessionArchetypeReference(
        archetypeId: recommendation.recommendedSessionArchetype?.archetypeId ?? '',
        label: recommendation.recommendedSessionArchetype?.label ?? '',
        primaryTrainingIntentId:
            recommendation.recommendedSessionArchetype?.primaryTrainingIntentId ??
            '',
      ),
      primaryTrainingIntentId:
          recommendation.recommendedSessionArchetype?.primaryTrainingIntentId ??
          '',
      primaryTrainingIntentLabel: '',
      requiredCapabilities: const [],
      semanticIntensity: const SemanticIntensityTarget(
        level: SemanticIntensityLevel.restorative,
      ),
      semanticVolume: const SemanticVolumeTarget(level: SemanticVolumeLevel.minimal),
      semanticDensity: const SemanticDensityTarget(level: SemanticDensityLevel.sparse),
      structuralComponents: const [],
      progressionContext: SessionProgressionContext(
        programmePhaseId: recommendation.selectedProgrammePhase?.phaseId,
        programmePhaseLabel: recommendation.selectedProgrammePhase?.label,
        progressionEmphasis: SessionProgressionEmphasis.general,
        adaptationEmphasis: 'Infeasible planning state',
        expectedFatiguePosture: SemanticFatiguePosture.restorative,
      ),
      confidence: recommendation.confidence,
      explainability: SessionBlueprintExplainability(
        factors: factors,
        narrativeSummary:
            'Planning recommendation is infeasible; no executable session blueprint is offered.',
      ),
      warnings: warnings,
    );
  }

  SessionBlueprint _partialShell(
    PlanningRecommendation recommendation,
    SessionBlueprintGenerationContext context,
    List<SessionBlueprintExplainabilityFactor> factors,
    List<SessionBlueprintWarning> warnings,
    {required String reason}
  ) {
    final source = SessionBlueprintSourceReference(
      athleteId: recommendation.athleteId,
      goalId: recommendation.goalId,
      recommendationGeneratedAt: recommendation.generatedAt,
      ontologyVersion: recommendation.ontologyVersion,
    );
    return SessionBlueprint(
      blueprintId: computeSessionBlueprintId(source),
      athleteId: recommendation.athleteId,
      sourceRecommendation: source,
      ontologyVersion: recommendation.ontologyVersion,
      generatedAt: recommendation.generatedAt,
      status: SessionBlueprintStatus.partial,
      objective: SessionObjective(summary: 'Partial blueprint ($reason).'),
      desiredAdaptations: const [],
      sessionArchetype: const SessionArchetypeReference(
        archetypeId: '',
        label: '',
        primaryTrainingIntentId: '',
      ),
      primaryTrainingIntentId: '',
      primaryTrainingIntentLabel: '',
      requiredCapabilities: const [],
      semanticIntensity: const SemanticIntensityTarget(
        level: SemanticIntensityLevel.moderate,
      ),
      semanticVolume: const SemanticVolumeTarget(level: SemanticVolumeLevel.moderate),
      semanticDensity: const SemanticDensityTarget(level: SemanticDensityLevel.moderate),
      structuralComponents: const [],
      progressionContext: const SessionProgressionContext(
        progressionEmphasis: SessionProgressionEmphasis.general,
        adaptationEmphasis: 'Partial',
        expectedFatiguePosture: SemanticFatiguePosture.moderate,
      ),
      confidence: recommendation.confidence,
      explainability: SessionBlueprintExplainability(
        factors: factors,
        narrativeSummary: 'Partial blueprint: $reason',
      ),
      warnings: warnings,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
