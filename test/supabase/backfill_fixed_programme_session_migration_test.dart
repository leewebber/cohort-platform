import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final overdue = File(
    'supabase/migrations/20260911120000_overdue_fixed_programme_recovery.sql',
  );
  final backfill = File(
    'supabase/migrations/20260913120000_backfill_fixed_programme_session_results.sql',
  );

  late String overdueSql;
  late String backfillSql;

  setUpAll(() {
    overdueSql = overdue.readAsStringSync();
    backfillSql = backfill.readAsStringSync();
  });

  group('overdue recovery migration', () {
    test('replaces recovery functions without rewriting rows', () {
      expect(overdue.existsSync(), isTrue);
      expect(
        overdueSql,
        contains('does not rewrite historical'),
      );
      expect(
        overdueSql,
        contains('CREATE OR REPLACE FUNCTION public.cohort_reconcile_fixed_programme_schedule_at'),
      );
      expect(
        overdueSql,
        contains('CREATE OR REPLACE FUNCTION public.cohort_create_or_resume_fixed_occurrence_at'),
      );
      expect(
        overdueSql,
        contains('CREATE OR REPLACE FUNCTION public.recover_overdue_fixed_programme_occurrence'),
      );
      expect(overdueSql, contains("disposition IN ('scheduled', 'missed')"));
      expect(overdueSql, contains('occurrence_skipped'));
      expect(
        overdueSql,
        contains('GRANT EXECUTE ON FUNCTION public.recover_overdue_fixed_programme_occurrence(JSONB)'),
      );
    });
  });

  group('backfill persistence migration', () {
    test('extends training_session_records without scheduled_date or recorded_at', () {
      expect(backfill.existsSync(), isTrue);
      expect(backfillSql, contains('ADD COLUMN IF NOT EXISTS entry_mode'));
      expect(backfillSql, contains('ADD COLUMN IF NOT EXISTS performed_on'));
      expect(backfillSql, contains('ADD COLUMN IF NOT EXISTS performed_precision'));
      expect(backfillSql, isNot(contains('ADD COLUMN IF NOT EXISTS recorded_at')));
      expect(backfillSql, isNot(contains('ADD COLUMN IF NOT EXISTS scheduled_date')));
      expect(
        backfillSql,
        contains('complete_backfilled_fixed_programme_occurrence'),
      );
      expect(backfillSql, contains('cohort_athlete_runtime_capabilities'));
      expect(
        backfillSql,
        contains('GRANT EXECUTE ON FUNCTION public.complete_backfilled_fixed_programme_occurrence(JSONB)'),
      );
      expect(
        backfillSql,
        contains('GRANT EXECUTE ON FUNCTION public.cohort_athlete_runtime_capabilities()'),
      );
      expect(backfillSql, contains('backfill:'));
      expect(backfillSql, contains('occurrence_in_progress'));
      expect(backfillSql, contains('empty_result_tree'));
    });
  });
}
