import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 3.1F Part 1b — catalogue export provenance + inventory checks.
/// Does not contact hosted environments.
void main() {
  final root = _repoRoot(Directory.current);

  test('export meta records authoritative complete published catalogue', () {
    final metaFile = File(
      '$root/docs/architecture/reviews/'
      'exercises_v2_published_export_phase_3_1f_part1b.meta.json',
    );
    expect(metaFile.existsSync(), isTrue);
    final meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    expect(meta['table'], 'public.exercises_v2');
    expect(meta['scope'], 'published IS TRUE');
    expect(meta['row_count'], 127);
    expect(meta['min_exercise_id'], 'EX-001');
    expect(meta['max_exercise_id'], 'EX-127');
    expect(meta['malformed_id_count'], 0);
    expect(meta['duplicate_id_count'], 0);
    expect(meta['source_authority_classification'], 'AUTHORITATIVE_COMPLETE');
    expect(meta['hosted_mutation_performed'], isFalse);
    expect(meta['contains_connection_secrets'], isFalse);
  });

  test('transitional inventory remains 21 with zero platform_exercise_id', () {
    final yaml = File(
      '$root/knowledge/reference/exercises_reference.yaml',
    ).readAsStringSync();
    final ids = RegExp(r'^\s+- id: (cohort\.exercise\.[a-z0-9_]+)', multiLine: true)
        .allMatches(yaml)
        .map((m) => m.group(1)!)
        .toList();
    expect(ids.length, 21);
    expect(yaml.contains('platform_exercise_id'), isFalse);
  });

  test('Part 1b review doc completes matrix without implementing mappings', () {
    final text = File(
      '$root/docs/architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md',
    ).readAsStringSync();
    expect(text.contains('FOUNDER_MAPPING_MATRIX_COMPLETE=true'), isTrue);
    expect(text.contains('AUTHORITATIVE_COMPLETE'), isTrue);
    expect(text.contains('PROPOSED_MAPPING_COUNT=14'), isTrue);
    expect(text.contains('PRODUCTION_MAPPINGS_IMPLEMENTED=false'), isTrue);
    expect(text.contains('HEURISTIC_IDENTITY_MATCHING_USED=false'), isTrue);
    expect(text.contains('HOSTED_MUTATION_PERFORMED=false'), isTrue);
  });

  test('raw export is gitignored when present', () {
    final gitignore = File('$root/.gitignore').readAsStringSync();
    expect(
      gitignore.contains(
        'docs/architecture/reviews/exercises_v2_published_export_*.json',
      ),
      isTrue,
    );
  });

  test('lib does not load Part 1b review export or matrix', () {
    final lib = Directory('$root/lib');
    final offenders = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('exercises_v2_published_export_phase_3_1f') ||
          source.contains('FOUNDER_MAPPING_MATRIX_COMPLETE') ||
          source.contains('Phase_3_1F_Part1')) {
        offenders.add(entity.path.substring(root.length + 1));
      }
    }
    expect(offenders, isEmpty, reason: 'Offenders: $offenders');
  });
}

String _repoRoot(Directory start) {
  var dir = start;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${start.path}');
    }
    dir = parent;
  }
}
