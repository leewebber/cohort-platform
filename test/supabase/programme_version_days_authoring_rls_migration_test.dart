import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260722160000_fix_programme_version_days_authoring_rls.sql',
  );

  late String migrationSql;

  setUpAll(() {
    migrationSql = migrationFile.readAsStringSync();
  });

  group('programme_version_days authoring RLS fix', () {
    test('migration exists after lineage/version INSERT RETURNING fix', () {
      expect(migrationFile.existsSync(), isTrue);
      expect(
        migrationSql,
        contains('20260722150000_fix_authenticated_programme_authoring_insert_returning.sql'),
      );
    });

    test('replaces day-id policies with week_id ownership for INSERT RETURNING', () {
      expect(
        migrationSql,
        contains('DROP POLICY IF EXISTS programme_version_days_select_coach'),
      );
      expect(
        migrationSql,
        contains('DROP POLICY IF EXISTS programme_version_days_write_coach'),
      );
      expect(
        migrationSql,
        contains(
          'CREATE POLICY programme_version_days_select_coach\n'
          '  ON programme_version_days\n'
          '  FOR SELECT\n'
          '  TO authenticated\n'
          '  USING (cohort_programme_week_is_dev_coach_readable(week_id))',
        ),
      );
      expect(
        migrationSql,
        contains(
          'WITH CHECK (cohort_programme_week_is_dev_coach_draft_writable(week_id))',
        ),
      );
    });

    test('week helper joins lineage and version owner_id to auth.uid()', () {
      expect(migrationSql, contains('JOIN programme_lineages l ON l.id = v.lineage_id'));
      expect(migrationSql, contains('AND v.owner_id = auth.uid()::TEXT'));
      expect(migrationSql, contains('AND l.created_by = auth.uid()::TEXT'));
    });

    test('session slot write policy uses week ownership chain', () {
      expect(
        migrationSql,
        contains('DROP POLICY IF EXISTS programme_version_session_slots_write_coach'),
      );
      expect(
        migrationSql,
        contains('cohort_programme_week_is_dev_coach_draft_writable(d.week_id)'),
      );
    });

    test('does not broaden access to anon or dev-coach', () {
      expect(migrationSql, isNot(contains("TO anon")));
      expect(migrationSql, isNot(contains("'dev-coach'")));
    });
  });
}
