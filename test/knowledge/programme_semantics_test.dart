import 'dart:io';

import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
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

  test('programme semantics ontology validates', () async {
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final result = const KnowledgeOntologyValidator().validate(bundle);
    expect(result.isValid, isTrue, reason: result.errors.join('\n'));
    expect(bundle.ontologyVersion, '1.3.0');
    expect(bundle.programmePhases.length, greaterThanOrEqualTo(10));
    expect(bundle.trainingBlocks.length, greaterThanOrEqualTo(8));
  });

  test('progressionPath returns default competition standard', () {
    final path = reader.progressionPath();
    expect(path, isNotNull);
    expect(path!.id, 'cohort.progression_path.competition_standard');
    expect(path.steps.first.phaseId, 'cohort.programme_phase.foundation');
    expect(
      path.steps.map((s) => s.phaseId),
      contains('cohort.programme_phase.competition'),
    );
  });

  test('recommendedBlocks ranks threshold block in specific preparation', () {
    final blocks = reader.recommendedBlocks(
      'cohort.programme_phase.specific_preparation',
    );
    expect(blocks, isNotEmpty);
    expect(
      blocks.map((b) => b.id),
      contains('cohort.training_block.threshold'),
    );
  });

  test('weekTypesForPhase filters accumulation for general preparation', () {
    final weeks = reader.weekTypesForPhase(
      'cohort.programme_phase.general_preparation',
    );
    expect(weeks.map((w) => w.id), contains('cohort.week_type.accumulation'));
  });

  test('phaseCapabilities and phaseTrainingIntents expose priorities', () {
    expect(
      reader.phaseCapabilities('cohort.programme_phase.foundation'),
      contains('cohort.capability.movement_competency'),
    );
    expect(
      reader.phaseTrainingIntents('cohort.programme_phase.foundation'),
      contains('cohort.training_intent.aerobic_base'),
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
