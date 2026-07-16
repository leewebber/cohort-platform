import 'dart:io';

import 'package:cohort_platform/core/constants/programme_dev_identity.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260716150000_allow_dev_coach_programme_authoring.sql',
  );

  late String migrationSql;

  setUpAll(() {
    migrationSql = migrationFile.readAsStringSync();
  });

  group('dev-coach RLS migration contract', () {
    test('migration file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('defines coach SECURITY DEFINER helpers', () {
      expect(migrationSql, contains('cohort_programme_lineage_is_dev_coach_owned'));
      expect(migrationSql, contains('cohort_programme_version_is_dev_coach_draft_writable'));
      expect(migrationSql, contains('cohort_programme_version_is_dev_coach_draft_deletable'));
      expect(migrationSql, contains('SET search_path = public, pg_temp'));
      expect(migrationSql, contains('REVOKE ALL'));
      expect(migrationSql, contains('GRANT EXECUTE'));
    });

    test('defines lineage insert/select/update/delete coach policies', () {
      expect(migrationSql, contains('dev_programme_lineages_insert_coach'));
      expect(migrationSql, contains('dev_programme_lineages_select_coach'));
      expect(migrationSql, contains('dev_programme_lineages_delete_coach'));
    });

    test('defines version coach draft policies', () {
      expect(migrationSql, contains('dev_programme_versions_insert_coach_draft'));
      expect(migrationSql, contains('dev_programme_versions_update_coach_draft'));
      expect(migrationSql, contains('dev_programme_versions_delete_coach_draft'));
      expect(migrationSql, contains('dev_programme_versions_select_coach'));
    });

    test('defines child tree coach write policies', () {
      expect(migrationSql, contains('dev_programme_version_weeks_write_coach'));
      expect(migrationSql, contains('dev_programme_version_days_write_coach'));
      expect(migrationSql, contains('dev_programme_version_session_slots_write_coach'));
    });

    test('denies other-coach ownership in insert WITH CHECK', () {
      expect(migrationSql, contains("owner_id = cohort_programme_dev_coach_id()"));
      expect(migrationSql, contains("owner_id = 'other-coach'"));
    });

    test('requires draft lifecycle for coach draft writes', () {
      expect(migrationSql, contains("lifecycle_status = 'draft'"));
    });

    test('blocks organisation scope in coach draft insert', () {
      expect(migrationSql, contains('organisation_id IS NULL'));
      expect(migrationSql, contains("library_scope = 'coach_private'"));
    });

    test('delete safety checks assignments and published versions', () {
      expect(migrationSql, contains('cohort_programme_version_is_dev_coach_draft_deletable'));
      expect(migrationSql, contains('programme_assignments'));
      expect(migrationSql, contains("lifecycle_status = 'published'"));
    });

    test('documents validation queries A–G', () {
      expect(migrationSql, contains('anon can insert a dev-coach lineage'));
      expect(migrationSql, contains("owner_id = 'other-coach'"));
      expect(migrationSql, contains('Cohort Global reads still work'));
    });
  });

  group('dev identity alignment', () {
    test('ProgrammeDevIdentity.coachId matches migration dev-coach constant', () {
      expect(ProgrammeDevIdentity.coachId, 'dev-coach');
      expect(migrationSql, contains("'dev-coach'"));
      expect(migrationSql, contains('cohort_programme_dev_coach_id()'));
    });

    test('New Programme default scope matches coach draft policy vocabulary', () {
      expect(ProgrammeLibraryScope.coachPrivate.dbValue, 'coach_private');
      expect(ProgrammeOwnerType.coach.dbValue, 'coach');
      expect(ProgrammeLifecycleStatus.draft.dbValue, 'draft');
    });
  });
}
