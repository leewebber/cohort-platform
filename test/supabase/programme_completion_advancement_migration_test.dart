import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260801160000_complete_programme_session_and_advance.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('programme completion advancement migration', () {
    test('file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('defines atomic RPC with auth.uid and controlled search_path', () {
      expect(sql, contains('complete_programme_session_and_advance'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('SET search_path = public, pg_temp'));
      expect(sql, contains('FOR UPDATE'));
    });

    test('rejects client-nominated athlete and next cursor', () {
      expect(sql, contains('client_nominated_authority_forbidden'));
      expect(sql, contains("payload ? 'athlete_id'"));
      expect(sql, contains("payload ? 'next_cursor'"));
    });

    test('adds logical completion uniqueness and idempotency indexes', () {
      expect(sql, contains('logical_completion_key'));
      expect(sql, contains('idempotency_key'));
      expect(sql, contains('actuals_fingerprint'));
      expect(sql, contains('programme_slot_outcomes_logical_completion_uidx'));
      expect(sql, contains('programme_slot_outcomes_idempotency_uidx'));
    });

    test('protects cursor columns without weakening GUC bypass rules', () {
      expect(sql, contains('current_week_number'));
      expect(sql, contains('current_day_key'));
      expect(sql, contains('current_slot_order'));
      expect(sql, contains("current_user IN ('postgres', 'supabase_admin')"));
      expect(sql, contains('cohort.allow_materialisation_write'));
    });

    test('grants authenticated and revokes anon/public', () {
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.complete_programme_session_and_advance(JSONB) FROM PUBLIC',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.complete_programme_session_and_advance(JSONB) FROM anon',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.complete_programme_session_and_advance(JSONB) TO authenticated',
        ),
      );
    });

    test('derives next authored slot from package order', () {
      expect(sql, contains('cohort_programme_version_next_executable_slot'));
      expect(sql, contains('ORDER BY w.week_number ASC, d.day_order ASC, s.session_order ASC'));
    });
  });
}
