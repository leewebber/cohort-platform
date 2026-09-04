-- Gate AQ — authenticated completed-performance correction RPC, RLS, and audit.

DO $$
DECLARE
  v_owner UUID := 'a1000001-0000-4000-8000-0000000000a1';
  v_other UUID := 'a1000002-0000-4000-8000-0000000000a2';
  v_record UUID := 'a1100001-0000-4000-8000-0000000000a1';
  v_block UUID := 'a1100001-0000-4000-8000-0000000000b1';
  v_exercise UUID := 'a1100001-0000-4000-8000-0000000000c1';
  v_set UUID := 'a1100001-0000-4000-8000-0000000000d1';
  v_bw_record UUID := 'a1100001-0000-4000-8000-0000000000a2';
  v_bw_block UUID := 'a1100001-0000-4000-8000-0000000000b2';
  v_bw_exercise UUID := 'a1100001-0000-4000-8000-0000000000c2';
  v_bw_set UUID := 'a1100001-0000-4000-8000-0000000000d2';
  v_open UUID := 'a1100001-0000-4000-8000-0000000000a3';
  v_completed_at TIMESTAMPTZ := TIMESTAMPTZ '2026-09-04 12:00:00+00';
  v_result JSONB;
  v_count INT;
  v_duration INT;
  v_status TEXT;
  v_completed_at_after TIMESTAMPTZ;
  v_load NUMERIC;
  v_unit TEXT;
  v_sqlstate TEXT;
