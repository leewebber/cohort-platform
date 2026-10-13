import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'protocol_authoring_isolation_test.dart' as traversal;

void main() {
  test('production and all older preview entries cannot reach composition', () {
    for (final entry in [
      'lib/main.dart',
      'lib/main_programme_studio_preview.dart',
      'lib/main_programme_studio_authoring_preview.dart',
      'lib/main_programme_studio_protocol_authoring_preview.dart',
      'lib/main_performance_tracking_review_preview.dart',
    ]) {
      expect(
        traversal
            .reachable(entry, strict: false)
            .where(
              (p) =>
                  p.contains('/programme_studio/composition/') ||
                  p.contains('main_programme_studio_composition_preview'),
            ),
        isEmpty,
        reason: entry,
      );
    }
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') ||
          f.path.contains('/programme_studio/composition/') ||
          f.path.endsWith('main_programme_studio_composition_preview.dart')) {
        continue;
      }
      final edges = RegExp(
        r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''',
        multiLine: true,
      );
      for (final edge in edges.allMatches(f.readAsStringSync())) {
        expect(edge.group(1), isNot(contains('/composition/')), reason: f.path);
      }
    }
  });
  test(
    'dedicated graph includes reused forms, existing compiler/Studio and no hosted or persistence services',
    () {
      final paths = traversal.reachable(
        'lib/main_programme_studio_composition_preview.dart',
      );
      for (final suffix in [
        'programme_authoring_screen.dart',
        'protocol_authoring_screen.dart',
        'founder_programme_import_validator.dart',
        'founder_programme_prescription_mapper.dart',
        'plan_package_compiler.dart',
        'programme_review_projector.dart',
      ]) {
        expect(paths.any((p) => p.endsWith(suffix)), true, reason: suffix);
      }
      for (final path in paths) {
        final s = File(path).readAsStringSync();
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
          expect(s.contains(forbidden), false, reason: '$path: $forbidden');
        }
        expect(path.contains('founder_programme_import_service'), false);
        expect(path.contains('session_revision_service'), false);
        expect(path.contains('/performance_tracking/'), false);
      }
    },
  );
}
