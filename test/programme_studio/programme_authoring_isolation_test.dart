import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Set<String> reachable(String entry) {
    final seen = <String>{};
    final queue = [entry];
    final links = RegExp(
      r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    while (queue.isNotEmpty) {
      final path = queue.removeLast();
      if (!seen.add(path) || !File(path).existsSync()) continue;
      final text = File(path).readAsStringSync();
      for (final link in links.allMatches(text)) {
        final spec = link.group(1)!;
        if (spec.startsWith('package:cohort_platform/')) {
          queue.add('lib/${spec.substring('package:cohort_platform/'.length)}');
        } else if (!spec.startsWith('package:') && !spec.startsWith('dart:')) {
          final uri = Uri.file(path).resolve(spec).normalizePath();
          queue.add(
            uri.path.startsWith('/') ? uri.path.substring(1) : uri.path,
          );
        }
      }
    }
    return seen;
  }

  test(
    'production and existing Studio entry cannot reach D1 authoring or fixtures',
    () {
      for (final entry in [
        'lib/main.dart',
        'lib/main_programme_studio_preview.dart',
      ]) {
        final visited = reachable(entry);
        expect(
          visited.where(
            (p) =>
                p.contains('/authoring/') ||
                p.contains('main_programme_studio_authoring_preview'),
          ),
          isEmpty,
        );
      }
      final preview = reachable(
        'lib/main_programme_studio_authoring_preview.dart',
      );
      expect(
        preview,
        contains(
          'lib/features/programme_studio/authoring/programme_authoring_controller.dart',
        ),
      );
      expect(
        preview,
        contains(
          'lib/features/programme_studio/projection/programme_review_projector.dart',
        ),
      );
    },
  );

  test(
    'D1 contains no live transport persistence or publication authority',
    () {
      final sources = Directory(
        'lib/features/programme_studio/authoring',
      ).listSync().whereType<File>();
      for (final file in sources) {
        final text = file.readAsStringSync();
        for (final prohibited in [
          'package:supabase',
          'SupabaseClient',
          'Supabase.instance',
          'dart:io',
          'dart:html',
          'package:http',
          'package:shared_preferences',
          'localStorage',
          'File(',
          'import_authored_plan_package',
          'publish_cohort_global_programme_version',
          'publish_private_exact_version',
          'enrol_athlete',
        ]) {
          expect(
            text,
            isNot(contains(prohibited)),
            reason: '${file.path}: $prohibited',
          );
        }
      }
      final preview = reachable(
        'lib/main_programme_studio_authoring_preview.dart',
      );
      expect(
        preview.where(
          (p) =>
              p.contains('/performance_tracking/') ||
              p.contains('/coach_studio/'),
        ),
        isEmpty,
      );
    },
  );
}
