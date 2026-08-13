-- Gate Q — atomic programme training-session create/resume and ownership.
-- Requires helpers.sql.
TRUNCATE sprint12_gate_results;

CREATE TABLE IF NOT EXISTS sprint12_gate_q_fixture (
  fixture_key TEXT PRIMARY KEY,
  athlete_id UUID NOT NULL,
  payload JSONB NOT NULL
);
TRUNCATE sprint12_gate_q_fixture;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-Q-A';
  v_lineage UUID := '91919191-9191-4919-8919-919191919191';
  v_hash TEXT := sprint12_hash('gate-q-atomic-start');
  v_package JSONB;
  v_res JSONB;
  v_version UUID;
  v_slot UUID;
  v_athlete_a UUID := 'a1000000-0000-4000-8000-000000000001';
  v_athlete_b UUID := 'b1000000-0000-4000-8000-000000000002';
  v_athlete_c UUID := 'c1000000-0000-4000-8000-000000000003';
  v_athlete_d UUID := 'd1000000-0000-4000-8000-000000000004';
  v_athlete_e UUID := 'e1000000-0000-4000-8000-000000000005';
  v_assignment_a UUID;
  v_assignment_b UUID;
  v_assignment_c UUID;
  v_assignment_d UUID;
  v_assignment_e UUID;
  v_payload_a JSONB;
  v_payload_b JSONB;
  v_payload_c JSONB;
  v_payload_d JSONB;
  v_payload_e JSONB;
  v_key TEXT;
  v_session_a BIGINT;
  v_session_b BIGINT;
  v_legacy_session BIGINT;
  v_count INT;
