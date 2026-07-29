import 'dart:io';

import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/gap_analysis_scenario_loader.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/planning/exercise_policy/deterministic_exercise_policy_engine.dart';
import 'package:cohort_platform/planning/exercise_policy/exercise_policy_validator.dart';
import 'package:cohort_platform/planning/exercise_policy/models/exercise_policy_models.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/models/planning_recommendation.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:cohort_platform/planning/session_blueprint/models/session_blueprint.dart';
import 'package:cohort_platform/planning/session_blueprint/models/session_blueprint_semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String knowledgeRoot;
  late InMemoryKnowledgeGraphReader knowledge;
  late PlanningEngineService planningEngine;
  late DeterministicSessionBlueprintGenerator blueprintGenerator;
  late DeterministicExercisePolicyEngine policyEngine;
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
    blueprintGenerator = DeterministicSessionBlueprintGenerator(
      knowledge: knowledge,
    );
    policyEngine = DeterministicExercisePolicyEngine(knowledge: knowledge);
  });

  Future<SessionBlueprint> blueprintFromScenario(String scenarioId) async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere((s) => s.id == scenarioId);
    final input = PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
    final rec = planningEngine.createRecommendation(input);
    return blueprintGenerator.generate(rec);
  }

  SessionBlueprint heavyLowerBlueprint() {
    final rec = _archetypeRecommendation(
      archetypeId: 'cohort.session_archetype.heavy_lower',
      intentId: 'cohort.training_intent.squat_strength',
      ontologyVersion: ontologyVersion,
      capabilityId: 'cohort.capability.absolute_strength',
      capabilityLabel: 'Absolute strength',
    );
    return blueprintGenerator.generate(rec);
  }

  test('commercial gym selects equipment-compatible movements', () async {
    final bp = await blueprintFromScenario('cohort.scenario.military_selection_a');
    final result = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: EquipmentPresets.commercialGym,
      ),
    );
    expect(result.status, isNot(MovementSelectionStatus.invalidBlueprint));
    expect(result.selections, isNotEmpty);
    expect(result.primaryTrainingIntentId, bp.primaryTrainingIntentId);
    ExercisePolicyContract.assertSemanticPlanOnly(result.executionPlan);
  });

  test('home gym prefers limited-equipment options', () async {
    final bp = await blueprintFromScenario('cohort.scenario.general_fat_loss_a');
    final result = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.home',
        availableEquipmentIds: EquipmentPresets.homeGym,
      ),
    );
    expect(result.selections, isNotEmpty);
    for (final sel in result.selections) {
      final ex = knowledge.exerciseById(sel.exerciseId)!;
      expect(
        ex.requiredEquipmentIds.every(EquipmentPresets.homeGym.contains),
        isTrue,
      );
    }
  });

  test('hotel gym avoids barbell-only selections', () {
    final bp = heavyLowerBlueprint();
    final result = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.hotel_gym',
        availableEquipmentIds: EquipmentPresets.hotelGym,
        isTraveling: true,
      ),
    );
    expect(result.selections, isNotEmpty);
    expect(
      result.selections.any((s) => s.exerciseId.contains('back_squat')),
      isFalse,
    );
  });

  test('injured athlete avoids overhead-dominant picks', () {
    final bp = heavyLowerBlueprint();
    bp; // injury flags on request
    final result = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: EquipmentPresets.commercialGym,
        injuryFlags: const ['shoulder'],
      ),
    );
    expect(
      result.activeConstraints.any((c) => c.kind == MovementConstraintKind.injury),
      isTrue,
    );
    expect(
      result.selections.any((s) => s.exerciseId.contains('overhead')),
      isFalse,
    );
  });

  test('travel hotel room still produces selections', () async {
    final bp = await blueprintFromScenario('cohort.scenario.general_fat_loss_a');
    final result = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.hotel_room',
        availableEquipmentIds: EquipmentPresets.hotelRoom,
        isTraveling: true,
      ),
    );
    expect(result.selections, isNotEmpty);
  });

  test('limited equipment narrows selection count', () {
    final bp = heavyLowerBlueprint();
    final full = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: EquipmentPresets.commercialGym,
      ),
    );
    final limited = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.home',
        availableEquipmentIds: EquipmentPresets.homeGym,
      ),
    );
    expect(full.selections.length, greaterThanOrEqualTo(limited.selections.length));
  });

  test('movement diversity limits repeated patterns', () async {
    final bp = heavyLowerBlueprint();
    final result = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: EquipmentPresets.commercialGym,
        maxTotalSelections: 6,
      ),
    );
    if (result.selections.length >= 2) {
      final patterns = result.selections.expand((s) => s.movementPatternIds).toSet();
      expect(patterns.length, greaterThan(1));
    }
  });

  test('deterministic policy output across repeated runs', () async {
    final bp = await blueprintFromScenario('cohort.scenario.military_selection_a');
    final request = ExercisePolicyRequest(
      blueprint: bp,
      environmentId: 'cohort.environment.commercial_gym',
      availableEquipmentIds: EquipmentPresets.commercialGym,
    );
    final a = policyEngine.evaluate(request);
    final b = policyEngine.evaluate(request);
    expect(
      a.selections.map((s) => s.exerciseId),
      b.selections.map((s) => s.exerciseId),
    );
  });

  test('integration pipeline scenario to validated policy result', () async {
    final bp = await blueprintFromScenario('cohort.scenario.military_selection_a');
    final request = ExercisePolicyRequest(
      blueprint: bp,
      environmentId: 'cohort.environment.commercial_gym',
      availableEquipmentIds: EquipmentPresets.commercialGym,
    );
    final result = policyEngine.evaluate(request);
    final validation = const ExercisePolicyValidator().validateResult(
      request: request,
      result: result,
    );
    expect(result.sessionArchetypeId, bp.sessionArchetype.archetypeId);
    expect(validation.isValid, isTrue);
    for (final sel in result.selections) {
      expect(sel.reasons, isNotEmpty);
    }
  });

  test('invalid blueprint status rejected', () {
    final bp = _invalidStatusBlueprint(ontologyVersion);
    final result = policyEngine.evaluate(ExercisePolicyRequest(blueprint: bp));
    expect(result.status, MovementSelectionStatus.invalidBlueprint);
  });
}

