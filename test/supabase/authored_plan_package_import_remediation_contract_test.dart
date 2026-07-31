import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-contract regression for Sprint 1.2 deployment-readiness remediation.
///
/// These assert the committed migration SQL contract. They are not live RPC /
/// database execution proofs.
void main() {
  final migrationFile = File(
    'supabase/migrations/20260731120000_authored_plan_package_import.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('immutability remediation contract', () {
    test('treats published and archived as immutable', () {
      expect(sql, contains('cohort_programme_version_is_immutable'));
      expect(sql, contains("v.lifecycle_status IN ('published', 'archived')"));
      expect(
        sql,
        contains(
          'Published or archived programme package content is immutable',
        ),
      );
    });

    test('UPDATE checks both original and proposed parents', () {
      expect(
        sql,
        contains(
          'public.cohort_programme_version_is_immutable(OLD.version_id)\n'
          '         OR public.cohort_programme_version_is_immutable(NEW.version_id)',
        ),
      );
      expect(
        sql,
        contains('cohort_programme_version_id_for_week(OLD.week_id)'),
      );
      expect(
        sql,
        contains('cohort_programme_version_id_for_week(NEW.week_id)'),
      );
      expect(sql, contains('cohort_programme_version_id_for_day(OLD.day_id)'));
      expect(sql, contains('cohort_programme_version_id_for_day(NEW.day_id)'));
      expect(sql, isNot(contains('COALESCE(NEW.version_id, OLD.version_id)')));
      expect(sql, isNot(contains('COALESCE(NEW.week_id, OLD.week_id)')));
      expect(sql, isNot(contains('COALESCE(NEW.day_id, OLD.day_id)')));
    });

    test('catalogue approval whitelist freezes authored columns', () {
      expect(
        sql,
        contains('NEW.duration_weeks IS NOT DISTINCT FROM OLD.duration_weeks'),
      );
      expect(
        sql,
        contains(
          'NEW.sessions_per_week IS NOT DISTINCT FROM OLD.sessions_per_week',
        ),
      );
      expect(
        sql,
        contains('NEW.primary_goal IS NOT DISTINCT FROM OLD.primary_goal'),
      );
      expect(sql, contains('NEW.owner_id IS NOT DISTINCT FROM OLD.owner_id'));
      expect(
        sql,
        contains(
          'NEW.package_imported_by IS NOT DISTINCT FROM OLD.package_imported_by',
        ),
      );
      expect(
        sql,
        contains(
          'NEW.package_content_hash IS NOT DISTINCT FROM OLD.package_content_hash',
        ),
      );
      expect(
        sql,
        contains(
          "SET approved_for_global = TRUE,\n      updated_at = NOW()\n  WHERE id = p_version_id;",
        ),
      );
    });
  });

  group('import transaction remediation contract', () {
    test('validates sessions before any lineage write', () {
      final sessionsIdx = sql.indexOf(
        'Referenced session revision was not found',
      );
      final lineageInsertIdx = sql.indexOf(
        'INSERT INTO public.programme_lineages (code, created_by)',
      );
      expect(sessionsIdx, greaterThan(0));
      expect(lineageInsertIdx, greaterThan(sessionsIdx));
    });

    test('uses advisory lock for lineage concurrency', () {
      expect(sql, contains('pg_advisory_xact_lock'));
      expect(sql, contains('872314001'));
      expect(sql, contains('hashtext(v_lineage_code)'));
    });

    test('maps expected races without leaking SQLERRM', () {
      expect(sql, contains('WHEN unique_violation THEN'));
      expect(sql, contains('lineage_or_version_race'));
      expect(sql, contains('unexpected_database_failure'));
      expect(sql, contains('Import failed and was rolled back.'));
      expect(sql, isNot(contains('SQLERRM')));
      expect(sql, isNot(contains("'code', SQLSTATE")));
    });

    test('idempotent predicate requires cohort global ownership', () {
      expect(sql, contains("v_existing.library_scope = 'cohort_global'"));
      expect(sql, contains("v_existing.owner_type = 'global'"));
      expect(sql, contains('v_existing.owner_id IS NULL'));
      expect(sql, contains('v_existing.approved_for_global = FALSE'));
    });

    test('revalidates package references before writes', () {
      expect(
        sql,
        contains(
          'Comparison identity session_lineage_id is not in package sessions',
        ),
      );
      expect(
        sql,
        contains('Adaptation target_ref does not resolve to a package slot'),
      );
      expect(sql, contains('Protected invariant target_ref does not resolve'));
      expect(
        sql,
        contains('Assessment slot_ref does not resolve to a package slot'),
      );
      expect(
        sql,
        contains(
          'Evidence requirement comparison_identity_id does not resolve',
        ),
      );
      expect(sql, contains('broken_reference'));
    });

    test('nested write block rolls back on failure', () {
      expect(sql, contains('Atomic write section'));
      expect(sql, contains('WHEN check_violation THEN'));
      expect(sql, contains('WHEN foreign_key_violation THEN'));
      expect(sql, contains('WHEN OTHERS THEN'));
    });
  });
}
