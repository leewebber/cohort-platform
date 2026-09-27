import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260927130000_running_5k_benchmark_evidence.sql',
  ).readAsStringSync();
  final gate = File(
    'supabase/tests/sql/gate_bi_running_5k_benchmark_evidence.sql',
  ).readAsStringSync();

  test(
    'evidence is exact, append-only, athlete scoped, and source explicit',
    () {
      expect(migration, contains('CHECK (distance_metres = 5000)'));
      expect(
        migration,
        contains("duration_basis = 'elapsed_including_pauses'"),
      );
      expect(
        migration,
        contains("declaration = 'completed_five_kilometre_test'"),
      );
      expect(
        migration,
        contains("surface_context IN ('outdoor', 'treadmill')"),
      );
      expect(
        migration,
        contains('running 5 km benchmark evidence is append-only'),
      );
      expect(migration, contains('athlete_id = auth.uid()'));
    },
  );

  test('manual and Cohort command grants preserve the authority split', () {
    expect(
      migration,
      contains(
        'GRANT EXECUTE ON FUNCTION public.record_manual_completed_5k_benchmark(JSONB) TO authenticated;',
      ),
    );
    expect(
      migration,
      contains(
        'REVOKE ALL ON FUNCTION public.record_cohort_completed_5k_benchmark(JSONB) FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      migration,
      contains(
        'GRANT EXECUTE ON FUNCTION public.record_cohort_completed_5k_benchmark(JSONB) TO service_role;',
      ),
    );
  });

  test(
    'disposable gate covers eligibility, freshness, ownership, and history',
    () {
      for (final caseId in <String>[
        'manual_explicit_test_eligible',
        'arbitrary_5k_activity_ineligible',
        'freshness_day_90_inclusive',
        'freshness_day_91_excluded',
        'cross_athlete_denied',
        'duplicate_retry_idempotent',
        'idempotency_reuse_fails_closed',
        'correction_history_append_only',
        'correction_preserves_identity',
        'cohort_completed_test_eligible',
        'incomplete_cohort_session_rejected',
        'service_role_cannot_bypass_commands',
      ]) {
        expect(gate, contains("'$caseId'"));
      }
    },
  );
}
