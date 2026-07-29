import 'package:cohort_platform/application/ports/capability_gap_analysis_reader.dart';
import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/application/ports/planning_engine_reader.dart';
import 'package:cohort_platform/application/ports/training_intent_resolution_reader.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/knowledge/models/knowledge_ontology_models.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_recommendation_models.dart';

import 'models/planning_input.dart';
import 'models/planning_recommendation.dart';
import 'planning_input_validator.dart';

/// Deterministic planning merge (ADR-023). Does not own gap/intent/semantics formulas.
class PlanningEngineService implements PlanningEngineReader {
  PlanningEngineService({
    required KnowledgeGraphReader knowledge,
    required CapabilityGapAnalysisReader gapAnalysis,
    required TrainingIntentResolutionReader intentResolution,
    PlanningInputValidator? validator,
  }) : _knowledge = knowledge,
       _gapAnalysis = gapAnalysis,
       _intentResolution = intentResolution,
       _validator = validator ?? const PlanningInputValidator();

  final KnowledgeGraphReader _knowledge;
  final CapabilityGapAnalysisReader _gapAnalysis;
  final TrainingIntentResolutionReader _intentResolution;
  final PlanningInputValidator _validator;

  static const _foundationPhaseId = 'cohort.programme_phase.foundation';
  static const _assessmentWeekId = 'cohort.week_type.assessment';
  static const _recoveryWeekId = 'cohort.week_type.recovery';
  static const _deloadWeekId = 'cohort.week_type.deload';
  static const _accumulationWeekId = 'cohort.week_type.accumulation';
  static const _intensificationWeekId = 'cohort.week_type.intensification';
  static const _realisationWeekId = 'cohort.week_type.realisation';
  static const _recoveryArchetypeId =
      'cohort.session_archetype.recovery_session';

  static const Map<String, String> _goalDefaultPhaseIds = {
    'cohort.goal.general_fat_loss':
        'cohort.programme_phase.general_preparation',
    'cohort.goal.hyrox_sub_60': 'cohort.programme_phase.specific_preparation',
    'cohort.goal.military_selection':
        'cohort.programme_phase.general_preparation',
  };

