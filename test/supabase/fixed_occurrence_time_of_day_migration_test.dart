import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('occurrence JSON projection adds authored time_of_day only', () {
    final sql = File(
      'supabase/migrations/20260926190000_fixed_occurrence_time_of_day.sql',
    ).readAsStringSync();
    expect(sql, contains("'time_of_day', COALESCE(s.time_of_day, 'any')"));
    expect(sql, contains('programme_version_session_slots'));
    expect(sql, isNot(contains('UPDATE public.programme_assignments')));
    expect(sql, isNot(contains('lee@')));
  });
}
