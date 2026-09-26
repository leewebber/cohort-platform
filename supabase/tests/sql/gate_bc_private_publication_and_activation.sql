-- Gate BC — private exact publication, discovery isolation, explicit start date.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-BC-R1';
  v_lineage UUID := 'c1c1c1c1-c1c1-41c1-81c1-c1c1c1c1c1c1';
  v_hash TEXT := sprint12_hash('gate-bc-priv');
  v_hash2 TEXT := sprint12_hash('gate-bc-conflict');
  v_owner UUID := 'c2c2c2c2-c2c2-42c2-82c2-c2c2c2c2c2c2';
  v_other UUID := 'c3c3c3c3-c3c3-43c3-83c3-c3c3c3c3c3c3';
  v_coach UUID := 'c4c4c4c4-c4c4-44c4-84c4-c4c4c4c4c4c4';
  v_version UUID := 'c5c5c5c5-c5c5-45c5-85c5-c5c5c5c5c5c5';
  v_payload JSONB;
  v_res JSONB;
  v_count INT;
  v_date TEXT;
  v_has_exec BOOLEAN;
BEGIN
  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate BC session');

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
     'gate-bc-owner@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_other, 'authenticated', 'authenticated',
     'gate-bc-other@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coach, 'authenticated', 'authenticated',
     'gate-bc-coach@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_owner, 'Gate BC Owner', TRUE, TRUE),
    (v_other, 'Gate BC Other', TRUE, FALSE),
    (v_coach, 'Gate BC Coach', FALSE, TRUE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  v_payload := sprint12_build_package('PROG-GATE-BC', 1, v_hash, v_protocol, v_lineage)
    || jsonb_build_object(
      'publication_kind', 'private_exact_version',
      'programme_version_id', v_version,
      'library_scope', 'coach_private',
      'owner_id', v_owner,
      'authorised_timezone', 'Asia/Makassar',
      'authorised_local_start_date', '2026-09-26'
    );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'publish_exact', 'published', v_res->>'status',
    NULL,
    (v_res->>'status') = 'published'
      AND (v_res->>'programme_version_id') = v_version::text
      AND (v_res->>'package_content_hash') = v_hash
      AND (v_res->>'session_count')::int >= 1,
    v_res::text
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'publish_idempotent', 'already_published', v_res->>'status',
    NULL, (v_res->>'status') = 'already_published', v_res::text
  );

  v_payload := v_payload || jsonb_build_object('package_content_hash', v_hash2);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'hash_conflict', 'immutable_version_conflict', v_res->>'code',
    NULL, (v_res->>'code') = 'immutable_version_conflict', v_res::text
  );

  PERFORM sprint12_record(
    'BC', 'not_catalogue', 'false',
    public.cohort_programme_version_is_catalogue_eligible(v_version)::text,
    NULL, NOT public.cohort_programme_version_is_catalogue_eligible(v_version), NULL
  );

  SELECT count(*) INTO v_count
  FROM programme_versions
  WHERE id = v_version
    AND library_scope = 'coach_private'
    AND approved_for_global IS NOT TRUE
    AND lifecycle_status = 'published'
    AND owner_id = v_owner::text
    AND authorised_local_start_date = DATE '2026-09-26'
    AND authorised_timezone = 'Asia/Makassar';
  PERFORM sprint12_record(
    'BC', 'private_row', '1', v_count::text, NULL, v_count = 1, NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.list_my_private_programme_versions();
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'owner_lists', '1',
    jsonb_array_length(v_res->'programmes')::text,
    NULL,
    (v_res->>'status') = 'ok'
      AND jsonb_array_length(v_res->'programmes') = 1
      AND (v_res->'programmes'->0->>'version_id') = v_version::text
      AND (v_res->'programmes'->0->>'title') IS NOT NULL
      AND (v_res->'programmes'->0->>'package_content_hash') IS NULL,
    v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.list_my_private_programme_versions();
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'unrelated_empty', '0',
    jsonb_array_length(v_res->'programmes')::text,
    NULL, jsonb_array_length(v_res->'programmes') = 0, v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_coach::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.list_my_private_programme_versions();
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'coach_only_empty', 'athlete_role_required', v_res->>'code',
    NULL,
    (v_res->>'code') = 'athlete_role_required'
      AND jsonb_array_length(v_res->'programmes') = 0,
    v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM sprint12_record(
    'BC', 'guessed_id_hidden', 'false',
    public.cohort_private_programme_visible_to_caller(v_version)::text,
    NULL, NOT public.cohort_private_programme_visible_to_caller(v_version), NULL
  );
  PERFORM set_config('role', 'postgres', true);

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(
    v_version, 'Asia/Makassar', DATE '2026-09-26', TRUE
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'explicit_start', '2026-09-26', v_res->>'started_at',
    NULL,
    (v_res->>'status') = 'enrolled' AND (v_res->>'started_at') = '2026-09-26',
    v_res::text
  );

  SELECT scheduled_date::text INTO v_date
  FROM programme_schedule_occurrences o
  JOIN programme_assignments a ON a.id = o.assignment_id
  WHERE a.athlete_id = v_owner AND a.status = 'active'
  ORDER BY scheduled_date, session_order
  LIMIT 1;
  PERFORM sprint12_record(
    'BC', 'w1d1', '2026-09-26', v_date, NULL, v_date = '2026-09-26', NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(
    v_version, 'Asia/Makassar', DATE '2026-09-26', TRUE
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'idempotent_same_date', 'already_enrolled', v_res->>'status',
    NULL, (v_res->>'status') = 'already_enrolled', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(
    v_version, 'Asia/Makassar', DATE '2026-09-27', TRUE
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'conflicting_date', 'start_date_mismatch', v_res->>'code',
    NULL, (v_res->>'code') = 'start_date_mismatch', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(
    v_version, 'Not/AZone', DATE '2026-09-26', TRUE
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BC', 'invalid_timezone', 'invalid_timezone', v_res->>'code',
    NULL, (v_res->>'code') = 'invalid_timezone', v_res::text
  );

  SELECT has_function_privilege('anon', 'public.publish_private_exact_programme_version(jsonb)', 'EXECUTE')
    INTO v_has_exec;
  PERFORM sprint12_record(
    'BC', 'anon_cannot_publish', 'false', v_has_exec::text, NULL, NOT v_has_exec, NULL
  );
  SELECT has_function_privilege('authenticated', 'public.publish_private_exact_programme_version(jsonb)', 'EXECUTE')
    INTO v_has_exec;
  PERFORM sprint12_record(
    'BC', 'auth_cannot_publish', 'false', v_has_exec::text, NULL, NOT v_has_exec, NULL
  );
END $$;

SELECT sprint12_fail_if_any_failed();
