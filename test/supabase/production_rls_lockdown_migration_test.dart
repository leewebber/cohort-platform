import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260722130000_production_identity_rls_lockdown.sql',
  );

  late String migrationSql;

  setUpAll(() {
    migrationSql = migrationFile.readAsStringSync();
  });

  group('production identity RLS lockdown migration', () {
    test('migration file exists after dual-role migration', () {
      expect(migrationFile.existsSync(), isTrue);
      expect(
        migrationSql,
        contains('Applies after 20260722120000_add_dual_role_self_assignment_policies.sql'),
      );
    });

    test('drops obsolete dev policies by exact name', () {
      const droppedPolicies = [
        'dev_programme_lineages_select',
        'dev_programme_lineages_insert_coach',
        'dev_programme_versions_select_catalogue',
        'dev_programme_versions_insert_coach_draft',
        'dev_programme_assignments_select',
        'dev_programme_assignments_coach_insert',
        'dev_programme_slot_outcomes_select',
        'programme_adaptation_events_dev_athlete_select',
        'dev_performance_records_select',
      ];

      for (final policy in droppedPolicies) {
        expect(
          migrationSql,
          contains('DROP POLICY IF EXISTS $policy'),
          reason: 'Expected drop for $policy',
        );
      }
    });

    test('removes anon identity fallbacks from helper functions', () {
      expect(migrationSql, isNot(contains("ELSE ARRAY['lee']")));
      expect(migrationSql, isNot(contains("COALESCE(auth.uid()::TEXT, 'dev-coach')")));
      expect(migrationSql, contains('cohort_auth_is_coach()'));
      expect(migrationSql, contains('cohort_auth_is_athlete()'));
    });

    test('creates authenticated production policies', () {
      const productionPolicies = [
        'programme_lineages_insert_coach',
        'programme_versions_select_coach',
        'programme_assignments_athlete_select',
        'programme_assignments_coach_insert',
        'programme_slot_outcomes_athlete_select',
        'programme_adaptation_events_athlete_select',
        'performance_records_athlete_select',
      ];

      for (final policy in productionPolicies) {
        expect(
          migrationSql,
          contains('CREATE POLICY $policy'),
          reason: 'Expected create for $policy',
        );
      }
    });

    test('retains dual-role self-assignment policy from prior migration', () {
      expect(migrationSql, contains('programme_assignments_dual_role_self_insert'));
      expect(
        migrationSql,
        isNot(contains('DROP POLICY IF EXISTS programme_assignments_dual_role_self_insert')),
      );
    });

    test('uses authenticated role only for coach authoring policies', () {
      expect(migrationSql, contains('CREATE POLICY programme_lineages_insert_coach'));
      expect(
        migrationSql,
        contains(
          'CREATE POLICY programme_lineages_insert_coach\n'
          '  ON programme_lineages\n'
          '  FOR INSERT\n'
          '  TO authenticated',
        ),
      );
    });

    test('documents hosted verification checklist', () {
      expect(migrationSql, contains('Hosted verification checklist'));
      expect(migrationSql, contains('Dual-role user can self-assign'));
    });
  });
}
