import 'dart:convert';

import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_identity_resolution.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_exception.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_service.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:founder_importer/models/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/founder_programme_import/repository_transitional_identity_adapter.dart';
import '../support/founder_importer_in_memory_programme_stores.dart';
import '../support/founder_programme_import_test_support.dart';

void main() {
  final mappings = FounderApprovedIdentityMappingsPhase31F.allMappings;

  List<Exercise> catalogue({
    Set<String> unpublished = const {},
    Iterable<ExerciseIdentityMapping>? source,
  }) {
    final ids = (source ?? mappings)
        .map((mapping) => mapping.canonicalId.value)
        .toSet();
    return [
      for (final id in ids)
        Exercise(
          exerciseId: id,
          name: id,
          published: !unpublished.contains(id),
        ),
    ];
  }

  FounderProgrammeExerciseResolver resolver({
    Iterable<ExerciseIdentityMapping>? source,
    List<Exercise>? definitions,
  }) {
    final selected = source?.toList() ?? mappings;
    return FounderProgrammeExerciseResolver.fromCatalogue(
      definitions ?? catalogue(source: selected),
      transitionalIdentityResolver: RepositoryTransitionalIdentityAdapter(
        InMemoryTransitionalExerciseIdBridge(initial: selected),
      ),
    );
  }

  test('parses transitional_exercise_id as untrusted input', () {
    final exercise = const FounderProgrammeYamlParser()
        .parse(_yaml(['cohort.exercise.goblet_squat']))
        .weeks
        .single
        .days
        .single
        .sessions
        .single
        .blocks
        .single
        .exercises
        .single;
    expect(exercise.transitionalExerciseId, 'cohort.exercise.goblet_squat');
  });

  test('all 21 mappings resolve to their exact published canonical ids', () {
    final references = mappings
        .map((mapping) => mapping.transitionalId.value)
        .toList();
    final plan = resolver().resolveDocument(
      const FounderProgrammeYamlParser().parse(_yaml(references)),
    );
    expect(plan.issues, isEmpty);
    for (var index = 0; index < mappings.length; index++) {
      expect(
        plan.canonicalIdAt(_location(index + 1)),
        mappings[index].canonicalId.value,
      );
    }
  });

  test('malformed and unmapped transitional ids fail explicitly', () {
    expect(
      _issues(resolver(), ['Back Squat']).single.code,
      'invalid_transitional_exercise_id',
    );
    expect(
      _issues(resolver(), ['cohort.exercise.not_in_matrix']).single.code,
      'unmapped_transitional_exercise_id',
    );
  });

  test('missing exercise references fail with the bounded taxonomy', () {
    expect(_issues(resolver(), ['']).single.code, 'missing_exercise_reference');
  });

  test('retired and conflicting mappings fail deterministically', () {
    final retired = ExerciseIdentityMapping(
      id: 'retired',
      transitionalId: TransitionalExerciseId.parse(
        'cohort.exercise.retired_test',
      ),
      canonicalId: ExerciseId.parse('EX-9001'),
      lifecycleStatus: ExerciseLifecycleStatus.retired,
      version: '1',
      provenance: 'Founder-authored retired test mapping.',
      retiredAt: DateTime.utc(2026, 8, 1),
    );
    expect(
      _issues(resolver(source: [retired]), [
        retired.transitionalId.value,
      ]).single.code,
      'retired_transitional_mapping',
    );

    final issue = _issues(
      resolver(
        source: [
          _mapping('a', 'conflict_test', 'EX-9002'),
          _mapping('b', 'conflict_test', 'EX-9001'),
        ],
      ),
      ['cohort.exercise.conflict_test'],
    ).single;
    expect(issue.code, 'conflicting_transitional_mapping');
    expect(issue.canonicalCandidates, ['EX-9001', 'EX-9002']);
  });

  test('missing and unpublished canonical targets fail closed', () {
    const reference = 'cohort.exercise.goblet_squat';
    expect(
      _issues(resolver(definitions: const []), [reference]).single.code,
      'missing_canonical_target',
    );
    expect(
      _issues(resolver(definitions: catalogue(unpublished: {'EX-030'})), [
        reference,
      ]).single.code,
      'canonical_target_not_published',
    );
    final duplicateCatalogue = [
      ...catalogue(),
      const Exercise(
        exerciseId: 'EX-030',
        name: 'Duplicate fixture',
        published: true,
      ),
    ];
    expect(
      _issues(resolver(definitions: duplicateCatalogue), [
        reference,
      ]).single.code,
      'conflicting_canonical_target',
    );
  });

  test('transitional references never fall back to slug or name', () {
    final withSlug = const FounderProgrammeYamlParser().parse(
      _yaml(
        ['cohort.exercise.not_in_matrix'],
        name: 'Goblet Squat',
        slug: 'goblet-squat',
      ),
    );
    expect(
      resolver().resolveDocument(withSlug).issues.single.code,
      'conflicting_authored_reference',
    );
    final nameOnly = const FounderProgrammeYamlParser().parse(
      _yaml(['cohort.exercise.not_in_matrix'], name: 'Goblet Squat'),
    );
    expect(
      resolver().resolveDocument(nameOnly).issues.single.code,
      'unmapped_transitional_exercise_id',
    );
  });

  test('writes canonical EX id and keeps exercise_name display-only', () async {
    final writer = RecordingFounderProgrammeProtocolWriter();
    final service = FounderProgrammeImportService(
      versionStore: InMemoryProgrammeVersionStore(InMemoryProgrammeTables()),
      protocolWriter: writer,
      exerciseResolver: resolver(),
    );
    await service.importYaml(
      yamlSource: _yaml([
        'cohort.exercise.goblet_squat',
      ], name: 'Display label'),
      coachId: 'founder-test',
    );
    final link = writer.drafts.single.blocks.single.linkedExercises.single;
    expect(link.exerciseId, 'EX-030');
    expect(link.displayLabelOverride, 'Display label');
    expect(writer.drafts.single.published, isFalse);
  });

  test('mixed valid and invalid import starts zero writes', () async {
    final tables = InMemoryProgrammeTables();
    final writer = RecordingFounderProgrammeProtocolWriter();
    final service = FounderProgrammeImportService(
      versionStore: InMemoryProgrammeVersionStore(tables),
      protocolWriter: writer,
      exerciseResolver: resolver(),
    );
    try {
      await service.importYaml(
        yamlSource: _yaml([
          'cohort.exercise.goblet_squat',
          'cohort.exercise.not_in_matrix',
        ]),
        coachId: 'founder-test',
      );
      fail('Expected import failure.');
    } on FounderProgrammeImportException catch (error) {
      expect(error.writesStarted, isFalse);
    }
    expect(writer.drafts, isEmpty);
    expect(tables.lineages, isEmpty);
    expect(tables.versions, isEmpty);
    expect(tables.weeks, isEmpty);
  });

  test('issues sort and serialize identically on repeated resolution', () {
    final document = const FounderProgrammeYamlParser().parse(
      _yaml(['cohort.exercise.not_in_matrix', 'Back Squat']),
    );
    final first = resolver().resolveDocument(document).issues;
    final second = resolver().resolveDocument(document).issues;
    expect(
      jsonEncode(first.map((issue) => issue.toJson()).toList()),
      jsonEncode(second.map((issue) => issue.toJson()).toList()),
    );
    expect(first.map((issue) => issue.location.exerciseOrder), [1, 2]);
  });

  test('legacy slug and exact-name behavior remains unchanged', () {
    final legacy = FounderProgrammeExerciseResolver.fromCatalogue(
      founderImportTestExercises(),
    );
    expect(
      legacy.resolveExerciseId(
        const FounderProgrammeYamlExercise(
          exerciseSlug: 'goblet-squat',
          order: 1,
        ),
      ),
      'GOBLET-SQ',
    );
    expect(
      legacy.resolveExerciseId(
        const FounderProgrammeYamlExercise(
          exerciseName: 'Dumbbell Floor Press',
          order: 1,
        ),
      ),
      'DB-FLOOR-PRESS',
    );
  });
}

