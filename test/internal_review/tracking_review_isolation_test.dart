import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> reachable(String entry) {
  final visited = <String>{};
  final queue = [entry];
  final refs = RegExp(r'''(?:import|export|part)\s+['"]([^'"]+)['"]''');
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!visited.add(path)) continue;
    final f = File(path);
    if (!f.existsSync()) continue;
    for (final match in refs.allMatches(f.readAsStringSync())) {
      final spec = match[1]!;
      if (spec.startsWith('dart:')) continue;
      if (spec.startsWith('package:cohort_platform/')) {
        queue.add('lib/${spec.substring('package:cohort_platform/'.length)}');
      } else if (!spec.startsWith('package:')) {
        queue.add(File.fromUri(f.absolute.uri.resolve(spec)).path);
      }
    }
  }
  return visited;
}

void main() {
  test('production and existing Studio entries cannot reach C4 preview', () {
    for (final entry in [
      'lib/main.dart',
      'lib/main_programme_studio_preview.dart',
    ]) {
      expect(File(entry).existsSync(), isTrue);
      expect(
        reachable(entry).where(
          (p) =>
              p.contains('internal_review/performance_tracking') ||
              p.contains('main_performance_tracking_review_preview'),
        ),
        isEmpty,
        reason: entry,
      );
    }
  });

  test(
    'C4 reaches actual evaluator and adapter without live services or stores',
    () {
      final files = reachable(
        'lib/main_performance_tracking_review_preview.dart',
      );
      expect(
        files.any((p) => p.endsWith('profile_tracking_evaluator.dart')),
        isTrue,
      );
      expect(
        files.any((p) => p.endsWith('history_tracking_adapter.dart')),
        isTrue,
      );
      for (final path in files) {
        expect(path.contains('/test/'), isFalse);
        if (!File(path).existsSync()) continue;
        final source = File(path).readAsStringSync();
        for (final token in [
          'package:supabase',
          'SupabaseClient',
          'HttpClient',
          'package:http/',
          'SharedPreferences',
          'rootBundle',
          'dart:io',
        ]) {
          expect(source.contains(token), isFalse, reason: '$path: $token');
        }
      }
    },
  );
}
