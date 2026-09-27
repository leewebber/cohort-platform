-- Gate BI — Running Pace Foundation B2 benchmark evidence authority.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_athlete UUID := 'b2100000-0000-4000-8000-000000000001';
  v_other UUID := 'b2100000-0000-4000-8000-000000000002';
  v_record UUID := 'b2100000-0000-4000-8000-000000000010';
  v_open_record UUID := 'b2100000-0000-4000-8000-000000000011';
  v_manual_command UUID := 'b2100000-0000-4000-8000-000000000020';
  v_correction_command UUID := 'b2100000-0000-4000-8000-000000000021';
  v_cohort_command UUID := 'b2100000-0000-4000-8000-000000000022';
  v_payload JSONB;
  v_result JSONB;
  v_retry JSONB;
  v_evidence UUID;
  v_count INT;
  v_value TEXT;
  v_has_exec BOOLEAN;
BEGIN
  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000',v_athlete,'authenticated','authenticated',
      'gate-bi-athlete@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''),
    ('00000000-0000-0000-0000-000000000000',v_other,'authenticated','authenticated',
      'gate-bi-other@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','','')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles(id, display_name, is_athlete, is_coach)
  VALUES (v_athlete, 'Gate BI Athlete', TRUE, FALSE),
         (v_other, 'Gate BI Other', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE SET is_athlete = TRUE, is_coach = FALSE;

  INSERT INTO public.training_session_records(
    record_id, athlete_id, status, session_snapshot, started_at, completed_at
  ) VALUES
    (v_record, v_athlete::TEXT, 'completed', '{"title":"Explicit 5 km test"}',
      '2026-03-01 00:00:00+00', '2026-03-01 00:22:00+00'),
    (v_open_record, v_athlete::TEXT, 'in_progress', '{"title":"Open activity"}',
      '2026-03-02 00:00:00+00', NULL);

  v_payload := jsonb_build_object(
    'command_id', v_manual_command,
    'source_reference', 'manual-test-gate-bi',
    'source', 'manual',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1260000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', '2026-01-01',
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'outdoor'
  );
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.record_manual_completed_5k_benchmark(v_payload);
  v_retry := public.record_manual_completed_5k_benchmark(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  v_evidence := (v_result->>'evidence_id')::UUID;
  SELECT count(*) INTO v_count FROM public.running_5k_benchmark_evidence
  WHERE evidence_id = v_evidence;
  PERFORM sprint12_record('BI', 'manual_explicit_test_eligible', 'recorded',
    v_result->>'status', v_count = 1,
    v_result->>'status' = 'recorded' AND v_count = 1, v_result::TEXT);
  PERFORM sprint12_record('BI', 'duplicate_retry_idempotent', 'already_recorded',
    v_retry->>'status', v_retry->>'evidence_id' = v_result->>'evidence_id',
    v_retry->>'status' = 'already_recorded'
      AND v_retry->>'revision_id' = v_result->>'revision_id', v_retry::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_retry := public.record_manual_completed_5k_benchmark(
    jsonb_set(v_payload, '{elapsed_duration_milliseconds}', '1261000')
  );
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record('BI', 'idempotency_reuse_fails_closed',
    'idempotency_key_reused', v_retry->>'code', NULL,
    v_retry->>'code' = 'idempotency_key_reused', v_retry::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_retry := public.record_manual_completed_5k_benchmark(
    jsonb_set(
      jsonb_set(v_payload, '{command_id}', to_jsonb('b2100000-0000-4000-8000-000000000023'::TEXT)),
      '{declaration}', '"five_kilometre_activity"'
    )
  );
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record('BI', 'arbitrary_5k_activity_ineligible',
    'ineligible_manual_evidence', v_retry->>'code', NULL,
    v_retry->>'code' = 'ineligible_manual_evidence', v_retry::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  SELECT count(*) INTO v_count
  FROM public.list_my_eligible_5k_benchmark_evidence('2026-04-01', 90);
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record('BI', 'freshness_day_90_inclusive', '1', v_count::TEXT,
    NULL, v_count = 1, NULL);
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  SELECT count(*) INTO v_count
  FROM public.list_my_eligible_5k_benchmark_evidence('2026-04-02', 90);
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record('BI', 'freshness_day_91_excluded', '0', v_count::TEXT,
    NULL, v_count = 0, NULL);

  v_payload := jsonb_build_object(
    'command_id', v_correction_command,
    'evidence_id', v_evidence,
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1255000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', '2026-01-01',
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'treadmill',
    'correction_reason', 'Corrected elapsed result and context'
  );
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.correct_manual_completed_5k_benchmark(v_payload);
  v_retry := public.correct_manual_completed_5k_benchmark(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count
  FROM public.running_5k_benchmark_evidence_revisions
  WHERE evidence_id = v_evidence;
  SELECT elapsed_duration_milliseconds::TEXT INTO v_value
  FROM public.running_5k_benchmark_evidence_revisions
  WHERE evidence_id = v_evidence
  ORDER BY revision_number DESC LIMIT 1;
  PERFORM sprint12_record('BI', 'correction_history_append_only', '2|1255000',
    v_count::TEXT || '|' || v_value,
    v_retry->>'status' = 'already_corrected',
    v_result->>'status' = 'corrected' AND v_count = 2
      AND v_value = '1255000'
      AND v_retry->>'revision_id' = v_result->>'revision_id', v_result::TEXT);
  SELECT count(*) INTO v_count FROM public.running_5k_benchmark_evidence
  WHERE evidence_id = v_evidence AND source_reference = 'manual-test-gate-bi';
  PERFORM sprint12_record('BI', 'correction_preserves_identity', '1', v_count::TEXT,
    NULL, v_count = 1, NULL);

  PERFORM set_config('request.jwt.claim.sub', v_other::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  SELECT count(*) INTO v_count FROM public.running_5k_benchmark_evidence;
  v_retry := public.correct_manual_completed_5k_benchmark(
    jsonb_set(v_payload, '{command_id}', to_jsonb('b2100000-0000-4000-8000-000000000024'::TEXT))
  );
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record('BI', 'cross_athlete_denied', '0|cross_athlete_evidence',
    v_count::TEXT || '|' || COALESCE(v_retry->>'code', ''), NULL,
    v_count = 0 AND v_retry->>'code' = 'cross_athlete_evidence', v_retry::TEXT);

  v_payload := jsonb_build_object(
    'command_id', v_cohort_command,
    'athlete_id', v_athlete,
    'session_record_id', v_record,
    'authored_test_reference', 'RUN-5K-TEST-A',
    'source', 'cohort',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1320000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', '2026-03-01',
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'treadmill'
  );
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);
  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('role', 'service_role', TRUE);
  v_result := public.record_cohort_completed_5k_benchmark(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT surface_context INTO v_value
  FROM public.running_5k_benchmark_evidence_revisions
  WHERE revision_id = (v_result->>'revision_id')::UUID;
  PERFORM sprint12_record('BI', 'cohort_completed_test_eligible', 'recorded|treadmill',
    v_result->>'status' || '|' || v_value, NULL,
    v_result->>'status' = 'recorded' AND v_value = 'treadmill', v_result::TEXT);

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('role', 'service_role', TRUE);
  v_retry := public.record_cohort_completed_5k_benchmark(
    jsonb_set(
      jsonb_set(v_payload, '{command_id}', to_jsonb('b2100000-0000-4000-8000-000000000025'::TEXT)),
      '{session_record_id}', to_jsonb(v_open_record::TEXT)
    )
  );
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record('BI', 'incomplete_cohort_session_rejected',
    'completed_cohort_test_missing', v_retry->>'code', NULL,
    v_retry->>'code' = 'completed_cohort_test_missing', v_retry::TEXT);

  SELECT has_function_privilege('authenticated',
    'public.record_cohort_completed_5k_benchmark(jsonb)', 'EXECUTE')
  INTO v_has_exec;
  PERFORM sprint12_record('BI', 'athlete_cannot_attest_cohort_test', 'false',
    v_has_exec::TEXT, NULL, NOT v_has_exec, NULL);
  SELECT has_function_privilege('anon',
    'public.record_manual_completed_5k_benchmark(jsonb)', 'EXECUTE')
  INTO v_has_exec;
  PERFORM sprint12_record('BI', 'anon_cannot_record_manual_test', 'false',
    v_has_exec::TEXT, NULL, NOT v_has_exec, NULL);
  SELECT has_function_privilege('service_role',
    'public.record_cohort_completed_5k_benchmark(jsonb)', 'EXECUTE')
  INTO v_has_exec;
  PERFORM sprint12_record('BI', 'service_role_can_attest_cohort_test', 'true',
    v_has_exec::TEXT, NULL, v_has_exec, NULL);
  SELECT has_table_privilege('service_role',
    'public.running_5k_benchmark_evidence', 'INSERT')
  INTO v_has_exec;
  PERFORM sprint12_record('BI', 'service_role_cannot_bypass_commands', 'false',
    v_has_exec::TEXT, NULL, NOT v_has_exec, NULL);
END $$;

SELECT * FROM sprint12_gate_results ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
