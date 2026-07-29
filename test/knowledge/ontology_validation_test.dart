import 'dart:io';

import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/models/knowledge_ontology_models.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/validation/knowledge_ontology_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String knowledgeRoot;

  setUpAll(() async {
    knowledgeRoot = _findKnowledgeRoot(Directory.current);
  });

  test('reference ontology loads and validates', () async {
    final loader = YamlKnowledgeOntologyLoader();
    final bundle = await loader.loadFromDirectory(knowledgeRoot);

    expect(bundle.ontologyVersion, '1.3.0');
    expect(bundle.exercises.length, greaterThanOrEqualTo(15));
    expect(bundle.substitutions, isNotEmpty);

    final result = const KnowledgeOntologyValidator().validate(bundle);
    expect(result.isValid, isTrue, reason: result.errors.join('\n'));
  });

  test('unique entity ids and alias index', () async {
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    expect(bundle.entityIds.length, greaterThan(bundle.exercises.length));
    expect(bundle.aliasIndex['core:back squat'], 'cohort.exercise.back_squat');
  });

  test('substitution query by constraint and intent', () async {
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final reader = InMemoryKnowledgeGraphReader(bundle);

    final rules = reader.querySubstitutions(
      const SubstitutionQuery(
        sourceExerciseId: 'cohort.exercise.back_squat',
        constraintTags: ['no_barbell', 'hotel_gym'],
        trainingIntentId: 'cohort.training_intent.lower_body_hypertrophy',
      ),
    );
    expect(rules, isNotEmpty);
    expect(rules.first.candidateExerciseId, 'cohort.exercise.goblet_squat');
  });

  test('capability hierarchy and exercise mapping', () async {
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    final reader = InMemoryKnowledgeGraphReader(bundle);

    final pulling = reader.capabilityById('cohort.capability.pulling_strength');
    expect(pulling, isNotNull);
    expect(
      reader.parentsOf(pulling!.id).map((c) => c.id),
      contains('cohort.capability.relative_strength'),
    );

    final mapping = reader.capabilitiesForExercise('cohort.exercise.pull_up');
    expect(mapping?.primaryCapabilityIds, contains(pulling.id));
    expect(
      mapping?.supportingCapabilityIds,
      contains('cohort.capability.scapular_control'),
    );

    final goal = reader.goalRequirements('cohort.goal.hyrox_sub_60');
    expect(goal, isNotNull);
    expect(
      goal!.requiredCapabilityIds,
      contains('cohort.capability.aerobic_capacity'),
    );
    expect(goal.requiredCapabilityIds, contains('cohort.capability.threshold'));
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
