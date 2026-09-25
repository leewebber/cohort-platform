import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production main cannot reach Programme Studio or its preview', () {
    final visited = <String>{};
    final queue = ['lib/main.dart'];
    final importRe = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true);
    final hits = <String>[];

    while (queue.isNotEmpty) {
      final path = queue.removeLast();
      if (!visited.add(path)) {
        continue;
      }
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final source = file.readAsStringSync();
      if (source.contains('programme_studio') ||
          source.contains('main_programme_studio_preview')) {
        hits.add(path);
      }
      for (final match in importRe.allMatches(source)) {
        final spec = match.group(1)!;
        if (spec.startsWith('package:cohort_platform/')) {
          queue.add('lib/${spec.substring('package:cohort_platform/'.length)}');
        } else if (spec.startsWith('package:')) {
          continue;
        } else if (spec.startsWith('dart:')) {
          continue;
        } else {
          queue.add(_resolve(path, '${spec.split('.dart').first}.dart'));
        }
      }
    }

    expect(visited, contains('lib/main.dart'));
    expect(hits, isEmpty, reason: hits.join('\n'));
    expect(
      File('lib/main.dart').readAsStringSync(),
      isNot(contains('main_programme_studio_preview')),
    );
  });

  test('studio sources do not call hosted services', () {
    final files = Directory('lib/features/programme_studio')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final violations = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final token in [
        'package:supabase',
        'SupabaseClient',
        'Supabase.instance',
        'enrol_athlete',
        'import_authored_plan_package',
        'publish_cohort_global_programme_version',
        'HttpClient',
      ]) {
        if (source.contains(token)) {
          violations.add('${file.path} contains $token');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String _resolve(String from, String spec) {
  if (!spec.startsWith('.')) {
    return spec;
  }
  final fromDir = from.split('/')..removeLast();
  final parts = [...fromDir, ...spec.split('/')];
  final resolved = <String>[];
  for (final part in parts) {
    if (part == '.' || part.isEmpty) {
      continue;
    }
    if (part == '..') {
      if (resolved.isNotEmpty) {
        resolved.removeLast();
      }
      continue;
    }
    resolved.add(part);
  }
  return resolved.join('/');
}
