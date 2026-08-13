import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/'
    '20260813140000_atomic_programme_training_session_start.sql',
  ).readAsStringSync();

  test('adds transactional authenticated create-or-resume RPC', () {
    expect(sql, contains('create_or_resume_programme_training_session'));
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('auth.uid()'));
    expect(sql, contains('cohort_auth_is_athlete()'));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains('TO authenticated'));
    expect(sql, contains('FROM anon'));
  });

  test('enforces one occurrence link per training session without repair', () {
    expect(sql, contains('programme_slot_outcomes_training_session_uidx'));
    expect(sql, contains('WHERE training_session_id IS NOT NULL'));
    expect(sql, contains('HAVING count(*) > 1'));
    expect(sql, isNot(contains('DELETE FROM public.programme_slot_outcomes')));
    expect(sql, isNot(contains('TRUNCATE')));
  });

  test(
    'validates exact assignment version slot cursor and package authority',
    () {
      expect(sql, contains('cross_athlete_assignment'));
      expect(sql, contains('exact_version_missing'));
      expect(sql, contains('package_hash_mismatch'));
      expect(sql, contains('authored_slot_mismatch'));
      expect(sql, contains('programme_key_mismatch'));
      expect(sql, contains('stale_cursor'));
      expect(sql, contains("v_package_hash !~ '^[0-9a-f]{64}\$'"));
    },
  );

  test('creates session and occurrence link in the same function', () {
    final sessionInsert = sql.indexOf('INSERT INTO public.training_sessions');
    final outcomeWrite = sql.indexOf(
      'INSERT INTO public.programme_slot_outcomes',
    );

    expect(sessionInsert, greaterThan(-1));
    expect(outcomeWrite, greaterThan(sessionInsert));
    expect(sql, contains("'status', 'created'"));
    expect(sql, contains("'status', 'resumed'"));
  });

  test(
    'stores lineage compatibility and accepts existing version-id links',
    () {
      expect(sql, contains('v_assignment.lineage_code'));
      expect(sql, contains('v_session.programme_id NOT IN'));
      expect(sql, contains('v_programme_version_id::TEXT'));
    },
  );
}