  @override
  PlanningRecommendation createRecommendation(PlanningInput input) {
    final validation = _validator.validate(
      input: input,
      bundleOntologyVersion: _knowledge.ontologyVersion,
      knowledge: _knowledge,
    );
    if (!validation.isOk) {
      return _invalidInputRecommendation(input, validation.messages);
    }

    final factors = <PlanningExplainabilityFactor>[];
    final warnings = <PlanningWarning>[];
    final constraints = _buildConstraints(input);

    factors.add(
      PlanningExplainabilityFactor(
        layer: PlanningExplainabilityLayer.goal,
        code: 'goal_selected',
        summary: 'Planning for goal ${input.goalContext.goalId}',
        rationale: input.goalContext.goalLabel ?? input.goalContext.goalId,
        sourceEntityIds: [input.goalContext.goalId],
      ),
    );

    factors.add(_evidenceFactor(input));

    final rankedGaps = _resolveGaps(input, factors);
    final capabilityPriorities = _mapCapabilityPriorities(rankedGaps);
    final intentRecs = _resolveIntents(input, rankedGaps, factors);
    final intentPriorities = _mapIntentPriorities(intentRecs);

    final unknownRatio = _unknownEvidenceRatio(input);
    final hasCriticalBlocker = rankedGaps.any(
      (g) =>
          g.blockerCapabilityIds.isNotEmpty &&
          g.severity == CapabilityGapSeverity.critical,
    );

    final phaseResult = _resolvePhase(
      input: input,
      rankedGaps: rankedGaps,
      unknownRatio: unknownRatio,
      hasCriticalBlocker: hasCriticalBlocker,
      factors: factors,
      warnings: warnings,
    );

    final blockResult = _resolveBlock(
      input: input,
      phaseId: phaseResult.phaseId,
      rankedGaps: rankedGaps,
      intentPriorities: intentPriorities,
      factors: factors,
      warnings: warnings,
    );

    final weekResult = _resolveWeekType(
      input: input,
      phaseId: phaseResult.phaseId,
      unknownRatio: unknownRatio,
      factors: factors,
    );

    _applyConflictPolicies(
      input: input,
      phaseResult: phaseResult,
      hasCriticalBlocker: hasCriticalBlocker,
      factors: factors,
      warnings: warnings,
    );

    final archetypeResult = _resolveArchetype(
      intentPriorities: intentPriorities,
      phaseId: phaseResult.phaseId,
      weekTypeId: weekResult.weekTypeId,
      recoveryLevel: input.recoverySummary?.level,
      factors: factors,
      warnings: warnings,
    );

    final status = _resolveStatus(
      input: input,
      unknownRatio: unknownRatio,
      phaseResult: phaseResult,
      blockResult: blockResult,
      archetypeResult: archetypeResult,
      intentPriorities: intentPriorities,
    );

    final confidence = _aggregateConfidence(
      capabilityPriorities: capabilityPriorities,
      intentPriorities: intentPriorities,
      unknownRatio: unknownRatio,
      status: status,
    );

    return PlanningRecommendation(
      athleteId: input.athleteId,
      goalId: input.goalContext.goalId,
      ontologyVersion: input.knowledgeOntologyVersion,
      generatedAt: input.asOf,
      status: status,
      capabilityPriorities: capabilityPriorities,
      trainingIntentRecommendations: intentPriorities,
      selectedProgrammePhase: PlanningPhaseSelection(
        phaseId: phaseResult.phaseId,
        label: phaseResult.label,
        inferred: phaseResult.inferred,
      ),
      recommendedTrainingBlock: blockResult,
      selectedWeekType: PlanningWeekTypeSelection(
        weekTypeId: weekResult.weekTypeId,
        label: weekResult.label,
        inferred: weekResult.inferred,
      ),
      recommendedSessionArchetype: archetypeResult,
      constraints: constraints,
      confidence: confidence,
      adaptationRationale: _adaptationRationale(
        capabilityPriorities: capabilityPriorities,
        intentPriorities: intentPriorities,
        phaseLabel: phaseResult.label,
        blockLabel: blockResult?.label,
      ),
      explainability: PlanningExplainability(
        factors: factors,
        narrativeSummary: _buildNarrative(factors),
      ),
      warnings: warnings,
    );
  }

  PlanningRecommendation _invalidInputRecommendation(
    PlanningInput input,
    List<String> messages,
  ) {
    return PlanningRecommendation(
      athleteId: input.athleteId,
      goalId: input.goalContext.goalId,
      ontologyVersion: input.knowledgeOntologyVersion,
      generatedAt: input.asOf,
      status: PlanningRecommendationStatus.invalidInput,
      capabilityPriorities: const [],
      trainingIntentRecommendations: const [],
      confidence: 0,
      adaptationRationale: const [],
      explainability: PlanningExplainability(
        factors: [
          PlanningExplainabilityFactor(
            layer: PlanningExplainabilityLayer.planningPolicy,
            code: 'invalid_input',
            summary: 'Planning input validation failed',
            rationale: messages.join('; '),
            severity: PlanningFactorSeverity.critical,
          ),
        ],
        narrativeSummary: messages.isEmpty
            ? 'Invalid input.'
            : 'Planning could not run: ${messages.first}',
      ),
      warnings: messages
          .map((m) => PlanningWarning(code: 'invalid_input', message: m))
          .toList(),
    );
  }

  List<PlanningConstraint> _buildConstraints(PlanningInput input) {
    final list = <PlanningConstraint>[];
    if (input.availableTimeMinutes != null) {
      list.add(
        PlanningConstraint(
          kind: PlanningConstraintKind.time,
          code: 'time_budget',
          description: '${input.availableTimeMinutes} minutes available',
        ),
      );
    }
    for (final flag in input.injuryFlags) {
      list.add(
        PlanningConstraint(
          kind: PlanningConstraintKind.injury,
          code: 'injury_flag',
          description: flag,
        ),
      );
    }
    if (input.travelContext?.isTraveling == true) {
      list.add(
        const PlanningConstraint(
          kind: PlanningConstraintKind.travel,
          code: 'travel',
          description: 'Travel context active',
        ),
      );
    }
    return list;
  }

