-- Gate BE — private protocol graphs must be executable before publish/repair.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-BE-R1';
  v_lineage UUID := 'be1be1be-be1b-41be-81be-be1be1be1be1';
  v_hash TEXT := sprint12_hash('gate-be-graph');
  v_hash_inc TEXT := sprint12_hash('gate-be-inc');
  v_owner UUID := 'be2be2be-be2b-42be-82be-be2be2be2be2';
  v_version UUID := 'be5be5be-be5b-45be-85be-be5be5be5be5';
  v_incomplete UUID := 'be6be6be-be6b-46be-86be-be6be6be6be6';
  v_payload JSONB;
  v_header_only JSONB;
  v_res JSONB;
  v_count INT;
  v_blocks INT;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
     'gate-be-owner@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_owner, 'Gate BE Owner', TRUE, TRUE)
  ON CONFLICT (id) DO UPDATE SET is_athlete = TRUE, is_coach = TRUE;

  v_payload := sprint12_build_package('PROG-GATE-BE', 1, v_hash, v_protocol, v_lineage)
    || jsonb_build_object(
      'publication_kind', 'private_exact_version',
      'programme_version_id', v_version,
      'library_scope', 'coach_private',
      'owner_id', v_owner
    );
  v_header_only := v_payload - 'protocol_graphs';

  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_private_exact_programme_version(v_header_only);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BE', 'header_only_blocked', 'protocol_graph_required', v_res->>'code',
    NULL, (v_res->>'code') = 'protocol_graph_required', v_res::text
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BE', 'publish_with_graph', 'published', v_res->>'status',
    NULL, (v_res->>'status') = 'published', v_res::text
  );

  SELECT count(*) INTO v_blocks FROM session_blocks WHERE session_id = v_protocol;
  PERFORM sprint12_record(
    'BE', 'blocks_written', '1', v_blocks::text, NULL, v_blocks >= 1, NULL
  );
  PERFORM sprint12_record(
    'BE', 'executable', 'true',
    public.cohort_private_protocol_is_executable(v_protocol)::text,
    NULL, public.cohort_private_protocol_is_executable(v_protocol), NULL
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BE', 'publish_idempotent', 'already_published', v_res->>'status',
    NULL, (v_res->>'status') = 'already_published', v_res::text
  );

  PERFORM sprint12_record(
    'BE', 'not_catalogue', 'false',
    public.cohort_programme_version_is_catalogue_eligible(v_version)::text,
    NULL, NOT public.cohort_programme_version_is_catalogue_eligible(v_version), NULL
  );

  -- Hosted-shape incomplete version: published headers, no blocks.
  INSERT INTO programme_lineages (code, created_by)
  VALUES ('PROG-GATE-BE-INC', 'gate-be')
  ON CONFLICT (code) DO UPDATE SET created_by = EXCLUDED.created_by;
  INSERT INTO session_lineages (id, display_name)
  VALUES ('be7be7be-be7b-47be-87be-be7be7be7be7', 'Incomplete session')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO performance_protocols (
    protocol_id, name, published, content_kind, authoring_scope, endorsement_status,
    session_lineage_id, revision_number, lifecycle_status
  ) VALUES (
    'PROT-GATE-BE-INC-R1', 'Incomplete session', 'true', 'session', 'coach_private',
    'coach_authored', 'be7be7be-be7b-47be-87be-be7be7be7be7', 1, 'published'
  ) ON CONFLICT (protocol_id) DO NOTHING;
  INSERT INTO programme_versions (
    id, lineage_id, version_number, lifecycle_status, library_scope, owner_type,
    owner_id, created_by, name, coaching_intent, package_schema_version,
    package_content_hash, approved_for_global
  )
  SELECT v_incomplete, l.id, 1, 'draft', 'coach_private', 'coach',
         v_owner::text, 'gate-be', 'Incomplete', 'Intent', 1, v_hash_inc, FALSE
  FROM programme_lineages l WHERE l.code = 'PROG-GATE-BE-INC';

  INSERT INTO programme_version_weeks (id, version_id, week_number)
  VALUES ('be8be8be-be8b-48be-88be-be8be8be8be8', v_incomplete, 1);
  INSERT INTO programme_version_days (id, week_id, day_key, day_order, day_type)
  VALUES ('be9be9be-be9b-49be-89be-be9be9be9be9', 'be8be8be-be8b-48be-88be-be8be8be8be8', 'day_1', 1, 'training');
  INSERT INTO programme_version_session_slots (
    day_id, session_order, protocol_id, package_slot_key, completion_expectation
  ) VALUES (
    'be9be9be-be9b-49be-89be-be9be9be9be9', 1, 'PROT-GATE-BE-INC-R1', 'BE-INC', 'required'
  );
  UPDATE programme_versions
  SET lifecycle_status = 'published', published_at = NOW()
  WHERE id = v_incomplete AND lifecycle_status = 'draft';

  PERFORM sprint12_record(
    'BE', 'incomplete_not_executable', 'false',
    public.cohort_private_version_graphs_are_executable(v_incomplete)::text,
    NULL, NOT public.cohort_private_version_graphs_are_executable(v_incomplete), NULL
  );

  v_payload := sprint12_build_package(
    'PROG-GATE-BE-INC', 1, v_hash_inc, 'PROT-GATE-BE-INC-R1',
    'be7be7be-be7b-47be-87be-be7be7be7be7'
  ) || jsonb_build_object(
    'publication_kind', 'private_exact_version',
    'programme_version_id', v_incomplete,
    'library_scope', 'coach_private',
    'owner_id', v_owner
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_incomplete_private_programme_graph(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BE', 'repair_incomplete', 'repaired', v_res->>'status',
    NULL,
    (v_res->>'status') = 'repaired' AND COALESCE((v_res->>'inserted_blocks')::INT, 0) >= 1,
    v_res::text
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_incomplete_private_programme_graph(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BE', 'repair_idempotent', 'repaired', v_res->>'status',
    NULL,
    (v_res->>'status') = 'repaired' AND COALESCE((v_res->>'existing_blocks')::INT, 0) >= 1,
    v_res::text
  );

  v_payload := jsonb_set(
    v_payload,
    '{protocol_graphs,0,blocks,0,title}',
    '"Conflicting title"'
  );
  PERFORM set_config('role', 'service_role', true);
  v_res := public.repair_incomplete_private_programme_graph(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BE', 'repair_conflict', 'protocol_graph_conflict', v_res->>'code',
    NULL, (v_res->>'code') = 'protocol_graph_conflict', v_res::text
  );

  SELECT has_function_privilege('anon', 'public.repair_incomplete_private_programme_graph(jsonb)', 'EXECUTE')
    OR has_function_privilege('authenticated', 'public.repair_incomplete_private_programme_graph(jsonb)', 'EXECUTE')
  INTO v_count;
  PERFORM sprint12_record(
    'BE', 'repair_not_client_executable', 'false', v_count::text, NULL, v_count = 0, NULL
  );
END $$;

SELECT sprint12_assert_gate('BE');
