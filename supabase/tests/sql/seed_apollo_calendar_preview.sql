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
    'apollo-calendar-athlete@example.invalid', crypt('x', gen_salt('bf')),
    NOW(), NOW(), NOW(),
    '{"provider":"email","providers":["email"]}', '{}',
    FALSE, '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_athlete, 'Apollo calendar athlete', TRUE, FALSE)
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
  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  IF v_count <> 84 THEN
    RAISE EXCEPTION 'Apollo calendar preview expected 84 occurrences, got %', v_count;
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

  RAISE NOTICE
    'Apollo calendar preview ready assignment=% start=% timezone=% occurrences=%',
    v_assignment,
    v_start_date,
    v_timezone,
    v_count;
END $$;
