-- Gate BJ — B2 fail-closed Cohort ingestion and SQL/Dart golden parity.
TRUNCATE sprint12_gate_results;

CREATE TEMP TABLE gate_bj_vectors(payload JSONB NOT NULL);
\copy gate_bj_vectors FROM '/tmp/running_pace_b2_golden_vectors.json'

DO $$
DECLARE
  v_vectors JSONB;
  v_case JSONB;
  v_actual JSONB;
  v_expected JSONB;
  v_policy JSONB;
  v_result JSONB;
  v_retry JSONB;
  v_athlete UUID := 'b2200000-0000-4000-8000-000000000001';
  v_command UUID := 'b2200000-0000-4000-8000-000000000010';
  v_evidence UUID;
  v_before INT;
  v_after INT;
  v_has_exec BOOLEAN;
BEGIN
  SELECT payload INTO STRICT v_vectors FROM gate_bj_vectors;

  SELECT count(*) INTO v_before
  FROM public.running_5k_benchmark_evidence
  WHERE source_kind = 'cohort';
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);
  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('role', 'service_role', TRUE);
  v_result := public.record_cohort_completed_5k_benchmark(
    jsonb_build_object('invented_activity', true)
  );
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_after
  FROM public.running_5k_benchmark_evidence
  WHERE source_kind = 'cohort';
  PERFORM sprint12_record(
    'BJ', 'cohort_ingestion_fails_closed',
    'blocked|cohort_test_completion_unproven|0',
    COALESCE(v_result->>'status', '') || '|' ||
      COALESCE(v_result->>'code', '') || '|' || (v_after - v_before)::TEXT,
    v_after = v_before,
    v_result->>'status' = 'blocked'
      AND v_result->>'code' = 'cohort_test_completion_unproven'
      AND v_after = v_before,
    v_result::TEXT
  );

  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',v_athlete,
    'authenticated','authenticated','gate-bj-athlete@example.invalid',
    crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
    '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''
  ) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles(id, display_name, is_athlete, is_coach)
  VALUES (v_athlete, 'Gate BJ Athlete', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE SET is_athlete = TRUE, is_coach = FALSE;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.record_manual_completed_5k_benchmark(jsonb_build_object(
    'command_id', v_command,
    'source_reference', 'manual-gate-bj',
    'source', 'manual',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1210000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', '2026-03-10',
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'outdoor'
  ));
  v_retry := public.record_manual_completed_5k_benchmark(jsonb_build_object(
    'command_id', v_command,
    'source_reference', 'manual-gate-bj',
    'source', 'manual',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1210000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', '2026-03-10',
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'outdoor'
  ));
  PERFORM set_config('role', 'postgres', TRUE);
  v_evidence := (v_result->>'evidence_id')::UUID;
  PERFORM sprint12_record(
    'BJ', 'manual_declared_test_preserved', 'recorded|already_recorded',
    COALESCE(v_result->>'status', '') || '|' || COALESCE(v_retry->>'status', ''),
    EXISTS (
      SELECT 1 FROM public.running_5k_benchmark_evidence
      WHERE evidence_id = v_evidence AND source_kind = 'manual'
    ),
    v_result->>'status' = 'recorded'
      AND v_retry->>'status' = 'already_recorded'
      AND v_retry->>'evidence_id' = v_result->>'evidence_id',
    v_result::TEXT
  );

  SELECT item->'policy' INTO STRICT v_policy
  FROM jsonb_array_elements(v_vectors->'selection_cases') AS cases(item)
  WHERE item->>'id' = 'source_eligibility';
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.select_my_running_5k_benchmark(
    v_policy, DATE '2026-04-01', 'Asia/Makassar'
  );
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record(
    'BJ', 'stored_manual_selection', 'success|' || v_evidence::TEXT,
    COALESCE(v_result->>'status', '') || '|' ||
      COALESCE(v_result->>'selected_evidence_id', ''),
    NULL,
    v_result->>'status' = 'success'
      AND v_result->>'selected_evidence_id' = v_evidence::TEXT,
    v_result::TEXT
  );

  SELECT
    (SELECT count(*) FROM public.running_5k_benchmark_evidence)
    + (SELECT count(*) FROM public.running_5k_benchmark_evidence_revisions)
  INTO v_before;
  FOR v_case IN
    SELECT value FROM jsonb_array_elements(v_vectors->'selection_cases')
  LOOP
    v_expected := v_case->'expected';
    v_actual := public.cohort_select_running_5k_benchmark(
      v_case->'evidence',
      v_case->'policy',
      v_case->>'athlete_id',
      (v_case->>'evaluation_local_date')::DATE,
      v_case->>'iana_timezone'
    );
    PERFORM sprint12_record(
      'BJ', 'selection_' || (v_case->>'id'), v_expected::TEXT, v_actual::TEXT,
      NULL, v_actual = v_expected, NULL
    );
  END LOOP;
  FOR v_case IN
    SELECT value FROM jsonb_array_elements(v_vectors->'calculation_cases')
  LOOP
    v_expected := v_case->'expected';
    v_actual := public.cohort_calculate_running_pace_range(
      (v_case->>'benchmark_duration_milliseconds')::BIGINT,
      (v_case->>'minimum_speed_basis_points')::INT,
      (v_case->>'maximum_speed_basis_points')::INT,
      (v_case->>'rounding_increment_milliseconds')::BIGINT,
      v_case->>'rounding_direction'
    );
    PERFORM sprint12_record(
      'BJ', 'calculation_' || (v_case->>'id'),
      v_expected::TEXT, v_actual::TEXT,
      NULL, v_actual = v_expected, NULL
    );
  END LOOP;
  SELECT
    (SELECT count(*) FROM public.running_5k_benchmark_evidence)
    + (SELECT count(*) FROM public.running_5k_benchmark_evidence_revisions)
  INTO v_after;
  PERFORM sprint12_record(
    'BJ', 'sql_selection_and_calculation_side_effect_free',
    v_before::TEXT, v_after::TEXT, NULL, v_before = v_after, NULL
  );

  SELECT has_function_privilege(
    'authenticated',
    'public.record_cohort_completed_5k_benchmark(jsonb)', 'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BJ', 'athlete_cannot_call_cohort_ingestion',
    'false', v_has_exec::TEXT, NULL, NOT v_has_exec, NULL
  );
  SELECT has_function_privilege(
    'authenticated',
    'public.record_manual_completed_5k_benchmark(jsonb)', 'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BJ', 'athlete_can_declare_manual_test',
    'true', v_has_exec::TEXT, NULL, v_has_exec, NULL
  );
END $$;

SELECT * FROM sprint12_gate_results ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
