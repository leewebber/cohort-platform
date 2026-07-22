import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260722150000_fix_authenticated_programme_authoring_insert_returning.sql',
  );

  late String migrationSql;

  setUpAll(() {
    migrationSql = migrationFile.readAsStringSync();
  });

  group('authenticated programme authoring INSERT RETURNING fix', () {
    test('migration file exists after production lockdown', () {
      expect(migrationFile.existsSync(), isTrue);
      expect(
        migrationSql,
        contains('20260722130000_production_identity_rls_lockdown.sql'),
      );
    });

    test('replaces indirect lineage select policy with direct created_by predicate', () {
      expect(migrationSql, contains('DROP POLICY IF EXISTS programme_lineages_select_coach'));
      expect(
        migrationSql,
        contains(
          'CREATE POLICY programme_lineages_select_coach\n'
          '  ON programme_lineages\n'
          '  FOR SELECT\n'
          '  TO authenticated\n'
          '  USING (\n'
          '    cohort_auth_is_coach()\n'
          '    AND created_by = auth.uid()::TEXT',
        ),
      );
      expect(
        migrationSql,
        isNot(contains('programme_lineages_select_coach\n  ON programme_lineages\n  FOR SELECT\n  TO authenticated\n  USING (cohort_programme_lineage_is_dev_coach_owned(id))')),
      );
    });

    test('replaces indirect version select policy with direct owner row predicates', () {
      expect(migrationSql, contains('DROP POLICY IF EXISTS programme_versions_select_coach'));
      expect(
        migrationSql,
        contains(
          'CREATE POLICY programme_versions_select_coach\n'
          '  ON programme_versions\n'
          '  FOR SELECT\n'
          '  TO authenticated\n'
          '  USING (\n'
          '    cohort_auth_is_coach()\n'
          '    AND owner_type = \'coach\'\n'
          '    AND owner_id = auth.uid()::TEXT',
        ),
      );
    });

    test('preserves insert ownership checks without broadening access', () {
      expect(migrationSql, isNot(contains('DROP POLICY IF EXISTS programme_lineages_insert_coach')));
      expect(migrationSql, isNot(contains('DROP POLICY IF EXISTS programme_versions_insert_coach_draft')));
      expect(migrationSql, isNot(contains("TO anon,")));
      expect(migrationSql, isNot(contains("TO anon\n")));
      expect(migrationSql, isNot(contains("'dev-coach'")));
    });

    test('documents cross-coach denial verification', () {
      expect(migrationSql, contains('Different authenticated coach SELECT/UPDATE those rows → denied'));
    });
  });
}
