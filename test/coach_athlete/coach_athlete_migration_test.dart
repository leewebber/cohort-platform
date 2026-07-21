import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260721150000_add_coach_athlete_relationships.sql',
  );

  test('coach athlete migration defines relationships, invites, and acceptance', () {
    expect(migrationFile.existsSync(), isTrue);

    final sql = migrationFile.readAsStringSync();
    expect(sql, contains('CREATE TABLE IF NOT EXISTS coach_athlete_relationships'));
    expect(sql, contains('CREATE TABLE IF NOT EXISTS coach_athlete_invites'));
    expect(sql, contains('accept_coach_athlete_invite'));
    expect(sql, contains('coach_athlete_relationships_one_active_per_athlete'));
    expect(sql, contains('dev_programme_assignments_coach_insert'));
    expect(sql, contains('profiles_select_linked_users'));
  });
}
