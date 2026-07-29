import 'dart:io';

import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/gap_analysis_scenario_loader.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/models/planning_recommendation.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:cohort_platform/planning/session_blueprint/models/session_blueprint.dart';
import 'package:cohort_platform/planning/session_blueprint/models/session_blueprint_semantics.dart';
import 'package:cohort_platform/planning/session_blueprint/session_blueprint_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String knowledgeRoot;
  late InMemoryKnowledgeGraphReader knowledge;
  late PlanningEngineService planningEngine;
  late DeterministicSessionBlueprintGenerator generator;
  late String ontologyVersion;

  setUpAll(() async {
    knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    ontologyVersion = bundle.ontologyVersion;
    knowledge = InMemoryKnowledgeGraphReader(bundle);
    planningEngine = PlanningEngineService(
      knowledge: knowledge,
      gapAnalysis: CapabilityGapAnalysisService(knowledge),
      intentResolution: TrainingIntentFromGapsService(knowledge),
    );
    generator = DeterministicSessionBlueprintGenerator(knowledge: knowledge);
  });

  Future<PlanningInput> scenarioInput(String scenarioId) async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere((s) => s.id == scenarioId);
    return PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
  }

  Future<PlanningRecommendation> recommendationFromScenario(
    String scenarioId,
  ) async {
    final input = await scenarioInput(scenarioId);
    return planningEngine.createRecommendation(input);
  }

  test('HYROX scenario integration can yield tempo-oriented blueprint', () async {
    final rec = await recommendationFromScenario('cohort.scenario.hyrox_athlete_a');
    final bp = generator.generate(rec);
    expect(bp.status, isNot(SessionBlueprintStatus.invalidRecommendation));
    expect(
      bp.sessionArchetype.archetypeId,
      rec.recommendedSessionArchetype?.archetypeId,
    );
    if (bp.sessionArchetype.archetypeId ==
        'cohort.session_archetype.tempo_run') {
      expect(bp.semanticIntensity.domainEmphasis, SemanticDomainEmphasis.threshold);
    }
    SessionBlueprintContract.assertNoPrescriptionContent(bp);
  });

  test('military scenario supports carry-oriented blueprint', () async {
    final rec = await recommendationFromScenario(
      'cohort.scenario.military_selection_a',
    );
    final bp = generator.generate(rec);
    expect(bp.status, isNot(SessionBlueprintStatus.invalidRecommendation));
    expect(
      bp.desiredAdaptations.map((a) => a.capabilityId),
      anyElement(contains('loaded_carry')),
    );
    SessionBlueprintContract.assertNoPrescriptionContent(bp);
  });

  test('general fat loss produces complete or partial blueprint', () async {
    final rec = await recommendationFromScenario(
      'cohort.scenario.general_fat_loss_a',
    );
    final bp = generator.generate(rec);
    expect(
      bp.status,
      anyOf(
        SessionBlueprintStatus.complete,
        SessionBlueprintStatus.partial,
      ),
    );
    expect(bp.objective.summary, isNotEmpty);
    SessionBlueprintContract.assertNoPrescriptionContent(bp);
  });

  test('long easy run archetype profile semantics', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.long_easy_run',
      intentId: 'cohort.training_intent.aerobic_base',
      ontologyVersion: ontologyVersion,
      weekTypeId: 'cohort.week_type.accumulation',
    );
    final bp = generator.generate(rec);
    expect(bp.semanticIntensity.level, SemanticIntensityLevel.low);
    expect(
      bp.semanticVolume.level.index,
      greaterThanOrEqualTo(SemanticVolumeLevel.high.index),
    );
    expect(bp.structuralComponents, isNotEmpty);
  });

  test('heavy lower archetype profile semantics', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.heavy_lower',
      intentId: 'cohort.training_intent.squat_strength',
      ontologyVersion: ontologyVersion,
      weekTypeId: 'cohort.week_type.accumulation',
    );
    final bp = generator.generate(rec);
    expect(bp.semanticIntensity.level, SemanticIntensityLevel.high);
    expect(
      bp.structuralComponents.any(
        (c) => c.componentType == SessionStructuralComponentType.primaryDevelopment,
      ),
      isTrue,
    );
  });

  test('mixed engine archetype profile semantics', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.mixed_engine',
      intentId: 'cohort.training_intent.work_capacity',
      ontologyVersion: ontologyVersion,
    );
    final bp = generator.generate(rec);
    expect(bp.semanticDensity.level, SemanticDensityLevel.variable);
    expect(bp.structuralComponents.length, greaterThanOrEqualTo(3));
  });

  test('recovery week reduces intensity and volume semantics', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.tempo_run',
      intentId: 'cohort.training_intent.threshold_development',
      ontologyVersion: ontologyVersion,
      weekTypeId: 'cohort.week_type.recovery',
    );
    final bp = generator.generate(rec);
    expect(
      bp.semanticIntensity.level.index,
      lessThan(SemanticIntensityLevel.moderatelyHigh.index),
    );
    expect(
      bp.structuralComponents.any(
        (c) => c.componentType == SessionStructuralComponentType.recoveryOrCooldown,
      ),
      isTrue,
    );
  });

  test('deload week strips optional high-fatigue components', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.mixed_engine',
      intentId: 'cohort.training_intent.work_capacity',
      ontologyVersion: ontologyVersion,
      weekTypeId: 'cohort.week_type.deload',
    );
    final bp = generator.generate(rec);
    expect(
      bp.structuralComponents.where(
        (c) =>
            c.optionality == SessionComponentOptionality.optional &&
            c.fatigueContribution == SessionFatigueContribution.high,
      ),
      isEmpty,
    );
  });

  test('assessment week adds assessment component and tag', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.technique_session',
      intentId: 'cohort.training_intent.assessment',
      ontologyVersion: ontologyVersion,
      weekTypeId: 'cohort.week_type.assessment',
    );
    final bp = generator.generate(rec);
    expect(
      bp.structuralComponents.any(
        (c) => c.componentType == SessionStructuralComponentType.assessment,
      ),
      isTrue,
    );
    expect(
      bp.substitutionPolicyTags,
      contains(SessionSubstitutionPolicyTag.assessmentIntegrityRequired),
    );
  });

  test('poor recovery context modifies density and fatigueReduced tag', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.tempo_run',
      intentId: 'cohort.training_intent.threshold_development',
      ontologyVersion: ontologyVersion,
    );
    final bp = generator.generate(
      rec,
      context: const SessionBlueprintGenerationContext(
        recoverySummary: PlanningRecoverySummary(
          level: PlanningRecoveryLevel.poor,
        ),
      ),
    );
    expect(
      bp.substitutionPolicyTags,
      contains(SessionSubstitutionPolicyTag.fatigueReduced),
    );
    expect(
      bp.explainability.factors.any((f) => f.code == 'recovery_semantic_cap'),
      isTrue,
    );
  });

  test('injury constraint propagates policy tags without substitution', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.heavy_upper',
      intentId: 'cohort.training_intent.push_strength',
      ontologyVersion: ontologyVersion,
      constraints: const [
        PlanningConstraint(
          kind: PlanningConstraintKind.injury,
          code: 'injury_flag',
          description: 'shoulder irritation',
        ),
      ],
    );
    final bp = generator.generate(rec);
    expect(
      bp.substitutionPolicyTags,
      contains(SessionSubstitutionPolicyTag.lowImpactRequired),
    );
    expect(
      bp.substitutionPolicyTags,
      contains(SessionSubstitutionPolicyTag.noOverheadLoading),
    );
    expect(bp.explainability.narrativeSummary.toLowerCase(), isNot(contains('substitute')));
  });

  test('primary intent and archetype preserved from recommendation', () async {
    final rec = await recommendationFromScenario('cohort.scenario.hyrox_athlete_a');
    final archetypeId = rec.recommendedSessionArchetype!.archetypeId;
    final bp = generator.generate(rec);
    expect(bp.sessionArchetype.archetypeId, archetypeId);
    expect(
      bp.explainability.factors.any((f) => f.code == 'archetype_preserved'),
      isTrue,
    );
  });

  test('supporting intents limited and sorted deterministically', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.mixed_engine',
      intentId: 'cohort.training_intent.work_capacity',
      ontologyVersion: ontologyVersion,
      extraIntents: const [
        PlanningIntentPriority(
          trainingIntentId: 'cohort.training_intent.strength_endurance',
          trainingIntentLabel: 'Strength endurance',
          priorityScore: 0.7,
          suitability: 0.8,
          rationale: 'support',
          capabilityId: 'cohort.capability.strength_endurance',
        ),
        PlanningIntentPriority(
          trainingIntentId: 'cohort.training_intent.cruise_intervals',
          trainingIntentLabel: 'Cruise intervals',
          priorityScore: 0.65,
          suitability: 0.75,
          rationale: 'support',
          capabilityId: 'cohort.capability.threshold',
        ),
        PlanningIntentPriority(
          trainingIntentId: 'cohort.training_intent.race_preparation',
          trainingIntentLabel: 'Race prep',
          priorityScore: 0.9,
          suitability: 0.5,
          rationale: 'support',
          capabilityId: 'cohort.capability.pacing',
        ),
      ],
    );
    final bp = generator.generate(rec);
    expect(bp.supportingTrainingIntentIds.length, lessThanOrEqualTo(2));
    final again = generator.generate(rec);
    expect(bp.supportingTrainingIntentIds, again.supportingTrainingIntentIds);
  });

  test('invalid archetype intent pairing returns invalidRecommendation', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.heavy_lower',
      intentId: 'cohort.training_intent.threshold_development',
      ontologyVersion: ontologyVersion,
    );
    final bp = generator.generate(rec);
    expect(bp.status, SessionBlueprintStatus.invalidRecommendation);
  });

  test('infeasible planning recommendation yields infeasible blueprint', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.recovery_session',
      intentId: 'cohort.training_intent.recovery',
      ontologyVersion: ontologyVersion,
      status: PlanningRecommendationStatus.infeasible,
    );
    final bp = generator.generate(rec);
    expect(bp.status, SessionBlueprintStatus.infeasible);
  });

  test('deterministic blueprint across repeated runs', () async {
    final rec = await recommendationFromScenario('cohort.scenario.hyrox_athlete_a');
    final a = generator.generate(rec);
    final b = generator.generate(rec);
    expect(a.blueprintId, b.blueprintId);
    expect(a.semanticIntensity, b.semanticIntensity);
    expect(a.structuralComponents.length, b.structuralComponents.length);
    expect(a.supportingTrainingIntentIds, b.supportingTrainingIntentIds);
  });

  test('explainability contains major layers', () async {
    final rec = await recommendationFromScenario('cohort.scenario.hyrox_athlete_a');
    final bp = generator.generate(rec);
    final layers = bp.explainability.factors.map((f) => f.layer).toSet();
    expect(layers, contains(SessionBlueprintExplainabilityLayer.planningRecommendation));
    expect(layers, contains(SessionBlueprintExplainabilityLayer.archetype));
    expect(layers, contains(SessionBlueprintExplainabilityLayer.intensity));
    expect(layers, contains(SessionBlueprintExplainabilityLayer.structure));
  });

  test('blueprint model excludes prescription fields by contract test', () async {
    final rec = await recommendationFromScenario('cohort.scenario.military_selection_a');
    final bp = generator.generate(rec);
    SessionBlueprintContract.assertNoPrescriptionContent(bp);
    expect(bp.runtimeType.toString(), 'SessionBlueprint');
  });

  test('ontology version mismatch rejected', () {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.tempo_run',
      intentId: 'cohort.training_intent.threshold_development',
      ontologyVersion: '9.9.9',
    );
    final bp = generator.generate(rec);
    expect(bp.status, SessionBlueprintStatus.invalidRecommendation);
  });

  test('integration planning engine to validated blueprint', () async {
    final rec = await recommendationFromScenario('cohort.scenario.hyrox_athlete_a');
    expect(rec.status, isNot(PlanningRecommendationStatus.invalidInput));
    final bp = generator.generate(rec);
    final validation = const SessionBlueprintValidator().validateBlueprint(bp);
    expect(validation.isValid, isTrue);
    SessionBlueprintContract.assertNoPrescriptionContent(bp);
  });
}

