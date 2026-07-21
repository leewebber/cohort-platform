import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M10.1 migration adds Programme Version impact indexes', () {
    final migration = File(
      'supabase/migrations/20260721130000_add_programme_version_impact_indexes.sql',
    );
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('idx_training_session_records_assignment_terminal'));
    expect(sql, contains('idx_training_session_records_programme_session_terminal'));
    expect(sql, contains('idx_programme_assignments_version_active'));
    expect(sql, contains('idx_programme_version_weeks_version'));
    expect(sql, isNot(contains('DROP TABLE')));
  });
}
