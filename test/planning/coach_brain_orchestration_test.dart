import 'dart:io';

import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/gap_analysis_scenario_loader.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/planning/exercise_policy/deterministic_exercise_policy_engine.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/models/planning_recommendation.dart';
import 'package:cohort_platform/planning/orchestration/coach_brain_service.dart';
import 'package:cohort_platform/planning/orchestration/models/coach_brain_orchestration_request.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_stage_models.dart';
import 'package:cohort_platform/planning/orchestration/planning_context_validator.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/prescription/deterministic_prescription_engine.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:cohort_platform/planning/session_blueprint/models/session_blueprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CoachBrainService coachBrain;
  late String knowledgeRoot;
  late String ontologyVersion;

  setUpAll(() async {
    knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    ontologyVersion = bundle.ontologyVersion;
    final knowledge = InMemoryKnowledgeGraphReader(bundle);
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

  CoachBrainOrchestrationRequest requestFor(
    PlanningInput input, {
    List<String>? equipment,
    String? environment,
    bool travel = false,
    SessionBlueprintGenerationContext? blueprintContext,
  }) {
    return CoachBrainOrchestrationRequest(
      planningInput: input,
      blueprintContext: blueprintContext ?? const SessionBlueprintGenerationContext(),
      availableEquipmentIds: equipment ?? _commercialGym,
      environmentId: environment ?? 'cohort.environment.commercial_gym',
      isTraveling: travel,
    );
  }

  test('HYROX athlete completes or partial pipeline with explainability', () async {
    final input = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final ctx = coachBrain.run(requestFor(input));
    expect(ctx.recommendation, isNotNull);
    expect(ctx.aggregatedExplainability.planning, isNotNull);
    expect(ctx.stages.first.stageId, PlanningStageId.planningEngine);
    _assertProvenance(ctx, input.goalContext.goalId);
    if (ctx.orchestrationStatus == OrchestrationStatus.complete) {
      expect(ctx.sessionExecutionPlan, isNotNull);
      expect(ctx.aggregatedExplainability.sectionOrder.length, greaterThanOrEqualTo(4));
    }
  });

  test('military athlete preserves goal through pipeline', () async {
    final input = await scenarioInput('cohort.scenario.military_selection_a');
    final ctx = coachBrain.run(requestFor(input));
    expect(ctx.goalId, input.goalContext.goalId);
    expect(ctx.recommendation?.goalId, input.goalContext.goalId);
  });

  test('fat-loss athlete orchestration', () async {
    final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final ctx = coachBrain.run(requestFor(input));
    expect(
      ctx.orchestrationStatus,
      anyOf(
        OrchestrationStatus.complete,
        OrchestrationStatus.partial,
        OrchestrationStatus.failed,
      ),
    );
    expect(ctx.aggregatedExplainability.combinedNarrative, isNotEmpty);
  });

  test('poor recovery context runs blueprint stage', () async {
    final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final ctx = coachBrain.run(
      requestFor(
        input,
        blueprintContext: const SessionBlueprintGenerationContext(
          recoverySummary: PlanningRecoverySummary(
            level: PlanningRecoveryLevel.poor,
          ),
        ),
      ),
    );
    expect(
      ctx.stages.any((s) => s.stageId == PlanningStageId.sessionBlueprint),
      isTrue,
    );
  });

  test('travel and hotel equipment', () async {
    final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final ctx = coachBrain.run(
      requestFor(
        input,
        equipment: _hotelGym,
        environment: 'cohort.environment.hotel_gym',
        travel: true,
      ),
    );
    expect(ctx.stages.any((s) => s.stageId == PlanningStageId.exercisePolicy), isTrue);
  });

  test('limited home equipment', () async {
    final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final ctx = coachBrain.run(
      requestFor(
        input,
        equipment: _homeGym,
        environment: 'cohort.environment.home',
      ),
    );
    expect(ctx.exercisePolicyResult, isNotNull);
  });

  test('injury flags forwarded to policy stage', () async {
    final base = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: base.knowledgeOntologyVersion,
      asOf: base.asOf,
      injuryFlags: const ['shoulder'],
    );
    final ctx = coachBrain.run(requestFor(input));
    expect(ctx.exercisePolicyResult, isNotNull);
  });

  test('deterministic orchestration across repeated runs', () async {
    final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final req = requestFor(input);
    final a = coachBrain.run(req);
    final b = coachBrain.run(req);
    expect(a.recommendation?.status, b.recommendation?.status);
    expect(
      a.exercisePolicyResult?.selections.map((s) => s.exerciseId),
      b.exercisePolicyResult?.selections.map((s) => s.exerciseId),
    );
  });

  test('invalid input stops pipeline at planning', () async {
    final input = PlanningInput(
      athleteId: '',
      goalContext: const PlanningGoalContext(goalId: 'cohort.goal.hyrox_sub_60'),
      capabilityEvidence: (await scenarioInput('cohort.scenario.hyrox_athlete_a'))
          .capabilityEvidence,
      knowledgeOntologyVersion: ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
    final ctx = coachBrain.run(requestFor(input));
    expect(ctx.orchestrationStatus, OrchestrationStatus.invalidInput);
    expect(ctx.sessionBlueprint, isNull);
    expect(ctx.resumeFromStage, isNull);
    expect(ctx.diagnostics.failedStageId, PlanningStageId.planningEngine);
  });

  test('competition phase with injury stops at planning (infeasible)', () async {
    final base = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: base.knowledgeOntologyVersion,
      asOf: base.asOf,
      activeProgrammePhaseId: 'cohort.programme_phase.competition',
      injuryFlags: const ['shoulder'],
    );
    final ctx = coachBrain.run(requestFor(input));
    expect(ctx.recommendation?.status, PlanningRecommendationStatus.infeasible);
    expect(ctx.orchestrationStatus, OrchestrationStatus.failed);
    expect(ctx.sessionBlueprint, isNull);
    expect(ctx.resumeFromStage, PlanningStageId.planningEngine);
  });

  test('context validator passes successful pipeline', () async {
    final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final ctx = coachBrain.run(requestFor(input));
    if (ctx.sessionExecutionPlan != null) {
      final v = const PlanningContextValidator().validate(ctx);
      expect(v.isValid, isTrue);
    }
  });

  test('stage timings recorded', () async {
    final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
    final ctx = coachBrain.run(requestFor(input));
    expect(ctx.diagnostics.stageTimings, isNotEmpty);
    for (final t in ctx.diagnostics.stageTimings) {
      expect(t.duration.inMicroseconds, greaterThanOrEqualTo(0));
    }
  });
}

void _assertProvenance(PlanningContext ctx, String goalId) {
  expect(ctx.goalId, goalId);
  if (ctx.sessionBlueprint != null) {
    expect(ctx.sessionBlueprint!.sourceRecommendation.goalId, goalId);
  }
  if (ctx.primaryTrainingIntentId != null && ctx.recommendation != null) {
    expect(
      ctx.recommendation!.trainingIntentRecommendations
          .map((i) => i.trainingIntentId)
          .contains(ctx.primaryTrainingIntentId),
      isTrue,
    );
  }
}

const _commercialGym = [
  'cohort.equipment.barbell',
  'cohort.equipment.squat_rack',
  'cohort.equipment.dumbbell',
  'cohort.equipment.kettlebell',
  'cohort.equipment.bench',
  'cohort.equipment.bodyweight',
];

const _homeGym = [
  'cohort.equipment.kettlebell',
  'cohort.equipment.dumbbell',
  'cohort.equipment.bodyweight',
];

const _hotelGym = [
  'cohort.equipment.dumbbell',
  'cohort.equipment.kettlebell',
  'cohort.equipment.bodyweight',
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
