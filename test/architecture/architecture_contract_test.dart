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
import 'package:cohort_platform/planning/orchestration/coach_brain_service.dart';
import 'package:cohort_platform/planning/orchestration/models/coach_brain_orchestration_request.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/prescription/deterministic_prescription_engine.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:cohort_platform/planning/session_blueprint/session_blueprint_validator.dart';
import 'package:cohort_platform/planning/session_blueprint/session_blueprint_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryKnowledgeGraphReader knowledge;
  late CoachBrainService coachBrain;
  late String knowledgeRoot;

  setUpAll(() async {
    knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    knowledge = InMemoryKnowledgeGraphReader(bundle);
    coachBrain = CoachBrainService(
      planningEngine: PlanningEngineService(
        knowledge: knowledge,
        gapAnalysis: CapabilityGapAnalysisService(knowledge),
        intentResolution: TrainingIntentFromGapsService(knowledge),
      ),
      blueprintGenerator: DeterministicSessionBlueprintGenerator(
        knowledge: knowledge,
      ),
      exercisePolicy: DeterministicExercisePolicyEngine(knowledge: knowledge),
      prescriptionEngine: DeterministicPrescriptionEngine(knowledge: knowledge),
    );
  });

  test('PlanningRecommendation model has no exercise prescription fields', () {
    final source = File(
      'lib/planning/models/planning_recommendation.dart',
    ).readAsStringSync();
    expect(source.contains('exerciseId'), isFalse);
    expect(source.contains('StrengthExercisePrescription'), isFalse);
    expect(source.contains('sets'), isFalse);
  });

  test('SessionBlueprint contract rejects prescription patterns in runtime output',
      () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.general_fat_loss_a',
    );
    final input = PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: knowledge.ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
    final ctx = coachBrain.run(
      CoachBrainOrchestrationRequest(planningInput: input),
    );
    final bp = ctx.sessionBlueprint;
    expect(bp, isNotNull);
    SessionBlueprintContract.assertNoPrescriptionContent(bp!);
  });

  test('exercise policy semantic plan has no structured strength prescriptions', () {
    final source = File(
      'lib/planning/exercise_policy/models/exercise_policy_models.dart',
    ).readAsStringSync();
    expect(source.contains('StrengthExercisePrescription'), isFalse);
    expect(source.contains('sets'), isFalse);
    expect(source.contains('reps'), isFalse);
  });

  test('orchestration preserves intent and archetype across stages', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.general_fat_loss_a',
    );
    final input = PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: knowledge.ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
    final ctx = coachBrain.run(
      CoachBrainOrchestrationRequest(
        planningInput: input,
        availableEquipmentIds: _commercialGym,
        environmentId: 'cohort.environment.commercial_gym',
      ),
    );
    if (ctx.sessionBlueprint != null && ctx.exercisePolicyResult != null) {
      expect(
        ctx.exercisePolicyResult!.primaryTrainingIntentId,
        ctx.sessionBlueprint!.primaryTrainingIntentId,
      );
      expect(
        ctx.exercisePolicyResult!.sessionArchetypeId,
        ctx.sessionBlueprint!.sessionArchetype.archetypeId,
      );
    }
    if (ctx.prescriptionResult != null && ctx.sessionBlueprint != null) {
      expect(
        ctx.prescriptionResult!.primaryTrainingIntentId,
        ctx.sessionBlueprint!.primaryTrainingIntentId,
      );
    }
  });

  test('PlanningContext stages are append-only immutable hand-offs', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.general_fat_loss_a',
    );
    final input = PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: knowledge.ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
    final ctx = coachBrain.run(
      CoachBrainOrchestrationRequest(
        planningInput: input,
        availableEquipmentIds: _commercialGym,
        environmentId: 'cohort.environment.commercial_gym',
      ),
    );
    expect(ctx.stages.length, greaterThanOrEqualTo(1));
    for (var i = 1; i < ctx.stages.length; i++) {
      expect(
        ctx.stages[i].startedAt.isAfter(ctx.stages[i - 1].completedAt) ||
            ctx.stages[i].startedAt.isAtSameMomentAs(ctx.stages[i - 1].completedAt),
        isTrue,
      );
    }
  });

  test('explainability aggregated with planning provenance', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.general_fat_loss_a',
    );
    final input = PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: knowledge.ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
    final ctx = coachBrain.run(
      CoachBrainOrchestrationRequest(
        planningInput: input,
        availableEquipmentIds: _commercialGym,
        environmentId: 'cohort.environment.commercial_gym',
      ),
    );
    expect(ctx.aggregatedExplainability.planning, isNotNull);
    expect(ctx.aggregatedExplainability.combinedNarrative, isNotEmpty);
  });

  test('policy output validates when complete', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.general_fat_loss_a',
    );
    final input = PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: knowledge.ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
    final ctx = coachBrain.run(
      CoachBrainOrchestrationRequest(
        planningInput: input,
        availableEquipmentIds: _commercialGym,
        environmentId: 'cohort.environment.commercial_gym',
      ),
    );
    if (ctx.exercisePolicyResult != null && ctx.sessionBlueprint != null) {
      final v = const ExercisePolicyValidator().validateResult(
        request: ExercisePolicyRequest(blueprint: ctx.sessionBlueprint!),
        result: ctx.exercisePolicyResult!,
      );
      if (ctx.exercisePolicyResult!.status == MovementSelectionStatus.complete) {
        expect(v.isValid, isTrue);
      }
    }
  });
}

const _commercialGym = [
  'cohort.equipment.barbell',
  'cohort.equipment.squat_rack',
  'cohort.equipment.dumbbell',
  'cohort.equipment.kettlebell',
  'cohort.equipment.bench',
  'cohort.equipment.bodyweight',
];

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
