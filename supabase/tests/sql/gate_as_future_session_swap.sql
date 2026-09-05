-- Gate AS — authenticated future-session swap-and-begin authority.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_version UUID;
  v_hash TEXT;
  v_athlete_a UUID := 'a5000000-0000-4000-8000-00000000000a';
  v_athlete_b UUID := 'b5000000-0000-4000-8000-00000000000b';
  v_assignment_a UUID;
  v_assignment_b UUID;
  v_day1 UUID;
  v_day2 UUID;
  v_day3 UUID;
  v_day4 UUID;
  v_day5 UUID;
  v_day6 UUID;
  v_day1_date DATE;
  v_day2_date DATE;
  v_day3_date DATE;
  v_day4_date DATE;
  v_day5_date DATE;
  v_day6_date DATE;
  v_result JSONB;
  v_retry JSONB;
  v_session BIGINT;
  v_session_retry BIGINT;
  v_count INT;
  v_cursor_week INT;
  v_cursor_day TEXT;
  v_orig_day1 DATE;
  v_orig_day6 DATE;
  v_psk_day1 TEXT;
  v_psk_day6 TEXT;
  v_protocol_day6 TEXT;
  v_slot_day6 UUID;
  v_rev INT;
  v_has_exec BOOLEAN;
  v_start_date DATE := public.cohort_resolve_athlete_local_date(
    'Atlantic/Canary'
  );
  v_record UUID := 'a5000000-0000-4000-8000-0000000000aa';
