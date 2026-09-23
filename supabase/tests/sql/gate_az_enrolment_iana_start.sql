-- Gate AZ — Sprint 2 IANA enrolment start. Extends the AY-family local gate.
-- Generic fixtures only. No hosted apply.

DO $$
DECLARE
  v_athlete UUID := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  v_coach UUID := 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1';
  v_eligible UUID;
  v_res JSONB;
  v_count INT;
  v_before INT;
BEGIN
  SELECT id INTO v_eligible
  FROM programme_versions
  WHERE lifecycle_status = 'published'
    AND approved_for_global
    AND archived_at IS NULL
  ORDER BY created_at ASC
  LIMIT 1;
  IF v_eligible IS NULL THEN
    RAISE EXCEPTION 'AZ no eligible catalogue version';
  END IF;

  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete, 'authenticated', 'authenticated',
      'gate-az-athlete@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coach, 'authenticated', 'authenticated',
      'gate-az-coach@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete, 'Gate AZ athlete', TRUE, FALSE),
    (v_coach, 'Gate AZ coach', FALSE, TRUE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);

  SELECT count(*) INTO v_before FROM programme_assignments WHERE athlete_id = v_athlete;

  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'BST', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AZ', 'reject_abbreviation', 'invalid_timezone', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'invalid_timezone', v_res::text
  );

  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, '+08:00', FALSE);
  PERFORM sprint12_record(
    'AZ', 'reject_offset', 'invalid_timezone', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'invalid_timezone', v_res::text
  );

  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'UTC', FALSE);
  PERFORM sprint12_record(
    'AZ', 'reject_utc', 'invalid_timezone', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'invalid_timezone', v_res::text
  );

  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'Not/AZone', FALSE);
  PERFORM sprint12_record(
    'AZ', 'reject_unknown_iana', 'invalid_timezone', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'invalid_timezone', v_res::text
  );

  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, NULL, FALSE);
  PERFORM sprint12_record(
    'AZ', 'reject_missing', 'invalid_timezone', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'invalid_timezone', v_res::text
  );

  SELECT count(*) INTO v_count FROM programme_assignments WHERE athlete_id = v_athlete;
  PERFORM sprint12_record(
    'AZ', 'no_row_on_reject', v_before::text, v_count::text, NULL, v_count = v_before, NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'Asia/Makassar', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AZ', 'enrol_makassar', 'enrolled', v_res->>'status',
    NULL,
    (v_res->>'status') = 'enrolled'
      AND (v_res->>'timezone') = 'Asia/Makassar'
      AND (v_res->>'started_at') IS NOT NULL
      AND (v_res->>'programme_version_id') = v_eligible::text,
    v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'Europe/London', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AZ', 'idempotent_same_pin', 'already_enrolled', v_res->>'status',
    NULL, (v_res->>'status') = 'already_enrolled', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_coach::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'Europe/London', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'AZ', 'coach_denied', 'athlete_role_required', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') IN ('athlete_role_required', 'catalogue_enrolment_not_authorised', 'not_authenticated'),
    v_res::text
  );

  PERFORM sprint12_record(
    'AZ', 'makassar_after_utc_midnight', '2026-01-02',
    (('2026-01-01 16:30:00+00'::timestamptz AT TIME ZONE 'Asia/Makassar')::date)::text,
    NULL,
    (('2026-01-01 16:30:00+00'::timestamptz AT TIME ZONE 'Asia/Makassar')::date) = DATE '2026-01-02',
    NULL
  );
  PERFORM sprint12_record(
    'AZ', 'london_gmt_same_utc_date', '2026-01-01',
    (('2026-01-01 00:30:00+00'::timestamptz AT TIME ZONE 'Europe/London')::date)::text,
    NULL,
    (('2026-01-01 00:30:00+00'::timestamptz AT TIME ZONE 'Europe/London')::date) = DATE '2026-01-01',
    NULL
  );
  PERFORM sprint12_record(
    'AZ', 'london_bst_next_local_date', '2026-07-02',
    (('2026-07-01 23:30:00+00'::timestamptz AT TIME ZONE 'Europe/London')::date)::text,
    NULL,
    (('2026-07-01 23:30:00+00'::timestamptz AT TIME ZONE 'Europe/London')::date) = DATE '2026-07-02',
    NULL
  );
  PERFORM sprint12_record(
    'AZ', 'makassar_no_dst', '2026-07-02',
    (('2026-07-01 16:30:00+00'::timestamptz AT TIME ZONE 'Asia/Makassar')::date)::text,
    NULL,
    (('2026-07-01 16:30:00+00'::timestamptz AT TIME ZONE 'Asia/Makassar')::date) = DATE '2026-07-02',
    NULL
  );
END $$;
