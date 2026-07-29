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
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String knowledgeRoot;
  late InMemoryKnowledgeGraphReader knowledge;
  late PlanningEngineService engine;
  late String ontologyVersion;

  setUpAll(() async {
    knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    ontologyVersion = bundle.ontologyVersion;
    knowledge = InMemoryKnowledgeGraphReader(bundle);
    engine = PlanningEngineService(
      knowledge: knowledge,
      gapAnalysis: CapabilityGapAnalysisService(knowledge),
      intentResolution: TrainingIntentFromGapsService(knowledge),
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

  test('HYROX athlete prioritises station-related intents', () async {
    final input = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final rec = engine.createRecommendation(input);
    expect(rec.status, isNot(PlanningRecommendationStatus.invalidInput));
    expect(rec.capabilityPriorities, isNotEmpty);
    final intentIds = rec.trainingIntentRecommendations
        .map((i) => i.trainingIntentId)
        .toList();
    expect(
      intentIds.any(
        (id) =>
            id.contains('grip') ||
            id.contains('technique') ||
            id.contains('strength_endurance'),
      ),
      isTrue,
    );
    _assertNoExerciseContent(rec);
  });

  test('military athlete surfaces carry and resilience priorities', () async {
    final input = await scenarioInput('cohort.scenario.military_selection_a');
    final rec = engine.createRecommendation(input);
    expect(
      rec.capabilityPriorities.map((c) => c.capabilityId),
      anyElement(contains('loaded_carry')),
    );
    expect(rec.trainingIntentRecommendations, isNotEmpty);
    _assertNoExerciseContent(rec);
  });

  test(
    'general fat loss with adequate evidence yields complete or partial',
    () async {
      final input = await scenarioInput('cohort.scenario.general_fat_loss_a');
      final rec = engine.createRecommendation(input);
      expect(
        rec.status,
        anyOf(
          PlanningRecommendationStatus.complete,
          PlanningRecommendationStatus.partial,
        ),
      );
      expect(rec.selectedProgrammePhase, isNotNull);
      _assertNoExerciseContent(rec);
    },
  );

  test('explicit active phase and block preserved when valid', () async {
    final base = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: base.knowledgeOntologyVersion,
      asOf: base.asOf,
      activeProgrammePhaseId: 'cohort.programme_phase.specific_preparation',
      activeTrainingBlockId: 'cohort.training_block.threshold',
    );
    final rec = engine.createRecommendation(input);
    expect(
      rec.selectedProgrammePhase?.phaseId,
      'cohort.programme_phase.specific_preparation',
    );
    expect(rec.selectedProgrammePhase?.inferred, isFalse);
    expect(
      rec.recommendedTrainingBlock?.blockId,
      'cohort.training_block.threshold',
    );
    expect(rec.recommendedTrainingBlock?.inferred, isFalse);
  });

  test('invalid active block for phase is replaced with warning', () async {
    final base = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: base.knowledgeOntologyVersion,
      asOf: base.asOf,
      activeProgrammePhaseId: 'cohort.programme_phase.specific_preparation',
      activeTrainingBlockId: 'cohort.training_block.aerobic_base',
    );
    final rec = engine.createRecommendation(input);
    expect(rec.warnings.any((w) => w.code == 'block_replaced'), isTrue);
    expect(
      rec.recommendedTrainingBlock?.blockId,
      isNot('cohort.training_block.aerobic_base'),
    );
  });

  test('prerequisite chain favours foundation phase and base-oriented block', () async {
    final input = await scenarioInput(
      'cohort.scenario.hyrox_prerequisite_chain',
    );
    final rec = engine.createRecommendation(input);
    expect(rec.capabilityPriorities, isNotEmpty);
    expect(
      rec.selectedProgrammePhase?.phaseId,
      'cohort.programme_phase.foundation',
    );
    expect(
      rec.explainability.factors.any(
        (f) =>
            f.code == 'phase_foundation_fallback' ||
            f.code == 'phase_from_progression',
      ),
      isTrue,
    );
  });

  test('poor recovery selects recovery week and archetype override', () async {
    final base = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: base.knowledgeOntologyVersion,
      asOf: base.asOf,
      recoverySummary: const PlanningRecoverySummary(
        level: PlanningRecoveryLevel.poor,
      ),
    );
    final rec = engine.createRecommendation(input);
    expect(rec.selectedWeekType?.weekTypeId, 'cohort.week_type.recovery');
    expect(
      rec.recommendedSessionArchetype?.archetypeId,
      'cohort.session_archetype.recovery_session',
    );
  });

  test('high unknown evidence favours assessment week type', () async {
    final input = await scenarioInput(
      'cohort.scenario.hyrox_prerequisite_chain',
    );
    final rec = engine.createRecommendation(input);
    expect(rec.selectedWeekType?.weekTypeId, 'cohort.week_type.assessment');
  });

  test('precomputed gaps and intents are reused', () async {
    final base = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final gaps = CapabilityGapAnalysisService(knowledge).rankTrainingPriorities(
      goalId: base.goalContext.goalId,
      evidenceProfile: base.capabilityEvidence,
    );
    final intents = TrainingIntentFromGapsService(
      knowledge,
    ).resolveIntentsForGaps(rankedGaps: gaps);
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: base.knowledgeOntologyVersion,
      asOf: base.asOf,
      precomputedCapabilityGaps: PrecomputedCapabilityGaps(
        goalId: base.goalContext.goalId,
        ontologyVersion: ontologyVersion,
        rankedGaps: gaps,
      ),
      precomputedTrainingIntents: PrecomputedTrainingIntents(
        goalId: base.goalContext.goalId,
        ontologyVersion: ontologyVersion,
        recommendations: intents,
      ),
    );
    final rec = engine.createRecommendation(input);
    expect(
      rec.explainability.factors.any((f) => f.code == 'gaps_supplied'),
      isTrue,
    );
    expect(
      rec.explainability.factors.any((f) => f.code == 'intents_supplied'),
      isTrue,
    );
  });

  test('ontology version mismatch returns invalidInput', () async {
    final base = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: '0.0.1',
      asOf: base.asOf,
    );
    final rec = engine.createRecommendation(input);
    expect(rec.status, PlanningRecommendationStatus.invalidInput);
  });

  test('deterministic output across repeated runs', () async {
    final input = await scenarioInput('cohort.scenario.military_selection_a');
    final first = engine.createRecommendation(input);
    final second = engine.createRecommendation(input);
    expect(first.status, second.status);
    expect(
      first.selectedProgrammePhase?.phaseId,
      second.selectedProgrammePhase?.phaseId,
    );
    expect(
      first.recommendedTrainingBlock?.blockId,
      second.recommendedTrainingBlock?.blockId,
    );
    expect(
      first.recommendedSessionArchetype?.archetypeId,
      second.recommendedSessionArchetype?.archetypeId,
    );
    expect(first.confidence, second.confidence);
  });

  test('injury at competition phase is infeasible', () async {
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
    final rec = engine.createRecommendation(input);
    expect(rec.status, PlanningRecommendationStatus.infeasible);
  });

  test('precomputed gaps with wrong goal rejected', () async {
    final base = await scenarioInput('cohort.scenario.hyrox_athlete_a');
    final input = PlanningInput(
      athleteId: base.athleteId,
      goalContext: base.goalContext,
      capabilityEvidence: base.capabilityEvidence,
      knowledgeOntologyVersion: base.knowledgeOntologyVersion,
      asOf: base.asOf,
      precomputedCapabilityGaps: PrecomputedCapabilityGaps(
        goalId: 'cohort.goal.other',
        ontologyVersion: ontologyVersion,
        rankedGaps: const [],
      ),
    );
    final rec = engine.createRecommendation(input);
    expect(rec.status, PlanningRecommendationStatus.invalidInput);
  });
}

void _assertNoExerciseContent(PlanningRecommendation rec) {
  final blob =
      '${rec.adaptationRationale} ${rec.explainability.narrativeSummary}';
  expect(blob.contains('cohort.exercise.'), isFalse);
  expect(
    rec.recommendedSessionArchetype?.archetypeId,
    startsWith('cohort.session_archetype.'),
  );
}

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
