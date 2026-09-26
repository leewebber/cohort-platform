import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260926170000_private_exercise_capture_repair.sql',
  ).readAsStringSync();

  test('capture repair remains service-role only', () {
    expect(sql, contains('repair_private_programme_exercise_capture'));
    expect(sql, contains('exercise_capture_required'));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.repair_private_programme_exercise_capture(JSONB)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(sql, isNot(contains('lee@')));
    expect(sql, isNot(contains('95ee6900')));
  });
}
