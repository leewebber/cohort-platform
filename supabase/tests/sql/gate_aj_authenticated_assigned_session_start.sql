-- Gate AJ — authenticated athlete starts and resumes their assigned Apollo
-- Monday session through the canonical RPC, then persists one in-progress
-- performance draft through the RLS-constrained result tree.
-- Runs after AF–AI and intentionally reuses AF's Apollo athlete.

DO $$
DECLARE
  v_athlete UUID := 'af000002-0000-4000-8000-000000000002';
  v_other UUID := 'a7000001-0000-4000-8000-000000000001';
  v_unassigned UUID := 'a9000001-0000-4000-8000-000000000001';
  v_version UUID;
  v_assignment UUID;
  v_slot UUID;
  v_hash TEXT;
  v_payload JSONB;
  v_first JSONB;
  v_retry JSONB;
  v_other_result JSONB;
  v_session_id BIGINT;
  v_record_id UUID := 'a9000002-0000-4000-8000-000000000002';
  v_count INT;
BEGIN
  SELECT v.id, v.package_content_hash
  INTO v_version, v_hash
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK' AND v.version_number = 1;

  SELECT id INTO v_assignment
  FROM programme_assignments
  WHERE athlete_id = v_athlete AND status = 'active';

  SELECT s.id INTO v_slot
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_version
    AND w.week_number = 1
    AND d.day_key = 'day_1'
    AND s.session_order = 1
    AND s.protocol_id = 'APOLLO-W1-MON-R1';

  IF v_version IS NULL OR v_assignment IS NULL OR v_slot IS NULL THEN
    RAISE EXCEPTION 'AJ Apollo AF fixture is incomplete';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token, email_change_token_new,
    email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', v_unassigned,
    'authenticated', 'authenticated', 'gate-aj-unassigned@example.invalid',
    crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
    '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_unassigned, 'Gate AJ unassigned athlete', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  v_payload := jsonb_build_object(
    'assignment_id', v_assignment,
    'session_slot_id', v_slot,
    'programme_version_id', v_version,
    'materialised_package_content_hash', v_hash,
    'programmed_session_key', format(
      'prog:%s@%s:w1:day_1:s1:APOLLO-W1-MON-R1', v_assignment, v_version
    ),
    'planned_protocol_id', 'APOLLO-W1-MON-R1',
    'effective_protocol_id', 'APOLLO-W1-MON-R1',
    'expected_week', 1,
    'expected_day_key', 'day_1',
    'expected_slot_order', 1
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_first := public.create_or_resume_programme_training_session(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_session_id := (v_first->'training_session'->>'id')::BIGINT;
  PERFORM sprint12_record(
    'AJ', 'assigned_monday_start', 'APOLLO-W1-MON-R1',
    v_first->'training_session'->>'protocol_id', NULL,
    (v_first->>'status') IN ('created', 'resumed')
      AND v_first->'training_session'->>'protocol_id' = 'APOLLO-W1-MON-R1',
    v_first::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_retry := public.create_or_resume_programme_training_session(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AJ', 'start_retry_idempotent', v_session_id::TEXT,
    v_retry->'training_session'->>'id', NULL,
    (v_retry->>'status') = 'resumed'
      AND (v_retry->'training_session'->>'id')::BIGINT = v_session_id,
    v_retry::TEXT
  );

  -- This is the player-created in-progress draft. Existing RLS ties it to the
  -- caller and the app never receives direct write access to training_sessions
  -- or programme_slot_outcomes.
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  INSERT INTO training_session_records (
    record_id, athlete_id, training_session_id, source_protocol_id,
    programme_id, assignment_id, status, session_snapshot, started_at
  ) VALUES (
    v_record_id, v_athlete::TEXT, v_session_id, 'APOLLO-W1-MON-R1',
    'APOLLO-BUILD-12-WEEK', v_assignment, 'in_progress', '{}'::JSONB, NOW()
  ) ON CONFLICT (record_id) DO UPDATE
    SET session_snapshot = EXCLUDED.session_snapshot,
        updated_at = NOW();
  PERFORM set_config('role', 'postgres', true);

  SELECT count(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id = v_athlete::TEXT
    AND training_session_id = v_session_id
    AND status = 'in_progress';
  PERFORM sprint12_assert_eq('AJ', 'one_in_progress_performance', '1', v_count::TEXT);

  PERFORM set_config('request.jwt.claim.sub', v_other::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_other_result := public.create_or_resume_programme_training_session(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AJ', 'other_athlete_start_denied', 'authorization_failure', v_other_result->>'status',
    NULL, (v_other_result->>'status') = 'authorization_failure', v_other_result::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', v_unassigned::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_other_result := public.create_or_resume_programme_training_session(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AJ', 'unassigned_athlete_start_denied', 'authorization_failure', v_other_result->>'status',
    NULL, (v_other_result->>'status') = 'authorization_failure', v_other_result::TEXT
  );

  SELECT count(*) INTO v_count
  FROM programme_assignments
  WHERE athlete_id = v_athlete
  GROUP BY athlete_id
  HAVING count(*) > 2;
  PERFORM sprint12_assert_eq('AJ', 'no_duplicate_assignments', '0', COALESCE(v_count, 0)::TEXT);

  SELECT count(*) INTO v_count
  FROM (
    SELECT training_session_id
    FROM programme_slot_outcomes
    WHERE training_session_id IS NOT NULL
    GROUP BY training_session_id
    HAVING count(*) > 1
  ) duplicates;
  PERFORM sprint12_assert_eq('AJ', 'no_duplicate_session_link_groups', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id = v_athlete::TEXT AND status = 'completed';
  PERFORM sprint12_assert_eq('AJ', 'no_completed_performances', '0', v_count::TEXT);
  SELECT count(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id = v_athlete::TEXT AND status = 'abandoned';
  PERFORM sprint12_assert_eq('AJ', 'no_abandoned_performances', '0', v_count::TEXT);
END $$;

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM public.create_or_resume_programme_training_session('{}'::JSONB);
  RAISE EXCEPTION 'AJ anonymous start unexpectedly permitted';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END $$;
ROLLBACK;
SELECT sprint12_record('AJ','anonymous_start_denied','42501','42501',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'af000002-0000-4000-8000-000000000002', true);
DO $$
BEGIN
  INSERT INTO training_sessions (athlete_id, protocol_id, status)
  VALUES ('af000002-0000-4000-8000-000000000002', 'APOLLO-W1-MON-R1', 'in_progress');
  RAISE EXCEPTION 'AJ direct training_sessions write unexpectedly permitted';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END $$;
ROLLBACK;
SELECT sprint12_record('AJ','direct_session_write_remains_denied','42501','42501',NULL,TRUE,NULL);

SELECT gate,case_id,expected,actual,pass
FROM sprint12_gate_results WHERE gate='AJ' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
