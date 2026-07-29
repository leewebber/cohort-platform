import 'dart:io';

import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/gap_analysis_scenario_loader.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/knowledge/validation/knowledge_ontology_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String knowledgeRoot;
  late InMemoryKnowledgeGraphReader reader;

  setUpAll(() async {
    knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    reader = InMemoryKnowledgeGraphReader(bundle);
  });

  test('ontology validates training intent engine refs', () async {
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final result = const KnowledgeOntologyValidator().validate(bundle);
    expect(result.isValid, isTrue, reason: result.errors.join('\n'));
    expect(bundle.trainingIntents.length, greaterThan(25));
    expect(bundle.sessionArchetypes.length, greaterThanOrEqualTo(9));
  });

  test('threshold capability exposes multiple progression intents', () {
    final mappings = reader.intentsForCapability('cohort.capability.threshold');
    expect(mappings.length, greaterThanOrEqualTo(4));
    final intentIds = mappings.map((m) => m.trainingIntentId).toSet();
    expect(intentIds, contains('cohort.training_intent.tempo_development'));
    expect(intentIds, contains('cohort.training_intent.cruise_intervals'));
  });

  test('progressionOptions filters by stage', () {
    final foundation = reader.progressionOptions(
      'cohort.capability.aerobic_capacity',
      progressionStage: 'foundation',
    );
    expect(foundation, isNotEmpty);
    expect(foundation.every((m) => m.progressionStage == 'foundation'), isTrue);
  });

  test('archetypesForIntent links tempo run to threshold intents', () {
    final archetypes = reader.archetypesForIntent(
      'cohort.training_intent.tempo_development',
    );
    expect(
      archetypes.map((a) => a.id),
      contains('cohort.session_archetype.tempo_run'),
    );
  });

  test('intentsForGoal differentiates HYROX vs military', () {
    final hyrox = reader
        .intentsForGoal('cohort.goal.hyrox_sub_60')
        .map((m) => m.trainingIntentId)
        .toSet();
    final military = reader
        .intentsForGoal('cohort.goal.military_selection')
        .map((m) => m.trainingIntentId)
        .toSet();
    expect(hyrox, contains('cohort.training_intent.grip_endurance'));
    expect(
      military,
      contains('cohort.training_intent.loaded_carry_development'),
    );
    expect(hyrox.intersection(military), isNot(equals(military)));
  });

  test('gap to intent resolution ranks grip for HYROX scenario', () async {
    final scenarios = await const GapAnalysisScenarioLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final scenario = scenarios.firstWhere(
      (s) => s.id == 'cohort.scenario.hyrox_athlete_a',
    );
    final gaps = CapabilityGapAnalysisService(reader).rankTrainingPriorities(
      goalId: scenario.goalId,
      evidenceProfile: scenario.evidenceProfile,
    );
    final intents = TrainingIntentFromGapsService(
      reader,
    ).resolveIntentsForGaps(rankedGaps: gaps);
    expect(intents, isNotEmpty);
    expect(
      intents.first.trainingIntentId,
      anyOf(
        'cohort.training_intent.grip_endurance',
        'cohort.training_intent.technique_practice',
        'cohort.training_intent.strength_endurance',
      ),
    );
  });
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
