import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260927150000_occurrence_running_target_snapshot.sql',
  ).readAsStringSync();
  final gate = File(
    'supabase/tests/sql/gate_bk_occurrence_running_target_snapshot.sql',
  ).readAsStringSync();

  test('only explicit published v2 authored running slots participate', () {
    expect(migration, contains('v_version.package_schema_version = 2'));
    expect(migration, contains('v_authored.authored_running_v1 IS NOT NULL'));
    expect(migration, contains('public.cohort_authored_running_v1_is_valid'));
    expect(gate, contains("'v2_unattached_legacy_path'"));
    expect(gate, contains("'v1_bali_shape_legacy_path'"));
  });

  test('snapshot is occurrence-owned, insert-once, and transaction-bound', () {
    expect(migration, contains('occurrence_id UUID PRIMARY KEY'));
    expect(
      migration,
      contains('programme_occurrence_running_target_snapshot_immutable'),
    );
    expect(gate, contains("'snapshot_failure_rolls_back_start'"));
    expect(gate, contains("'retry_returns_identical_snapshot'"));
  });

  test('slice has no UI, Bali content, or device-export wiring', () {
    expect(migration, isNot(contains('Bali')));
    expect(migration, isNot(contains('garmin')));
    expect(migration, isNot(contains("'freeze_source', 'device_export'")));
    expect(migration, isNot(contains('Widget')));
  });
}