BEGIN
  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000',v_owner,'authenticated','authenticated',
      'apollo-gate-aq-owner@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''),
    ('00000000-0000-0000-0000-000000000000',v_other,'authenticated','authenticated',
      'apollo-gate-aq-other@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','','')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, status, session_snapshot, started_at, completed_at,
    duration_seconds, overall_rpe
  ) VALUES (
    v_record, v_owner::TEXT, 'completed',
    '{"sessionTitle":"Apollo Base"}'::JSONB,
    v_completed_at - INTERVAL '5 minutes', v_completed_at, 300, 6
  ), (
    v_bw_record, v_owner::TEXT, 'completed',
    '{"sessionTitle":"Core"}'::JSONB,
    v_completed_at - INTERVAL '20 minutes', v_completed_at, 1200, 5
  ), (
    v_open, v_owner::TEXT, 'in_progress',
    '{"sessionTitle":"Open"}'::JSONB,
    v_completed_at, NULL, NULL, NULL
  );

  INSERT INTO public.training_block_results (
    block_result_id, session_record_id, source_block_id, block_snapshot,
    status, result_type, result_data, position
  ) VALUES (
    v_block, v_record, 'base',
    '{"title":"Easy run","workoutFormat":"steady_state"}'::JSONB,
    'completed', 'endurance',
    '{"resultType":"endurance","completed":true,"distance":9.0,"distanceUnit":"km","durationSeconds":300,"averageHeartRate":145}'::JSONB,
    1
  ), (
    v_bw_block, v_bw_record, 'core',
    '{"title":"Core","workoutFormat":"none"}'::JSONB,
    'completed', 'strength',
    NULL,
    1
  );

  INSERT INTO public.training_exercise_results (
    exercise_result_id, block_result_id, source_exercise_id, exercise_snapshot, position
  ) VALUES (
    v_exercise, v_block, 'EX-RUN',
    '{"displayName":"Run","loadKind":"none"}'::JSONB,
    1
  ), (
    v_bw_exercise, v_bw_block, 'EX-HANG',
    '{"displayName":"Hang","loadKind":"bodyweight"}'::JSONB,
    1
  );

  INSERT INTO public.training_set_results (
    set_result_id, exercise_result_id, set_number, reps, load, load_unit,
    completed, position
  ) VALUES (
    v_set, v_exercise, 1, NULL, NULL, NULL, TRUE, 1
  ), (
    v_bw_set, v_bw_exercise, 1, 15, 20, 'kg', TRUE, 1
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count
  FROM public.training_session_records WHERE record_id = v_record;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('AQ', 'owner_can_read_own_result', '1', v_count::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_other::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count
  FROM public.training_session_records WHERE record_id = v_record;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('AQ', 'other_athlete_cannot_read_result', '0', v_count::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_other::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    v_result := public.correct_completed_performance_record(
      jsonb_build_object(
        'record_id', v_record,
        'blocks', jsonb_build_array(jsonb_build_object(
          'block_result_id', v_block,
          'result_data', '{"resultType":"endurance","completed":true,"distance":9.0,"distanceUnit":"km","durationSeconds":3000,"averageHeartRate":145}'::JSONB
        ))
      )
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'other_athlete_cannot_correct', '42501', 'executed', NULL, FALSE, v_result::TEXT
    );
  EXCEPTION WHEN insufficient_privilege OR others THEN
    v_sqlstate := SQLSTATE;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'other_athlete_cannot_correct', '42501', v_sqlstate,
      NULL, v_sqlstate IN ('42501', 'P0001'), SQLERRM
    );
  END;

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    UPDATE public.training_set_results SET reps = 99 WHERE set_result_id = v_set;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'direct_completed_set_update_denied', 'denied', 'updated', NULL, FALSE, NULL
    );
  EXCEPTION WHEN insufficient_privilege OR others THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'direct_completed_set_update_denied', 'denied', SQLSTATE, TRUE, TRUE, SQLERRM
    );
  END;

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    INSERT INTO public.performance_result_corrections (
      record_id, athlete_id, actor_id, before_values, after_values
    ) VALUES (v_record, v_owner::TEXT, v_owner, '{}'::JSONB, '{}'::JSONB);
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'direct_audit_insert_denied', '42501', 'inserted', NULL, FALSE, NULL
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'direct_audit_insert_denied', '42501', '42501', TRUE, TRUE, NULL
    );
  END;

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    v_result := public.correct_completed_performance_record(
      jsonb_build_object(
        'record_id', v_open,
        'overall_rpe', 8
      )
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'in_progress_correction_rejected', 'session_not_completed', 'accepted',
      NULL, FALSE, v_result::TEXT
    );
  EXCEPTION WHEN others THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'in_progress_correction_rejected', 'session_not_completed', SQLERRM,
      NULL, SQLERRM ILIKE '%session_not_completed%', SQLERRM
    );
  END;

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    v_result := public.correct_completed_performance_record(
      jsonb_build_object(
        'record_id', v_record,
        'blocks', jsonb_build_array(jsonb_build_object(
          'block_result_id', v_block,
          'result_data', '{"resultType":"endurance","durationSeconds":999999}'::JSONB
        ))
      )
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'out_of_range_duration_rejected', 'invalid_duration', 'accepted',
      NULL, FALSE, v_result::TEXT
    );
  EXCEPTION WHEN others THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'AQ', 'out_of_range_duration_rejected', 'invalid_duration', SQLERRM,
      NULL, SQLERRM ILIKE '%invalid_duration%', SQLERRM
    );
  END;

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.correct_completed_performance_record(
    jsonb_build_object(
      'record_id', v_record,
      'correction_note', 'Typed 5:00 instead of 50:00',
      'implausible_running_pace_acknowledged', TRUE,
      'blocks', jsonb_build_array(jsonb_build_object(
        'block_result_id', v_block,
        'result_data', '{"resultType":"endurance","completed":true,"distance":9.0,"distanceUnit":"km","durationSeconds":3000,"averageHeartRate":145}'::JSONB
      ))
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'AQ', 'valid_correction_status', 'corrected', v_result->>'status'
  );

  SELECT r.status, r.completed_at,
         (b.result_data->>'durationSeconds')::INT
  INTO v_status, v_completed_at_after, v_duration
  FROM public.training_session_records r
  JOIN public.training_block_results b ON b.session_record_id = r.record_id
  WHERE r.record_id = v_record;
  PERFORM sprint12_assert_eq('AQ', 'session_remains_completed', 'completed', v_status);
  PERFORM sprint12_record(
    'AQ', 'completed_at_unchanged', v_completed_at::TEXT, v_completed_at_after::TEXT,
    NULL, v_completed_at_after = v_completed_at, NULL
  );
  PERFORM sprint12_assert_eq('AQ', 'duration_corrected_in_place', '3000', v_duration::TEXT);

  SELECT count(*) INTO v_count FROM public.training_session_records WHERE athlete_id = v_owner::TEXT;
  PERFORM sprint12_assert_eq('AQ', 'no_duplicate_performance_records', '3', v_count::TEXT);
  SELECT count(*) INTO v_count FROM public.training_block_results WHERE session_record_id = v_record;
  PERFORM sprint12_assert_eq('AQ', 'no_duplicate_block_results', '1', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.performance_result_corrections WHERE record_id = v_record;
  PERFORM sprint12_assert_eq('AQ', 'audit_row_written', '1', v_count::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.correct_completed_performance_record(
    jsonb_build_object(
      'record_id', v_record,
      'overall_rpe', 7,
      'implausible_running_pace_acknowledged', TRUE
    )
  );
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO v_count
  FROM public.performance_result_corrections WHERE record_id = v_record;
  PERFORM sprint12_assert_eq('AQ', 'audit_is_append_only_inserts', '2', v_count::TEXT);

  BEGIN
    UPDATE public.performance_result_corrections
    SET correction_note = 'tamper'
    WHERE record_id = v_record;
    PERFORM sprint12_record(
      'AQ', 'audit_update_blocked', '42501', 'updated', NULL, FALSE, NULL
    );
  EXCEPTION WHEN others THEN
    PERFORM sprint12_record(
      'AQ', 'audit_update_blocked', '42501', SQLSTATE, NULL, TRUE, SQLERRM
    );
  END;

  PERFORM set_config('request.jwt.claim.sub', v_other::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count FROM public.performance_result_corrections;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('AQ', 'other_athlete_cannot_read_audit', '0', v_count::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.correct_completed_performance_record(
    jsonb_build_object(
      'record_id', v_bw_record,
      'sets', jsonb_build_array(jsonb_build_object(
        'set_result_id', v_bw_set,
        'reps', 15,
        'load', 40,
        'load_unit', 'kg'
      ))
    )
  );
  PERFORM set_config('role', 'postgres', true);
  SELECT load, load_unit INTO v_load, v_unit
  FROM public.training_set_results WHERE set_result_id = v_bw_set;
  PERFORM sprint12_record(
    'AQ', 'bodyweight_load_cleared', 'null', COALESCE(v_load::TEXT, 'null'),
    NULL, v_load IS NULL AND v_unit IS NULL, NULL
  );
  SELECT reps INTO v_count FROM public.training_set_results WHERE set_result_id = v_bw_set;
  PERFORM sprint12_assert_eq('AQ', 'bodyweight_reps_preserved', '15', v_count::TEXT);
END $$;

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM public.correct_completed_performance_record('{"record_id":"a1100001-0000-4000-8000-0000000000a1"}'::JSONB);
  RAISE EXCEPTION 'AQ anonymous correction unexpectedly permitted';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END $$;
ROLLBACK;
SELECT sprint12_record(
  'AQ', 'anonymous_correction_denied', '42501', '42501', NULL, TRUE, NULL
);

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results WHERE gate = 'AQ' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
