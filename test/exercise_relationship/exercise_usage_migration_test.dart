import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M9.4 migration adds exercise usage indexes', () {
    final migration = File(
      'supabase/migrations/20260721120000_add_exercise_usage_indexes.sql',
    );
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('idx_session_block_exercises_exercise_id'));
    expect(sql, contains('idx_training_exercise_results_source_exercise_terminal'));
    expect(sql, isNot(contains('CREATE TABLE')));
  });
}