  PlanningExplainabilityFactor _evidenceFactor(PlanningInput input) {
    final unknown = input.capabilityEvidence.items
        .where((i) => i.state == CapabilityEvidenceState.unknown)
        .length;
    final total = input.capabilityEvidence.items.length;
    return PlanningExplainabilityFactor(
      layer: PlanningExplainabilityLayer.evidence,
      code: 'evidence_profile',
      summary: total == 0
          ? 'No capability evidence items supplied'
          : '$unknown of $total evidence items unknown',
      rationale: 'Evidence profile used for gap analysis adequacy.',
      confidence: total == 0 ? 0.35 : (1 - unknown / total).clamp(0, 1),
    );
  }

  List<CapabilityGap> _resolveGaps(
    PlanningInput input,
    List<PlanningExplainabilityFactor> factors,
  ) {
    final pre = input.precomputedCapabilityGaps;
    if (pre != null) {
      factors.add(
        const PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.capabilityGap,
          code: 'gaps_supplied',
          summary: 'Reused precomputed capability gaps',
          rationale: 'Ranked gaps supplied on input.',
          metadata: {'source': 'supplied'},
        ),
      );
      return pre.rankedGaps;
    }
    final gaps = _gapAnalysis.rankTrainingPriorities(
      goalId: input.goalContext.goalId,
      evidenceProfile: input.capabilityEvidence,
    );
    factors.add(
      PlanningExplainabilityFactor(
        layer: PlanningExplainabilityLayer.capabilityGap,
        code: 'gaps_computed',
        summary: 'Computed capability gaps from evidence',
        rationale: '${gaps.length} gaps ranked for goal.',
        metadata: const {'source': 'computed'},
      ),
    );
    return gaps;
  }

  List<TrainingIntentRecommendation> _resolveIntents(
    PlanningInput input,
    List<CapabilityGap> rankedGaps,
    List<PlanningExplainabilityFactor> factors,
  ) {
    final pre = input.precomputedTrainingIntents;
    if (pre != null) {
      factors.add(
        const PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.trainingIntent,
          code: 'intents_supplied',
          summary: 'Reused precomputed training intents',
          rationale: 'Intent recommendations supplied on input.',
          metadata: {'source': 'supplied'},
        ),
      );
      return pre.recommendations;
    }
    var recommendations = _intentResolution.resolveIntentsForGaps(
      rankedGaps: rankedGaps,
    );
    if (recommendations.isEmpty) {
      recommendations = _fallbackIntentsFromGoal(input.goalContext.goalId);
      factors.add(
        const PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.trainingIntent,
          code: 'intents_goal_fallback',
          summary: 'No gap-derived intents; used goal capability mappings',
          rationale: 'Goal-level mappings when no gaps were identified.',
          metadata: {'source': 'computed_goal_fallback'},
        ),
      );
    } else {
      factors.add(
        PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.trainingIntent,
          code: 'intents_computed',
          summary: 'Computed training intents from ranked gaps',
          rationale: '${recommendations.length} intent recommendations.',
          metadata: const {'source': 'computed'},
        ),
      );
    }
    return recommendations;
  }

  List<TrainingIntentRecommendation> _fallbackIntentsFromGoal(String goalId) {
    final mappings = _knowledge.intentsForGoal(goalId);
    final list = <TrainingIntentRecommendation>[];
    for (final mapping in mappings.take(4)) {
      final intent = _knowledge.trainingIntentById(mapping.trainingIntentId);
      if (intent == null) continue;
      list.add(
        TrainingIntentRecommendation(
          trainingIntentId: intent.id,
          trainingIntentLabel: intent.meta.label,
          capabilityId: mapping.capabilityId,
          capabilityLabel: mapping.capabilityId,
          priorityScore: mapping.suitability,
          suitability: mapping.suitability,
          progressionStage: mapping.progressionStage,
          rationale: mapping.rationale,
          mappingId: mapping.id,
          commonSessionArchetypeIds: intent.commonSessionArchetypeIds,
        ),
      );
    }
    return list;
  }

  List<PlanningCapabilityPriority> _mapCapabilityPriorities(
    List<CapabilityGap> gaps,
  ) {
    return gaps
        .map(
          (g) => PlanningCapabilityPriority(
            capabilityId: g.capabilityId,
            capabilityLabel: g.capabilityLabel,
            priorityScore: g.priorityScore,
            rationale: g.rationale,
            gapSeverity: g.severity.name,
          ),
        )
        .toList(growable: false);
  }

  List<PlanningIntentPriority> _mapIntentPriorities(
    List<TrainingIntentRecommendation> recs,
  ) {
    return recs
        .map(
          (r) => PlanningIntentPriority(
            trainingIntentId: r.trainingIntentId,
            trainingIntentLabel: r.trainingIntentLabel,
            priorityScore: r.priorityScore,
            suitability: r.suitability,
            rationale: r.rationale,
            capabilityId: r.capabilityId,
          ),
        )
        .toList(growable: false);
  }

  double _unknownEvidenceRatio(PlanningInput input) {
    final goal = _knowledge.goalRequirements(input.goalContext.goalId);
    if (goal == null) return 1;
    final required = goal.requiredCapabilityIds;
    if (required.isEmpty) return 0;
    var unknown = 0;
    for (final capId in required) {
      final item = input.capabilityEvidence.evidenceFor(capId);
      if (item == null || item.state == CapabilityEvidenceState.unknown) {
        unknown++;
      }
    }
    return unknown / required.length;
  }

  ({String phaseId, String label, bool inferred}) _resolvePhase({
    required PlanningInput input,
    required List<CapabilityGap> rankedGaps,
    required double unknownRatio,
    required bool hasCriticalBlocker,
    required List<PlanningExplainabilityFactor> factors,
    required List<PlanningWarning> warnings,
  }) {
    final override = input.policyOverrides?.forceProgrammePhaseId;
    if (override != null) {
      final phase = _knowledge.programmePhaseById(override)!;
      factors.add(
        _phaseFactor(phase.id, inferred: false, code: 'phase_forced'),
      );
      return (phaseId: phase.id, label: phase.meta.label, inferred: false);
    }

    if (input.activeProgrammePhaseId != null) {
      final phase = _knowledge.programmePhaseById(
        input.activeProgrammePhaseId!,
      )!;
      factors.add(
        _phaseFactor(phase.id, inferred: false, code: 'phase_explicit'),
      );
      return (phaseId: phase.id, label: phase.meta.label, inferred: false);
    }

    final path = _knowledge.progressionPath(pathId: input.progressionPathId);
    if (path != null && path.steps.isNotEmpty) {
      final index = _progressionStepIndex(
        path: path,
        unknownRatio: unknownRatio,
        gapCount: rankedGaps.length,
        hasCriticalBlocker: hasCriticalBlocker,
      );
      final step = path.steps[index.clamp(0, path.steps.length - 1)];
      final phase = _knowledge.programmePhaseById(step.phaseId)!;
      factors.add(
        _phaseFactor(
          phase.id,
          inferred: true,
          code: 'phase_from_progression',
          rationale: step.rationale,
        ),
      );
      return (phaseId: phase.id, label: phase.meta.label, inferred: true);
    }

    final defaultId =
        _goalDefaultPhaseIds[input.goalContext.goalId] ?? _foundationPhaseId;
    var phase = _knowledge.programmePhaseById(defaultId);
    if (phase == null ||
        ((unknownRatio >= 0.5 || hasCriticalBlocker) &&
            defaultId != _foundationPhaseId)) {
      phase = _knowledge.programmePhaseById(_foundationPhaseId)!;
      factors.add(
        _phaseFactor(
          phase.id,
          inferred: true,
          code: 'phase_foundation_fallback',
          rationale:
              'High unknown evidence or critical blockers favour foundation.',
        ),
      );
    } else {
      factors.add(
        _phaseFactor(phase.id, inferred: true, code: 'phase_goal_default'),
      );
    }
    return (phaseId: phase.id, label: phase.meta.label, inferred: true);
  }

  int _progressionStepIndex({
    required ProgrammeProgressionPathKnowledge path,
    required double unknownRatio,
    required int gapCount,
    required bool hasCriticalBlocker,
  }) {
    if (unknownRatio >= 0.5) return 0;
    if (hasCriticalBlocker) return 0;
    if (gapCount == 0) return path.steps.length > 3 ? 3 : path.steps.length - 1;
    if (gapCount >= 4) return 1;
    if (gapCount >= 2) return 2;
    return 1;
  }

  PlanningExplainabilityFactor _phaseFactor(
    String phaseId, {
    required bool inferred,
    required String code,
    String? rationale,
  }) {
    return PlanningExplainabilityFactor(
      layer: PlanningExplainabilityLayer.programmeSemantics,
      code: code,
      summary: inferred
          ? 'Inferred programme phase'
          : 'Explicit programme phase',
      rationale: rationale ?? phaseId,
      sourceEntityIds: [phaseId],
      metadata: {'inferred': inferred.toString()},
    );
  }

  PlanningBlockSelection? _resolveBlock({
    required PlanningInput input,
    required String phaseId,
    required List<CapabilityGap> rankedGaps,
    required List<PlanningIntentPriority> intentPriorities,
    required List<PlanningExplainabilityFactor> factors,
    required List<PlanningWarning> warnings,
  }) {
    final override = input.policyOverrides?.forceTrainingBlockId;
    if (override != null) {
      final block = _knowledge.trainingBlockById(override)!;
      if (!block.suitableProgrammePhaseIds.contains(phaseId)) {
        warnings.add(
          PlanningWarning(
            code: 'block_phase_incompatible',
            message:
                'Forced block ${block.id} is not listed for phase $phaseId',
          ),
        );
      }
      factors.add(
        PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.planningPolicy,
          code: 'block_forced',
          summary: 'Policy forced training block',
          rationale: block.id,
          sourceEntityIds: [block.id],
        ),
      );
      return PlanningBlockSelection(
        blockId: block.id,
        label: block.meta.label,
        inferred: false,
      );
    }

    if (input.activeTrainingBlockId != null) {
      final block = _knowledge.trainingBlockById(input.activeTrainingBlockId!)!;
      if (block.suitableProgrammePhaseIds.contains(phaseId)) {
        factors.add(
          PlanningExplainabilityFactor(
            layer: PlanningExplainabilityLayer.programmeSemantics,
            code: 'block_explicit',
            summary: 'Explicit active training block preserved',
            rationale: block.meta.label,
            sourceEntityIds: [block.id],
          ),
        );
        return PlanningBlockSelection(
          blockId: block.id,
          label: block.meta.label,
          inferred: false,
        );
      }
      warnings.add(
        PlanningWarning(
          code: 'block_replaced',
          message:
              'Active block ${block.id} incompatible with phase $phaseId; selecting recommended block.',
        ),
      );
    }

    final candidates = _knowledge.recommendedBlocks(phaseId);
    if (candidates.isEmpty) return null;

    final topIntentId = intentPriorities.isEmpty
        ? null
        : intentPriorities.first.trainingIntentId;

    double score(TrainingBlockKnowledge block) {
      var s = 0.0;
      for (final gap in rankedGaps) {
        if (block.primaryCapabilityIds.contains(gap.capabilityId)) {
          s += gap.priorityScore * 2;
        } else if (block.secondaryCapabilityIds.contains(gap.capabilityId)) {
          s += gap.priorityScore;
        }
      }
      if (topIntentId != null &&
          block.supportedTrainingIntentIds.contains(topIntentId)) {
        s += 0.5;
      }
      return s;
    }

    final sorted = [...candidates]
      ..sort((a, b) {
        final byScore = score(b).compareTo(score(a));
        if (byScore != 0) return byScore;
        return a.id.compareTo(b.id);
      });

    final best = sorted.first;
    final bestScore = score(best);
    factors.add(
      PlanningExplainabilityFactor(
        layer: PlanningExplainabilityLayer.programmeSemantics,
        code: 'block_scored',
        summary: 'Training block selected by gap/intent overlap score',
        rationale:
            'Score=${bestScore.toStringAsFixed(2)} (primary×2 + secondary×1 + intent bonus 0.5).',
        sourceEntityIds: [best.id],
        metadata: {'score': bestScore.toStringAsFixed(2)},
      ),
    );
    return PlanningBlockSelection(
      blockId: best.id,
      label: best.meta.label,
      inferred: true,
      selectionScore: bestScore,
    );
  }

  ({String weekTypeId, String label, bool inferred}) _resolveWeekType({
    required PlanningInput input,
    required String phaseId,
    required double unknownRatio,
    required List<PlanningExplainabilityFactor> factors,
  }) {
    final override = input.policyOverrides?.forceWeekTypeId;
    if (override != null) {
      final wt = _knowledge.weekTypeById(override)!;
      return _weekSelection(wt, false, factors, 'week_forced');
    }

    if (input.activeWeekTypeId != null) {
      final wt = _knowledge.weekTypeById(input.activeWeekTypeId!)!;
      if (wt.compatibleProgrammePhaseIds.contains(phaseId)) {
        return _weekSelection(wt, false, factors, 'week_explicit');
      }
    }

    final recovery =
        input.recoverySummary?.level ?? PlanningRecoveryLevel.unknown;
    if (recovery == PlanningRecoveryLevel.poor) {
      final wt =
          _knowledge.weekTypeById(_recoveryWeekId) ??
          _knowledge.weekTypeById(_deloadWeekId)!;
      factors.add(
        PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.planningPolicy,
          code: 'week_recovery_override',
          summary: 'Poor recovery favours recovery week type',
          rationale: wt.meta.label,
          sourceEntityIds: [wt.id],
          severity: PlanningFactorSeverity.notice,
        ),
      );
      return (weekTypeId: wt.id, label: wt.meta.label, inferred: true);
    }

    if (unknownRatio >= 0.5) {
      final wt = _knowledge.weekTypeById(_assessmentWeekId)!;
      return _weekSelection(wt, true, factors, 'week_assessment');
    }

    if (phaseId == _foundationPhaseId ||
        phaseId == 'cohort.programme_phase.general_preparation') {
      final wt = _knowledge.weekTypeById(_accumulationWeekId)!;
      return _weekSelection(wt, true, factors, 'week_accumulation');
    }

    if (phaseId == 'cohort.programme_phase.peak') {
      final wt = _knowledge.weekTypeById(_realisationWeekId)!;
      return _weekSelection(wt, true, factors, 'week_realisation');
    }

    if (phaseId == 'cohort.programme_phase.performance' ||
        phaseId == 'cohort.programme_phase.specific_preparation') {
      final wt = _knowledge.weekTypeById(_intensificationWeekId)!;
      return _weekSelection(
        wt,
        true,
        factors,
        'week_intensification',
      );
    }

    final compatible = _knowledge.weekTypesForPhase(phaseId);
    if (compatible.isNotEmpty) {
      return _weekSelection(
        compatible.first,
        true,
        factors,
        'week_phase_default',
      );
    }

    final wt = _knowledge.weekTypeById(_accumulationWeekId)!;
    return _weekSelection(wt, true, factors, 'week_fallback');
  }

  ({String weekTypeId, String label, bool inferred}) _weekSelection(
    WeekTypeKnowledge wt,
    bool inferred,
    List<PlanningExplainabilityFactor> factors,
    String code,
  ) {
    factors.add(
      PlanningExplainabilityFactor(
        layer: PlanningExplainabilityLayer.programmeSemantics,
        code: code,
        summary: 'Week type resolved',
        rationale: wt.meta.label,
        sourceEntityIds: [wt.id],
        metadata: {'inferred': inferred.toString()},
      ),
    );
    return (weekTypeId: wt.id, label: wt.meta.label, inferred: inferred);
  }

  void _applyConflictPolicies({
    required PlanningInput input,
    required ({String phaseId, String label, bool inferred}) phaseResult,
    required bool hasCriticalBlocker,
    required List<PlanningExplainabilityFactor> factors,
    required List<PlanningWarning> warnings,
  }) {
    if (hasCriticalBlocker &&
        phaseResult.phaseId == 'cohort.programme_phase.peak') {
      warnings.add(
        const PlanningWarning(
          code: 'blocker_phase_conflict',
          message:
              'Critical prerequisite blockers present while phase suggests peak emphasis.',
        ),
      );
      factors.add(
        const PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.planningPolicy,
          code: 'blocker_limits_peak',
          summary: 'Prerequisite blockers limit peak emphasis',
          rationale:
              'Critical gap blockers triggered policy notice for downstream intensity.',
          severity: PlanningFactorSeverity.warning,
        ),
      );
    }

    if (input.injuryFlags.isNotEmpty) {
      factors.add(
        PlanningExplainabilityFactor(
          layer: PlanningExplainabilityLayer.planningPolicy,
          code: 'injury_constraints',
          summary: 'Injury flags constrain exercise policy downstream',
          rationale: input.injuryFlags.join(', '),
          severity: PlanningFactorSeverity.notice,
        ),
      );
    }
  }

  PlanningArchetypeSelection? _resolveArchetype({
    required List<PlanningIntentPriority> intentPriorities,
    required String phaseId,
    required String weekTypeId,
    required PlanningRecoveryLevel? recoveryLevel,
    required List<PlanningExplainabilityFactor> factors,
    required List<PlanningWarning> warnings,
  }) {
    if (intentPriorities.isEmpty) {
      warnings.add(
        const PlanningWarning(
          code: 'no_intent_for_archetype',
          message: 'No training intents available to select session archetype.',
        ),
      );
      return null;
    }

    if (recoveryLevel == PlanningRecoveryLevel.poor) {
      final recoveryArch = _knowledge.sessionArchetypeById(
        _recoveryArchetypeId,
      );
      if (recoveryArch != null) {
        factors.add(
          PlanningExplainabilityFactor(
            layer: PlanningExplainabilityLayer.planningPolicy,
            code: 'archetype_recovery_override',
            summary: 'Recovery context favours recovery session archetype',
            rationale: recoveryArch.meta.label,
            sourceEntityIds: [recoveryArch.id],
          ),
        );
        return PlanningArchetypeSelection(
          archetypeId: recoveryArch.id,
          label: recoveryArch.meta.label,
          planningRelevanceScore: 1,
          primaryTrainingIntentId: intentPriorities.first.trainingIntentId,
        );
      }
    }

    final top = intentPriorities.first;
    final intent = _knowledge.trainingIntentById(top.trainingIntentId);
    final candidateIds = <String>{
      ...?intent?.commonSessionArchetypeIds,
      ..._knowledge.archetypesForIntent(top.trainingIntentId).map((a) => a.id),
    };

    if (candidateIds.isEmpty) {
      warnings.add(
        PlanningWarning(
          code: 'no_archetype',
          message:
              'No session archetype linked to intent ${top.trainingIntentId}',
        ),
      );
      return null;
    }

    final scored = <({SessionArchetypeKnowledge arch, double score})>[];
    for (final id in candidateIds) {
      final arch = _knowledge.sessionArchetypeById(id);
      if (arch == null) continue;
      final onIntentList =
          intent?.commonSessionArchetypeIds.contains(id) ?? false;
      final score = top.priorityScore * (onIntentList ? 1.0 : 0.85);
      scored.add((arch: arch, score: score));
    }

    if (scored.isEmpty) return null;

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.arch.id.compareTo(b.arch.id);
    });

    final pick = scored.first;
    factors.add(
      PlanningExplainabilityFactor(
        layer: PlanningExplainabilityLayer.programmeSemantics,
        code: 'archetype_selected',
        summary: 'Session archetype selected from intent linkage',
        rationale:
            'Relevance=${pick.score.toStringAsFixed(2)}; tie-break archetype id ascending.',
        sourceEntityIds: [pick.arch.id, top.trainingIntentId],
        metadata: {
          'planning_relevance': pick.score.toStringAsFixed(2),
          'week_type': weekTypeId,
          'phase': phaseId,
        },
      ),
    );

    return PlanningArchetypeSelection(
      archetypeId: pick.arch.id,
      label: pick.arch.meta.label,
      planningRelevanceScore: pick.score,
      primaryTrainingIntentId: top.trainingIntentId,
    );
  }

  PlanningRecommendationStatus _resolveStatus({
    required PlanningInput input,
    required double unknownRatio,
    required ({String phaseId, String label, bool inferred}) phaseResult,
    required PlanningBlockSelection? blockResult,
    required PlanningArchetypeSelection? archetypeResult,
    required List<PlanningIntentPriority> intentPriorities,
  }) {
    if (input.injuryFlags.isNotEmpty &&
        phaseResult.phaseId == 'cohort.programme_phase.competition') {
      return PlanningRecommendationStatus.infeasible;
    }

    if (unknownRatio >= 0.75 && intentPriorities.isEmpty) {
      return PlanningRecommendationStatus.insufficientEvidence;
    }

    if (archetypeResult == null || blockResult == null) {
      return PlanningRecommendationStatus.partial;
    }

    if (unknownRatio >= 0.5) {
      return PlanningRecommendationStatus.partial;
    }

    return PlanningRecommendationStatus.complete;
  }

  double _aggregateConfidence({
    required List<PlanningCapabilityPriority> capabilityPriorities,
    required List<PlanningIntentPriority> intentPriorities,
    required double unknownRatio,
    required PlanningRecommendationStatus status,
  }) {
    if (status == PlanningRecommendationStatus.invalidInput) return 0;
    if (status == PlanningRecommendationStatus.infeasible) return 0.2;
    var base = 0.55;
    if (intentPriorities.isNotEmpty) {
      base += 0.15;
      base += (intentPriorities.first.suitability * 0.1).clamp(0, 0.1);
    }
    if (capabilityPriorities.isNotEmpty) base += 0.1;
    base *= (1 - unknownRatio * 0.35);
    return base.clamp(0, 1);
  }

  List<String> _adaptationRationale({
    required List<PlanningCapabilityPriority> capabilityPriorities,
    required List<PlanningIntentPriority> intentPriorities,
    required String phaseLabel,
    required String? blockLabel,
  }) {
    final lines = <String>[];
    if (intentPriorities.isNotEmpty) {
      lines.add(
        'Emphasise ${intentPriorities.first.trainingIntentLabel} during $phaseLabel.',
      );
    }
    if (capabilityPriorities.isNotEmpty) {
      lines.add(
        'Priority capability: ${capabilityPriorities.first.capabilityLabel}.',
      );
    }
    if (blockLabel != null) {
      lines.add('Mesocycle block context: $blockLabel.');
    }
    return lines;
  }

  String _buildNarrative(List<PlanningExplainabilityFactor> factors) {
    final parts = <String>[];
    for (final layer in PlanningExplainabilityLayer.values) {
      final layerFactors = factors.where((f) => f.layer == layer).toList();
      if (layerFactors.isEmpty) continue;
      parts.add(layerFactors.map((f) => f.summary).join(' '));
    }
    if (parts.isEmpty) return 'Planning recommendation generated.';
    return parts.join(' ');
  }
}
