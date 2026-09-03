-- Gate AO — direct outcome reads require the table privilege and remain
-- isolated by the existing athlete RLS policy. Mutations stay RPC-owned.

DO $$
DECLARE
  v_athlete UUID := 'af000002-0000-4000-8000-000000000002';
  v_unassigned UUID := 'a9000001-0000-4000-8000-000000000001';
  v_assignment UUID;
  v_count INT;
BEGIN
  SELECT id INTO v_assignment
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete AND status = 'active'
  ORDER BY updated_at DESC
  LIMIT 1;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AO', 'own_outcome_read_allowed', 'at_least_1', v_count::TEXT,
    NULL, v_count >= 1, NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_unassigned::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count FROM public.programme_slot_outcomes;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'AO', 'other_athlete_outcomes_hidden', '0', v_count::TEXT
  );

  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
    PERFORM set_config('role', 'authenticated', true);
    DELETE FROM public.programme_slot_outcomes
    WHERE assignment_id = v_assignment;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AO', 'direct_mutation_denied', '42501', 'executed', NULL, FALSE, NULL
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AO', 'direct_mutation_denied', '42501', '42501', TRUE, TRUE, NULL
    );
  END;
END $$;

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM public.programme_slot_outcomes;
  RAISE EXCEPTION 'AO anonymous outcome read unexpectedly permitted';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END $$;
ROLLBACK;
SELECT sprint12_record(
  'AO', 'anonymous_outcome_read_denied', '42501', '42501', NULL, TRUE, NULL
);

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results WHERE gate = 'AO' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