PlanningRecommendation _archetypeRecommendation({
  required String archetypeId,
  required String intentId,
  required String ontologyVersion,
  String? weekTypeId,
  PlanningRecommendationStatus status = PlanningRecommendationStatus.complete,
  List<PlanningIntentPriority> extraIntents = const [],
  List<PlanningConstraint> constraints = const [],
}) {
  final archetype = _labelForArchetype(archetypeId);
  final intentLabel = intentId.split('.').last.replaceAll('_', ' ');
  final capId = 'cohort.capability.work_capacity';
  return PlanningRecommendation(
    athleteId: 'athlete.test',
    goalId: 'cohort.goal.hyrox_sub_60',
    ontologyVersion: ontologyVersion,
    generatedAt: DateTime.utc(2026, 7, 29, 12),
    status: status,
    capabilityPriorities: [
      PlanningCapabilityPriority(
        capabilityId: capId,
        capabilityLabel: 'Work capacity',
        priorityScore: 0.8,
        rationale: 'Test priority',
      ),
    ],
    trainingIntentRecommendations: [
      PlanningIntentPriority(
        trainingIntentId: intentId,
        trainingIntentLabel: intentLabel,
        priorityScore: 0.9,
        suitability: 0.85,
        rationale: 'Primary intent',
        capabilityId: capId,
      ),
      ...extraIntents,
    ],
    selectedProgrammePhase: const PlanningPhaseSelection(
      phaseId: 'cohort.programme_phase.specific_preparation',
      label: 'Specific preparation',
      inferred: true,
    ),
    recommendedTrainingBlock: const PlanningBlockSelection(
      blockId: 'cohort.training_block.threshold_development',
      label: 'Threshold development',
      inferred: true,
    ),
    selectedWeekType: PlanningWeekTypeSelection(
      weekTypeId: weekTypeId ?? 'cohort.week_type.intensification',
      label: weekTypeId?.split('.').last ?? 'Intensification',
      inferred: true,
    ),
    recommendedSessionArchetype: PlanningArchetypeSelection(
      archetypeId: archetypeId,
      label: archetype,
      planningRelevanceScore: 0.9,
      primaryTrainingIntentId: intentId,
    ),
    constraints: constraints,
    confidence: 0.75,
    adaptationRationale: const ['Test adaptation rationale'],
    explainability: const PlanningExplainability(
      factors: [],
      narrativeSummary: 'Test',
    ),
  );
}

String _labelForArchetype(String id) => id.split('.').last;

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  while (true) {
    final manifest = File('${dir.path}/knowledge/manifest.yaml');
    if (manifest.existsSync()) {
      return '${dir.path}/knowledge';
    }
    if (dir.parent.path == dir.path) {
      fail('Could not locate knowledge/manifest.yaml from ${start.path}');
    }
    dir = dir.parent;
  }
}
