import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M9.2 migration adds terminal source_protocol_id index', () {
    final migration = File(
      'supabase/migrations/20260721110000_add_session_revision_usage_indexes.sql',
    );
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('idx_training_session_records_source_protocol_terminal'));
    expect(sql, contains('source_protocol_id'));
    expect(sql, contains("status <> 'in_progress'"));
    expect(sql, isNot(contains('CREATE TABLE')));
  });
}
