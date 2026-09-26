import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260926170000_private_exercise_capture_repair.sql',
  ).readAsStringSync();
  final inProgress = File(
    'supabase/migrations/20260926180000_private_exercise_capture_repair_in_progress.sql',
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

  test('empty-load in-progress does not count as blocking evidence', () {
    expect(inProgress, contains('sr.load IS NOT NULL'));
    expect(inProgress, contains("'completed_partial'"));
    expect(inProgress, isNot(contains('t.protocol_id IN (')));
    expect(
      inProgress,
      contains(
        'REVOKE ALL ON FUNCTION public.repair_private_programme_exercise_capture(JSONB)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
  });
}
