import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260914121000_reconcile_terminal_training_sessions_from_records.sql',
  );

  test(
    'historical reconciliation is generic, evidence-gated and idempotent',
    () {
      final sql = migration.readAsStringSync();
      expect(migration.existsSync(), isTrue);
      expect(
        sql,
        contains('cohort_reconcile_terminal_training_sessions_from_records'),
      );
      expect(sql, contains("status IN ('completed', 'partially_completed')"));
      expect(sql, contains('linked_count = 1'));
      expect(sql, contains('terminal_count = 1'));
      expect(sql, contains('training_block_results'));
      expect(sql, contains('COALESCE(ts.completed_at, q.completed_at)'));
      expect(sql, isNot(contains('completed_at = NOW()')));
      expect(sql, isNot(contains('79853f15')));
      expect(sql, isNot(contains('UPDATE public.training_session_records')));
      expect(sql, isNot(contains('programme_schedule_occurrences')));
      expect(sql, isNot(contains('current_week_number')));
    },
  );
}
