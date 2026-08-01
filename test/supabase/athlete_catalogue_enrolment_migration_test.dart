import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260801120000_athlete_catalogue_enrolment.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('athlete catalogue enrolment migration', () {
    test('file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('adds enrolment_source without payment tables', () {
      expect(sql, contains('enrolment_source'));
      expect(sql, contains('non_commercial_test'));
      expect(sql, isNot(contains('CREATE TABLE public.subscriptions')));
      expect(sql, isNot(contains('CREATE TABLE public.purchases')));
      expect(sql, isNot(contains('stripe')));
    });

    test('defines enrolment RPC with auth.uid ownership', () {
      expect(sql, contains('enrol_athlete_in_catalogue_programme_version'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('SET search_path = public, pg_temp'));
      expect(sql, contains('cohort_programme_version_is_catalogue_eligible'));
      expect(
        sql,
        contains('cohort_athlete_may_use_non_commercial_catalogue_enrolment'),
      );
    });

    test('grants execute to authenticated and revokes anon', () {
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN)\n'
          '  TO authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN)\n'
          '  FROM anon',
        ),
      );
    });

    test('eligibility requires published approved cohort_global', () {
      expect(sql, contains("lifecycle_status = 'published'"));
      expect(sql, contains("library_scope = 'cohort_global'"));
      expect(sql, contains('approved_for_global = TRUE'));
    });

    test('documents temporary non-commercial seam', () {
      expect(sql, contains('TEMPORARY Sprint 1.3'));
      expect(sql, contains('recurring subscription'));
      expect(sql, contains('Not a purchase'));
    });

    test('grants authenticated select/update on assignments without insert', () {
      expect(
        sql,
        contains(
          'GRANT SELECT, UPDATE ON TABLE public.programme_assignments TO authenticated',
        ),
      );
      expect(
        sql,
        isNot(contains('GRANT INSERT ON TABLE public.programme_assignments')),
      );
    });
  });
}
