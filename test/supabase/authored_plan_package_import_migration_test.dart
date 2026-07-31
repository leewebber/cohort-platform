import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migrationFile = File(
    'supabase/migrations/20260731120000_authored_plan_package_import.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('authored plan package import migration', () {
    test('migration file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('adds package provenance columns on programme_versions', () {
      expect(sql, contains('package_schema_version'));
      expect(sql, contains('package_content_hash'));
      expect(sql, contains('coaching_intent'));
      expect(sql, contains('package_imported_at'));
      expect(sql, contains('package_imported_by'));
      expect(sql, contains("package_content_hash ~ '^[0-9a-f]{64}\$'"));
      expect(
        sql,
        contains('programme_versions_approved_for_global_requires_published'),
      );
    });

    test('adds slot package fields', () {
      expect(sql, contains('package_slot_key'));
      expect(sql, contains('authored_progression'));
      expect(sql, contains("authored_progression->>'prescription_summary'"));
    });

    test('creates five package child tables', () {
      expect(sql, contains('programme_version_adaptation_permissions'));
      expect(sql, contains('programme_version_protected_invariants'));
      expect(sql, contains('programme_version_assessments'));
      expect(sql, contains('programme_version_evidence_requirements'));
      expect(sql, contains('programme_version_comparison_identities'));
    });

    test('closes global draft catalogue SELECT leak', () {
      expect(
        sql,
        contains('DROP POLICY IF EXISTS programme_versions_select_catalogue'),
      );
      expect(
        sql,
        contains(
          "lifecycle_status = 'published'\n    AND library_scope = 'cohort_global'\n    AND approved_for_global = TRUE",
        ),
      );
      expect(
        sql,
        isNot(
          contains(
            "lifecycle_status = 'draft'\n      AND library_scope = 'cohort_global'\n      AND owner_type = 'global'",
          ),
        ),
      );
    });

    test('grants authenticated catalogue SELECT on versions and lineages only', () {
      expect(
        sql,
        contains(
          'REVOKE SELECT ON TABLE public.programme_versions FROM PUBLIC, anon',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE SELECT ON TABLE public.programme_lineages FROM PUBLIC, anon',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT SELECT ON TABLE public.programme_versions TO authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT SELECT ON TABLE public.programme_lineages TO authenticated',
        ),
      );
      expect(
        sql,
        contains('cohort_programme_lineage_has_dev_readable_version'),
      );
      expect(
        sql,
        contains("AND v.approved_for_global = TRUE"),
      );
      // Must not grant catalogue browse writes or package-internal table SELECT.
      expect(sql, isNot(contains('GRANT INSERT ON TABLE public.programme_versions')));
      expect(sql, isNot(contains('GRANT UPDATE ON TABLE public.programme_versions')));
      expect(sql, isNot(contains('GRANT DELETE ON TABLE public.programme_versions')));
      expect(sql, isNot(contains('GRANT ALL ON TABLE public.programme_versions')));
      expect(sql, isNot(contains('GRANT INSERT ON TABLE public.programme_lineages')));
      expect(sql, isNot(contains('GRANT UPDATE ON TABLE public.programme_lineages')));
      expect(sql, isNot(contains('GRANT DELETE ON TABLE public.programme_lineages')));
      expect(sql, isNot(contains('GRANT ALL ON TABLE public.programme_lineages')));
      expect(sql, isNot(contains('ALTER DEFAULT PRIVILEGES')));
      expect(sql, isNot(contains('GRANT SELECT ON ALL TABLES')));
      expect(
        sql,
        isNot(
          contains(
            'GRANT SELECT ON TABLE public.programme_version_adaptation_permissions',
          ),
        ),
      );
    });

    test('import function is service_role only with fixed search_path', () {
      expect(
        sql,
        contains(
          'CREATE OR REPLACE FUNCTION public.import_authored_plan_package',
        ),
      );
      expect(sql, contains('SET search_path = public, pg_temp'));
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM PUBLIC',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM anon',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) FROM authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.import_authored_plan_package(JSONB) TO service_role',
        ),
      );
    });

    test('import never publishes or approves for catalogue', () {
      expect(sql, contains("'approved_for_global', FALSE"));
      expect(sql, contains("'lifecycle_status', 'draft'"));
      expect(sql, contains("'draft',\n      'cohort_global',\n      'global'"));
      expect(sql, contains('ownership_or_lifecycle_spoof'));
      expect(sql, contains('idempotent_existing_draft'));
      expect(sql, contains('hash_collision'));
      expect(sql, contains('published_version_exists'));
      expect(sql, contains('partial_existing_draft'));
    });

    test('publish and catalogue approval are separate service_role RPCs', () {
      expect(sql, contains('publish_cohort_global_programme_version'));
      expect(sql, contains('approve_cohort_global_programme_version'));
      expect(sql, contains('draft_catalogue_approval_forbidden'));
      expect(sql, contains("'approved_for_global', FALSE"));
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.publish_cohort_global_programme_version(UUID, TEXT) TO service_role',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.publish_cohort_global_programme_version(UUID, TEXT) FROM authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.approve_cohort_global_programme_version(UUID, TEXT) TO service_role',
        ),
      );
    });

    test(
      'published immutability triggers cover parent and package children',
      () {
        expect(
          sql,
          contains('cohort_reject_published_programme_content_mutation'),
        );
        expect(sql, contains('cohort_programme_version_is_immutable'));
        expect(sql, contains('programme_versions_immutability'));
        expect(sql, contains('programme_version_session_slots_immutability'));
        expect(
          sql,
          contains('programme_version_adaptation_permissions_immutability'),
        );
        expect(
          sql,
          contains('programme_version_protected_invariants_immutability'),
        );
        expect(sql, contains('programme_version_assessments_immutability'));
        expect(
          sql,
          contains('programme_version_evidence_requirements_immutability'),
        );
        expect(
          sql,
          contains('programme_version_comparison_identities_immutability'),
        );
        expect(
          sql,
          contains('Catalogue approval cannot occur during publication'),
        );
        expect(
          sql,
          contains(
            'Publish transition cannot alter authored programme content',
          ),
        );
      },
    );

    test('does not persist raw YAML or canonical JSON columns', () {
      expect(sql, isNot(contains('package_yaml')));
      expect(sql, isNot(contains('canonical_json')));
      expect(sql, isNot(contains('source_filename')));
    });

    test('no global unique constraint on package_content_hash', () {
      expect(sql, isNot(contains('UNIQUE (package_content_hash)')));
      expect(sql, isNot(contains('package_content_hash_unique')));
    });
  });
}
