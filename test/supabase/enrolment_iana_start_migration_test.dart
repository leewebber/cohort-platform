import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File(
    'supabase/migrations/20260923120000_enrolment_iana_timezone_and_local_start.sql',
  );

  test('IANA enrolment migration validates timezone and local start', () {
    expect(file.existsSync(), isTrue);
    final sql = file.readAsStringSync();
    expect(sql, contains('enrol_athlete_in_catalogue_programme_version'));
    expect(sql, contains('invalid_timezone'));
    expect(sql, contains('pg_timezone_names'));
    expect(sql, contains('(now() AT TIME ZONE v_tz)::date'));
    expect(sql, isNot(contains('CURRENT_DATE')));
    expect(sql, contains("GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) TO authenticated"));
    expect(sql, contains("REVOKE ALL ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) FROM anon"));
    expect(sql, contains('started_at'));
    expect(sql, contains("'timezone', v_tz"));
  });
}
