-- Gate BD — assigned athletes can read the pinned private graph when
-- lineage.created_by is the operational importer, not the owner.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-BD-R1';
  v_lineage UUID := 'd1d1d1d1-d1d1-41d1-81d1-d1d1d1d1d1d1';
  v_hash TEXT := sprint12_hash('gate-bd-graph');
  v_owner UUID := 'd2d2d2d2-d2d2-42d2-82d2-d2d2d2d2d2d2';
  v_other UUID := 'd3d3d3d3-d3d3-43d3-83d3-d3d3d3d3d3d3';
  v_version UUID := 'd5d5d5d5-d5d5-45d5-85d5-d5d5d5d5d5d5';
  v_payload JSONB;
  v_res JSONB;
  v_days INT;
  v_cursor TEXT;
  v_has_exec BOOLEAN;
BEGIN
  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate BD session');

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
     'gate-bd-owner@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_other, 'authenticated', 'authenticated',
     'gate-bd-other@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_owner, 'Gate BD Owner', TRUE, TRUE),
    (v_other, 'Gate BD Other', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  v_payload := sprint12_build_package(
      'PROG-GATE-BD', 1, v_hash, v_protocol, v_lineage, 1, 'private-exact-publisher'
    )
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
    'BD', 'publish', 'published', v_res->>'status',
    NULL, (v_res->>'status') IN ('published', 'already_published'), v_res::text
  );

  PERFORM sprint12_record(
    'BD', 'lineage_publisher', 'private-exact-publisher',
    (SELECT l.created_by FROM programme_lineages l
      JOIN programme_versions v ON v.lineage_id = l.id
      WHERE v.id = v_version),
    NULL,
    EXISTS (
      SELECT 1 FROM programme_lineages l
      JOIN programme_versions v ON v.lineage_id = l.id
      WHERE v.id = v_version AND l.created_by = 'private-exact-publisher'
    ),
    NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(
    v_version, 'Asia/Makassar', DATE '2026-09-26', TRUE
  );
  SELECT current_day_key INTO v_cursor
  FROM programme_assignments
  WHERE athlete_id = v_owner AND status = 'active';
  SELECT count(*) INTO v_days
  FROM programme_version_days d
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_version;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BD', 'owner_days_after_enrol', '>=1', v_days::text,
    NULL, v_days >= 1, v_res::text
  );
  PERFORM sprint12_record(
    'BD', 'cursor_unchanged', 'day_1', v_cursor,
    NULL, v_cursor = 'day_1', NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_days
  FROM programme_version_days d
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_version;
  v_has_exec := public.cohort_can_read_assigned_programme_version(v_version);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BD', 'unrelated_days', '0', v_days::text, NULL, v_days = 0, NULL
  );
  PERFORM sprint12_record(
    'BD', 'unrelated_helper', 'false', v_has_exec::text, NULL, NOT v_has_exec, NULL
  );

  PERFORM sprint12_record(
    'BD', 'no_cursor_mutation_fn', 'absent',
    CASE WHEN to_regprocedure('public.repair_assignment_cursor(uuid)') IS NULL
      THEN 'absent' ELSE 'present' END,
    NULL,
    to_regprocedure('public.repair_assignment_cursor(uuid)') IS NULL,
    NULL
  );
END $$;

SELECT sprint12_fail_if_any_failed();
