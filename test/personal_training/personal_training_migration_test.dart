import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260722120000_add_dual_role_self_assignment_policies.sql',
  );

  test('dual-role self-assignment migration defines helper and insert policy', () {
    expect(migrationFile.existsSync(), isTrue);

    final sql = migrationFile.readAsStringSync();
    expect(sql, contains('cohort_auth_is_dual_role_coach_athlete'));
    expect(sql, contains('programme_assignments_dual_role_self_insert'));
    expect(sql, contains('DROP POLICY IF EXISTS dev_programme_assignments_insert'));
    expect(sql, contains('athlete_id = auth.uid()'));
    expect(sql, contains('is_coach = TRUE'));
    expect(sql, contains('is_athlete = TRUE'));
  });
}
