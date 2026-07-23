import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260723100000_fix_programme_version_publish_rls.sql',
  );

  late String migrationSql;

  setUpAll(() {
    migrationSql = migrationFile.readAsStringSync();
  });

  group('programme version publish RLS fix', () {
    test('migration file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('documents draft-only USING with published WITH CHECK transition', () {
      expect(
        migrationSql,
        contains('DROP POLICY IF EXISTS programme_versions_update_coach_draft'),
      );
      expect(
        migrationSql,
        contains("lifecycle_status = 'draft'\n    AND owner_type = 'coach'"),
      );
      expect(
        migrationSql,
        contains(
          "lifecycle_status = 'published'\n        AND published_at IS NOT NULL",
        ),
      );
    });

    test('adds archive transition without blanket authenticated update', () {
      expect(migrationSql, contains('programme_versions_archive_coach'));
      expect(migrationSql, contains("lifecycle_status = 'archived'"));
      expect(migrationSql, isNot(contains('USING (true)')));
      expect(migrationSql, isNot(contains('WITH CHECK (true)')));
      expect(migrationSql, isNot(contains('TO anon')));
    });

    test('preserves coach ownership and lineage ownership chain', () {
      expect(migrationSql, contains('cohort_auth_is_coach()'));
      expect(migrationSql, contains('owner_id = auth.uid()::TEXT'));
      expect(
        migrationSql,
        contains('cohort_programme_lineage_is_dev_coach_owned(lineage_id)'),
      );
      expect(migrationSql, contains("library_scope = 'coach_private'"));
    });

    test('documents cross-role denial verification', () {
      expect(migrationSql, contains('Athlete role UPDATE draft → denied'));
      expect(
        migrationSql,
        contains('UPDATE published row content in place → denied'),
      );
    });
  });
}
