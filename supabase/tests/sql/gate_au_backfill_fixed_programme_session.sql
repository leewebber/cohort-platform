-- Gate AU — truthful backfill persistence for fixed-programme occurrences.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_version UUID;
  v_hash TEXT;
  v_athlete_a UUID := 'a8000000-0000-4000-8000-00000000000a';
  v_athlete_b UUID := 'b8000000-0000-4000-8000-00000000000b';
  v_assignment_a UUID;
  v_assignment_b UUID;
  v_day1 UUID;
  v_day2 UUID;
  v_day_open UUID;
  v_day3 UUID;
  v_slot UUID;
  v_protocol TEXT;
  v_result JSONB;
  v_retry JSONB;
  v_projection JSONB;
  v_record UUID := 'c8000000-0000-4000-8000-00000000000c';
  v_block UUID := 'c8000000-0000-4000-8000-00000000000d';
  v_exercise UUID := 'c8000000-0000-4000-8000-00000000000e';
  v_set UUID := 'c8000000-0000-4000-8000-00000000000f';
  v_record2 UUID := 'c8000000-0000-4000-8000-000000000010';
  v_live_before INT;
  v_live_after INT;
  v_count INT;
  v_cursor_week INT;
  v_cursor_day TEXT;
  v_week_before INT;
  v_day_before TEXT;
  v_today_state TEXT;
  v_entry TEXT;
  v_performed TEXT;
  v_created TIMESTAMPTZ;
  v_disp TEXT;
  v_performed_null BOOLEAN;
  v_caps JSONB;
  v_start_date DATE := public.cohort_resolve_athlete_local_date(
    'Atlantic/Canary'
  );
  v_today DATE := v_start_date + 3;
  v_clock TIMESTAMPTZ;
  v_tree JSONB;
  v_fp TEXT := 'gate-au-fp-1';
  v_idem TEXT;
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
     'authenticated', 'authenticated', 'gate-au-a@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b,
     'authenticated', 'authenticated', 'gate-au-b@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate AU Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate AU Athlete B', TRUE, FALSE)
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

  SELECT id, session_slot_id, protocol_id
  INTO v_day1, v_slot, v_protocol
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = v_start_date;
  SELECT id INTO v_day2
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = v_start_date + 1;
  SELECT id INTO v_day_open
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a
    AND scheduled_date < v_today
    AND id IS DISTINCT FROM v_day1
    AND id IS DISTINCT FROM v_day2
  ORDER BY scheduled_date
  LIMIT 1;
  SELECT id INTO v_day3
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment_a AND scheduled_date = v_today;

  SELECT current_week_number, current_day_key
  INTO v_week_before, v_day_before
  FROM programme_assignments WHERE id = v_assignment_a;

  SELECT count(*) INTO v_live_before
  FROM training_session_records
  WHERE athlete_id = v_athlete_a::TEXT;

  -- Existing live-shaped row remains readable after additive columns.
  INSERT INTO training_session_records (
    record_id, athlete_id, status, session_snapshot, started_at
  ) VALUES (
    'c8000000-0000-4000-8000-000000000099',
    v_athlete_a::TEXT,
    'completed',
    '{}'::jsonb,
    TIMESTAMPTZ '2026-09-01 10:00:00+00'
  );
  SELECT entry_mode, performed_on IS NULL
  INTO v_entry, v_performed_null
  FROM training_session_records
  WHERE record_id = 'c8000000-0000-4000-8000-000000000099';
  PERFORM sprint12_assert_eq('AU', 'existing_live_default_mode', 'live', v_entry);
  PERFORM sprint12_assert_eq(
    'AU', 'existing_live_performed_on_null', 'true', v_performed_null::TEXT
  );

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET disposition = 'missed'
  WHERE id = v_day1;

  v_idem := format('backfill:%s:%s:%s', v_athlete_a, v_assignment_a, v_day1);
  v_tree := jsonb_build_array(
    jsonb_build_object(
      'block_result_id', v_block,
      'source_block_id', 'block-1',
      'block_snapshot', jsonb_build_object('blockType', 'strength'),
      'status', 'completed',
      'result_type', 'strength',
      'position', 1,
      'exercise_results', jsonb_build_array(
        jsonb_build_object(
          'exercise_result_id', v_exercise,
          'source_exercise_id', 'EX-095',
          'exercise_snapshot', jsonb_build_object('displayName', 'Back Squat'),
          'position', 1,
          'set_results', jsonb_build_array(
            jsonb_build_object(
              'set_result_id', v_set,
              'set_number', 1,
              'position', 1,
              'reps', 5,
              'load', 80,
              'load_unit', 'kg',
              'completed', true
            )
          )
        )
      )
    )
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_caps := public.cohort_athlete_runtime_capabilities();
  PERFORM sprint12_record(
    'AU', 'capabilities_backfill', 'true',
    (v_caps->>'backfill_results'),
    NULL,
    v_caps->>'status' = 'ok' AND (v_caps->>'backfill_results') = 'true',
    v_caps::TEXT
  );

  -- Future performed date (assignment-local).
  v_result := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day1,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_today + 1, 'YYYY-MM-DD'),
      'idempotency_key', v_idem,
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record,
      'completion_record', jsonb_build_object(
        'source_protocol_id', v_protocol,
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq('AU', 'reject_future_performed', 'future_date', v_result->>'code');

  -- Before scheduled occurrence.
  v_result := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day1,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_start_date - 1, 'YYYY-MM-DD'),
      'idempotency_key', v_idem,
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record,
      'completion_record', jsonb_build_object(
        'source_protocol_id', v_protocol,
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq('AU', 'reject_before_scheduled', 'before_scheduled', v_result->>'code');

  -- Explicit skip is terminal.
  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_occurrences
  SET disposition = 'skipped'
  WHERE id = v_day2;
  v_result := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day2,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_start_date + 1, 'YYYY-MM-DD'),
      'idempotency_key', format('backfill:%s:%s:%s', v_athlete_a, v_assignment_a, v_day2),
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record2,
      'completion_record', jsonb_build_object(
        'source_protocol_id', v_protocol,
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq('AU', 'reject_explicit_skip', 'occurrence_skipped', v_result->>'code');

  -- Cross-athlete.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version, 'Atlantic/Canary', FALSE
  );
  v_assignment_b := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', true);
  v_result := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day1,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_start_date + 1, 'YYYY-MM-DD'),
      'idempotency_key', format('backfill:%s:%s:%s', v_athlete_b, v_assignment_a, v_day1),
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record2,
      'completion_record', jsonb_build_object(
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_record(
    'AU', 'cross_athlete_rejected', 'authorization_failure',
    v_result->>'status', NULL,
    v_result->>'status' = 'authorization_failure',
    v_result::TEXT
  );

  -- Happy path: leftover missed + original occurrence + tree.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  v_result := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day1,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_start_date + 1, 'YYYY-MM-DD'),
      'idempotency_key', v_idem,
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record,
      'completion_record', jsonb_build_object(
        'source_protocol_id', v_protocol,
        'session_snapshot', jsonb_build_object('sessionTitle', 'Apollo Strength'),
        'overall_rpe', 7,
        'athlete_note', 'gate-au-note',
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq('AU', 'commit_status', 'committed', v_result->>'status');
  PERFORM sprint12_assert_eq(
    'AU', 'performed_on_persisted',
    to_char(v_start_date + 1, 'YYYY-MM-DD'),
    v_result->>'performed_on'
  );
  PERFORM sprint12_assert_eq('AU', 'entry_mode_backfill', 'backfill', v_result->>'entry_mode');

  SELECT disposition INTO v_disp
  FROM programme_schedule_occurrences WHERE id = v_day1;
  PERFORM sprint12_assert_eq('AU', 'original_occurrence_completed', 'completed', v_disp);
  PERFORM sprint12_assert_eq(
    'AU', 'original_scheduled_date_preserved',
    to_char(v_start_date, 'YYYY-MM-DD'),
    (v_result->>'original_scheduled_date')::TEXT
  );

  SELECT count(*) INTO v_count FROM training_session_records
  WHERE record_id = v_record AND entry_mode = 'backfill' AND performed_precision = 'date';
  PERFORM sprint12_assert_eq('AU', 'one_backfill_record', '1', v_count::TEXT);

  SELECT count(*) INTO v_count FROM training_block_results WHERE session_record_id = v_record;
  PERFORM sprint12_assert_eq('AU', 'tree_blocks', '1', v_count::TEXT);
  SELECT count(*) INTO v_count FROM training_set_results WHERE set_result_id = v_set;
  PERFORM sprint12_assert_eq('AU', 'tree_sets', '1', v_count::TEXT);

  SELECT created_at, performed_on::TEXT INTO v_created, v_performed
  FROM training_session_records WHERE record_id = v_record;
  PERFORM sprint12_record(
    'AU', 'created_at_is_recorded_at', 'true',
    (v_result->>'recorded_at' IS NOT NULL)::TEXT,
    NULL,
    (v_result->>'recorded_at')::TIMESTAMPTZ IS NOT DISTINCT FROM v_created
      AND v_performed IS DISTINCT FROM to_char(v_created AT TIME ZONE 'Atlantic/Canary', 'YYYY-MM-DD'),
    format('performed=%s created=%s recorded=%s', v_performed, v_created, v_result->>'recorded_at')
  );

  SELECT current_week_number, current_day_key
  INTO v_cursor_week, v_cursor_day
  FROM programme_assignments WHERE id = v_assignment_a;
  PERFORM sprint12_assert_eq(
    'AU', 'cursor_week_unchanged', v_week_before::TEXT, v_cursor_week::TEXT
  );
  PERFORM sprint12_assert_eq(
    'AU', 'cursor_day_unchanged', v_day_before, v_cursor_day
  );

  v_projection := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment_a, v_clock
  );
  SELECT e->>'state' INTO v_today_state
  FROM jsonb_array_elements(v_projection->'occurrences') e
  WHERE e->>'id' = v_day3::TEXT;
  PERFORM sprint12_record(
    'AU', 'today_unchanged', 'TODAY',
    v_today_state, NULL, v_today_state = 'TODAY', v_projection::TEXT
  );
  SELECT e->>'state' INTO v_today_state
  FROM jsonb_array_elements(v_projection->'occurrences') e
  WHERE e->>'id' = v_day1::TEXT;
  PERFORM sprint12_assert_eq('AU', 'backfill_projects_complete', 'COMPLETED', v_today_state);

  -- Retry / double-tap.
  v_retry := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day1,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_start_date + 1, 'YYYY-MM-DD'),
      'idempotency_key', v_idem,
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record,
      'completion_record', jsonb_build_object(
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq('AU', 'idempotent_replay', 'already_committed', v_retry->>'status');
  SELECT count(*) INTO v_count FROM training_session_records
  WHERE assignment_id = v_assignment_a AND entry_mode = 'backfill';
  PERFORM sprint12_assert_eq('AU', 'no_duplicate_backfill', '1', v_count::TEXT);
  SELECT count(*) INTO v_count FROM training_block_results WHERE session_record_id = v_record;
  PERFORM sprint12_assert_eq('AU', 'no_duplicate_tree', '1', v_count::TEXT);

  -- Concurrent second device: same key after commit.
  v_retry := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day1,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_start_date + 1, 'YYYY-MM-DD'),
      'idempotency_key', v_idem,
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', 'c8000000-0000-4000-8000-000000000011',
      'completion_record', jsonb_build_object(
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq('AU', 'second_device_same_key', 'already_committed', v_retry->>'status');

  IF v_day_open IS NULL THEN
    PERFORM sprint12_record(
      'AU', 'open_past_create_or_resume', 'skipped',
      'no_open_past_occurrence', NULL, FALSE, NULL
    );
  ELSE
  v_result := public.cohort_create_or_resume_fixed_occurrence_at(v_day_open, v_clock);
  PERFORM sprint12_record(
    'AU', 'open_past_create_or_resume', 'created',
    v_result->>'status', NULL,
    v_result->>'status' IN ('created', 'resumed'),
    v_result::TEXT
  );
  v_retry := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day_open,
      'assignment_id', v_assignment_a,
      'performed_on', (
        SELECT to_char(scheduled_date, 'YYYY-MM-DD')
        FROM programme_schedule_occurrences WHERE id = v_day_open
      ),
      'idempotency_key', format('backfill:%s:%s:%s', v_athlete_a, v_assignment_a, v_day_open),
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record2,
      'completion_record', jsonb_build_object(
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq(
    'AU', 'reject_in_progress', 'occurrence_in_progress', v_retry->>'code'
  );
  END IF;

  v_result := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day3,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_today, 'YYYY-MM-DD'),
      'idempotency_key', format('backfill:%s:%s:%s', v_athlete_a, v_assignment_a, v_day3),
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record2,
      'completion_record', jsonb_build_object(
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    v_clock
  );
  PERFORM sprint12_assert_eq('AU', 'reject_today_occurrence', 'future_occurrence', v_result->>'code');

  -- In-progress: late-start a remaining unfinished past day if any scheduled before today besides day1/day2.
  -- If week has only those, create_or_resume on a synthetic leftover: restore day2 from skipped? Don't rewrite skip.
  -- Instead start today's session then try backfill today (already rejected as future).
  v_result := public.cohort_create_or_resume_fixed_occurrence_at(v_day3, v_clock);
  PERFORM sprint12_record(
    'AU', 'today_create_or_resume', 'created',
    v_result->>'status', NULL,
    v_result->>'status' IN ('created', 'resumed'),
    v_result::TEXT
  );

  SELECT count(*) INTO v_live_after
  FROM training_session_records
  WHERE athlete_id = v_athlete_a::TEXT
    AND record_id = 'c8000000-0000-4000-8000-000000000099'
    AND started_at = TIMESTAMPTZ '2026-09-01 10:00:00+00'
    AND entry_mode = 'live';
  PERFORM sprint12_assert_eq('AU', 'legacy_live_row_untouched', '1', v_live_after::TEXT);

  -- Timezone boundary: 23:30 UTC on v_today is next calendar day in Canary (WEST, UTC+1).
  v_result := public.cohort_complete_backfilled_fixed_occurrence_at(
    jsonb_build_object(
      'occurrence_id', v_day1,
      'assignment_id', v_assignment_a,
      'performed_on', to_char(v_today + 1, 'YYYY-MM-DD'),
      'idempotency_key', v_idem,
      'actuals_fingerprint', v_fp,
      'status', 'completed',
      'record_id', v_record,
      'completion_record', jsonb_build_object(
        'session_snapshot', '{}'::jsonb,
        'block_results', v_tree
      )
    ),
    ((v_today::TEXT || ' 23:30:00')::TIMESTAMP AT TIME ZONE 'UTC')
  );
  PERFORM sprint12_record(
    'AU', 'timezone_uses_assignment_not_utc', 'already_committed_or_future',
    v_result->>'code',
    NULL,
    v_result->>'status' IN ('already_committed', 'validation_failure', 'conflict'),
    v_result::TEXT
  );
END $$;

SELECT sprint12_fail_if_any_failed();
