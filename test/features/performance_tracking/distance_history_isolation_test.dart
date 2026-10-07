import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> reachable(String entry) {
  final seen = <String>{};
  final queue = [File(entry).absolute.path];
  final pattern = RegExp(r'''(?:import|export|part)\s+['"]([^'"]+)['"]''');
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!seen.add(path)) {
      continue;
    }
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    for (final match in pattern.allMatches(file.readAsStringSync())) {
      final ref = match[1]!;
      if (ref.startsWith('package:cohort_platform/')) {
        queue.add(File('lib/${ref.substring(24)}').absolute.path);
      } else if (!ref.startsWith('package:') && !ref.startsWith('dart:')) {
        queue.add(File.fromUri(file.uri.resolve(ref)).path);
      }
    }
  }
  return seen;
}

void main() {
  test(
    'production path reaches actual controller and C2/C3, never synthetic fixtures',
    () {
      final files = reachable('lib/main.dart');
      expect(
        files.any((f) => f.endsWith('distance_history_controller.dart')),
        isTrue,
      );
      expect(
        files.any((f) => f.endsWith('coherent_history_rpc_reader.dart')),
        isTrue,
      );
      expect(
        files.any((f) => f.endsWith('profile_tracking_evaluator.dart')),
        isTrue,
      );
      expect(
        files.where(
          (f) =>
              f.contains('internal_review/') ||
              f.contains('main_athlete_distance_review_preview'),
        ),
        isEmpty,
      );
    },
  );
  test(
    'preview uses actual athlete view and evaluator, with no production composition',
    () {
      final files = reachable('lib/main_athlete_distance_review_preview.dart');
      expect(
        files.any((f) => f.endsWith('distance_history_screen.dart')),
        isTrue,
      );
      expect(
        files.any((f) => f.endsWith('coherent_history_rpc_reader.dart')),
        isTrue,
      );
      expect(
        files.where(
          (f) =>
              f.contains('supabase_distance_history') ||
              f.contains('supabase_service') ||
              f.contains('supabase_history_tracking_rpc_client'),
        ),
        isEmpty,
      );
    },
  );
  test(
    'new consumer contains no programme reader, session table or write path',
    () {
      final files = Directory(
        'lib/features/performance_tracking',
      ).listSync().whereType<File>();
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(source.contains("from('training_sessions')"), isFalse);
        expect(source.contains('programme_history'), isFalse);
        expect(
          RegExp(r'\.(insert|upsert|update|delete)\(').hasMatch(source),
          isFalse,
        );
      }
    },
  );
}
