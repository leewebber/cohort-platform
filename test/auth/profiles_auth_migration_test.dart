import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260721140000_add_profiles_and_auth_rls.sql',
  );

  test('profiles and auth RLS migration exists with required objects', () {
    expect(migrationFile.existsSync(), isTrue);

    final sql = migrationFile.readAsStringSync();
    expect(sql, contains('CREATE TABLE IF NOT EXISTS profiles'));
    expect(sql, contains('profiles_select_own'));
    expect(sql, contains('auth.uid()'));
    expect(sql, contains('CREATE OR REPLACE FUNCTION cohort_programme_dev_athlete_ids()'));
  });
}
