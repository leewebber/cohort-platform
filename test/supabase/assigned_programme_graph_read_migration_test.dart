import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260926150000_assigned_programme_graph_read.sql',
  ).readAsStringSync();

  test('assigned graph read is select-only and unguessable', () {
    expect(sql, contains('cohort_can_read_assigned_programme_version'));
    expect(sql, contains('programme_version_days_select_assigned'));
    expect(sql, contains('athlete_id = auth.uid()'));
    expect(sql, isNot(contains('UPDATE public.programme_assignments')));
    expect(sql, isNot(contains('enrol_athlete_in_private_programme_version')));
    expect(sql, isNot(contains('lee')));
    expect(sql, isNot(contains('b1a1b001-0000-4000-8000-ba11b0010001')));
  });
}
