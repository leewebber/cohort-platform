-- Loopback-only founder preview state. The shell wrapper validates and passes
-- preview_start_date / preview_timezone as psql variables.
SELECT set_config('cohort.preview_start_date', :'preview_start_date', false);
SELECT set_config('cohort.preview_timezone', :'preview_timezone', false);

DO $$
DECLARE
  v_athlete UUID := 'ac000001-0000-4000-8000-000000000001';
  v_start_date DATE := current_setting('cohort.preview_start_date')::DATE;
  v_timezone TEXT := current_setting('cohort.preview_timezone');
  v_version UUID;
  v_assignment UUID;
  v_result JSONB;
  v_count INT;
  v_occurrence_count INT;
BEGIN
  SELECT v.id INTO v_version
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK'
    AND v.version_number = 1
    AND v.lifecycle_status = 'published';
  IF v_version IS NULL THEN
    RAISE EXCEPTION 'Apollo published version is unavailable';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', v_athlete,
    'authenticated', 'authenticated',
    'apollo-local-athlete@example.invalid', crypt('x', gen_salt('bf')),
    NOW(), NOW(), NOW(),
    '{"provider":"email","providers":["email"]}', '{}',
    FALSE, '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_athlete, 'Apollo local athlete', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
  SET is_athlete = TRUE, is_coach = FALSE;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version,
    v_timezone,
    FALSE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  v_result := public.start_fixed_programme_from_enrolment(
    v_assignment,
    v_start_date,
    v_timezone
  );
  IF v_result->>'status' NOT IN ('materialised', 'already_materialised') THEN
    RAISE EXCEPTION 'Apollo calendar preview start failed: %', v_result;
  END IF;

  PERFORM set_config('role', 'postgres', true);
  SELECT COUNT(*) INTO v_occurrence_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  IF v_occurrence_count <> 84 THEN
    RAISE EXCEPTION 'Apollo calendar preview expected 84 occurrences, got %', v_occurrence_count;
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM programme_assignments
    WHERE id = v_assignment
      AND schedule_mode = 'fixed_schedule'
      AND started_at = v_start_date
      AND timezone = v_timezone
  ) THEN
    RAISE EXCEPTION 'Apollo calendar preview selection was not preserved';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM auth.users
  WHERE id = v_athlete
    AND email = 'apollo-local-athlete@example.invalid'
    AND crypt('x', encrypted_password) = encrypted_password;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Apollo canonical preview login is not stable';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM programme_assignments
  WHERE athlete_id = v_athlete
    AND status = 'active';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Apollo canonical preview expected one active assignment, got %', v_count;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_version;
  IF v_count <> 84 THEN
    RAISE EXCEPTION 'Apollo canonical preview expected 84 materialised links, got %', v_count;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT assignment_id, session_slot_id
    FROM programme_schedule_occurrences
    WHERE assignment_id = v_assignment
    GROUP BY assignment_id, session_slot_id
    HAVING COUNT(*) > 1
  ) duplicate_occurrences;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo canonical preview has duplicate occurrence identities';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT assignment_id, scheduled_date
    FROM programme_schedule_occurrences
    WHERE assignment_id = v_assignment
    GROUP BY assignment_id, scheduled_date
    HAVING COUNT(*) > 1
  ) duplicate_dates;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo canonical preview has duplicate occurrence dates';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM programme_slot_outcomes
  WHERE assignment_id = v_assignment;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo canonical preview has synthetic session links';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM training_sessions
  WHERE athlete_id = v_athlete::TEXT
    AND status = 'in_progress';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo canonical preview has active sessions';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id = v_athlete::TEXT
    AND status IN ('completed', 'abandoned');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo canonical preview has terminal performances';
  END IF;

  RAISE NOTICE
    'Apollo canonical calendar preview ready assignment=% start=% timezone=% occurrences=%',
    v_assignment,
    v_start_date,
    v_timezone,
    v_occurrence_count;
END $$;
