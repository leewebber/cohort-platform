import 'dart:io';

import 'package:founder_importer/features/founder_programme_import/founder_programme_import_service.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_protocol_writer.dart';
import 'package:founder_importer/models/protocol_draft.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:founder_importer/models/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/founder_importer_in_memory_programme_stores.dart';

/// Validates Spartan Week 1 YAML against Wave 1 + prior catalogue slugs (no Supabase writes).
void main() {
  final yamlPath = File('tool/programmes/spartan_physique_block1_week1.yaml');
  late String yamlSource;
  late FounderProgrammeImportService importer;

  setUpAll(() {
    yamlSource = yamlPath.readAsStringSync();
    importer = FounderProgrammeImportService(
      versionStore: InMemoryProgrammeVersionStore(InMemoryProgrammeTables()),
      protocolWriter: _NoOpProtocolWriter(),
      exerciseResolver: FounderProgrammeExerciseResolver.fromCatalogue(
        _spartanWeek1Catalogue(),
      ),
    );
  });

  test('Spartan Week 1 YAML dry-run passes catalogue resolution', () async {
    const parser = FounderProgrammeYamlParser();
    final document = parser.parse(yamlSource);
    expect(document.programme.importKey, 'founder-spartan-physique-v1');
    expect(document.weeks.single.days.length, 7);

    final result = await importer.dryRunYaml(yamlSource: yamlSource);

    if (!result.readyForApply) {
      fail(
        'Expected dry-run to pass.\n'
        'Errors:\n${result.validationErrors.join('\n')}\n'
        'Unresolved:\n${result.unresolvedExerciseSlugs.join('\n')}',
      );
    }

    expect(result.sessionCount, 6);
    expect(result.unresolvedExerciseSlugs, isEmpty);
  });
}

class _NoOpProtocolWriter implements FounderProgrammeProtocolWriter {
  @override
  Future<void> saveDraft(ProtocolDraft draft) async {}
}

List<Exercise> _spartanWeek1Catalogue() {
  final migrationSql = File(
    'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql',
  ).readAsStringSync();

  Exercise ex(String id, String name, String slug) {
    return Exercise(exerciseId: id, name: name, slug: slug, published: true);
  }

  final catalogue = <Exercise>[
    ex('EX-001', 'Easy Run', 'easy-run'),
    ex('EX-002', 'Threshold Run', 'threshold-run'),
    ex('EX-012', 'Push Up', 'push-up'),
    ex('EX-053', 'Pull Up', 'pull-up'),
    ex('EX-029', 'Bulgarian Split Squat', 'bulgarian-split-squat'),
    ex('EX-025', 'Walking Lunge', 'walking-lunge'),
    ex('EX-037', 'Dumbbell Strict Press', 'dumbbell-strict-press'),
    ex('EX-044', 'Lateral Raise', 'lateral-raise'),
    ex('EX-047', 'Reverse Fly', 'reverse-fly'),
    ex('EX-042', 'Hammer Curl', 'hammer-curl'),
    ex('EX-021', 'Plank', 'plank'),
    ex('EX-062', 'Full Body Mobility Flow', 'full-body-mobility-flow'),
  ];

  final slugPattern = RegExp(r"'([a-z0-9-]+)',\s*true,");
  for (final match in slugPattern.allMatches(migrationSql)) {
    final slug = match.group(1)!;
    if (catalogue.any((row) => row.slug == slug)) continue;
    catalogue.add(
      Exercise(
        exerciseId: 'EX-W1-$slug',
        name: slug,
        slug: slug,
        published: true,
      ),
    );
  }

  return catalogue;
}
