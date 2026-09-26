-- Gate BG — private enrol creates fixed_schedule; bounded repair is
-- idempotent and evidence-preserving for a Bali-shaped used assignment.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol_a TEXT := 'PROT-GATE-BG-A';
  v_protocol_b TEXT := 'PROT-GATE-BG-B';
  v_lineage_a UUID := 'b61b61b6-b61b-41b6-81b6-b61b61b61b61';
  v_lineage_b UUID := 'b65b65b6-b65b-45b6-85b6-b65b65b65b65';
  v_hash TEXT := sprint12_hash('gate-bg-priv');
  v_hash_cat TEXT := sprint12_hash('gate-bg-cat');
  v_owner UUID := 'b62b62b6-b62b-42b6-82b6-b62b62b62b62';
  v_other UUID := 'b63b63b6-b63b-43b6-83b6-b63b63b63b63';
  v_stray UUID := 'b64b64b6-b64b-44b6-84b6-b64b64b64b64';
  v_payload JSONB;
  v_res JSONB;
  v_cal JSONB;
  v_priv UUID;
  v_cat UUID;
  v_cat_version UUID;
  v_cat_hash TEXT;
  v_assign UUID;
  v_cat_assign UUID;
  v_incomplete UUID;
  v_sat UUID;
  v_sun_am UUID;
  v_sun_pm UUID;
  v_count INT;
  v_mode TEXT;
  v_week INT;
  v_day TEXT;
  v_slot INT;
  v_started DATE;
  v_tz TEXT;
  v_pin TEXT;
  v_records INT;
  v_outcomes INT;
  v_sessions INT;
  v_occ INT;
  v_priv_exec INT;
  v_sunday INT;
  v_day1 UUID;
  v_day2 UUID;