List<FounderProgrammeIdentityIssue> _issues(
  FounderProgrammeExerciseResolver resolver,
  List<String> references,
) => resolver
    .resolveDocument(
      const FounderProgrammeYamlParser().parse(_yaml(references)),
    )
    .issues;

FounderProgrammeExerciseLocation _location(int exerciseOrder) =>
    FounderProgrammeExerciseLocation(
      importKey: 'bridge-test',
      weekNumber: 1,
      dayNumber: 1,
      sessionOrder: 1,
      blockOrder: 1,
      exerciseOrder: exerciseOrder,
    );

ExerciseIdentityMapping _mapping(String id, String source, String target) =>
    ExerciseIdentityMapping(
      id: id,
      transitionalId: TransitionalExerciseId.parse('cohort.exercise.$source'),
      canonicalId: ExerciseId.parse(target),
      lifecycleStatus: ExerciseLifecycleStatus.published,
      version: '1',
      provenance: 'Founder-authored conflict test mapping.',
      publishedAt: DateTime.utc(2026, 8, 1),
    );

String _yaml(List<String> references, {String? name, String? slug}) {
  final exercises = references
      .asMap()
      .entries
      .map((entry) {
        final nameLine = name == null
            ? ''
            : '\n                    exercise_name: $name';
        final slugLine = slug == null
            ? ''
            : '\n                    exercise_slug: $slug';
        return '''
                  - transitional_exercise_id: ${entry.value}$nameLine$slugLine
                    order: ${entry.key + 1}''';
      })
      .join('\n');
  return '''
schema_version: 1
programme:
  import_key: bridge-test
  title: Bridge Test
  code: BRIDGE-TEST
  duration_weeks: 1
weeks:
  - week_number: 1
    days:
      - day_number: 1
        is_rest_day: false
        sessions:
          - title: Session
            session_type: strength
            blocks:
              - title: Main
                block_type: strength
                order: 1
                exercises:
$exercises
''';
}
