import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260926130000_private_exact_version_enrolment.sql',
  ).readAsStringSync();

  test('private enrol is a distinct lifecycle RPC with minimal grants', () {
    expect(sql, contains('enrol_athlete_in_private_programme_version'));
    expect(sql, contains('cohort_programme_version_is_private_assignable'));
    expect(sql, contains('library_scope IN (\'coach_private\', \'organisation\')'));
    expect(sql, isNot(contains('approved_for_global IS TRUE')));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN)\n'
        '  FROM PUBLIC, anon;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN)\n'
        '  TO authenticated, service_role;',
      ),
    );
    expect(sql, contains('use_catalogue_enrolment'));
    expect(sql, isNot(contains('lee')));
  });

  test('public catalogue enrol is not rewritten', () {
    expect(sql, isNot(contains('CREATE OR REPLACE FUNCTION public.enrol_athlete_in_catalogue_programme_version')));
  });
}