BEGIN
  PERFORM sprint12_ensure_published_session(v_protocol_a, v_lineage_a, 1, 'Strength A');
  PERFORM sprint12_ensure_published_session(v_protocol_b, v_lineage_b, 1, 'Strength B');

  v_payload := sprint12_build_package('PROG-GATE-BG-PRIV', 1, v_hash, v_protocol_a, v_lineage_a);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  v_priv := (v_res->>'programme_version_id')::uuid;
  v_payload := sprint12_build_package('PROG-GATE-BG-CAT', 1, v_hash_cat, v_protocol_a, v_lineage_a);
  v_res := public.import_authored_plan_package(v_payload);
  v_cat := (v_res->>'programme_version_id')::uuid;
  PERFORM public.publish_cohort_global_programme_version(v_cat, 'gate-bg');
  PERFORM public.approve_cohort_global_programme_version(v_cat, 'gate-bg');
  PERFORM set_config('role', 'postgres', true);

  UPDATE programme_versions
  SET library_scope = 'coach_private',
      owner_type = 'coach',
      owner_id = v_owner::text,
      approved_for_global = FALSE
  WHERE id = v_priv;

  SELECT w.id INTO v_day1
  FROM programme_version_weeks w
  WHERE w.version_id = v_priv
  LIMIT 1;
  SELECT d.id INTO v_day1
  FROM programme_version_weeks w
  JOIN programme_version_days d ON d.week_id = w.id
  WHERE w.version_id = v_priv AND d.day_key = 'day_1'
  LIMIT 1;
  UPDATE programme_version_session_slots
  SET time_of_day = 'morning', display_title = 'Strength A'
  WHERE day_id = v_day1 AND session_order = 1;

  INSERT INTO programme_version_days (id, week_id, day_key, day_order, day_type)
  SELECT gen_random_uuid(), w.id, 'day_2', 2, 'training'
  FROM programme_version_weeks w
  WHERE w.version_id = v_priv
  LIMIT 1
  RETURNING id INTO v_day2;

  INSERT INTO programme_version_session_slots (
    day_id, session_order, protocol_id, display_title, time_of_day
  ) VALUES
    (v_day2, 1, v_protocol_a, 'Long Aerobic — BikeErg', 'morning'),
    (v_day2, 2, v_protocol_b, 'Strength B — Upper Strength', 'afternoon');

  UPDATE programme_versions
  SET lifecycle_status = 'published',
      published_at = NOW(),
      updated_at = NOW()
  WHERE id = v_priv;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
     'gate-bg-owner@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_other, 'authenticated', 'authenticated',
     'gate-bg-other@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_stray, 'authenticated', 'authenticated',
     'gate-bg-stray@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_owner, 'Gate BG Owner', TRUE, TRUE),
    (v_other, 'Gate BG Other', TRUE, FALSE),
    (v_stray, 'Gate BG Stray', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(
    v_priv, 'Asia/Makassar', DATE '2026-09-26', TRUE
  );
  PERFORM set_config('role', 'postgres', true);
  v_assign := (v_res->>'enrolment_id')::uuid;
  PERFORM sprint12_record(
    'BG', 'new_enrol_fixed', 'fixed_schedule', v_res->>'schedule_mode',
    NULL,
    (v_res->>'status') = 'enrolled' AND (v_res->>'schedule_mode') = 'fixed_schedule',
    v_res::text
  );
  SELECT schedule_mode INTO v_mode FROM programme_assignments WHERE id = v_assign;
  PERFORM sprint12_record(
    'BG', 'new_enrol_row_fixed', 'fixed_schedule', v_mode, NULL, v_mode = 'fixed_schedule', NULL
  );

  SELECT count(*) INTO v_occ
  FROM programme_schedule_occurrences WHERE assignment_id = v_assign;
  PERFORM sprint12_record('BG', 'three_occurrences', '3', v_occ::text, NULL, v_occ = 3, NULL);

  SELECT o.id INTO v_sat
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assign AND o.day_key = 'day_1' AND o.session_order = 1;
  SELECT o.id INTO v_sun_am
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assign AND o.day_key = 'day_2' AND o.session_order = 1;
  SELECT o.id INTO v_sun_pm
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_assign AND o.day_key = 'day_2' AND o.session_order = 2;

  PERFORM sprint12_record(
    'BG', 'sat_date', '2026-09-26',
    (SELECT scheduled_date::text FROM programme_schedule_occurrences WHERE id = v_sat),
    NULL,
    (SELECT scheduled_date FROM programme_schedule_occurrences WHERE id = v_sat) = DATE '2026-09-26',
    NULL
  );
  PERFORM sprint12_record(
    'BG', 'sunday_shared', '2026-09-27',
    (SELECT scheduled_date::text FROM programme_schedule_occurrences WHERE id = v_sun_am),
    NULL,
    (SELECT scheduled_date FROM programme_schedule_occurrences WHERE id = v_sun_am) = DATE '2026-09-27'
      AND (SELECT scheduled_date FROM programme_schedule_occurrences WHERE id = v_sun_pm) = DATE '2026-09-27',
    NULL
  );

  UPDATE programme_schedule_occurrences
  SET disposition = 'completed'
  WHERE id = v_sat;
  INSERT INTO training_session_records (
    record_id, athlete_id, assignment_id, programme_session_id, status, session_snapshot, started_at
  ) VALUES (
    gen_random_uuid(), v_owner::text, v_assign, NULL, 'completed', '{}'::jsonb, NOW()
  );
  INSERT INTO training_sessions (
    athlete_id, protocol_id, programme_id, week_number, status, started_at, completed_at
  ) VALUES (
    v_owner::text, v_protocol_a, 'PROG-GATE-BG-PRIV', 1, 'completed', NOW(), NOW()
  );

  SELECT current_week_number, current_day_key, current_slot_order, started_at, timezone,
         materialised_package_content_hash
    INTO v_week, v_day, v_slot, v_started, v_tz, v_pin
  FROM programme_assignments WHERE id = v_assign;
  SELECT count(*) INTO v_records FROM training_session_records WHERE assignment_id = v_assign;
  SELECT count(*) INTO v_outcomes FROM programme_slot_outcomes WHERE assignment_id = v_assign;
  SELECT count(*) INTO v_sessions
  FROM training_sessions
  WHERE athlete_id = v_owner::text AND protocol_id IN (v_protocol_a, v_protocol_b);
  SELECT count(*) INTO v_occ FROM programme_schedule_occurrences WHERE assignment_id = v_assign;

  UPDATE programme_assignments
  SET schedule_mode = 'legacy_cursor'
  WHERE id = v_assign;

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_cal := public.resolve_fixed_programme_calendar(v_assign);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BG', 'calendar_legacy_blocked', 'unsupported_scheduling_mode', v_cal->>'code',
    NULL, (v_cal->>'code') = 'unsupported_scheduling_mode', v_cal::text
  );

  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM public.repair_private_materialised_assignment_schedule_mode(
      jsonb_build_object(
        'assignment_id', v_assign,
        'programme_version_id', v_priv,
        'package_content_hash', v_hash
      )
    );
    v_priv_exec := 0;
  EXCEPTION WHEN insufficient_privilege THEN
    v_priv_exec := 1;
  WHEN others THEN
    v_priv_exec := 1;
  END;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('BG', 'authenticated_denied', '1', v_priv_exec::text, NULL, v_priv_exec = 1, NULL);

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_private_materialised_assignment_schedule_mode(
    jsonb_build_object(
      'assignment_id', v_assign,
      'programme_version_id', v_priv,
      'package_content_hash', v_hash
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BG', 'repair', 'repaired', v_res->>'status',
    NULL, (v_res->>'status') = 'repaired' AND (v_res->>'schedule_mode') = 'fixed_schedule',
    v_res::text
  );

  PERFORM sprint12_record(
    'BG', 'cursor_preserved', format('%s:%s:%s', v_week, v_day, v_slot),
    (
      SELECT format('%s:%s:%s', current_week_number, current_day_key, current_slot_order)
      FROM programme_assignments WHERE id = v_assign
    ),
    NULL,
    (SELECT current_week_number FROM programme_assignments WHERE id = v_assign) = v_week
      AND (SELECT current_day_key FROM programme_assignments WHERE id = v_assign) = v_day
      AND (SELECT current_slot_order FROM programme_assignments WHERE id = v_assign) = v_slot
      AND (SELECT started_at FROM programme_assignments WHERE id = v_assign) = v_started
      AND (SELECT timezone FROM programme_assignments WHERE id = v_assign) = v_tz
      AND (SELECT materialised_package_content_hash FROM programme_assignments WHERE id = v_assign) = v_pin,
    NULL
  );
  PERFORM sprint12_record(
    'BG', 'evidence_preserved', format('%s:%s:%s:%s', v_occ, v_records, v_outcomes, v_sessions),
    (
      SELECT format(
        '%s:%s:%s:%s',
        (SELECT count(*) FROM programme_schedule_occurrences WHERE assignment_id = v_assign),
        (SELECT count(*) FROM training_session_records WHERE assignment_id = v_assign),
        (SELECT count(*) FROM programme_slot_outcomes WHERE assignment_id = v_assign),
        (SELECT count(*) FROM training_sessions WHERE athlete_id = v_owner::text AND protocol_id IN (v_protocol_a, v_protocol_b))
      )
    ),
    NULL,
    (SELECT count(*) FROM programme_schedule_occurrences WHERE assignment_id = v_assign) = v_occ
      AND (SELECT count(*) FROM training_session_records WHERE assignment_id = v_assign) = v_records
      AND (SELECT count(*) FROM programme_slot_outcomes WHERE assignment_id = v_assign) = v_outcomes
      AND (SELECT disposition FROM programme_schedule_occurrences WHERE id = v_sat) = 'completed'
      AND (SELECT disposition FROM programme_schedule_occurrences WHERE id = v_sun_am) IS DISTINCT FROM 'completed'
      AND (SELECT disposition FROM programme_schedule_occurrences WHERE id = v_sun_pm) IS DISTINCT FROM 'completed',
    NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_cal := public.resolve_fixed_programme_calendar(v_assign);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BG', 'calendar_rpc_ok', 'ok', v_cal->>'status',
    NULL, (v_cal->>'status') = 'ok', v_cal->>'code'
  );

  v_cal := public.cohort_resolve_fixed_programme_calendar_at(
    v_assign, TIMESTAMPTZ '2026-09-27 01:00:00+08'
  );
  SELECT count(*) INTO v_sunday
  FROM jsonb_array_elements(v_cal->'occurrences') occ
  WHERE occ->>'scheduled_date' = '2026-09-27';
  PERFORM sprint12_record(
    'BG', 'calendar_sunday_group', '2', v_sunday::text,
    NULL,
    (v_cal->>'status') = 'ok' AND v_sunday = 2, v_cal->>'status'
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_private_materialised_assignment_schedule_mode(
    jsonb_build_object(
      'assignment_id', v_assign,
      'programme_version_id', v_priv,
      'package_content_hash', v_hash
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BG', 'repair_idempotent', 'already_repaired', v_res->>'status',
    NULL, (v_res->>'status') = 'already_repaired', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_cat, 'Asia/Makassar', FALSE);
  v_cat_assign := (v_res->>'enrolment_id')::uuid;
  v_res := public.start_fixed_programme_from_enrolment(
    v_cat_assign, DATE '2026-09-26', 'Asia/Makassar'
  );
  PERFORM set_config('role', 'postgres', true);
  SELECT programme_version_id, materialised_package_content_hash
    INTO v_cat_version, v_cat_hash
  FROM programme_assignments
  WHERE id = v_cat_assign;

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_private_materialised_assignment_schedule_mode(
    jsonb_build_object(
      'assignment_id', v_cat_assign,
      'programme_version_id', v_cat_version,
      'package_content_hash', v_cat_hash
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BG', 'catalogue_rejected', 'version_not_repairable', v_res->>'code',
    NULL, (v_res->>'code') = 'version_not_repairable', v_res::text
  );

  v_incomplete := gen_random_uuid();
  INSERT INTO programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    timezone, current_week_number, current_day_key, current_slot_order,
    enrolment_source, schedule_mode, materialised_at, materialisation_source,
    materialised_package_content_hash
  ) VALUES (
    v_incomplete, v_stray, v_priv, 'PROG-GATE-BG-PRIV', 'active', DATE '2026-09-26',
    'Asia/Makassar', 1, 'day_1', 1,
    'dual_role_self', 'legacy_cursor', NOW(), 'athlete_start_programme',
    v_hash
  );
  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_private_materialised_assignment_schedule_mode(
    jsonb_build_object(
      'assignment_id', v_incomplete,
      'programme_version_id', v_priv,
      'package_content_hash', v_hash
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BG', 'incomplete_rejected', 'fixed_schedule_incomplete', v_res->>'code',
    NULL, (v_res->>'code') = 'fixed_schedule_incomplete', v_res::text
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_private_materialised_assignment_schedule_mode(
    jsonb_build_object(
      'assignment_id', v_assign,
      'programme_version_id', v_priv,
      'package_content_hash', repeat('ab', 32)
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BG', 'wrong_hash_rejected', 'assignment_not_repairable', v_res->>'code',
    NULL, (v_res->>'code') = 'assignment_not_repairable', v_res::text
  );
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results WHERE gate = 'BG' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
