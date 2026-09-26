import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260926200000_private_assignment_fixed_schedule.sql',
  ).readAsStringSync();

  test('private enrol inserts fixed_schedule and repair is service-role only', () {
    expect(sql, contains("schedule_mode\n  ) VALUES ("));
    expect(sql, contains("'fixed_schedule'"));
    expect(
      sql,
      contains('repair_private_materialised_assignment_schedule_mode'),
    );
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.repair_private_materialised_assignment_schedule_mode(JSONB)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.repair_private_materialised_assignment_schedule_mode(JSONB)\n'
        '  TO service_role;',
      ),
    );
    expect(sql, contains('session_evidence_incomplete'));
    expect(sql, contains('assignment_not_repairable'));
    expect(sql, isNot(contains('lee@')));
    expect(sql, isNot(contains('enrol_athlete_in_catalogue_programme_version')));
  });
}