BEGIN
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
     'authenticated', 'authenticated', 'gate-as-a@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b,
     'authenticated', 'authenticated', 'gate-as-b@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate AS Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate AS Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
  SET is_athlete = TRUE, is_coach = FALSE;

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
    v_start_date,
    'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'assignment_materialised', 'materialised',
    v_result->>'status', NULL,
    v_result->>'status' = 'materialised',
    v_result::TEXT
  );

  SELECT o.id, o.scheduled_date, o.original_scheduled_date, o.programmed_session_key
  INTO v_day1, v_day1_date, v_orig_day1, v_psk_day1
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_a
    AND o.week_number = 1
    AND o.day_key = 'day_1';
  SELECT o.id, o.scheduled_date INTO v_day2, v_day2_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_a AND o.week_number = 1 AND o.day_key = 'day_2';
  SELECT o.id, o.scheduled_date INTO v_day3, v_day3_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_a AND o.week_number = 1 AND o.day_key = 'day_3';
  SELECT o.id, o.scheduled_date INTO v_day4, v_day4_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_a AND o.week_number = 1 AND o.day_key = 'day_4';
  SELECT o.id, o.scheduled_date INTO v_day5, v_day5_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_a AND o.week_number = 1 AND o.day_key = 'day_5';
  SELECT o.id, o.scheduled_date, o.original_scheduled_date, o.programmed_session_key,
         o.protocol_id, o.session_slot_id
  INTO v_day6, v_day6_date, v_orig_day6, v_psk_day6, v_protocol_day6, v_slot_day6
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_a
    AND o.week_number = 1
    AND o.day_key = 'day_6';

  PERFORM sprint12_assert_eq('AS', 'day1_is_today', v_start_date::TEXT, v_day1_date::TEXT);
  PERFORM sprint12_record(
    'AS', 'day6_is_future', 'future',
    v_day6_date::TEXT, NULL,
    v_day6_date > v_start_date,
    NULL
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections
  WHERE assignment_id = v_assignment_a;

  -- Anonymous cannot execute.
  SELECT has_function_privilege(
    'anon',
    'public.swap_future_fixed_programme_session_and_begin(jsonb)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'AS', 'anon_execute_revoked', 'false', v_has_exec::TEXT, NULL, v_has_exec IS FALSE, NULL
  );
  SELECT has_function_privilege(
    'authenticated',
    'public.swap_future_fixed_programme_session_and_begin(jsonb)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'AS', 'authenticated_execute_granted', 'true', v_has_exec::TEXT, NULL,
    v_has_exec IS TRUE, NULL
  );

  BEGIN
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('role', 'anon', true);
    PERFORM public.swap_future_fixed_programme_session_and_begin(
      jsonb_build_object(
        'assignment_id', v_assignment_a,
        'today_occurrence_id', v_day1,
        'selected_occurrence_id', v_day6,
        'expected_today_date', v_day1_date,
        'expected_selected_date', v_day6_date
      )
    );
    PERFORM sprint12_record(
      'AS', 'anonymous_denied', '42501', 'executed', NULL, FALSE, NULL
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record(
      'AS', 'anonymous_denied', '42501', '42501', TRUE, TRUE, NULL
    );
  END;

  -- Other athlete denied.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    'Atlantic/Canary',
    FALSE
  );
  v_assignment_b := (v_result->>'enrolment_id')::UUID;
  PERFORM public.start_fixed_programme_from_enrolment(
    v_assignment_b,
    v_start_date,
    'Atlantic/Canary'
  );
  v_result := public.swap_future_fixed_programme_session_and_begin(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'today_occurrence_id', v_day1,
      'selected_occurrence_id', v_day6,
      'expected_today_date', v_day1_date,
      'expected_selected_date', v_day6_date
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'other_athlete_denied', 'assignment_not_authorised',
    v_result->>'code', NULL,
    v_result->>'code' = 'assignment_not_authorised',
    v_result::TEXT
  );

  -- Successful Day 1 ↔ Day 6 swap.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.swap_future_fixed_programme_session_and_begin(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'today_occurrence_id', v_day1,
      'selected_occurrence_id', v_day6,
      'expected_today_date', v_day1_date,
      'expected_selected_date', v_day6_date,
      'expected_schedule_revision', v_rev
    )
  );
  v_session := (v_result->'training_session'->>'id')::BIGINT;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'swap_and_begin_created', 'created/swapped_and_begun',
    (v_result->>'status') || '/' || (v_result->>'code'),
    NULL,
    v_result->>'status' = 'created'
      AND v_result->>'code' = 'swapped_and_begun'
      AND v_session IS NOT NULL,
    v_result::TEXT
  );

  PERFORM sprint12_assert_eq(
    'AS', 'selected_now_today', v_day1_date::TEXT,
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day6)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'displaced_now_future', v_day6_date::TEXT,
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day1)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'day2_unchanged', v_day2_date::TEXT,
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day2)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'day3_unchanged', v_day3_date::TEXT,
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day3)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'day4_unchanged', v_day4_date::TEXT,
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day4)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'day5_unchanged', v_day5_date::TEXT,
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day5)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'original_dates_preserved',
    v_orig_day1::TEXT || '/' || v_orig_day6::TEXT,
    (SELECT original_scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day1)
      || '/' ||
    (SELECT original_scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day6)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'programmed_keys_preserved',
    v_psk_day1 || '/' || v_psk_day6,
    (SELECT programmed_session_key FROM programme_schedule_occurrences WHERE id = v_day1)
      || '/' ||
    (SELECT programmed_session_key FROM programme_schedule_occurrences WHERE id = v_day6)
  );
  PERFORM sprint12_assert_eq(
    'AS', 'package_hash_unchanged', v_hash,
    (SELECT materialised_package_content_hash FROM programme_assignments WHERE id = v_assignment_a)
  );

  SELECT current_week_number, current_day_key
  INTO v_cursor_week, v_cursor_day
  FROM programme_assignments
  WHERE id = v_assignment_a;
  PERFORM sprint12_record(
    'AS', 'cursor_is_selected_actionable', '1/day_6',
    v_cursor_week::TEXT || '/' || v_cursor_day,
    NULL,
    v_cursor_week = 1 AND v_cursor_day = 'day_6',
    NULL
  );

  SELECT COUNT(*) INTO v_count
  FROM training_sessions
  WHERE athlete_id = v_athlete_a::TEXT;
  PERFORM sprint12_assert_eq('AS', 'one_training_session', '1', v_count::TEXT);
  SELECT COUNT(*) INTO v_count
  FROM programme_slot_outcomes
  WHERE assignment_id = v_assignment_a;
  PERFORM sprint12_assert_eq('AS', 'one_slot_outcome', '1', v_count::TEXT);
  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a;
  PERFORM sprint12_assert_eq('AS', 'occurrence_count_unchanged', '84', v_count::TEXT);
  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT scheduled_date
    FROM programme_schedule_occurrences
    WHERE assignment_id = v_assignment_a
    GROUP BY scheduled_date
    HAVING COUNT(*) > 1
  ) d;
  PERFORM sprint12_assert_eq('AS', 'no_duplicate_dates', '0', v_count::TEXT);
  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_operations
  WHERE assignment_id = v_assignment_a
    AND operation_type = 'future_train_today_swap';
  PERFORM sprint12_assert_eq('AS', 'one_swap_operation', '1', v_count::TEXT);

  -- Idempotent retry does not swap back or duplicate.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_retry := public.swap_future_fixed_programme_session_and_begin(
    jsonb_build_object(
      'assignment_id', v_assignment_a,
      'today_occurrence_id', v_day1,
      'selected_occurrence_id', v_day6,
      'expected_today_date', v_day1_date,
      'expected_selected_date', v_day6_date
    )
  );
  v_session_retry := (v_retry->'training_session'->>'id')::BIGINT;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'idempotent_retry', 'resumed/already_applied',
    (v_retry->>'status') || '/' || (v_retry->>'code'),
    NULL,
    v_retry->>'status' = 'resumed'
      AND v_retry->>'code' = 'already_applied'
      AND v_session_retry = v_session,
    v_retry::TEXT
  );
  PERFORM sprint12_assert_eq(
    'AS', 'retry_dates_unchanged',
    v_day1_date::TEXT || '/' || v_day6_date::TEXT,
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day6)
      || '/' ||
    (SELECT scheduled_date::TEXT FROM programme_schedule_occurrences WHERE id = v_day1)
  );
  SELECT COUNT(*) INTO v_count
  FROM training_sessions
  WHERE athlete_id = v_athlete_a::TEXT;
  PERFORM sprint12_assert_eq('AS', 'retry_no_duplicate_session', '1', v_count::TEXT);
  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_operations
  WHERE assignment_id = v_assignment_a
    AND operation_type = 'future_train_today_swap';
  PERFORM sprint12_assert_eq('AS', 'retry_no_duplicate_operation', '1', v_count::TEXT);

  -- Completion of the swapped session keeps the displaced session.
  SELECT programmed_session_key INTO v_psk_day6
  FROM programme_schedule_occurrences
  WHERE id = v_day6;
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.complete_fixed_programme_occurrence_and_advance(
    jsonb_build_object(
      'occurrence_id', v_day6,
      'assignment_id', v_assignment_a,
      'session_slot_id', v_slot_day6,
      'programme_version_id', v_version,
      'materialised_package_content_hash', v_hash,
      'programmed_session_key', v_psk_day6,
      'logical_completion_key', v_psk_day6,
      'idempotency_key', 'gate-as-complete-day6',
      'actuals_fingerprint', 'gate-as-athlete-entered-actuals',
      'protocol_id', v_protocol_day6,
      'expected_week', 1,
      'expected_day_key', 'day_6',
      'expected_slot_order', 1,
      'training_session_id', v_session,
      'record_id', v_record,
      'status', 'completed',
      'completion_record', jsonb_build_object(
        'record_id', v_record,
        'source_protocol_id', v_protocol_day6,
        'session_snapshot', '{}'::JSONB,
        'athlete_note', 'Gate AS swapped-session completion'
      )
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'completion_after_swap', 'committed',
    v_result->>'status', NULL,
    v_result->>'status' = 'committed',
    v_result::TEXT
  );
  PERFORM sprint12_assert_eq(
    'AS', 'displaced_still_scheduled',
    v_day6_date::TEXT || '/scheduled',
    (SELECT scheduled_date::TEXT || '/' || disposition
     FROM programme_schedule_occurrences WHERE id = v_day1)
  );
  SELECT current_week_number, current_day_key
  INTO v_cursor_week, v_cursor_day
  FROM programme_assignments
  WHERE id = v_assignment_a;
  PERFORM sprint12_record(
    'AS', 'cursor_advances_to_next_date', '1/day_2',
    v_cursor_week::TEXT || '/' || v_cursor_day,
    NULL,
    v_cursor_week = 1 AND v_cursor_day = 'day_2',
    NULL
  );

  -- Rejection cases on athlete B (clean assignment).
  SELECT o.id, o.scheduled_date
  INTO v_day1, v_day1_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_b
    AND o.week_number = 1 AND o.day_key = 'day_1';
  SELECT o.id, o.scheduled_date
  INTO v_day6, v_day6_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_b
    AND o.week_number = 1 AND o.day_key = 'day_6';
  SELECT o.id INTO v_day2
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_b
    AND o.week_number = 1 AND o.day_key = 'day_2';

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET disposition = 'skipped'
  WHERE id = v_day1;
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.swap_future_fixed_programme_session_and_begin(
    jsonb_build_object(
      'assignment_id', v_assignment_b,
      'today_occurrence_id', v_day1,
      'selected_occurrence_id', v_day6,
      'expected_today_date', v_day1_date,
      'expected_selected_date', v_day6_date
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'skipped_today_rejected', 'occurrence_skipped',
    v_result->>'code', NULL,
    v_result->>'code' = 'occurrence_skipped',
    v_result::TEXT
  );

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET disposition = 'scheduled'
  WHERE id = v_day1;
  UPDATE programme_schedule_occurrences
  SET disposition = 'completed'
  WHERE id = v_day6;
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.swap_future_fixed_programme_session_and_begin(
    jsonb_build_object(
      'assignment_id', v_assignment_b,
      'today_occurrence_id', v_day1,
      'selected_occurrence_id', v_day6,
      'expected_today_date', v_day1_date,
      'expected_selected_date', v_day6_date
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'completed_selected_rejected', 'occurrence_completed',
    v_result->>'code', NULL,
    v_result->>'code' = 'occurrence_completed',
    v_result::TEXT
  );

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET disposition = 'scheduled'
  WHERE id = v_day6;
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.create_or_resume_fixed_programme_occurrence_session(v_day1);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'seed_in_progress_today', 'created',
    v_result->>'status', NULL,
    v_result->>'status' = 'created',
    v_result::TEXT
  );
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.swap_future_fixed_programme_session_and_begin(
    jsonb_build_object(
      'assignment_id', v_assignment_b,
      'today_occurrence_id', v_day1,
      'selected_occurrence_id', v_day6,
      'expected_today_date', v_day1_date,
      'expected_selected_date', v_day6_date
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'in_progress_rejected', 'ineligible',
    v_result->>'status', NULL,
    v_result->>'status' = 'ineligible'
      AND v_result->>'code' IN (
        'in_progress_session_exists',
        'occurrence_has_session_state'
      ),
    v_result::TEXT
  );

  DELETE FROM programme_slot_outcomes WHERE assignment_id = v_assignment_b;
  DELETE FROM training_sessions WHERE athlete_id = v_athlete_b::TEXT;
  SELECT o.id, o.scheduled_date
  INTO v_day1, v_day1_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_b
    AND o.week_number = 1 AND o.day_key = 'day_1';
  SELECT o.id, o.scheduled_date
  INTO v_day6, v_day6_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_b
    AND o.week_number = 1 AND o.day_key = 'day_6';
  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET disposition = 'scheduled'
  WHERE assignment_id = v_assignment_b
    AND id IN (v_day1, v_day6);
  UPDATE programme_schedule_occurrences
  SET scheduled_date = v_start_date - 1
  WHERE assignment_id = v_assignment_b
    AND week_number = 1
    AND day_key = 'day_2';
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.swap_future_fixed_programme_session_and_begin(
    jsonb_build_object(
      'assignment_id', v_assignment_b,
      'today_occurrence_id', v_day1,
      'selected_occurrence_id', v_day6,
      'expected_today_date', v_day1_date,
      'expected_selected_date', v_day6_date
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AS', 'overdue_rejected', 'overdue_occurrence',
    v_result->>'code', NULL,
    v_result->>'code' = 'overdue_occurrence',
    v_result::TEXT
  );

  SELECT COUNT(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id IN (v_athlete_a::TEXT, v_athlete_b::TEXT)
    AND status = 'abandoned';
  PERFORM sprint12_assert_eq('AS', 'zero_abandoned', '0', v_count::TEXT);

  PERFORM sprint12_assert_eq(
    'AS', 'projection_hash_matches_assignment',
    (SELECT materialised_package_content_hash FROM programme_assignments WHERE id = v_assignment_a),
    (SELECT package_content_hash FROM programme_schedule_projections WHERE assignment_id = v_assignment_a)
  );
END $$;

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results
WHERE gate = 'AS'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
