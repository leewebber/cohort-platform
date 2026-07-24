import 'dart:io';

import 'package:founder_importer/features/founder_programme_import/founder_programme_import_service.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_protocol_writer.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:founder_importer/models/exercise.dart';
import 'package:founder_importer/models/protocol_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/founder_importer_in_memory_programme_stores.dart';

/// Prints importer dry-run report for Spartan Week 1 (catalogue mirror of Wave 1 + core slugs).
void main() {
  test('print Spartan Week 1 dry-run report', () async {
    final yamlSource = File(
      'tool/programmes/spartan_physique_block1_week1.yaml',
    ).readAsStringSync();

    final importer = FounderProgrammeImportService(
      versionStore: InMemoryProgrammeVersionStore(InMemoryProgrammeTables()),
      protocolWriter: _NoOpProtocolWriter(),
      exerciseResolver: FounderProgrammeExerciseResolver.fromCatalogue(
        _spartanWeek1Catalogue(),
      ),
    );

    final result = await importer.dryRunYaml(yamlSource: yamlSource);

    // ignore: avoid_print
    print(result.summaryMessage);
    // ignore: avoid_print
    print('import_key=${result.importKey}');
    // ignore: avoid_print
    print('lineage_code=${result.lineageCode}');
    // ignore: avoid_print
    print('session_count=${result.sessionCount}');
    // ignore: avoid_print
    print('ready_for_apply=${result.readyForApply}');
    for (final error in result.validationErrors) {
      // ignore: avoid_print
      print('validation_error: $error');
    }
    for (final slug in result.unresolvedExerciseSlugs) {
      // ignore: avoid_print
      print('unresolved_slug: $slug');
    }
    for (final warning in result.warnings) {
      // ignore: avoid_print
      print('warning: $warning');
    }

    expect(result.readyForApply, isTrue);
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
