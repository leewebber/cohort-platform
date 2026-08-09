import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 3.1F Part 1 — review artifacts must remain non-operational.
void main() {
  final root = _repoRoot(Directory.current);

  test('Part 1 review document exists and marks catalogue blocked', () {
    final doc = File(
      '$root/docs/architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md',
    );
    expect(doc.existsSync(), isTrue);
    final text = doc.readAsStringSync();
    expect(text.contains('BLOCKED_AUTHORITATIVE_CATALOGUE_UNAVAILABLE'), isTrue);
    expect(text.contains('AUTHORITATIVE_CANONICAL_CATALOGUE_AVAILABLE=false'), isTrue);
    expect(text.contains('PRODUCTION_MAPPINGS_IMPLEMENTED=false'), isTrue);
    expect(text.contains('HEURISTIC_IDENTITY_MATCHING_USED=false'), isTrue);
  });

  test('no DRAFT_NOT_APPROVED mapping manifest is loaded by lib/', () {
    final lib = Directory('$root/lib');
    final offenders = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('DRAFT_NOT_APPROVED') ||
          source.contains('Phase_3_1F_Part1') ||
          source.contains('identity_mapping_review')) {
        offenders.add(entity.path.substring(root.length + 1));
      }
    }
    expect(offenders, isEmpty, reason: 'Offenders: $offenders');
  });

  test('EX-900x fixture ids are not treated as production catalogue in review doc',
      () {
    final text = File(
      '$root/docs/architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md',
    ).readAsStringSync();
    expect(text.contains('Fixture-only'), isTrue);
    expect(text.contains('Forbidden'), isTrue);
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
