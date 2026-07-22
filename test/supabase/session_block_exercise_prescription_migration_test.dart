import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration adds prescription JSONB to session_block_exercises', () {
    final migration = File(
      'supabase/migrations/20260722170000_add_session_block_exercise_prescriptions.sql',
    );
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('session_block_exercises'));
    expect(sql, contains('prescription JSONB'));
  });
}
