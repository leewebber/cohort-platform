import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260914120000_terminalize_training_session_from_completed_record.sql',
  );

  test('terminal session trigger is additive and evidence-gated', () {
    final sql = migration.readAsStringSync();
    expect(migration.existsSync(), isTrue);
    expect(
      sql,
      contains('CREATE TRIGGER trg_sync_training_session_from_terminal_record'),
    );
    expect(sql, contains('AFTER INSERT OR UPDATE OF status'));
    expect(sql, contains('No migration-time row writes'));
    expect(sql, isNot(contains('INSERT INTO public.training_sessions')));
  });
}
