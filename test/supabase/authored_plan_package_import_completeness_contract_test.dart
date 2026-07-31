import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static SQL/source contract for Sprint 1.2 completeness + uniqueness follow-up.
///
/// These are not live PostgreSQL execution proofs. Runtime hollow-draft,
/// duplicate-key, and concurrency cases remain deployment gates.
void main() {
  final migrationFile = File(
    'supabase/migrations/20260731120000_authored_plan_package_import.sql',
  );

  late String sql;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
  });

  group('package graph completeness contract (static)', () {
    test('defines authoritative graph match helper', () {
      expect(sql, contains('cohort_authored_plan_package_graph_matches'));
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.cohort_authored_plan_package_graph_matches(UUID, JSONB) TO service_role',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.cohort_authored_plan_package_graph_matches(UUID, JSONB) FROM authenticated',
        ),
      );
    });

    test('idempotent path requires graph match after provenance', () {
      final provenanceIdx = sql.indexOf(
        "v_existing.approved_for_global = FALSE THEN\n"
        "        IF public.cohort_authored_plan_package_graph_matches(v_existing.id, payload) THEN",
      );
      expect(provenanceIdx, greaterThan(0));
      expect(
        sql,
        contains(
          'Existing draft provenance matches but package graph is incomplete or inconsistent',
        ),
      );
    });

    test('graph helper compares structure and all five child domains', () {
      expect(sql, contains('programme_version_phases p'));
      expect(sql, contains('programme_version_weeks w'));
      expect(sql, contains('programme_version_days d'));
      expect(sql, contains('programme_version_session_slots s'));
      expect(sql, contains('programme_version_adaptation_permissions a'));
      expect(sql, contains('programme_version_protected_invariants i'));
      expect(sql, contains('programme_version_assessments a'));
      expect(sql, contains('programme_version_evidence_requirements e'));
      expect(sql, contains('programme_version_comparison_identities c'));
      expect(sql, contains('s.authored_progression IS NOT DISTINCT FROM'));
      expect(sql, contains('s.protocol_id IS NOT DISTINCT FROM'));
    });
  });

  group('duplicate identity classification contract (static)', () {
    test('pre-validates structure and child identity duplicates before writes', () {
      final firstWrite = sql.indexOf(
        'INSERT INTO public.programme_lineages (code, created_by)',
      );
      for (final marker in [
        "code', 'duplicate_package_identity', 'message', 'phase_key missing or duplicated.",
        "code', 'duplicate_package_identity', 'message', 'phase_order missing or duplicated.",
        "code', 'duplicate_package_identity', 'message', 'week_number missing or duplicated.",
        "code', 'duplicate_package_identity', 'message', 'day_key missing or duplicated within week.",
        "code', 'duplicate_package_identity', 'message', 'day_order missing or duplicated within week.",
        "code', 'duplicate_package_identity', 'message', 'Duplicate package_slot_key in package.",
        "code', 'duplicate_package_identity', 'message', 'session_order missing or duplicated within day.",
        "code', 'duplicate_package_identity', 'message', 'adaptation permission id missing or duplicated.",
        "code', 'duplicate_package_identity', 'message', 'protected invariant id missing or duplicated.",
        "code', 'duplicate_package_identity', 'message', 'assessment id missing or duplicated.",
        "code', 'duplicate_package_identity', 'message', 'evidence requirement id missing or duplicated.",
        "code', 'duplicate_package_identity', 'message', 'comparison identity id missing or duplicated.",
      ]) {
        final idx = sql.indexOf(marker);
        expect(idx, greaterThan(0), reason: marker);
        expect(idx, lessThan(firstWrite), reason: marker);
      }
    });

    test(
      'unique_violation race only for lineage/version identity constraints',
      () {
        expect(
          sql,
          contains("GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME"),
        );
        expect(sql, contains("'programme_lineages_code_unique'"));
        expect(sql, contains("'programme_versions_lineage_version_unique'"));
        expect(sql, contains("'duplicate_package_identity'"));
        expect(
          sql,
          contains(
            'Import rejected due to duplicate package identity and was rolled back.',
          ),
        );
      },
    );
  });
}
