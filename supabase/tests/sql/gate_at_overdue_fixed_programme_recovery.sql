-- Gate AT — overdue derivation, late start, and explicit overdue recovery.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_version UUID;
  v_hash TEXT;
  v_athlete_a UUID := 'a7000000-0000-4000-8000-00000000000a';
  v_athlete_b UUID := 'b7000000-0000-4000-8000-00000000000b';
  v_assignment_a UUID;
  v_assignment_b UUID;
  v_day1 UUID;
  v_day2 UUID;
  v_day3 UUID;
  v_empty DATE;
  v_occupied UUID;
  v_occupied_date DATE;
  v_result JSONB;
  v_retry JSONB;
  v_projection JSONB;
  v_count INT;
  v_session BIGINT;
  v_op_count INT;
  v_hash_before TEXT;
  v_disp TEXT;
  v_start_date DATE := public.cohort_resolve_athlete_local_date(
    'Atlantic/Canary'
  );
  v_today DATE := v_start_date + 1;
  v_clock TIMESTAMPTZ;
BEGIN
  v_clock := v_today::TIMESTAMP AT TIME ZONE 'Atlantic/Canary';
  SELECT v.id, v.package_content_hash
  INTO v_version, v_hash
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK'
    AND v.version_number = 2
    AND v.lifecycle_status = 'published';

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a,
     'authenticated', 'authenticated', 'gate-at-a@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b,
     'authenticated', 'authenticated', 'gate-at-b@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate AT Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate AT Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
  SET is_athlete = TRUE, is_coach = FALSE;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version, 'Atlantic/Canary', FALSE
  );
  v_assignment_a := (v_result->>'enrolment_id')::UUID;
  v_result := public.start_fixed_programme_from_enrolment(
    v_assignment_a, v_start_date, 'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);
  v_hash_before := (
    SELECT materialised_package_content_hash
    FROM programme_assignments WHERE id = v_assignment_a
  );

  SELECT id INTO v_day1
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = v_start_date;
  SELECT id INTO v_day2
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = v_today;
  SELECT id INTO v_day3
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = v_today + 1;

  -- Leftover auto-missed row is still derived overdue, not terminal missed.
  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET disposition = 'missed'
  WHERE id = v_day1;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_projection := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment_a, v_clock
  );
  PERFORM sprint12_record(
    'AT', 'leftover_missed_projects_overdue', 'OVERDUE',
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e
      WHERE e->>'id' = v_day1::TEXT),
    NULL,
    (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e
      WHERE e->>'id' = v_day1::TEXT) = 'OVERDUE'
      AND (SELECT e->>'state' FROM jsonb_array_elements(v_projection->'occurrences') e
            WHERE e->>'id' = v_day2::TEXT) = 'TODAY',
    v_projection::TEXT
  );
  SELECT disposition INTO v_disp
  FROM programme_schedule_occurrences WHERE id = v_day1;
  PERFORM sprint12_assert_eq(
    'AT', 'reconcile_does_not_rewrite_missed', 'missed', v_disp
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_result := public.cohort_create_or_resume_fixed_occurrence_at(v_day1, v_clock);
  v_session := (v_result->'training_session'->>'id')::BIGINT;
  PERFORM sprint12_record(
    'AT', 'late_start_original_occurrence', 'created', v_result->>'status',
    NULL,
    v_result->>'status' = 'created'
      AND v_result->>'occurrence_id' = v_day1::TEXT
      AND v_result->>'original_scheduled_date' = v_start_date::TEXT,
    v_result::TEXT
  );
  SELECT COUNT(*) INTO v_count FROM training_sessions
  WHERE athlete_id = v_athlete_a::TEXT;
  PERFORM sprint12_assert_eq('AT', 'exactly_one_late_session', '1', v_count::TEXT);
  SELECT disposition INTO v_disp
  FROM programme_schedule_occurrences WHERE id = v_day1;
  PERFORM sprint12_assert_eq(
    'AT', 'late_start_clears_leftover_missed', 'scheduled', v_disp
  );
  SELECT scheduled_date::TEXT INTO v_disp
  FROM programme_schedule_occurrences WHERE id = v_day1;
  PERFORM sprint12_assert_eq(
    'AT', 'late_start_preserves_scheduled_date', v_start_date::TEXT, v_disp
  );

  v_result := public.cohort_create_or_resume_fixed_occurrence_at(v_day1, v_clock);
  PERFORM sprint12_record(
    'AT', 'late_resume_same_session', v_session::TEXT,
    v_result->'training_session'->>'id',
    NULL,
    v_result->>'status' = 'resumed'
      AND (v_result->'training_session'->>'id')::BIGINT = v_session,
    v_result::TEXT
  );

  PERFORM set_config('role', 'postgres', true);
  DELETE FROM programme_slot_outcomes WHERE assignment_id = v_assignment_a;
  DELETE FROM training_sessions WHERE athlete_id = v_athlete_a::TEXT;
  UPDATE programme_schedule_occurrences
  SET disposition = 'scheduled'
  WHERE assignment_id = v_assignment_a;

  -- Guarantee one empty destination in the 7-day horizon.
  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  SELECT scheduled_date INTO v_empty
  FROM programme_schedule_occurrences
  WHERE id = v_day3;
  UPDATE programme_schedule_occurrences
  SET scheduled_date = (
    SELECT MAX(scheduled_date) + 21
    FROM programme_schedule_occurrences
    WHERE assignment_id = v_assignment_a
  )
  WHERE id = v_day3;

  SELECT id, scheduled_date INTO v_occupied, v_occupied_date
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a
    AND scheduled_date > v_today
    AND scheduled_date <= v_today + 7
  ORDER BY scheduled_date
  LIMIT 1;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'move',
      'destination_date', v_empty,
      'expected_source_date', v_start_date,
      'idempotency_key', 'gate-at-move-1'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'move_to_empty_date', 'moved', v_result->>'code',
    NULL, v_result->>'status' = 'applied' AND v_result->>'code' = 'moved',
    v_result::TEXT
  );
  v_retry := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'move',
      'destination_date', v_empty,
      'expected_source_date', v_start_date,
      'idempotency_key', 'gate-at-move-1'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'move_idempotent', 'already_applied', v_retry->>'status',
    NULL, v_retry->>'status' = 'already_applied', v_retry::TEXT
  );

  PERFORM set_config('role', 'postgres', true);
  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = v_empty;
  PERFORM sprint12_assert_eq('AT', 'no_duplicate_dates_after_move', '1', v_count::TEXT);
  SELECT COUNT(*) INTO v_op_count
  FROM programme_schedule_operations
  WHERE assignment_id = v_assignment_a
    AND operation_type = 'move'
    AND idempotency_key = 'gate-at-move-1';
  PERFORM sprint12_assert_eq('AT', 'move_audit_row', '1', v_op_count::TEXT);

  -- Restore day1 overdue and swap with a future incomplete occupant.
  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET scheduled_date = v_start_date, disposition = 'scheduled'
  WHERE id = v_day1;
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'swap',
      'destination_date', v_occupied_date,
      'counterpart_occurrence_id', v_occupied,
      'expected_source_date', v_start_date,
      'expected_destination_date', v_occupied_date,
      'idempotency_key', 'gate-at-swap-1'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'atomic_swap_incomplete', 'swapped', v_result->>'code',
    NULL, v_result->>'status' = 'applied' AND v_result->>'code' = 'swapped',
    v_result::TEXT
  );
  PERFORM set_config('role', 'postgres', true);
  SELECT COUNT(*) INTO v_op_count
  FROM programme_schedule_operations
  WHERE assignment_id = v_assignment_a AND operation_type = 'swap';
  PERFORM sprint12_assert_eq('AT', 'swap_audit_distinct_from_move', '1', v_op_count::TEXT);

  -- Horizon, past, completed, and in-progress destination rejections.
  UPDATE programme_schedule_occurrences
  SET scheduled_date = v_start_date, disposition = 'scheduled'
  WHERE id = v_day1;
  UPDATE programme_schedule_occurrences
  SET scheduled_date = v_occupied_date, disposition = 'scheduled'
  WHERE id = v_occupied;
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'move',
      'destination_date', v_today + 8,
      'expected_source_date', v_start_date,
      'idempotency_key', 'gate-at-horizon'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'seven_day_destination_horizon', 'destination_outside_horizon',
    v_result->>'code', NULL,
    v_result->>'code' = 'destination_outside_horizon',
    v_result::TEXT
  );
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'move',
      'destination_date', v_start_date - 1,
      'expected_source_date', v_start_date,
      'idempotency_key', 'gate-at-past'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'destination_before_today', 'destination_in_past',
    v_result->>'code', NULL,
    v_result->>'code' = 'destination_in_past',
    v_result::TEXT
  );

  INSERT INTO programme_slot_outcomes (
    assignment_id, session_slot_id, week_number, day_key, session_order,
    outcome_status, programme_version_id, materialised_package_content_hash,
    programmed_session_key
  )
  SELECT assignment_id, session_slot_id, week_number, day_key, session_order,
         'completed', programme_version_id, package_content_hash,
         programmed_session_key
  FROM programme_schedule_occurrences WHERE id = v_day2;
  UPDATE programme_schedule_occurrences SET disposition = 'completed' WHERE id = v_day2;
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'swap',
      'destination_date', v_today,
      'counterpart_occurrence_id', v_day2,
      'expected_source_date', v_start_date,
      'expected_destination_date', v_today,
      'idempotency_key', 'gate-at-completed-dest'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'completed_destination_rejected', 'destination_completed',
    v_result->>'code', NULL,
    v_result->>'code' IN ('destination_completed', 'occurrence_ineligible'),
    v_result::TEXT
  );

  DELETE FROM programme_slot_outcomes WHERE assignment_id = v_assignment_a;
  UPDATE programme_schedule_occurrences
  SET disposition = 'scheduled' WHERE id = v_day2;
  INSERT INTO training_sessions (
    athlete_id, protocol_id, programme_id, week_number, status, started_at
  )
  SELECT v_athlete_a::TEXT, protocol_id, (
           SELECT lineage_code FROM programme_assignments WHERE id = v_assignment_a
         ), week_number, 'in_progress', NOW()
  FROM programme_schedule_occurrences WHERE id = v_day2;
  INSERT INTO programme_slot_outcomes (
    assignment_id, session_slot_id, week_number, day_key, session_order,
    outcome_status, training_session_id, programme_version_id,
    materialised_package_content_hash, programmed_session_key
  )
  SELECT o.assignment_id, o.session_slot_id, o.week_number, o.day_key,
         o.session_order, 'in_progress', ts.id, o.programme_version_id,
         o.package_content_hash, o.programmed_session_key
  FROM programme_schedule_occurrences o
  JOIN training_sessions ts ON ts.athlete_id = v_athlete_a::TEXT
  WHERE o.id = v_day2
  ORDER BY ts.id DESC LIMIT 1;
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'swap',
      'destination_date', v_today,
      'counterpart_occurrence_id', v_day2,
      'expected_source_date', v_start_date,
      'expected_destination_date', v_today,
      'idempotency_key', 'gate-at-in-progress-dest'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'in_progress_destination_rejected', 'destination_in_progress',
    v_result->>'code', NULL,
    v_result->>'code' = 'destination_in_progress',
    v_result::TEXT
  );

  -- In-progress overdue source cannot move.
  DELETE FROM programme_slot_outcomes WHERE assignment_id = v_assignment_a;
  DELETE FROM training_sessions WHERE athlete_id = v_athlete_a::TEXT;
  INSERT INTO training_sessions (
    athlete_id, protocol_id, programme_id, week_number, status, started_at
  )
  SELECT v_athlete_a::TEXT, protocol_id, (
           SELECT lineage_code FROM programme_assignments WHERE id = v_assignment_a
         ), week_number, 'in_progress', NOW()
  FROM programme_schedule_occurrences WHERE id = v_day1;
  INSERT INTO programme_slot_outcomes (
    assignment_id, session_slot_id, week_number, day_key, session_order,
    outcome_status, training_session_id, programme_version_id,
    materialised_package_content_hash, programmed_session_key
  )
  SELECT o.assignment_id, o.session_slot_id, o.week_number, o.day_key,
         o.session_order, 'in_progress', ts.id, o.programme_version_id,
         o.package_content_hash, o.programmed_session_key
  FROM programme_schedule_occurrences o
  JOIN training_sessions ts ON ts.athlete_id = v_athlete_a::TEXT
  WHERE o.id = v_day1
  ORDER BY ts.id DESC LIMIT 1;
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'move',
      'destination_date', v_empty,
      'expected_source_date', v_start_date,
      'idempotency_key', 'gate-at-in-progress-source'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'in_progress_source_rejected', 'occurrence_in_progress',
    v_result->>'code', NULL,
    v_result->>'code' = 'occurrence_in_progress',
    v_result::TEXT
  );

  DELETE FROM programme_slot_outcomes WHERE assignment_id = v_assignment_a;
  DELETE FROM training_sessions WHERE athlete_id = v_athlete_a::TEXT;
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'skip',
      'idempotency_key', 'gate-at-skip-1'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'explicit_skip', 'skipped', v_result->>'code',
    NULL, v_result->>'status' = 'applied' AND v_result->>'code' = 'skipped',
    v_result::TEXT
  );

  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'AT', 'catalogue_hash_unchanged',
    v_hash_before,
    (SELECT materialised_package_content_hash FROM programme_assignments WHERE id = v_assignment_a)
  );

  -- Other-athlete isolation.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version, 'Atlantic/Canary', FALSE
  );
  v_assignment_b := (v_result->>'enrolment_id')::UUID;
  v_result := public.start_fixed_programme_from_enrolment(
    v_assignment_b, v_start_date, 'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);
  v_result := public.cohort_recover_overdue_fixed_programme_occurrence_at(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'source_occurrence_id', v_day1,
      'operation', 'skip',
      'idempotency_key', 'gate-at-cross-athlete'
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AT', 'other_athlete_isolated', 'assignment_not_authorised',
    v_result->>'code', NULL,
    v_result->>'status' = 'authorization_failure',
    v_result::TEXT
  );
END $$;

SELECT sprint12_fail_if_any_failed();
