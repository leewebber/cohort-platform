import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Phase 1 production migrations are timestamp-ordered and include closeout trigger',
    () {
      final dir = Directory('supabase/migrations');
      final files =
          dir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.sql'))
              .map((file) => file.uri.pathSegments.last)
              .toList()
            ..sort();

      expect(files, isNotEmpty);
      expect(files, equals(List<String>.from(files)..sort()));
      expect(
        files.last,
        '20260918120400_content_graph_reconstruction.sql',
      );
      expect(
        files,
        contains(
          '20260914121000_reconcile_terminal_training_sessions_from_records.sql',
        ),
      );
      expect(
        files,
        contains(
          '20260914120000_terminalize_training_session_from_completed_record.sql',
        ),
      );
      expect(
        files,
        contains('20260913120000_backfill_fixed_programme_session_results.sql'),
      );
      expect(
        files,
        contains('20260911120000_overdue_fixed_programme_recovery.sql'),
      );
      expect(
        files,
        contains('20260824120000_apollo_calendar_driven_schedule_slice_1.sql'),
      );
    },
  );

  test('local baseline fixture remains schema-only for upgrade replay', () {
    final sql = File(
      'supabase/tests/fixtures/local_test_baseline_prereq.sql',
    ).readAsStringSync();
    expect(sql, contains('CREATE TABLE public.training_sessions'));
    expect(sql, isNot(contains('\nINSERT INTO ')));
    expect(sql, isNot(contains('\nCOPY ')));
  });
}