BEGIN
  DELETE FROM programme_assignments
  WHERE athlete_id IN (
    v_athlete_a,
    v_athlete_b,
    v_athlete_c,
    v_athlete_d,
    v_athlete_e
  );

  PERFORM sprint12_ensure_published_session(
    v_protocol,
    v_lineage,
    1,
    'Gate Q Session'
  );
  v_package := sprint12_build_package(
    'PROG-GATE-Q-ATOMIC',
    1,
    v_hash,
    v_protocol,
    v_lineage
  );
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_package);
  PERFORM set_config('role', 'postgres', true);
  v_version := (v_res->>'programme_version_id')::UUID;

  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_version, 'gate-q');
  PERFORM public.approve_cohort_global_programme_version(v_version, 'gate-q');
  PERFORM set_config('role', 'postgres', true);

  SELECT package_content_hash INTO v_hash
  FROM programme_versions
  WHERE id = v_version;

  SELECT s.id INTO v_slot
  FROM programme_version_weeks w
  JOIN programme_version_days d ON d.week_id = w.id
  JOIN programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_version
    AND w.week_number = 1
    AND d.day_key = 'day_1'
    AND s.session_order = 1;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a,
     'authenticated', 'authenticated', 'gate-q-a@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b,
     'authenticated', 'authenticated', 'gate-q-b@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_c,
     'authenticated', 'authenticated', 'gate-q-c@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_d,
     'authenticated', 'authenticated', 'gate-q-d@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_e,
     'authenticated', 'authenticated', 'gate-q-e@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate Q Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate Q Athlete B', TRUE, FALSE),
    (v_athlete_c, 'Gate Q Athlete C', TRUE, FALSE),
    (v_athlete_d, 'Gate Q Athlete D', TRUE, FALSE),
    (v_athlete_e, 'Gate Q Athlete E', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete,
        is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'UTC',
    FALSE
  );
  v_assignment_a := (v_res->>'enrolment_id')::UUID;
  PERFORM public.materialise_athlete_plan_from_enrolment(
    v_assignment_a,
    'UTC'
  );
  PERFORM set_config('role', 'postgres', true);

  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'UTC',
    FALSE
  );
  v_assignment_b := (v_res->>'enrolment_id')::UUID;
  PERFORM public.materialise_athlete_plan_from_enrolment(
    v_assignment_b,
    'UTC'
  );
  PERFORM set_config('role', 'postgres', true);

  PERFORM set_config('request.jwt.claim.sub', v_athlete_c::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'UTC',
    FALSE
  );
  v_assignment_c := (v_res->>'enrolment_id')::UUID;
  PERFORM public.materialise_athlete_plan_from_enrolment(
    v_assignment_c,
    'UTC'
  );
  PERFORM set_config('role', 'postgres', true);

  PERFORM set_config('request.jwt.claim.sub', v_athlete_d::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'UTC',
    FALSE
  );
  v_assignment_d := (v_res->>'enrolment_id')::UUID;
  PERFORM public.materialise_athlete_plan_from_enrolment(
    v_assignment_d,
    'UTC'
  );
  PERFORM set_config('role', 'postgres', true);

  PERFORM set_config('request.jwt.claim.sub', v_athlete_e::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'UTC',
    FALSE
  );
  v_assignment_e := (v_res->>'enrolment_id')::UUID;
  PERFORM public.materialise_athlete_plan_from_enrolment(
    v_assignment_e,
    'UTC'
  );
  PERFORM set_config('role', 'postgres', true);

  v_key := format(
    'prog:%s@%s:w1:day_1:s1:%s',
    v_assignment_a,
    v_version,
    v_protocol
  );
  v_payload_a := jsonb_build_object(
    'assignment_id', v_assignment_a,
    'session_slot_id', v_slot,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', v_key,
    'planned_protocol_id', v_protocol,
    'effective_protocol_id', v_protocol,
    'expected_week', 1,
    'expected_day_key', 'day_1',
    'expected_slot_order', 1
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_programme_training_session(v_payload_a);
  PERFORM set_config('role', 'postgres', true);
  v_session_a := (v_res->'training_session'->>'id')::BIGINT;
  PERFORM sprint12_record(
    'Q', 'first_launch_created', 'created', v_res->>'status',
    NULL, (v_res->>'status') = 'created', v_res::TEXT
  );

  SELECT count(*) INTO v_count
  FROM training_sessions ts
  JOIN programme_slot_outcomes o ON o.training_session_id = ts.id
  WHERE o.assignment_id = v_assignment_a
    AND o.session_slot_id = v_slot
    AND ts.athlete_id = v_athlete_a::TEXT;
  PERFORM sprint12_record(
    'Q', 'session_and_link_atomic', '1', v_count::TEXT,
    NULL, v_count = 1, NULL
  );

  SELECT programme_id INTO v_key
  FROM training_sessions
  WHERE id = v_session_a;
  PERFORM sprint12_record(
    'Q', 'training_session_uses_lineage_code', 'PROG-GATE-Q-ATOMIC', v_key,
    NULL, v_key = 'PROG-GATE-Q-ATOMIC', NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_programme_training_session(v_payload_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'Q', 'repeat_resumes', 'resumed', v_res->>'status',
    NULL,
    (v_res->>'status') = 'resumed'
      AND (v_res->'training_session'->>'id')::BIGINT = v_session_a,
    v_res::TEXT
  );

  -- Cross-athlete access to A is rejected and creates no extra row.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_programme_training_session(v_payload_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'Q', 'cross_athlete_denied', 'authorization_failure', v_res->>'status',
    NULL,
    (v_res->>'status') = 'authorization_failure'
      AND (v_res->>'code') = 'cross_athlete_assignment',
    v_res::TEXT
  );

  SELECT count(*) INTO v_count
  FROM training_sessions
  WHERE athlete_id = v_athlete_a::TEXT;
  PERFORM sprint12_record(
    'Q', 'cross_athlete_no_duplicate', '1', v_count::TEXT,
    NULL, v_count = 1, NULL
  );

  -- A second canonical occurrence (different assignment/athlete) gets a
  -- different session and cannot collide with A.
  v_payload_b := v_payload_a || jsonb_build_object(
    'assignment_id', v_assignment_b,
    'programmed_session_key', format(
      'prog:%s@%s:w1:day_1:s1:%s',
      v_assignment_b,
      v_version,
      v_protocol
    )
  );
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_programme_training_session(v_payload_b);
  PERFORM set_config('role', 'postgres', true);
  v_session_b := (v_res->'training_session'->>'id')::BIGINT;
  PERFORM sprint12_record(
    'Q', 'different_occurrence_distinct_session', 'different',
    CASE WHEN v_session_b IS DISTINCT FROM v_session_a
      THEN 'different' ELSE 'same' END,
    NULL, v_session_b IS DISTINCT FROM v_session_a, v_res::TEXT
  );

  -- Wrong version and slot fail before any new session.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_programme_training_session(
    v_payload_a || jsonb_build_object(
      'programme_version_id', '00000000-0000-4000-8000-000000000099'
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'Q', 'wrong_version_rejected', 'exact_version_missing', v_res->>'code',
    NULL, (v_res->>'code') = 'exact_version_missing', v_res::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_programme_training_session(
    v_payload_a || jsonb_build_object(
      'session_slot_id', '00000000-0000-4000-8000-000000000098'
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'Q', 'wrong_slot_rejected', 'authored_slot_mismatch', v_res->>'code',
    NULL, (v_res->>'code') = 'authored_slot_mismatch', v_res::TEXT
  );

  -- Existing valid pre-correction data resumes without deletion or identity
  -- replacement; null provenance is enriched only after all checks.
  INSERT INTO training_sessions (
    athlete_id, protocol_id, programme_id, week_number, status,
    started_at, created_at, updated_at
  ) VALUES (
    v_athlete_c::TEXT, v_protocol, v_version::TEXT, 1, 'in_progress',
    NOW(), NOW(), NOW()
  )
  RETURNING id INTO v_legacy_session;

  INSERT INTO programme_slot_outcomes (
    assignment_id, session_slot_id, week_number, day_key, session_order,
    outcome_status, training_session_id
  ) VALUES (
    v_assignment_c, v_slot, 1, 'day_1', 1, 'in_progress', v_legacy_session
  );

  v_payload_c := v_payload_a || jsonb_build_object(
    'assignment_id', v_assignment_c,
    'programmed_session_key', format(
      'prog:%s@%s:w1:day_1:s1:%s',
      v_assignment_c,
      v_version,
      v_protocol
    )
  );
  PERFORM set_config('request.jwt.claim.sub', v_athlete_c::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_programme_training_session(v_payload_c);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'Q', 'existing_valid_data_resumed', 'resumed', v_res->>'status',
    NULL,
    (v_res->>'status') = 'resumed'
      AND (v_res->'training_session'->>'id')::BIGINT = v_legacy_session,
    v_res::TEXT
  );

  -- Force outcome persistence failure after session insert. The function call
  -- must roll the inserted session back with the failed link.
  v_payload_d := v_payload_a || jsonb_build_object(
    'assignment_id', v_assignment_d,
    'programmed_session_key', format(
      'prog:%s@%s:w1:day_1:s1:%s',
      v_assignment_d,
      v_version,
      v_protocol
    )
  );
  CREATE OR REPLACE FUNCTION pg_temp.gate_q_reject_link()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $trigger$
  BEGIN
    IF NEW.assignment_id::TEXT = current_setting(
      'cohort.gate_q_fail_assignment',
      true
    ) THEN
      RAISE EXCEPTION 'gate-q forced link failure';
    END IF;
    RETURN NEW;
  END;
  $trigger$;
  CREATE TRIGGER gate_q_reject_link
    BEFORE INSERT OR UPDATE ON programme_slot_outcomes
    FOR EACH ROW EXECUTE FUNCTION pg_temp.gate_q_reject_link();

  BEGIN
    PERFORM set_config(
      'cohort.gate_q_fail_assignment',
      v_assignment_d::TEXT,
      true
    );
    PERFORM set_config('request.jwt.claim.sub', v_athlete_d::TEXT, true);
    PERFORM set_config('role', 'authenticated', true);
    PERFORM public.create_or_resume_programme_training_session(v_payload_d);
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'Q', 'transaction_failure_surfaces', 'error', 'success',
      NULL, FALSE, 'forced link failure did not surface'
    );
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'Q', 'transaction_failure_surfaces', 'error', 'error',
      NULL, SQLERRM LIKE '%gate-q forced link failure%', SQLERRM
    );
  END;
  DROP TRIGGER gate_q_reject_link ON programme_slot_outcomes;

  SELECT count(*) INTO v_count
  FROM training_sessions
  WHERE athlete_id = v_athlete_d::TEXT;
  PERFORM sprint12_record(
    'Q', 'transaction_failure_no_orphan', '0', v_count::TEXT,
    NULL, v_count = 0, NULL
  );

  -- RLS still hides A's outcome from B.
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
    PERFORM set_config('role', 'authenticated', true);
    SELECT count(*) INTO v_count
    FROM programme_slot_outcomes
    WHERE assignment_id = v_assignment_a;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'Q', 'rls_cross_athlete_hidden', '0', v_count::TEXT,
      NULL, v_count = 0, NULL
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'Q', 'rls_cross_athlete_hidden', 'hidden', 'hidden',
      TRUE, TRUE, 'table privilege and RLS boundary denied cross-athlete read'
    );
  END;

  -- Anon has no execute grant.
  BEGIN
    PERFORM set_config('role', 'anon', true);
    PERFORM public.create_or_resume_programme_training_session('{}'::JSONB);
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'Q', 'anon_execute_denied', 'denied', 'executed',
      NULL, FALSE, NULL
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'Q', 'anon_execute_denied', 'denied', 'denied',
      TRUE, TRUE, 'EXECUTE denied'
    );
  END;

  -- Leave one clean occurrence for the true multi-session concurrency gate.
  v_payload_e := v_payload_a || jsonb_build_object(
    'assignment_id', v_assignment_e,
    'programmed_session_key', format(
      'prog:%s@%s:w1:day_1:s1:%s',
      v_assignment_e,
      v_version,
      v_protocol
    )
  );
  INSERT INTO sprint12_gate_q_fixture (fixture_key, athlete_id, payload)
  VALUES ('concurrency', v_athlete_e, v_payload_e);
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results
WHERE gate = 'Q'
ORDER BY case_id;

SELECT sprint12_fail_if_any_failed();
