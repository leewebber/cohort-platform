import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Follow all local package edges, including the nested importer, not just app
/// imports. External Flutter/yaml/crypto packages are toolchain dependencies.
Set<String> reachable(String entry, {bool strict = true}) {
  final queue = [File(entry).absolute.uri], seen = <String>{};
  final packages = {
    'cohort_platform': 'lib/',
    'cohort_plan_package': 'packages/cohort_plan_package/lib/',
    'founder_importer': 'tool/importer/lib/',
  };
  final links = RegExp(
    r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  while (queue.isNotEmpty) {
    final uri = queue.removeLast().normalizePath(), path = uri.toFilePath();
    if (!seen.add(path)) {
      continue;
    }
    final file = File(path);
    if (!file.existsSync()) {
      if (strict) {
        fail('Unresolved D2 local import: $path');
      }
      continue;
    }
    for (final m in links.allMatches(file.readAsStringSync())) {
      final spec = m.group(1)!;
      if (spec.startsWith('dart:')) {
        continue;
      }
      if (spec.startsWith('package:')) {
        final name = spec.substring(8).split('/').first,
            root = packages[spec.substring(8).split('/').first];
        if (root != null) {
          queue.add(
            File('$root${spec.substring(9 + name.length)}').absolute.uri,
          );
        }
      } else {
        queue.add(uri.resolve(spec));
      }
    }
  }
  return seen;
}

void main() {
  test('production, Studio, D1 and C4 entries cannot reach the D2 editor', () {
    for (final entry in [
      'lib/main.dart',
      'lib/main_programme_studio_preview.dart',
      'lib/main_programme_studio_authoring_preview.dart',
      'lib/main_performance_tracking_review_preview.dart',
    ]) {
      expect(File(entry).existsSync(), true);
      expect(
        reachable(entry, strict: false).where(
          (p) =>
              p.contains('/protocol_authoring/') ||
              p.contains('main_programme_studio_protocol_authoring_preview'),
        ),
        isEmpty,
        reason: entry,
      );
    }
  });
  test('no existing application source imports the new D2 folder or entry', () {
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.contains('/protocol_authoring/') ||
          file.path.endsWith(
            'main_programme_studio_protocol_authoring_preview.dart',
          )) {
        continue;
      }
      final links = RegExp(
        r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''',
        multiLine: true,
      );
      for (final link in links.allMatches(file.readAsStringSync())) {
        expect(
          link.group(1),
          isNot(contains('protocol_authoring')),
          reason: file.path,
        );
      }
    }
  });
  test(
    'dedicated D2 graph includes actual compiler and Studio, with no hosted/write services',
    () {
      final paths = reachable(
        'lib/main_programme_studio_protocol_authoring_preview.dart',
      );
      expect(
        paths.any((p) => p.endsWith('founder_programme_import_validator.dart')),
        true,
      );
      expect(
        paths.any(
          (p) => p.endsWith('founder_programme_prescription_mapper.dart'),
        ),
        true,
      );
      expect(paths.any((p) => p.endsWith('plan_package_compiler.dart')), true);
      expect(
        paths.any((p) => p.endsWith('programme_review_projector.dart')),
        true,
      );
      for (final path in paths) {
        final source = File(path).readAsStringSync();
        for (final forbidden in [
          'package:supabase',
          'Supabase.instance',
          'package:http',
          'package:shared_preferences',
          'dart:io',
          'dart:html',
          'localStorage',
          'File(',
          'import_authored_plan_package',
          'publish_private_exact_version',
          'enrol_athlete',
        ]) {
          expect(
            source.contains(forbidden),
            false,
            reason: '$path: $forbidden',
          );
        }
        expect(path.contains('founder_programme_import_service'), false);
        expect(path.contains('session_revision_service'), false);
        expect(path.contains('/performance_tracking/'), false);
      }
    },
  );
}
