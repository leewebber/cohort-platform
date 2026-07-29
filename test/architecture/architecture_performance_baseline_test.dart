import 'dart:io';

import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/gap_analysis_scenario_loader.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/planning/exercise_policy/deterministic_exercise_policy_engine.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/coach_brain_service.dart';
import 'package:cohort_platform/planning/orchestration/models/coach_brain_orchestration_request.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/prescription/deterministic_prescription_engine.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records baseline latency for full orchestration (in-process, reference ontology).
void main() {
  late CoachBrainService coachBrain;
  late PlanningInput input;

  setUpAll(() async {
    final knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
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
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.general_fat_loss_a',
    );
    input = PlanningInput(
      athleteId: 'athlete.test',
      goalContext: PlanningGoalContext(goalId: scenario.goalId),
      capabilityEvidence: scenario.evidenceProfile,
      knowledgeOntologyVersion: knowledge.ontologyVersion,
      asOf: DateTime.utc(2026, 7, 29),
    );
  });

  test('full pipeline median latency under 500ms (local baseline)', () {
    const runs = 10;
    final samples = <int>[];
    final request = CoachBrainOrchestrationRequest(
      planningInput: input,
      availableEquipmentIds: _commercialGym,
      environmentId: 'cohort.environment.commercial_gym',
    );
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      coachBrain.run(request);
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }
    samples.sort();
    final median = samples[samples.length ~/ 2];
    final p95 = samples[(samples.length * 0.95).floor().clamp(0, samples.length - 1)];
    expect(median, lessThan(500), reason: 'median=${samples}ms');
    expect(p95, lessThan(800), reason: 'p95=${samples}ms');
  });

  test('planning engine-only calls are deterministic', () {
    final knowledgeRoot = _findKnowledgeRoot(Directory.current);
    // synchronous double-run using same service instance from setup
    final request = CoachBrainOrchestrationRequest(
      planningInput: input,
      availableEquipmentIds: _commercialGym,
      environmentId: 'cohort.environment.commercial_gym',
    );
    final a = coachBrain.run(request);
    final b = coachBrain.run(request);
    expect(a.recommendation?.status, b.recommendation?.status);
    expect(
      a.exercisePolicyResult?.selections.map((s) => s.exerciseId),
      b.exercisePolicyResult?.selections.map((s) => s.exerciseId),
    );
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
    if (dir.parent.path == dir.path) fail('knowledge root not found');
    dir = dir.parent;
  }
}
