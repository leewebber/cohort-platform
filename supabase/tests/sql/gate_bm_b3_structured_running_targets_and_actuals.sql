-- Gate BM — B3 slice 3 server-authoritative target and actual preservation.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_coach UUID := 'b3000000-0000-4000-8000-000000000002';
  v_athlete UUID := 'b3100000-0000-4000-8000-000000000001';
  v_skip_athlete UUID := 'b3100000-0000-4000-8000-000000000002';
  v_version UUID := 'b3000000-0000-4000-8000-000000000010';
  v_assignment UUID;
  v_occurrence UUID;
  v_slot UUID;
  v_training BIGINT;
  v_record UUID := 'b3100000-0000-4000-8000-000000000010';
  v_block_result UUID := 'b3100000-0000-4000-8000-000000000011';
  v_block_id TEXT;
  v_workout_id TEXT;
  v_step_id TEXT;
  v_start JSONB;
  v_enrol JSONB;
  v_snapshot JSONB;
  v_result JSONB;
  v_before JSONB;
  v_after JSONB;
  v_failed BOOLEAN;
  v_count INT;
  v_has_exec BOOLEAN;
BEGIN
  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  )
  SELECT
    '00000000-0000-0000-0000-000000000000', identity.id,
    'authenticated','authenticated',identity.email,
    crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
    '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''
  FROM (VALUES
    (v_coach, 'gate-bm-coach@example.invalid'),
    (v_athlete, 'gate-bm-athlete@example.invalid'),
    (v_skip_athlete, 'gate-bm-skip@example.invalid')
  ) AS identity(id, email)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles(id, display_name, is_athlete, is_coach)
  VALUES
    (v_coach, 'Gate BM Coach', FALSE, TRUE),
    (v_athlete, 'Gate BM Athlete', TRUE, FALSE),
    (v_skip_athlete, 'Gate BM Skip Athlete', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE SET
    is_athlete = EXCLUDED.is_athlete,
    is_coach = EXCLUDED.is_coach;
  INSERT INTO public.coach_athlete_relationships(coach_id, athlete_id, status)
  VALUES
    (v_coach, v_athlete, 'active'),
    (v_coach, v_skip_athlete, 'active')
  ON CONFLICT DO NOTHING;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_enrol := public.enrol_athlete_in_private_programme_version(
    v_version, 'Asia/Makassar', FALSE
  );
  v_assignment := (v_enrol->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT id, session_slot_id INTO STRICT v_occurrence, v_slot
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  SELECT
    authored_running_v1#>>'{executable_step_bindings,0,session_block_id}',
    authored_running_v1->>'workout_id',
    authored_running_v1#>>'{executable_step_bindings,0,step_id}'
  INTO STRICT v_block_id, v_workout_id, v_step_id
  FROM public.programme_version_session_slots
  WHERE id = v_slot;

  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM public.record_manual_completed_5k_benchmark(jsonb_build_object(
    'command_id', 'b3100000-0000-4000-8000-000000000020',
    'source_reference', 'manual-gate-bm',
    'source', 'manual',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1200000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', ((NOW() AT TIME ZONE 'Asia/Makassar')::DATE - 1)::TEXT,
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'outdoor'
  ));
  v_start := public.create_or_resume_fixed_programme_occurrence_session(
    v_occurrence
  );
  PERFORM set_config('role', 'postgres', TRUE);
  v_training := (v_start#>>'{training_session,id}')::BIGINT;
  v_snapshot := v_start->'running_target_snapshot';

  INSERT INTO public.training_session_records(
    record_id, athlete_id, training_session_id, source_protocol_id,
    programme_id, assignment_id, programme_session_id, status,
    session_snapshot, started_at
  ) VALUES (
    v_record, v_athlete::TEXT, v_training, 'PROT-RUN-A-R1',
    v_version::TEXT, v_assignment, v_slot, 'in_progress', '{}'::JSONB, NOW()
  );
  v_result := jsonb_build_object(
    'resultType', 'interval',
    'intervalsCompleted', 1,
    'totalIntervals', 1,
    'entered', TRUE,
    'paceUnit', 'sec_per_km',
    'intervals', jsonb_build_array(jsonb_build_object(
      'ordinal', 1,
      'workSeconds', 60,
      'workoutId', v_workout_id,
      'sessionBlockId', v_block_id,
      'authoredStepId', v_step_id,
      'repeatOrdinal', 1,
      'paceSecondsPerKm', 240,
      'paceUnit', 'sec_per_km',
      'state', 'completed'
    ))
  );
  INSERT INTO public.training_block_results(
    block_result_id, session_record_id, source_block_id, block_snapshot,
    status, result_type, result_data, position
  ) VALUES (
    v_block_result, v_record, v_block_id, '{}'::JSONB,
    'completed', 'interval', v_result, 1
  );
  UPDATE public.training_session_records
  SET status = 'completed', completed_at = NOW()
  WHERE record_id = v_record;
  SELECT block_snapshot->'structuredRunningV1' INTO STRICT v_after
  FROM public.training_block_results
  WHERE block_result_id = v_block_result;
  PERFORM sprint12_record(
    'BM', 'server_freezes_authoritative_target', 'true',
    (v_after#>'{frozen_target_snapshot}' = v_snapshot)::TEXT,
    v_after#>>'{workout_id}' = v_workout_id,
    v_after#>'{frozen_target_snapshot}' = v_snapshot
      AND v_after#>>'{session_block_id}' = v_block_id
      AND v_after#>>'{package_content_hash}' =
        v_snapshot->>'package_content_hash',
    v_after::TEXT
  );

  v_failed := FALSE;
  BEGIN
    UPDATE public.training_block_results
    SET result_data = jsonb_set(
      result_data,
      '{intervals,0,authoredStepId}',
      '"wrong-step"'::JSONB
    )
    WHERE block_result_id = v_block_result;
  EXCEPTION WHEN integrity_constraint_violation THEN
    v_failed := TRUE;
  END;
  PERFORM sprint12_record(
    'BM', 'actual_identity_tamper_rejected', 'true', v_failed::TEXT,
    NULL, v_failed, NULL
  );

  SELECT block_snapshot INTO v_before
  FROM public.training_block_results WHERE block_result_id = v_block_result;
  UPDATE public.training_block_results
  SET result_data = jsonb_set(
    result_data,
    '{intervals,0,paceSecondsPerKm}',
    '241'::JSONB
  )
  WHERE block_result_id = v_block_result;
  SELECT block_snapshot INTO v_after
  FROM public.training_block_results WHERE block_result_id = v_block_result;
  PERFORM sprint12_record(
    'BM', 'actual_correction_preserves_target', 'true',
    (v_before = v_after)::TEXT, NULL,
    v_before = v_after, NULL
  );

  v_failed := FALSE;
  BEGIN
    UPDATE public.training_block_results
    SET block_snapshot = jsonb_set(
      block_snapshot,
      '{structuredRunningV1,package_content_hash}',
      to_jsonb(repeat('0', 64))
    )
    WHERE block_result_id = v_block_result;
  EXCEPTION WHEN insufficient_privilege THEN
    v_failed := TRUE;
  END;
  PERFORM sprint12_record(
    'BM', 'target_mutation_rejected', 'true', v_failed::TEXT,
    NULL, v_failed, NULL
  );

  -- A skipped work repetition requires a partially completed session.
  PERFORM set_config('request.jwt.claim.sub', v_skip_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_enrol := public.enrol_athlete_in_private_programme_version(
    v_version, 'Asia/Makassar', FALSE
  );
  v_assignment := (v_enrol->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT id, session_slot_id INTO STRICT v_occurrence, v_slot
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  PERFORM set_config('role', 'authenticated', TRUE);
  v_start := public.create_or_resume_fixed_programme_occurrence_session(
    v_occurrence
  );
  PERFORM set_config('role', 'postgres', TRUE);
  v_training := (v_start#>>'{training_session,id}')::BIGINT;
  v_record := 'b3100000-0000-4000-8000-000000000030';
  v_block_result := 'b3100000-0000-4000-8000-000000000031';
  INSERT INTO public.training_session_records(
    record_id, athlete_id, training_session_id, source_protocol_id,
    programme_id, assignment_id, programme_session_id, status,
    session_snapshot, started_at
  ) VALUES (
    v_record, v_skip_athlete::TEXT, v_training, 'PROT-RUN-A-R1',
    v_version::TEXT, v_assignment, v_slot, 'in_progress', '{}'::JSONB, NOW()
  );
  v_result := jsonb_set(v_result, '{intervals,0,state}', '"skipped"'::JSONB);
  v_result := v_result #- '{intervals,0,paceSecondsPerKm}';
  v_result := jsonb_set(v_result, '{intervalsCompleted}', '0'::JSONB);
  INSERT INTO public.training_block_results(
    block_result_id, session_record_id, source_block_id, block_snapshot,
    status, result_type, result_data, position
  ) VALUES (
    v_block_result, v_record, v_block_id, '{}'::JSONB,
    'completed', 'interval', v_result, 1
  );
  v_failed := FALSE;
  BEGIN
    UPDATE public.training_session_records
    SET status = 'completed', completed_at = NOW()
    WHERE record_id = v_record;
  EXCEPTION WHEN integrity_constraint_violation THEN
    v_failed := TRUE;
  END;
  UPDATE public.training_session_records
  SET status = 'partially_completed', completed_at = NOW()
  WHERE record_id = v_record;
  PERFORM sprint12_record(
    'BM', 'skipped_requires_partial_session', 'true|partially_completed',
    v_failed::TEXT || '|' || (
      SELECT status FROM public.training_session_records WHERE record_id = v_record
    ), NULL,
    v_failed AND (
      SELECT status = 'partially_completed'
      FROM public.training_session_records WHERE record_id = v_record
    ), NULL
  );

  -- Unrelated records do not acquire B3 authority.
  INSERT INTO public.training_sessions(
    athlete_id, protocol_id, status, started_at, completed_at
  ) VALUES (
    v_athlete::TEXT, 'LEGACY-BM', 'completed', NOW(), NOW()
  ) RETURNING id INTO v_training;
  INSERT INTO public.training_session_records(
    record_id, athlete_id, training_session_id, source_protocol_id,
    status, session_snapshot, started_at, completed_at
  ) VALUES (
    'b3100000-0000-4000-8000-000000000040', v_athlete::TEXT,
    v_training, 'LEGACY-BM', 'completed', '{}'::JSONB, NOW(), NOW()
  );
  INSERT INTO public.training_block_results(
    block_result_id, session_record_id, source_block_id, block_snapshot,
    status, result_type, result_data, position
  ) VALUES (
    'b3100000-0000-4000-8000-000000000041',
    'b3100000-0000-4000-8000-000000000040', 'legacy-block', '{}'::JSONB,
    'completed', 'completion', '{"resultType":"completion","completed":true}', 1
  );
  SELECT count(*) INTO v_count
  FROM public.training_block_results
  WHERE block_result_id = 'b3100000-0000-4000-8000-000000000041'
    AND NOT (block_snapshot ? 'structuredRunningV1');
  PERFORM sprint12_record(
    'BM', 'legacy_completion_unchanged', '1', v_count::TEXT,
    NULL, v_count = 1, NULL
  );

  SELECT has_function_privilege(
    'authenticated',
    'public.cohort_b3_running_completion_authority(bigint,uuid)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BM', 'athlete_helpers_denied', 'false', v_has_exec::TEXT,
    NULL, NOT v_has_exec, NULL
  );
END $$;

SELECT * FROM sprint12_gate_results ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
