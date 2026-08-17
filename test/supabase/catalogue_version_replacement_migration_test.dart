import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final replacementMigration = File(
    'supabase/migrations/20260813160000_atomic_catalogue_version_replacement.sql',
  );
  final alreadyApprovedMigration = File(
    'supabase/migrations/20260813160500_atomic_catalogue_replacement_already_approved_target.sql',
  );
  final uniquenessMigration = File(
    'supabase/migrations/20260813161000_catalogue_lineage_uniqueness.sql',
  );

  late String replacementSql;
  late String alreadyApprovedSql;
  late String uniquenessSql;

  setUpAll(() {
    replacementSql = replacementMigration.readAsStringSync();
    alreadyApprovedSql = alreadyApprovedMigration.readAsStringSync();
    uniquenessSql = uniquenessMigration.readAsStringSync();
  });

  test('replacement RPC is lineage-locked and service-role only', () {
    expect(
      replacementSql,
      contains('replace_approved_cohort_global_programme_version'),
    );
    expect(replacementSql, contains('FROM public.programme_lineages'));
    expect(replacementSql, contains('FOR UPDATE'));
    expect(
      replacementSql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.replace_approved_cohort_global_programme_version',
      ),
    );
    expect(replacementSql, contains('FROM authenticated'));
    expect(replacementSql, contains("'code', 'conflicting_eligible_version'"));
    expect(replacementSql, contains("'code', 'wrong_lineage'"));
    expect(replacementSql, contains("'code', 'idempotent_success'"));
    expect(
      replacementSql,
      contains("'code', 'atomic_replacement_rolled_back'"),
    );
  });

  test('retirement revokes approval in the archive transition', () {
    expect(
      replacementSql,
      contains(
        "SET approved_for_global = FALSE,\n"
        "        lifecycle_status = 'archived'",
      ),
    );
    expect(replacementSql, contains('NEW.approved_for_global = FALSE'));
  });

  test('direct approval refuses a competing eligible version', () {
    expect(
      replacementSql,
      contains(
        'CREATE OR REPLACE FUNCTION public.approve_cohort_global_programme_version',
      ),
    );
    expect(replacementSql, contains("'status', 'conflict'"));
    expect(replacementSql, contains("'code', 'conflicting_eligible_version'"));
  });

  test('already-approved correction skips immutable replacement UPDATE', () {
    expect(
      alreadyApprovedSql,
      contains(
        'CREATE OR REPLACE FUNCTION public.replace_approved_cohort_global_programme_version',
      ),
    );
    expect(alreadyApprovedSql, contains('v_replacement_already_approved'));
    expect(alreadyApprovedSql, contains("'already_satisfied'"));
    expect(
      alreadyApprovedSql,
      contains('IF NOT v_replacement_already_approved THEN'),
    );
    expect(
      alreadyApprovedSql,
      isNot(contains('32986922-47d1-46b0-b391-a7931d73033e')),
    );
    expect(
      alreadyApprovedSql,
      isNot(contains('e75d7374-147f-4493-ba67-021855f51798')),
    );
  });

  test('final migration enforces one eligible version per lineage', () {
    expect(
      uniquenessSql,
      contains(
        'CREATE UNIQUE INDEX idx_programme_versions_one_catalogue_eligible_per_lineage',
      ),
    );
    expect(
      uniquenessSql,
      contains('ON public.programme_versions (lineage_id)'),
    );
    expect(uniquenessSql, contains("lifecycle_status = 'published'"));
    expect(uniquenessSql, contains("library_scope = 'cohort_global'"));
    expect(uniquenessSql, contains("owner_type = 'global'"));
    expect(uniquenessSql, contains('approved_for_global = TRUE'));
    expect(uniquenessSql, contains('archived_at IS NULL'));
    expect(
      uniquenessSql,
      isNot(contains('32986922-47d1-46b0-b391-a7931d73033e')),
    );
    expect(
      uniquenessSql,
      isNot(contains('e75d7374-147f-4493-ba67-021855f51798')),
    );
  });
}
