import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260801140000_athlete_plan_materialisation.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('athlete plan materialisation migration', () {
    test('file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test(
      'adds materialisation columns without parallel athlete_plans table',
      () {
        expect(sql, contains('materialised_at'));
        expect(sql, contains('materialisation_source'));
        expect(sql, contains('materialised_package_content_hash'));
        expect(sql, contains('athlete_start_programme'));
        expect(sql, isNot(contains('CREATE TABLE public.athlete_plans')));
        expect(sql, isNot(contains('CREATE TABLE public.subscriptions')));
        expect(sql, isNot(contains('prepared_sessions')));
      },
    );

    test('enforces one active materialised assignment per athlete', () {
      expect(
        sql,
        contains('programme_assignments_one_active_materialised_per_athlete'),
      );
    });

    test('defines materialisation RPC with auth.uid ownership', () {
      expect(sql, contains('materialise_athlete_plan_from_enrolment'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('SET search_path = public, pg_temp'));
      expect(sql, contains('cohort.allow_materialisation_write'));
    });

    test('grants execute to authenticated and revokes anon', () {
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT)\n'
          '  TO authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT)\n'
          '  FROM anon',
        ),
      );
    });

    test(
      'protects materialisation columns from direct authenticated writes',
      () {
        expect(
          sql,
          contains('cohort_programme_assignment_protect_materialisation'),
        );
        expect(
          sql,
          contains('materialisation-controlled columns are RPC-only'),
        );
      },
    );

    test('uses athlete-local today and first executable slot', () {
      expect(sql, contains('cohort_resolve_athlete_local_date'));
      expect(sql, contains('cohort_programme_version_first_executable_slot'));
      expect(sql, contains('Start today'));
    });

    test('does not retrospectively materialise existing rows', () {
      expect(sql, contains('existing rows stay non-materialised'));
      expect(sql, isNot(contains('SET materialised_at = NOW()')));
    });
  });
}