class EquipmentPresets {
  static const commercialGym = [
    'cohort.equipment.barbell',
    'cohort.equipment.squat_rack',
    'cohort.equipment.dumbbell',
    'cohort.equipment.kettlebell',
    'cohort.equipment.bench',
    'cohort.equipment.pull_up_bar',
    'cohort.equipment.cable_machine',
    'cohort.equipment.rower',
    'cohort.equipment.sled',
    'cohort.equipment.bodyweight',
  ];

  static const homeGym = [
    'cohort.equipment.kettlebell',
    'cohort.equipment.dumbbell',
    'cohort.equipment.bodyweight',
    'cohort.equipment.pull_up_bar',
  ];

  static const hotelGym = [
    'cohort.equipment.dumbbell',
    'cohort.equipment.kettlebell',
    'cohort.equipment.cable_machine',
    'cohort.equipment.rower',
    'cohort.equipment.bodyweight',
  ];

  static const hotelRoom = [
    'cohort.equipment.bodyweight',
    'cohort.equipment.dumbbell',
  ];
}

PlanningRecommendation _archetypeRecommendation({
  required String archetypeId,
  required String intentId,
  required String ontologyVersion,
  required String capabilityId,
  required String capabilityLabel,
}) {
  return PlanningRecommendation(
    athleteId: 'athlete.test',
    goalId: 'cohort.goal.general_fat_loss',
    ontologyVersion: ontologyVersion,
    generatedAt: DateTime.utc(2026, 7, 29, 12),
    status: PlanningRecommendationStatus.complete,
    capabilityPriorities: [
      PlanningCapabilityPriority(
        capabilityId: capabilityId,
        capabilityLabel: capabilityLabel,
        priorityScore: 0.9,
        rationale: 'Test',
      ),
    ],
    trainingIntentRecommendations: [
      PlanningIntentPriority(
        trainingIntentId: intentId,
        trainingIntentLabel: intentId.split('.').last,
        priorityScore: 0.9,
        suitability: 0.9,
        rationale: 'Test',
        capabilityId: capabilityId,
      ),
    ],
    selectedProgrammePhase: const PlanningPhaseSelection(
      phaseId: 'cohort.programme_phase.general_preparation',
      label: 'GPP',
      inferred: true,
    ),
    recommendedTrainingBlock: const PlanningBlockSelection(
      blockId: 'cohort.training_block.hypertrophy_lower',
      label: 'Hypertrophy lower',
      inferred: true,
    ),
    selectedWeekType: const PlanningWeekTypeSelection(
      weekTypeId: 'cohort.week_type.accumulation',
      label: 'Accumulation',
      inferred: true,
    ),
    recommendedSessionArchetype: PlanningArchetypeSelection(
      archetypeId: archetypeId,
      label: archetypeId.split('.').last,
      planningRelevanceScore: 0.9,
      primaryTrainingIntentId: intentId,
    ),
    confidence: 0.8,
    adaptationRationale: const ['Test'],
    explainability: const PlanningExplainability(
      factors: [],
      narrativeSummary: 'Test',
    ),
  );
}

SessionBlueprint _invalidStatusBlueprint(String ontologyVersion) {
  return SessionBlueprint(
    blueprintId: 'cohort.session_blueprint.invalid',
    athleteId: 'athlete.test',
    sourceRecommendation: SessionBlueprintSourceReference(
      athleteId: 'athlete.test',
      goalId: 'cohort.goal.general_fat_loss',
      recommendationGeneratedAt: DateTime.utc(2026, 7, 29),
      ontologyVersion: ontologyVersion,
    ),
    ontologyVersion: ontologyVersion,
    generatedAt: DateTime.utc(2026, 7, 29),
    status: SessionBlueprintStatus.invalidRecommendation,
    objective: const SessionObjective(summary: 'Invalid'),
    desiredAdaptations: const [],
    sessionArchetype: const SessionArchetypeReference(
      archetypeId: 'cohort.session_archetype.heavy_lower',
      label: 'Heavy lower',
      primaryTrainingIntentId: 'cohort.training_intent.squat_strength',
    ),
    primaryTrainingIntentId: 'cohort.training_intent.squat_strength',
    primaryTrainingIntentLabel: 'Squat strength',
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
    explainability: const SessionBlueprintExplainability(
      factors: [],
      narrativeSummary: 'Invalid',
    ),
  );
}

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  while (true) {
    final manifest = File('${dir.path}/knowledge/manifest.yaml');
    if (manifest.existsSync()) return '${dir.path}/knowledge';
    if (dir.parent.path == dir.path) {
      fail('Could not locate knowledge/manifest.yaml');
    }
    dir = dir.parent;
  }
}
