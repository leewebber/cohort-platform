import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M9.1 session lineage migration', () {
    late String migrationSql;

    setUpAll(() {
      migrationSql = File(
        'supabase/migrations/20260721100000_add_session_lineages_and_revisions.sql',
      ).readAsStringSync();
    });

    test('creates session_lineages and revision columns additively', () {
      expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS session_lineages'));
      expect(migrationSql, contains('session_lineage_id UUID'));
      expect(migrationSql, contains('revision_number INT'));
      expect(migrationSql, contains('lifecycle_status TEXT'));
    });

    test('backfills existing protocols as revision 1 without changing protocol_id', () {
      expect(migrationSql, contains('revision_number = 1'));
      expect(migrationSql, contains('WHERE session_lineage_id IS NULL'));
      expect(migrationSql, isNot(contains('UPDATE performance_protocols SET protocol_id')));
    });

    test('defines lifecycle and lineage revision constraints', () {
      expect(migrationSql, contains('performance_protocols_lifecycle_status_check'));
      expect(migrationSql, contains('performance_protocols_lineage_revision_unique'));
    });
  });
}
