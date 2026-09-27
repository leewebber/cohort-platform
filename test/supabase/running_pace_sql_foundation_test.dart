import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260927140000_running_pace_sql_foundation.sql',
  ).readAsStringSync();
  final gate = File(
    'supabase/tests/sql/gate_bj_running_pace_sql_foundation.sql',
  ).readAsStringSync();

  test('unproven Cohort ingestion is blocked without changing manual input', () {
    expect(migration, contains("'cohort_test_completion_unproven'"));
    expect(
      migration,
      isNot(
        contains(
          'CREATE OR REPLACE FUNCTION public.record_manual_completed_5k_benchmark',
        ),
      ),
    );
    expect(migration, contains("AND e.source_kind = 'manual'"));
  });

  test(
    'selection and exact calculation are side-effect-free SQL boundaries',
    () {
      expect(migration, contains('public.cohort_select_running_5k_benchmark'));
      expect(migration, contains('public.cohort_calculate_running_pace_range'));
      expect(migration, contains('LANGUAGE plpgsql\nIMMUTABLE'));
      expect(migration, contains('p_maximum_speed_basis_points'));
      expect(migration, contains('p_minimum_speed_basis_points'));
      expect(
        gate,
        contains("'sql_selection_and_calculation_side_effect_free'"),
      );
    },
  );

  test('slice does not alter Plan Package or programme content', () {
    expect(migration, isNot(contains('programme_version_session_slots')));
    expect(migration, isNot(contains('authored_running_v1')));
    expect(migration, isNot(contains('Bali')));
  });
}
