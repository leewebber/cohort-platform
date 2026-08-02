-- Sprint 1.5A Gate L — atomic programme completion + cursor advancement.
-- Requires helpers.sql. Uses auth.users + profiles + request.jwt.claim.sub.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol_a TEXT := 'PROT-GATE-L-A';
  v_protocol_b TEXT := 'PROT-GATE-L-B';
  v_lineage UUID := 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1';
  v_lineage_b UUID := 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2';
  v_hash TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_version UUID;
  v_athlete_a UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_athlete_b UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_enrol_a UUID;
  v_enrol_b UUID;
  v_slot_a UUID;
  v_slot_b UUID;
  v_week INT;
  v_day TEXT;
  v_slot INT;
  v_key TEXT;
  v_record UUID := '11111111-1111-4111-8111-111111111111';
  v_record_2 UUID := '22222222-2222-4222-8222-222222222222';
  v_ts BIGINT;
  v_count INT;
  v_fp TEXT := 'fp-gate-l-actuals-1';
  v_fp_conflict TEXT := 'fp-gate-l-actuals-conflict';
  v_idem TEXT := 'idem-gate-l-1';
  v_idem_2 TEXT := 'idem-gate-l-2';
BEGIN
  DELETE FROM programme_assignments
  WHERE athlete_id IN (v_athlete_a, v_athlete_b);

  PERFORM sprint12_ensure_published_session(v_protocol_a, v_lineage, 1, 'Gate L Slot A');
  PERFORM sprint12_ensure_published_session(v_protocol_b, v_lineage_b, 1, 'Gate L Slot B');

  v_hash := sprint12_hash('gate-l-complete');
  -- Build a two-slot package via import helper, then add second slot if needed.
  v_payload := sprint12_build_package('PROG-GATE-L-ELIG', 1, v_hash, v_protocol_a, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_version := (v_res->>'programme_version_id')::uuid;

  -- Ensure day_1 has two executable slots in authored order.
  SELECT s.id INTO v_slot_a
  FROM programme_version_weeks w
  JOIN programme_version_days d ON d.week_id = w.id
  JOIN programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_version
    AND w.week_number = 1
    AND d.day_key = 'day_1'
    AND s.session_order = 1
  LIMIT 1;

  IF NOT EXISTS (
    SELECT 1
    FROM programme_version_weeks w
    JOIN programme_version_days d ON d.week_id = w.id
    JOIN programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = v_version
      AND w.week_number = 1
      AND d.day_key = 'day_1'
      AND s.session_order = 2
  ) THEN
    INSERT INTO programme_version_session_slots (
      id, day_id, session_order, protocol_id, display_title, is_optional
    )
    SELECT gen_random_uuid(), d.id, 2, v_protocol_b, 'Gate L Slot B', FALSE
    FROM programme_version_weeks w
    JOIN programme_version_days d ON d.week_id = w.id
    WHERE w.version_id = v_version
      AND w.week_number = 1
      AND d.day_key = 'day_1'
    LIMIT 1;
  END IF;

  SELECT s.id INTO v_slot_b
  FROM programme_version_weeks w
  JOIN programme_version_days d ON d.week_id = w.id
  JOIN programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_version
    AND w.week_number = 1
    AND d.day_key = 'day_1'
    AND s.session_order = 2
  LIMIT 1;

  -- Keep draft mutable until structure is final, then refresh hash + publish.
  v_hash := sprint12_hash('gate-l-complete-two-slot');
  UPDATE programme_versions
  SET package_content_hash = v_hash,
      lifecycle_status = 'draft'
  WHERE id = v_version;

  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_version, 'gate-l');
  PERFORM public.approve_cohort_global_programme_version(v_version, 'gate-l');
  PERFORM set_config('role', 'postgres', true);

  SELECT package_content_hash INTO v_hash FROM programme_versions WHERE id = v_version;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
     'gate-l-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
     'gate-l-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate L Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate L Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_version, 'UTC', FALSE);
  v_enrol_a := (v_res->>'enrolment_id')::uuid;
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, 'UTC');
  PERFORM set_config('role', 'postgres', true);

  PERFORM sprint12_record(
    'L','materialise_ok','materialised', v_res->>'status',
    NULL, (v_res->>'status') IN ('materialised','already_materialised'), v_res::text
  );

  SELECT current_week_number, current_day_key, current_slot_order,
         materialised_package_content_hash
    INTO v_week, v_day, v_slot, v_hash
  FROM programme_assignments WHERE id = v_enrol_a;

  v_key := format('prog:%s@%s:w%s:%s:s%s:%s', v_enrol_a, v_version, v_week, v_day, v_slot, v_protocol_a);

  INSERT INTO training_sessions (athlete_id, protocol_id, status, started_at)
  VALUES (v_athlete_a::text, v_protocol_a, 'in_progress', NOW())
  RETURNING id INTO v_ts;

  -- Anon denied
  BEGIN
    PERFORM set_config('role', 'anon', true);
    v_res := public.complete_programme_session_and_advance('{}'::jsonb);
    PERFORM sprint12_record('L','anon_execute','denied', coalesce(v_res->>'status','executed'), NULL, FALSE, NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('L','anon_execute','denied','denied', TRUE, TRUE, 'EXECUTE denied');
  WHEN OTHERS THEN
    PERFORM sprint12_record('L','anon_execute','denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Direct cursor write denied
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
    PERFORM set_config('role', 'authenticated', true);
    UPDATE programme_assignments
    SET current_slot_order = 2
    WHERE id = v_enrol_a;
    PERFORM sprint12_record('L','direct_cursor_update','denied','updated', NULL, FALSE, NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('L','direct_cursor_update','denied','denied', TRUE, TRUE, SQLERRM);
  WHEN OTHERS THEN
    PERFORM sprint12_record('L','direct_cursor_update','denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- GUC bypass still blocked for authenticated (Gate K invariant)
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    UPDATE programme_assignments
    SET current_slot_order = 2
    WHERE id = v_enrol_a;
    PERFORM sprint12_record('L','guc_bypass_blocked','denied','updated', NULL, FALSE, NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('L','guc_bypass_blocked','denied','denied', TRUE, TRUE, SQLERRM);
  WHEN OTHERS THEN
    PERFORM sprint12_record('L','guc_bypass_blocked','denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Happy path commit
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.complete_programme_session_and_advance(jsonb_build_object(
    'assignment_id', v_enrol_a,
    'session_slot_id', v_slot_a,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', v_key,
    'logical_completion_key', v_key,
    'idempotency_key', v_idem,
    'actuals_fingerprint', v_fp,
    'protocol_id', v_protocol_a,
    'expected_week', v_week,
    'expected_day_key', v_day,
    'expected_slot_order', v_slot,
    'training_session_id', v_ts,
    'record_id', v_record,
    'status', 'completed',
    'completion_record', jsonb_build_object(
      'record_id', v_record,
      'source_protocol_id', v_protocol_a,
      'session_snapshot', '{}'::jsonb,
      'athlete_note', 'gate-l-note'
    )
  ));
  PERFORM set_config('role', 'postgres', true);

  PERFORM sprint12_record(
    'L','commit_status','committed', v_res->>'status',
    NULL, (v_res->>'status') = 'committed', v_res::text
  );

  SELECT current_slot_order INTO v_slot FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record('L','cursor_advanced_once','2', v_slot::text, NULL, v_slot = 2, NULL);

  SELECT count(*) INTO v_count
  FROM programme_slot_outcomes
  WHERE assignment_id = v_enrol_a AND outcome_status IN ('completed','completed_partial');
  PERFORM sprint12_record('L','one_completion','1', v_count::text, NULL, v_count = 1, NULL);

  SELECT count(*) INTO v_count
  FROM training_session_records
  WHERE record_id = v_record AND status = 'completed' AND athlete_note = 'gate-l-note';
  PERFORM sprint12_record('L','actuals_authority','1', v_count::text, NULL, v_count = 1, NULL);

  -- Same idempotency key replay
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.complete_programme_session_and_advance(jsonb_build_object(
    'assignment_id', v_enrol_a,
    'session_slot_id', v_slot_a,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', v_key,
    'logical_completion_key', v_key,
    'idempotency_key', v_idem,
    'actuals_fingerprint', v_fp,
    'protocol_id', v_protocol_a,
    'expected_week', 1,
    'expected_day_key', 'day_1',
    'expected_slot_order', 1,
    'training_session_id', v_ts,
    'record_id', v_record,
    'status', 'completed',
    'completion_record', jsonb_build_object(
      'record_id', v_record,
      'source_protocol_id', v_protocol_a,
      'session_snapshot', '{}'::jsonb,
      'athlete_note', 'gate-l-note'
    )
  ));
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'L','idempotent_replay','already_committed', v_res->>'status',
    NULL, (v_res->>'status') = 'already_committed', v_res::text
  );

  SELECT current_slot_order INTO v_slot FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record('L','no_double_advance','2', v_slot::text, NULL, v_slot = 2, NULL);

  -- Different idempotency key, same logical completion + same fingerprint
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.complete_programme_session_and_advance(jsonb_build_object(
    'assignment_id', v_enrol_a,
    'session_slot_id', v_slot_a,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', v_key,
    'logical_completion_key', v_key,
    'idempotency_key', v_idem_2,
    'actuals_fingerprint', v_fp,
    'protocol_id', v_protocol_a,
    'expected_week', 1,
    'expected_day_key', 'day_1',
    'expected_slot_order', 1,
    'training_session_id', v_ts,
    'record_id', v_record,
    'status', 'completed',
    'completion_record', jsonb_build_object(
      'record_id', v_record,
      'source_protocol_id', v_protocol_a,
      'session_snapshot', '{}'::jsonb
    )
  ));
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'L','logical_replay','already_committed', v_res->>'status',
    NULL, (v_res->>'status') = 'already_committed', v_res::text
  );

  -- Conflicting payload rejected
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.complete_programme_session_and_advance(jsonb_build_object(
    'assignment_id', v_enrol_a,
    'session_slot_id', v_slot_a,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', v_key,
    'logical_completion_key', v_key,
    'idempotency_key', 'idem-conflict',
    'actuals_fingerprint', v_fp_conflict,
    'protocol_id', v_protocol_a,
    'expected_week', 1,
    'expected_day_key', 'day_1',
    'expected_slot_order', 1,
    'training_session_id', v_ts,
    'record_id', v_record_2,
    'status', 'completed',
    'completion_record', jsonb_build_object(
      'record_id', v_record_2,
      'source_protocol_id', v_protocol_a,
      'session_snapshot', '{}'::jsonb,
      'athlete_note', 'overwrite-attempt'
    )
  ));
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'L','conflict_rejects_overwrite','conflict', v_res->>'status',
    NULL, (v_res->>'status') = 'conflict', v_res::text
  );

  SELECT athlete_note INTO v_day
  FROM training_session_records WHERE record_id = v_record;
  PERFORM sprint12_record(
    'L','actuals_not_overwritten','gate-l-note', v_day,
    NULL, v_day = 'gate-l-note', NULL
  );

  -- Cross-athlete denied
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_version, 'UTC', FALSE);
  -- May fail if one-active / version exclusivity; ignore for B isolation probe.
  v_res := public.complete_programme_session_and_advance(jsonb_build_object(
    'assignment_id', v_enrol_a,
    'session_slot_id', v_slot_a,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', v_key,
    'logical_completion_key', v_key,
    'idempotency_key', 'idem-b',
    'actuals_fingerprint', v_fp,
    'protocol_id', v_protocol_a,
    'expected_week', 1,
    'expected_day_key', 'day_1',
    'expected_slot_order', 1,
    'training_session_id', v_ts,
    'record_id', v_record_2,
    'status', 'completed',
    'completion_record', jsonb_build_object(
      'record_id', v_record_2,
      'source_protocol_id', v_protocol_a,
      'session_snapshot', '{}'::jsonb
    )
  ));
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'L','cross_athlete_denied','authorization_failure', v_res->>'status',
    NULL, (v_res->>'status') = 'authorization_failure', v_res::text
  );

  -- Client-nominated next cursor rejected
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.complete_programme_session_and_advance(jsonb_build_object(
    'assignment_id', v_enrol_a,
    'next_slot_order', 99,
    'session_slot_id', v_slot_b,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', 'x',
    'logical_completion_key', 'x',
    'idempotency_key', 'idem-next',
    'actuals_fingerprint', 'fp',
    'protocol_id', v_protocol_b,
    'expected_week', 1,
    'expected_day_key', 'day_1',
    'expected_slot_order', 2,
    'training_session_id', v_ts,
    'record_id', v_record_2,
    'status', 'completed'
  ));
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'L','client_next_cursor_forbidden','validation_failure', v_res->>'status',
    NULL, (v_res->>'status') = 'validation_failure' AND (v_res->>'code') = 'client_nominated_authority_forbidden',
    v_res::text
  );

  -- Package hash unchanged
  SELECT count(*) INTO v_count
  FROM programme_assignments
  WHERE id = v_enrol_a
    AND materialised_package_content_hash = v_hash
    AND programme_version_id = v_version;
  PERFORM sprint12_record('L','version_hash_preserved','1', v_count::text, NULL, v_count = 1, NULL);

END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results
WHERE gate = 'L'
ORDER BY case_id;

SELECT sprint12_fail_if_any_failed();
