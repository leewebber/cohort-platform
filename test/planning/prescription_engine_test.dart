import 'dart:io';

import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/gap_analysis_scenario_loader.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/planning/exercise_policy/deterministic_exercise_policy_engine.dart';
import 'package:cohort_platform/planning/exercise_policy/models/exercise_policy_models.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/models/planning_recommendation.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/prescription/deterministic_prescription_engine.dart';
import 'package:cohort_platform/planning/prescription/models/prescription_models.dart';
import 'package:cohort_platform/planning/prescription/prescription_execution_plan_adapter.dart';
import 'package:cohort_platform/planning/prescription/prescription_templates.dart';
import 'package:cohort_platform/planning/prescription/prescription_validator.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:cohort_platform/planning/session_blueprint/models/session_blueprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryKnowledgeGraphReader knowledge;
  late DeterministicPrescriptionEngine prescriptionEngine;
  late DeterministicExercisePolicyEngine policyEngine;
  late DeterministicSessionBlueprintGenerator blueprintGenerator;
  late PlanningEngineService planningEngine;
  late String ontologyVersion;
  late String knowledgeRoot;

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
    prescriptionEngine = DeterministicPrescriptionEngine(knowledge: knowledge);
  });

  Future<({SessionBlueprint bp, SemanticSessionExecutionPlan plan})>
  fullPipeline(String scenarioId) async {
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
    final bp = blueprintGenerator.generate(rec);
    final policy = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: _commercialGym,
      ),
    );
    return (bp: bp, plan: policy.executionPlan);
  }

  PrescriptionResult prescribeHeavyLower({required String weekTypeId}) {
    final rec = _heavyLowerRec(ontologyVersion, weekTypeId: weekTypeId);
    final bp = blueprintGenerator.generate(rec);
    final plan = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: _commercialGym,
      ),
    ).executionPlan;
    return prescriptionEngine.prescribe(
      PrescriptionRequest(executionPlan: plan, blueprint: bp),
    );
  }

  for (final archetypeId in _archetypeIds) {
    test('template exists for $archetypeId', () {
      expect(PrescriptionTemplateLibrary.forArchetype(archetypeId), isNotNull);
    });
  }

  test('heavy lower yields strength prescriptions', () {
    final result = prescribeHeavyLower(
      weekTypeId: 'cohort.week_type.accumulation',
    );
    expect(result.status, isNot(PrescriptionStatus.invalidInput));
    expect(result.prescriptions, isNotEmpty);
    expect(result.prescriptions.first.sets, greaterThan(0));
  });

  test('deload week reduces sets vs intensification week', () {
    final deload = prescribeHeavyLower(weekTypeId: 'cohort.week_type.deload');
    final intens = prescribeHeavyLower(
      weekTypeId: 'cohort.week_type.intensification',
    );
    expect(
      deload.prescriptions.first.sets,
      lessThanOrEqualTo(intens.prescriptions.first.sets),
    );
  });

  test('poor recovery blueprint lowers RPE vs normal', () {
    final normal = prescribeHeavyLower(
      weekTypeId: 'cohort.week_type.accumulation',
    );
    final rec = _heavyLowerRec(ontologyVersion);
    final poorBp = blueprintGenerator.generate(
      rec,
      context: const SessionBlueprintGenerationContext(
        recoverySummary: PlanningRecoverySummary(
          level: PlanningRecoveryLevel.poor,
        ),
      ),
    );
    final plan = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: poorBp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: _commercialGym,
      ),
    ).executionPlan;
    final poor = prescriptionEngine.prescribe(
      PrescriptionRequest(executionPlan: plan, blueprint: poorBp),
    );
    expect(
      poor.prescriptions.first.rpeMax ?? 10,
      lessThanOrEqualTo(normal.prescriptions.first.rpeMax ?? 10),
    );
  });

  test('deterministic across repeated runs', () {
    final rec = _heavyLowerRec(ontologyVersion);
    final bp = blueprintGenerator.generate(rec);
    final plan = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: _commercialGym,
      ),
    ).executionPlan;
    final request = PrescriptionRequest(executionPlan: plan, blueprint: bp);
    final a = prescriptionEngine.prescribe(request);
    final b = prescriptionEngine.prescribe(request);
    expect(
      a.prescriptions.map((p) => '${p.exerciseId}:${p.sets}'),
      b.prescriptions.map((p) => '${p.exerciseId}:${p.sets}'),
    );
  });

  test('adapter produces executable SessionExecutionPlan', () {
    final result = prescribeHeavyLower(
      weekTypeId: 'cohort.week_type.accumulation',
    );
    final plan = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: blueprintGenerator.generate(_heavyLowerRec(ontologyVersion)),
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: _commercialGym,
      ),
    ).executionPlan;
    final m7 = const PrescriptionExecutionPlanAdapter().toExecutionPlan(
      result: result,
      semanticPlan: plan,
    );
    expect(m7.hasExecutableBlocks, isTrue);
  });

  test('validation preserves intent', () {
    final rec = _heavyLowerRec(ontologyVersion);
    final bp = blueprintGenerator.generate(rec);
    final plan = policyEngine.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        environmentId: 'cohort.environment.commercial_gym',
        availableEquipmentIds: _commercialGym,
      ),
    ).executionPlan;
    final request = PrescriptionRequest(executionPlan: plan, blueprint: bp);
    final result = prescriptionEngine.prescribe(request);
    final validation = const PrescriptionValidator().validateResult(
      request: request,
      result: result,
    );
    expect(result.primaryTrainingIntentId, bp.primaryTrainingIntentId);
    expect(validation.isValid, isTrue);
  });

  test('military scenario end-to-end prescription', () async {
    final pipe = await fullPipeline('cohort.scenario.military_selection_a');
    final result = prescriptionEngine.prescribe(
      PrescriptionRequest(executionPlan: pipe.plan, blueprint: pipe.bp),
    );
    expect(result.prescriptions, isNotEmpty);
    expect(result.explainability.factors, isNotEmpty);
  });
}

