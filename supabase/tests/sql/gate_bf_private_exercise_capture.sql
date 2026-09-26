-- Gate BF — private exercise capture metadata can be repaired without assignment mutation.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-BF-R1';
  v_lineage UUID := 'bf1bf1bf-bf1b-41bf-81bf-bf1bf1bf1bf1';
  v_hash TEXT := sprint12_hash('gate-bf-capture');
  v_owner UUID := 'bf2bf2bf-bf2b-42bf-82bf-bf2bf2bf2bf2';
  v_version UUID := 'bf5bf5bf-bf5b-45bf-85bf-bf5bf5bf5bf5';
  v_payload JSONB;
  v_res JSONB;
  v_updated INT;
  v_priv INT;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
     'gate-bf-owner@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_owner, 'Gate BF Owner', TRUE, TRUE)
  ON CONFLICT (id) DO UPDATE SET is_athlete = TRUE, is_coach = TRUE;

  v_payload := sprint12_build_package('PROG-GATE-BF', 1, v_hash, v_protocol, v_lineage)
    || jsonb_build_object(
      'publication_kind', 'private_exact_version',
      'programme_version_id', v_version,
      'library_scope', 'coach_private',
      'owner_id', v_owner
    );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BF', 'publish', 'published', v_res->>'status',
    NULL, (v_res->>'status') IN ('published', 'already_published'), v_res::text
  );

  v_payload := jsonb_set(
    v_payload,
    '{protocol_graphs,0,blocks,0,exercises,0,prescription}',
    jsonb_build_object(
      'sets', 3,
      'reps', jsonb_build_object('type', 'exact', 'exact_reps', 5),
      'load', jsonb_build_object('type', 'rpe', 'rpe', 7),
      'performance_capture', jsonb_build_object('load_unit', 'kg', 'rpe', true)
    )
  );

  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM public.repair_private_programme_exercise_capture(v_payload);
    v_priv := 0;
  EXCEPTION WHEN insufficient_privilege THEN
    v_priv := 1;
  WHEN others THEN
    v_priv := 1;
  END;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('BF', 'authenticated_denied', '1', v_priv::text, NULL, v_priv = 1, NULL);

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_private_programme_exercise_capture(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BF', 'repair', 'repaired', v_res->>'status',
    NULL, (v_res->>'status') = 'repaired', v_res::text
  );
  v_updated := COALESCE((v_res->>'updated_exercises')::INT, 0);
  PERFORM sprint12_record(
    'BF', 'updated', '1', v_updated::text, NULL, v_updated >= 1, NULL
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_private_programme_exercise_capture(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BF', 'idempotent', '0', COALESCE(v_res->>'updated_exercises', ''),
    NULL, COALESCE((v_res->>'updated_exercises')::INT, -1) = 0, v_res::text
  );

  PERFORM sprint12_record(
    'BF', 'capture_present', 'kg',
    (
      SELECT e.prescription->'performance_capture'->>'load_unit'
      FROM public.session_block_exercises e
      JOIN public.session_blocks b ON b.block_id = e.block_id
      WHERE b.session_id = v_protocol
      LIMIT 1
    ),
    NULL,
    EXISTS (
      SELECT 1 FROM public.session_block_exercises e
      JOIN public.session_blocks b ON b.block_id = e.block_id
      WHERE b.session_id = v_protocol
        AND e.prescription->'performance_capture'->>'load_unit' = 'kg'
    ),
    NULL
  );
END $$;

SELECT sprint12_fail_if_any_failed();
