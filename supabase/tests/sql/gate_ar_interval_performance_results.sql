-- Gate AR — per-interval set identities, isolation, and correction.

DO $$
DECLARE
  v_owner UUID := 'a1000001-0000-4000-8000-0000000000b1';
  v_other UUID := 'a1000002-0000-4000-8000-0000000000b2';
  v_record UUID := 'a1200001-0000-4000-8000-0000000000a1';
  v_open UUID := 'a1200001-0000-4000-8000-0000000000a2';
  v_block UUID := 'a1200001-0000-4000-8000-0000000000b1';
  v_open_block UUID := 'a1200001-0000-4000-8000-0000000000b2';
  v_exercise UUID := 'a1200001-0000-4000-8000-0000000000c1';
  v_open_exercise UUID := 'a1200001-0000-4000-8000-0000000000c2';
  v_set UUID := 'a1200001-0000-4000-8000-0000000000d1';
  v_open_set UUID := 'a1200001-0000-4000-8000-0000000000d2';
  v_completed_at TIMESTAMPTZ := TIMESTAMPTZ '2026-09-05 12:00:00+00';
  v_result JSONB;
  v_count INT;
  v_sqlstate TEXT;
  v_completed_at_after TIMESTAMPTZ;
BEGIN
  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000',v_owner,'authenticated','authenticated',
      'apollo-gate-ar-owner@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''),
    ('00000000-0000-0000-0000-000000000000',v_other,'authenticated','authenticated',
      'apollo-gate-ar-other@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
      '{"provider":"email","providers":["email"]}','{}',FALSE,'','','','')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.training_session_records (
    record_id, athlete_id, status, session_snapshot, started_at, completed_at
  ) VALUES (
    v_record, v_owner::TEXT, 'completed',
    '{"sessionTitle":"Apollo Engine"}'::JSONB,
    v_completed_at - INTERVAL '50 minutes', v_completed_at
  ), (
    v_open, v_owner::TEXT, 'in_progress',
    '{"sessionTitle":"Open Engine"}'::JSONB,
    v_completed_at, NULL
  );

  INSERT INTO public.training_block_results (
    block_result_id, session_record_id, source_block_id, block_snapshot,
    status, result_type, result_data, position
  ) VALUES (
    v_block, v_record, 'engine',
    '{"title":"Intervals","workoutFormat":"intervals","workSeconds":180}'::JSONB,
    'completed', 'interval',
    '{"resultType":"interval","totalIntervals":5,"workSeconds":180,"paceUnit":"sec_per_km","intervalsCompleted":1,"intervals":[{"ordinal":1,"workSeconds":180,"paceSecondsPerKm":250,"paceUnit":"sec_per_km","state":"completed"}]}'::JSONB,
    1
  ), (
    v_open_block, v_open, 'engine',
    '{"title":"Intervals","workoutFormat":"intervals","workSeconds":180}'::JSONB,
    'in_progress', 'interval',
    '{"resultType":"interval","totalIntervals":5,"workSeconds":180,"paceUnit":"sec_per_km","intervalsCompleted":0}'::JSONB,
    1
  );

  INSERT INTO public.training_exercise_results (
    exercise_result_id, block_result_id, source_exercise_id, exercise_snapshot, position
  ) VALUES (
    v_exercise, v_block, 'EX-129', '{"displayName":"Run","loadKind":"none"}'::JSONB, 1
  ), (
    v_open_exercise, v_open_block, 'EX-129', '{"displayName":"Run","loadKind":"none"}'::JSONB, 1
  );

  INSERT INTO public.training_set_results (
    set_result_id, exercise_result_id, set_number, position, duration_seconds,
    distance, distance_unit, completed
  ) VALUES (
    v_set, v_exercise, 1, 1, 180, 0.72, 'km', TRUE
  ), (
    v_open_set, v_open_exercise, 1, 1, 180, NULL, 'km', FALSE
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('role', 'authenticated', true);

  UPDATE public.training_set_results
  SET distance = 0.725, completed = TRUE
  WHERE set_result_id = v_open_set;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 1 THEN
    PERFORM set_config('role', 'postgres', true);
    RAISE EXCEPTION 'AR owner cannot write own in-progress interval';
  END IF;

  BEGIN
    INSERT INTO public.training_set_results (
      set_result_id, exercise_result_id, set_number, position
    ) VALUES (
      'a1200001-0000-4000-8000-0000000000d3', v_open_exercise, 1, 2
    );
    PERFORM set_config('role', 'postgres', true);
    RAISE EXCEPTION 'AR duplicate ordinal accepted';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO public.training_set_results (
      set_result_id, exercise_result_id, set_number, position
    ) VALUES (
      'a1200001-0000-4000-8000-0000000000d4', v_open_exercise, 9, 9
    );
    PERFORM set_config('role', 'postgres', true);
    RAISE EXCEPTION 'AR out-of-range ordinal accepted';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    IF v_sqlstate NOT IN ('22023', 'P0001') THEN
      PERFORM set_config('role', 'postgres', true);
      RAISE;
    END IF;
  END;

  BEGIN
    UPDATE public.training_set_results SET distance = 0.8 WHERE set_result_id = v_set;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count <> 0 THEN
      PERFORM set_config('role', 'postgres', true);
      RAISE EXCEPTION 'AR direct completed interval update succeeded';
    END IF;
  EXCEPTION WHEN insufficient_privilege OR check_violation OR integrity_constraint_violation THEN
    NULL;
  END;

  v_result := public.correct_completed_performance_record(
    jsonb_build_object(
      'record_id', v_record,
      'blocks', jsonb_build_array(
        jsonb_build_object(
          'block_result_id', v_block,
          'result_data', jsonb_build_object(
            'resultType', 'interval',
            'totalIntervals', 5,
            'workSeconds', 180,
            'paceUnit', 'sec_per_km',
            'intervals', jsonb_build_array(
              jsonb_build_object(
                'ordinal', 1,
                'workSeconds', 180,
                'paceSecondsPerKm', 243,
                'paceUnit', 'sec_per_km',
                'state', 'completed'
              )
            )
          )
        )
      ),
      'sets', jsonb_build_array(
        jsonb_build_object(
          'set_result_id', v_set,
          'distance', 0.74074,
          'distance_unit', 'km',
          'duration_seconds', 180,
          'completed', TRUE,
          'note', NULL
        )
      )
    )
  );
  IF v_result->>'status' IS DISTINCT FROM 'corrected' THEN
    PERFORM set_config('role', 'postgres', true);
    RAISE EXCEPTION 'AR correction failed %', v_result;
  END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT completed_at INTO v_completed_at_after
  FROM public.training_session_records WHERE record_id = v_record;
  IF v_completed_at_after IS DISTINCT FROM v_completed_at THEN
    RAISE EXCEPTION 'AR completed_at mutated';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_owner::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM public.correct_completed_performance_record(
      jsonb_build_object(
        'record_id', v_record,
        'blocks', jsonb_build_array(
          jsonb_build_object(
            'block_result_id', v_block,
            'result_data', jsonb_build_object(
              'resultType', 'interval',
              'totalIntervals', 5,
              'paceUnit', 'min_per_mile',
              'intervalsCompleted', 1
            )
          )
        )
      )
    );
    PERFORM set_config('role', 'postgres', true);
    RAISE EXCEPTION 'AR unsupported unit accepted';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    IF v_sqlstate NOT IN ('22023', 'P0001') THEN
      RAISE;
    END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_other::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count
  FROM public.training_set_results WHERE set_result_id = v_open_set;
  IF v_count <> 0 THEN
    PERFORM set_config('role', 'postgres', true);
    RAISE EXCEPTION 'AR other athlete can read interval rows';
  END IF;
  BEGIN
    UPDATE public.training_set_results SET completed = TRUE WHERE set_result_id = v_open_set;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count <> 0 THEN
      PERFORM set_config('role', 'postgres', true);
      RAISE EXCEPTION 'AR other athlete wrote interval row';
    END IF;
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    PERFORM public.correct_completed_performance_record(
      jsonb_build_object('record_id', v_record, 'overall_rpe', 5)
    );
    PERFORM set_config('role', 'postgres', true);
    RAISE EXCEPTION 'AR other athlete corrected owner record';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    IF v_sqlstate NOT IN ('42501', 'P0001') THEN
      PERFORM set_config('role', 'postgres', true);
      RAISE;
    END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', 'anon', true);
  PERFORM set_config('role', 'anon', true);
  BEGIN
    SELECT count(*) INTO v_count
    FROM public.training_set_results WHERE set_result_id IN (v_set, v_open_set);
    IF v_count <> 0 THEN
      PERFORM set_config('role', 'postgres', true);
      RAISE EXCEPTION 'AR anon can read interval rows';
    END IF;
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO v_count
  FROM public.performance_result_corrections WHERE record_id = v_record;
  IF v_count < 1 THEN
    RAISE EXCEPTION 'AR audit row missing';
  END IF;

  RAISE NOTICE 'gate_ar_interval_performance_results PASSED';
END $$;
