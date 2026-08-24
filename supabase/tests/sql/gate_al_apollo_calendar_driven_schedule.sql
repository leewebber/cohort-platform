-- Gate AL — Apollo fixed-calendar occurrence and execution authority.
-- Uses private clock-injectable helpers as postgres inside this disposable
-- gate; authenticated production RPCs expose no date override.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_version UUID;
  v_athlete_a UUID := 'a1000000-0000-4000-8000-00000000000a';
  v_athlete_b UUID := 'b1000000-0000-4000-8000-00000000000b';
  v_assignment_a UUID;
  v_assignment_b UUID;
  v_day1_a UUID;
  v_day2_a UUID;
  v_day3_a UUID;
  v_day1_b UUID;
  v_day2_b UUID;
  v_session_a BIGINT;
  v_session_b BIGINT;
  v_record_b UUID := 'b1000000-0000-4000-8000-0000000000bb';
  v_hash TEXT;
  v_key_b TEXT;
  v_result JSONB;
  v_projection JSONB;
  v_count INT;
  v_state TEXT;
  v_original DATE;
BEGIN
  SELECT v.id, v.package_content_hash
  INTO v_version, v_hash
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK'
    AND v.version_number = 1
    AND v.lifecycle_status = 'published';

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a,
     'authenticated', 'authenticated', 'gate-al-a@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b,
     'authenticated', 'authenticated', 'gate-al-b@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate AL Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate AL Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
  SET is_athlete = TRUE, is_coach = FALSE;

  -- Athlete A: selected start is preserved and untouched Day 1 becomes missed.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'Atlantic/Canary',
    FALSE
  );
  v_assignment_a := (v_result->>'enrolment_id')::UUID;
  v_result := public.start_fixed_programme_from_enrolment(
    v_assignment_a,
    DATE '2026-09-01',
    'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AL', 'selected_start_preserved', '2026-09-01/Atlantic/Canary',
    (v_result->>'started_at') || '/' || (v_result->>'timezone'),
    NULL,
    (v_result->>'status') = 'materialised'
      AND (v_result->>'started_at') = '2026-09-01'
      AND (v_result->>'timezone') = 'Atlantic/Canary',
    v_result::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a;
  PERFORM sprint12_assert_eq('AL', 'apollo_occurrences_exactly_84', '84', v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_version;
  PERFORM sprint12_assert_eq('AL', 'apollo_materialised_links_exactly_84', '84', v_count::TEXT);

  SELECT id INTO v_day1_a
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = DATE '2026-09-01';
  SELECT id INTO v_day2_a
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = DATE '2026-09-02';
  SELECT id INTO v_day3_a
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = DATE '2026-09-03';

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_projection := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment_a,
    TIMESTAMPTZ '2026-08-31 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'before_start_upcoming', 'PLANNED',
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_a::TEXT),
    NULL,
    v_projection->>'status' = 'ok'
      AND NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_projection->'occurrences') e
        WHERE e->>'scheduled_date' = v_projection->>'today'
      ),
    v_projection::TEXT
  );
  v_result := public.cohort_create_or_resume_fixed_occurrence_at(
    v_day1_a,
    TIMESTAMPTZ '2026-08-31 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'future_day1_denied', 'future_occurrence', v_result->>'code',
    NULL, v_result->>'code' = 'future_occurrence', v_result::TEXT
  );

  v_projection := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment_a,
    TIMESTAMPTZ '2026-09-01 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'sep1_day1_today', 'TODAY/APOLLO-W1-MON-R1',
    (SELECT (e->>'state') || '/' || (e->>'protocol_id')
       FROM jsonb_array_elements(v_projection->'occurrences') e
      WHERE e->>'id' = v_day1_a::TEXT),
    NULL,
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_a::TEXT) = 'TODAY'
      AND (SELECT e->>'protocol_id' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_a::TEXT) = 'APOLLO-W1-MON-R1',
    v_projection::TEXT
  );

  v_projection := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment_a,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'sep2_missed_day1_today_day2', 'MISSED/TODAY',
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_a::TEXT)
      || '/' ||
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day2_a::TEXT),
    NULL,
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_a::TEXT) = 'MISSED'
      AND (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day2_a::TEXT) = 'TODAY',
    v_projection::TEXT
  );
  PERFORM sprint12_assert_eq(
    'AL', 'week_projection_exactly_seven', '7',
    jsonb_array_length(v_projection->'current_week')::TEXT
  );
  PERFORM sprint12_record(
    'AL', 'week_projection_ordered_iso', '2026-08-31..2026-09-06',
    (v_projection->'current_week'->0->>'date') || '..' ||
      (v_projection->'current_week'->6->>'date'),
    NULL,
    v_projection->'current_week'->0->>'date' = '2026-08-31'
      AND v_projection->'current_week'->6->>'date' = '2026-09-06',
    NULL
  );

  v_result := public.cohort_create_or_resume_fixed_occurrence_at(
    v_day1_a,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'missed_day1_cannot_start', 'missed_occurrence', v_result->>'code',
    NULL, v_result->>'code' = 'missed_occurrence', v_result::TEXT
  );
  v_result := public.cohort_create_or_resume_fixed_occurrence_at(
    v_day3_a,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'future_day3_denied', 'future_occurrence', v_result->>'code',
    NULL, v_result->>'code' = 'future_occurrence', v_result::TEXT
  );

  v_result := public.cohort_create_or_resume_fixed_occurrence_at(
    v_day2_a,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  v_session_a := (v_result->'training_session'->>'id')::BIGINT;
  PERFORM sprint12_record(
    'AL', 'sep2_day2_starts_despite_day1_cursor', 'APOLLO-W1-TUE-R1/day_1',
    (v_result->'training_session'->>'protocol_id') || '/' ||
      (SELECT current_day_key FROM programme_assignments WHERE id = v_assignment_a),
    NULL,
    v_result->>'status' = 'created'
      AND v_result->'training_session'->>'protocol_id' = 'APOLLO-W1-TUE-R1'
      AND (SELECT current_day_key FROM programme_assignments WHERE id = v_assignment_a) = 'day_1',
    v_result::TEXT
  );
  v_result := public.cohort_create_or_resume_fixed_occurrence_at(
    v_day2_a,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'occurrence_start_retry_idempotent', v_session_a::TEXT,
    v_result->'training_session'->>'id',
    NULL,
    v_result->>'status' = 'resumed'
      AND (v_result->'training_session'->>'id')::BIGINT = v_session_a,
    v_result::TEXT
  );

  -- Athlete B: Day 1 starts on Sep 1, becomes overdue, resumes without hiding
  -- Day 2, then completes late with immutable original date and lineage.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'Atlantic/Canary',
    FALSE
  );
  v_assignment_b := (v_result->>'enrolment_id')::UUID;
  v_result := public.start_fixed_programme_from_enrolment(
    v_assignment_b,
    DATE '2026-09-01',
    'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);

  SELECT id, programmed_session_key, original_scheduled_date
  INTO v_day1_b, v_key_b, v_original
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_b AND scheduled_date = DATE '2026-09-01';
  SELECT id INTO v_day2_b
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_b AND scheduled_date = DATE '2026-09-02';

  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  v_result := public.cohort_create_or_resume_fixed_occurrence_at(
    v_day1_b,
    TIMESTAMPTZ '2026-09-01 12:00:00+00'
  );
  v_session_b := (v_result->'training_session'->>'id')::BIGINT;
  v_projection := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment_b,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'overdue_day1_and_today_day2', 'IN_PROGRESS_OVERDUE/TODAY',
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_b::TEXT)
      || '/' ||
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day2_b::TEXT),
    NULL,
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_b::TEXT) = 'IN_PROGRESS_OVERDUE'
      AND (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day2_b::TEXT) = 'TODAY',
    v_projection::TEXT
  );

  v_result := public.cohort_create_or_resume_fixed_occurrence_at(
    v_day1_b,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'overdue_resume_same_session', v_session_b::TEXT,
    v_result->'training_session'->>'id',
    NULL,
    v_result->>'status' = 'resumed'
      AND (v_result->'training_session'->>'id')::BIGINT = v_session_b,
    v_result::TEXT
  );

  PERFORM set_config('role', 'authenticated', true);
  v_result := public.complete_fixed_programme_occurrence_and_advance(
    jsonb_build_object(
      'occurrence_id', v_day1_b,
      'assignment_id', v_assignment_b,
      'session_slot_id', (
        SELECT session_slot_id FROM programme_schedule_occurrences WHERE id = v_day1_b
      ),
      'programme_version_id', v_version,
      'materialised_package_content_hash', v_hash,
      'programmed_session_key', v_key_b,
      'logical_completion_key', v_key_b,
      'idempotency_key', 'gate-al-late-day1',
      'actuals_fingerprint', 'gate-al-athlete-entered-actuals',
      'protocol_id', 'APOLLO-W1-MON-R1',
      'expected_week', 1,
      'expected_day_key', 'day_1',
      'expected_slot_order', 1,
      'training_session_id', v_session_b,
      'record_id', v_record_b,
      'status', 'completed',
      'completion_record', jsonb_build_object(
        'record_id', v_record_b,
        'source_protocol_id', 'APOLLO-W1-MON-R1',
        'session_snapshot', '{}'::JSONB,
        'athlete_note', 'Gate AL explicit athlete completion'
      )
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AL', 'late_completion_committed', 'committed', v_result->>'status',
    NULL, v_result->>'status' = 'committed', v_result::TEXT
  );
  SELECT original_scheduled_date INTO v_original
  FROM programme_schedule_occurrences WHERE id = v_day1_b;
  PERFORM sprint12_assert_eq('AL', 'late_completion_original_date', '2026-09-01', v_original::TEXT);
  SELECT COUNT(*) INTO v_count
  FROM training_session_records
  WHERE record_id = v_record_b
    AND status = 'completed'
    AND completed_at IS NOT NULL
    AND source_protocol_id = 'APOLLO-W1-MON-R1';
  PERFORM sprint12_assert_eq('AL', 'late_completion_actual_timestamp_and_lineage', '1', v_count::TEXT);

  v_projection := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment_b,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_record(
    'AL', 'late_day1_completed_day2_still_today', 'COMPLETED/TODAY',
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_b::TEXT)
      || '/' ||
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day2_b::TEXT),
    NULL,
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day1_b::TEXT) = 'COMPLETED'
      AND (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e WHERE e->>'id' = v_day2_b::TEXT) = 'TODAY',
    v_projection::TEXT
  );

  -- Security boundaries: cross-athlete projection/start and anonymous execute.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.resolve_fixed_programme_calendar(v_assignment_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AL', 'cross_athlete_projection_denied', 'authorization_failure',
    v_result->>'status', NULL,
    v_result->>'status' = 'authorization_failure', v_result::TEXT
  );

  PERFORM set_config('role', 'authenticated', true);
  v_result := public.create_or_resume_fixed_programme_occurrence_session(v_day2_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AL', 'cross_athlete_start_denied', 'cross_athlete_occurrence',
    v_result->>'code', NULL,
    v_result->>'code' = 'cross_athlete_occurrence', v_result::TEXT
  );

  BEGIN
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('role', 'anon', true);
    PERFORM public.resolve_active_fixed_programme_calendar();
    PERFORM sprint12_record('AL', 'anonymous_projection_denied', '42501', 'executed', NULL, FALSE, NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('AL', 'anonymous_projection_denied', '42501', '42501', TRUE, TRUE, NULL);
  END;
  PERFORM set_config('role', 'postgres', true);

  BEGIN
    PERFORM set_config('role', 'anon', true);
    PERFORM public.create_or_resume_fixed_programme_occurrence_session(v_day2_a);
    PERFORM sprint12_record('AL', 'anonymous_start_denied', '42501', 'executed', NULL, FALSE, NULL);
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('AL', 'anonymous_start_denied', '42501', '42501', TRUE, TRUE, NULL);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Repeat lifecycle/reconciliation remains row-idempotent.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.start_fixed_programme_from_enrolment(
    v_assignment_a,
    DATE '2026-09-01',
    'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AL', 'fixed_start_retry_idempotent', 'already_materialised',
    v_result->>'status', NULL,
    v_result->>'status' = 'already_materialised', v_result::TEXT
  );
  v_result := public.cohort_reconcile_fixed_programme_schedule_at(
    v_assignment_a,
    TIMESTAMPTZ '2026-09-02 12:00:00+00'
  );
  PERFORM sprint12_assert_eq('AL', 'reconcile_retry_changes_zero', '0', v_result->>'missed_count');

  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT athlete_id
    FROM programme_assignments
    WHERE athlete_id IN (v_athlete_a, v_athlete_b)
      AND status = 'active'
    GROUP BY athlete_id
    HAVING COUNT(*) <> 1
  ) duplicate_active;
  PERFORM sprint12_assert_eq('AL', 'one_active_apollo_assignment_each', '0', v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT assignment_id, session_slot_id
    FROM programme_schedule_occurrences
    WHERE assignment_id IN (v_assignment_a, v_assignment_b)
    GROUP BY assignment_id, session_slot_id
    HAVING COUNT(*) > 1
  ) duplicate_occurrences;
  PERFORM sprint12_assert_eq('AL', 'zero_duplicate_occurrence_groups', '0', v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT assignment_id, session_slot_id
    FROM programme_slot_outcomes
    WHERE assignment_id IN (v_assignment_a, v_assignment_b)
    GROUP BY assignment_id, session_slot_id
    HAVING COUNT(*) > 1
  ) duplicate_links;
  PERFORM sprint12_assert_eq('AL', 'zero_duplicate_session_link_groups', '0', v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT o.assignment_id, o.session_slot_id
    FROM programme_slot_outcomes o
    JOIN training_sessions t ON t.id = o.training_session_id
    WHERE o.assignment_id IN (v_assignment_a, v_assignment_b)
      AND t.status = 'in_progress'
    GROUP BY o.assignment_id, o.session_slot_id
    HAVING COUNT(*) > 1
  ) duplicate_active_sessions;
  PERFORM sprint12_assert_eq('AL', 'zero_duplicate_active_sessions', '0', v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id IN (v_athlete_a::TEXT, v_athlete_b::TEXT)
    AND status = 'abandoned';
  PERFORM sprint12_assert_eq('AL', 'zero_abandoned_performances', '0', v_count::TEXT);

  SELECT COUNT(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id IN (v_athlete_a::TEXT, v_athlete_b::TEXT)
    AND status = 'completed'
    AND record_id <> v_record_b;
  PERFORM sprint12_assert_eq('AL', 'zero_synthetic_completed_performances', '0', v_count::TEXT);

  PERFORM sprint12_assert_eq(
    'AL', 'canonical_apollo_hash_unchanged',
    '7264703a8db56edd6685e97e736405ffa99124fd4c419a676a1246653ea52b87',
    (SELECT package_content_hash FROM programme_versions WHERE id = v_version)
  );

  SELECT COUNT(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'create_or_resume_fixed_programme_occurrence_session'
    AND pg_get_function_identity_arguments(p.oid) = 'p_occurrence_id uuid';
  PERFORM sprint12_assert_eq('AL', 'start_rpc_accepts_occurrence_only', '1', v_count::TEXT);
END $$;

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results
WHERE gate = 'AL'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
