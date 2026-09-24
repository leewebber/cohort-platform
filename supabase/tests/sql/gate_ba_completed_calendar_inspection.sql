-- Gate BA — Sprint 3 completed fixed-calendar inspection (read-only).
-- Generic fixtures only. No hosted apply.

TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_version UUID;
  v_hash TEXT;
  v_athlete UUID := 'ba100000-0000-4000-8000-0000000000a1';
  v_other UUID := 'ba100000-0000-4000-8000-0000000000b2';
  v_coach UUID := 'ba100000-0000-4000-8000-0000000000c3';
  v_assignment UUID;
  v_paused UUID;
  v_unmat UUID;
  v_start DATE := public.cohort_resolve_athlete_local_date('Atlantic/Canary');
  v_res JSONB;
  v_first JSONB;
  v_second JSONB;
  v_occ_before INT;
  v_occ_after INT;
  v_assign_before TEXT;
  v_assign_after TEXT;
  v_outcome_before INT;
  v_session_before INT;
  v_outcome_after INT;
  v_session_after INT;
  v_day1 UUID;
BEGIN
  SELECT v.id, v.package_content_hash
  INTO v_version, v_hash
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK'
    AND v.version_number = 2
    AND v.lifecycle_status = 'published';
  IF v_version IS NULL THEN
    RAISE EXCEPTION 'BA missing Apollo published v2';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete,
     'authenticated', 'authenticated', 'gate-ba-a@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_other,
     'authenticated', 'authenticated', 'gate-ba-b@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coach,
     'authenticated', 'authenticated', 'gate-ba-c@example.invalid',
     crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete, 'Gate BA Athlete', TRUE, FALSE),
    (v_other, 'Gate BA Other', TRUE, FALSE),
    (v_coach, 'Gate BA Coach', FALSE, TRUE)
  ON CONFLICT (id) DO UPDATE
  SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version, 'Atlantic/Canary', FALSE
  );
  v_assignment := (v_res->>'enrolment_id')::UUID;
  v_res := public.start_fixed_programme_from_enrolment(
    v_assignment, v_start, 'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'materialise_active', 'materialised', v_res->>'status',
    NULL, v_res->>'status' = 'materialised', v_res::TEXT
  );

  SELECT id INTO v_day1
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment AND scheduled_date = v_start;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.resolve_fixed_programme_calendar(v_assignment);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'owner_inspect_active', 'active', v_res->>'assignment_status',
    NULL,
    COALESCE(v_res->>'status', '') = 'ok'
      AND COALESCE(v_res->>'assignment_status', '') = 'active'
      AND COALESCE(v_res->>'assignment_id', '') = v_assignment::TEXT,
    v_res::TEXT
  );

  v_res := public.resolve_active_fixed_programme_calendar();
  PERFORM sprint12_record(
    'BA', 'active_resolver_while_active', 'ok', v_res->>'status',
    NULL,
    COALESCE(v_res->>'status', '') = 'ok'
      AND COALESCE(v_res->>'assignment_id', '') = v_assignment::TEXT
      AND COALESCE(v_res->>'assignment_status', '') = 'active',
    v_res::TEXT
  );

  SELECT COUNT(*) INTO v_occ_before
  FROM programme_schedule_occurrences WHERE assignment_id = v_assignment;
  SELECT COUNT(*) INTO v_outcome_before
  FROM programme_slot_outcomes WHERE assignment_id = v_assignment;
  SELECT COUNT(*) INTO v_session_before
  FROM training_session_records WHERE assignment_id = v_assignment;
  SELECT status || '|' || programme_version_id::TEXT || '|' ||
         COALESCE(materialised_package_content_hash, '')
  INTO v_assign_before
  FROM programme_assignments WHERE id = v_assignment;

  UPDATE programme_assignments
  SET status = 'completed', completed_at = NOW()
  WHERE id = v_assignment;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_first := public.resolve_fixed_programme_calendar(v_assignment);
  v_second := public.resolve_fixed_programme_calendar(v_assignment);
  PERFORM set_config('role', 'postgres', true);

  PERFORM sprint12_record(
    'BA', 'owner_inspect_completed', 'completed', v_first->>'assignment_status',
    NULL,
    COALESCE(v_first->>'status', '') = 'ok'
      AND COALESCE(v_first->>'assignment_status', '') = 'completed'
      AND COALESCE(v_first->>'assignment_id', '') = v_assignment::TEXT
      AND (v_first->>'programme_name') IS NOT NULL,
    v_first::TEXT
  );
  PERFORM sprint12_record(
    'BA', 'inspection_idempotent', 'same',
    CASE WHEN v_first = v_second THEN 'same' ELSE 'different' END,
    NULL, v_first = v_second, NULL
  );
  PERFORM sprint12_record(
    'BA', 'pinned_version_unchanged', v_version::TEXT,
    (
      SELECT programme_version_id::TEXT
      FROM programme_assignments WHERE id = v_assignment
    ),
    NULL,
    (SELECT programme_version_id FROM programme_assignments WHERE id = v_assignment)
      = v_version,
    NULL
  );

  SELECT COUNT(*) INTO v_occ_after
  FROM programme_schedule_occurrences WHERE assignment_id = v_assignment;
  SELECT COUNT(*) INTO v_outcome_after
  FROM programme_slot_outcomes WHERE assignment_id = v_assignment;
  SELECT COUNT(*) INTO v_session_after
  FROM training_session_records WHERE assignment_id = v_assignment;
  SELECT status || '|' || programme_version_id::TEXT || '|' ||
         COALESCE(materialised_package_content_hash, '')
  INTO v_assign_after
  FROM programme_assignments WHERE id = v_assignment;

  PERFORM sprint12_record(
    'BA', 'no_occurrence_mutation', v_occ_before::TEXT, v_occ_after::TEXT,
    NULL, v_occ_before = v_occ_after, NULL
  );
  PERFORM sprint12_record(
    'BA', 'no_outcome_mutation', v_outcome_before::TEXT, v_outcome_after::TEXT,
    NULL, v_outcome_before = v_outcome_after, NULL
  );
  PERFORM sprint12_record(
    'BA', 'no_session_mutation', v_session_before::TEXT, v_session_after::TEXT,
    NULL, v_session_before = v_session_after, NULL
  );
  PERFORM sprint12_record(
    'BA', 'assignment_pin_stable_after_inspect',
    'completed|' || v_version::TEXT || '|' || COALESCE(v_hash, ''),
    v_assign_after,
    NULL,
    v_assign_after = ('completed|' || v_version::TEXT || '|' || COALESCE(v_hash, '')),
    v_assign_before || ' -> ' || v_assign_after
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.resolve_active_fixed_programme_calendar();
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'active_resolver_after_complete', 'no_active_assignment',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL,
    v_res->>'status' = 'absent' AND v_res->>'code' = 'no_active_assignment',
    v_res::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.create_or_resume_fixed_programme_occurrence_session(v_day1);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'create_resume_rejected_when_completed', 'ineligible',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL,
    v_res->>'status' IS DISTINCT FROM 'ok'
      AND COALESCE(v_res->>'code', '') IN (
        'fixed_assignment_ineligible',
        'assignment_inactive',
        'completed_occurrence'
      ),
    v_res::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', v_other::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.resolve_fixed_programme_calendar(v_assignment);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'other_athlete_denied', 'assignment_not_found',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL,
    v_res->>'status' = 'authorization_failure'
      AND v_res->>'code' = 'assignment_not_found',
    v_res::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', v_coach::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.resolve_fixed_programme_calendar(v_assignment);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'coach_denied', 'athlete_role_required',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL, v_res->>'code' = 'athlete_role_required', v_res::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('role', 'postgres', true);
  v_res := public.cohort_resolve_fixed_programme_calendar_at(
    v_assignment,
    NOW()
  );
  PERFORM sprint12_record(
    'BA', 'anonymous_denied', 'athlete_role_required',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL, v_res->>'code' = 'athlete_role_required', v_res::TEXT
  );

  INSERT INTO programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status,
    started_at, timezone, schedule_mode, materialised_at,
    materialised_package_content_hash
  )
  SELECT
    'ba200000-0000-4000-8000-0000000000p1'::UUID,
    v_athlete, v_version, 'APOLLO-BUILD-12-WEEK', 'paused',
    v_start, 'Atlantic/Canary', 'fixed_schedule', NOW(), v_hash
  WHERE NOT EXISTS (
    SELECT 1 FROM programme_assignments
    WHERE id = 'ba200000-0000-4000-8000-0000000000p1'
  );
  v_paused := 'ba200000-0000-4000-8000-0000000000p1';

  INSERT INTO programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status,
    started_at, timezone, schedule_mode
  )
  SELECT
    'ba200000-0000-4000-8000-0000000000u1'::UUID,
    v_athlete, v_version, 'APOLLO-BUILD-12-WEEK', 'active',
    v_start, 'Atlantic/Canary', 'fixed_schedule'
  WHERE NOT EXISTS (
    SELECT 1 FROM programme_assignments
    WHERE id = 'ba200000-0000-4000-8000-0000000000u1'
  );
  v_unmat := 'ba200000-0000-4000-8000-0000000000u1';

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.resolve_fixed_programme_calendar(v_paused);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'paused_rejected', 'fixed_assignment_ineligible',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL, v_res->>'code' = 'fixed_assignment_ineligible', v_res::TEXT
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.resolve_fixed_programme_calendar(v_unmat);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'unmaterialised_rejected', 'fixed_assignment_ineligible',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL, v_res->>'code' = 'fixed_assignment_ineligible', v_res::TEXT
  );

  UPDATE programme_assignments
  SET status = 'cancelled'
  WHERE id = v_paused;
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.resolve_fixed_programme_calendar(v_paused);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BA', 'cancelled_rejected', 'fixed_assignment_ineligible',
    COALESCE(v_res->>'code', v_res->>'status'),
    NULL, v_res->>'code' = 'fixed_assignment_ineligible', v_res::TEXT
  );
END $$;

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results
WHERE gate = 'BA'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