PlanningRecommendation _heavyLowerRec(
  String ontologyVersion, {
  String weekTypeId = 'cohort.week_type.accumulation',
}) {
  return PlanningRecommendation(
    athleteId: 'athlete.test',
    goalId: 'cohort.goal.general_fat_loss',
    ontologyVersion: ontologyVersion,
    generatedAt: DateTime.utc(2026, 7, 29),
    status: PlanningRecommendationStatus.complete,
    capabilityPriorities: const [
      PlanningCapabilityPriority(
        capabilityId: 'cohort.capability.absolute_strength',
        capabilityLabel: 'Absolute strength',
        priorityScore: 0.9,
        rationale: 'Test',
      ),
    ],
    trainingIntentRecommendations: const [
      PlanningIntentPriority(
        trainingIntentId: 'cohort.training_intent.squat_strength',
        trainingIntentLabel: 'Squat strength',
        priorityScore: 0.9,
        suitability: 0.9,
        rationale: 'Test',
        capabilityId: 'cohort.capability.absolute_strength',
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
    selectedWeekType: PlanningWeekTypeSelection(
      weekTypeId: weekTypeId,
      label: weekTypeId.split('.').last,
      inferred: true,
    ),
    recommendedSessionArchetype: const PlanningArchetypeSelection(
      archetypeId: 'cohort.session_archetype.heavy_lower',
      label: 'Heavy lower',
      planningRelevanceScore: 0.9,
      primaryTrainingIntentId: 'cohort.training_intent.squat_strength',
    ),
    confidence: 0.8,
    adaptationRationale: const ['Test'],
    explainability: const PlanningExplainability(
      factors: [],
      narrativeSummary: 'Test',
    ),
  );
}

const _commercialGym = [
  'cohort.equipment.barbell',
  'cohort.equipment.squat_rack',
  'cohort.equipment.dumbbell',
  'cohort.equipment.kettlebell',
  'cohort.equipment.bench',
  'cohort.equipment.bodyweight',
];

const _archetypeIds = [
  'cohort.session_archetype.heavy_lower',
  'cohort.session_archetype.heavy_upper',
  'cohort.session_archetype.tempo_run',
  'cohort.session_archetype.long_easy_run',
  'cohort.session_archetype.carry_session',
  'cohort.session_archetype.recovery_session',
  'cohort.session_archetype.mobility_flow',
  'cohort.session_archetype.technique_session',
  'cohort.session_archetype.mixed_engine',
];

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  while (true) {
    final manifest = File('${dir.path}/knowledge/manifest.yaml');
    if (manifest.existsSync()) return '${dir.path}/knowledge';
    if (dir.parent.path == dir.path) fail('knowledge root not found');
    dir = dir.parent;
  }
}
