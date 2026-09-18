-- Gate AX — M9 content-graph persistence, pinning, used-by, RLS.
-- Generic fixtures only. Does not load Lee or hosted Apollo assignment rows.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-AX-R1';
  v_lineage UUID := 'd0000001-0000-4000-8000-0000000000a1';
  v_v1 UUID;
  v_v2 UUID;
  v_hash TEXT;
  v_supp TEXT;
  v_graph TEXT;
  v_composite TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_block UUID;
  v_assign_a UUID := 'd0000001-0000-4000-8000-0000000000aa';
  v_assign_b UUID := 'd0000001-0000-4000-8000-0000000000ab';
  v_athlete_a UUID := 'd0000001-0000-4000-8000-0000000000a2';
  v_athlete_b UUID := 'd0000001-0000-4000-8000-0000000000a3';
  v_athlete_c UUID := 'd0000001-0000-4000-8000-0000000000a4';
  v_coach UUID := 'd0000001-0000-4000-8000-0000000000c1';
  v_owner UUID := 'd0000001-0000-4000-8000-0000000000c0';
  v_unrelated_coach UUID := 'd0000001-0000-4000-8000-0000000000c3';
  v_other_pub UUID := 'd0000001-0000-4000-8000-0000000000c2';
  v_private_version UUID;
  v_count INT;
  v_pin UUID;
  v_hash_before TEXT;
  v_hash_after TEXT;
  v_assign_before INT;
  v_job JSONB;
  v_caps JSONB;
BEGIN
  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate AX Session');

  INSERT INTO public.session_blocks (
    block_id, session_id, block_type, title, content, workout_format, position
  ) VALUES (
    'd0000001-0000-4000-8000-0000000000b1', v_protocol, 'strength', 'Main', '', 'none', 99
  )
  ON CONFLICT (block_id) DO NOTHING;
  v_block := 'd0000001-0000-4000-8000-0000000000b1';

  INSERT INTO public.session_block_exercises (block_id, exercise_id, position)
  VALUES (v_block, 'EX-136', 1)
  ON CONFLICT (block_id, position) DO NOTHING;

  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
      'gate-ax-athlete-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
      'gate-ax-athlete-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coach, 'authenticated', 'authenticated',
      'gate-ax-coach@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
      'gate-ax-owner@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_unrelated_coach, 'authenticated', 'authenticated',
      'gate-ax-unrelated-coach@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_c, 'authenticated', 'authenticated',
      'gate-ax-athlete-c@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, display_name, is_athlete, is_coach) VALUES
    (v_athlete_a, 'Gate AX athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate AX athlete B', TRUE, FALSE),
    (v_athlete_c, 'Gate AX athlete C', TRUE, FALSE),
    (v_coach, 'Gate AX coach', FALSE, TRUE),
    (v_owner, 'Gate AX owner', FALSE, TRUE),
    (v_unrelated_coach, 'Gate AX unrelated coach', FALSE, TRUE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('role', 'postgres', true);

  SELECT COUNT(*) INTO v_count FROM public.content_publishers;
  PERFORM sprint12_assert_eq('AX', 'schema_only_zero_publishers', '0', v_count::TEXT, NULL);
  SELECT COUNT(*) INTO v_count FROM public.content_publisher_principals;
  PERFORM sprint12_assert_eq('AX', 'schema_only_zero_principals', '0', v_count::TEXT, NULL);
  SELECT COUNT(*) INTO v_count FROM public.content_graph_manifests;
  PERFORM sprint12_assert_eq('AX', 'schema_only_zero_manifests', '0', v_count::TEXT, NULL);
  SELECT COUNT(*) INTO v_count FROM public.content_graph_reconstruction_jobs;
  PERFORM sprint12_assert_eq('AX', 'schema_only_zero_recon', '0', v_count::TEXT, NULL);

  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::TEXT, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_caps := public.cohort_athlete_runtime_capabilities();
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', '', true);
  PERFORM sprint12_assert_eq('AX', 'schema_only_caps_version', '2', v_caps->>'schema_version', v_caps::TEXT);
  PERFORM sprint12_assert_eq('AX', 'schema_only_caps_read', 'true', v_caps->>'content_graph_read', NULL);
  PERFORM sprint12_assert_eq('AX', 'schema_only_caps_publish', 'false', v_caps->>'content_graph_publish', NULL);
  PERFORM sprint12_assert_eq('AX', 'schema_only_caps_impact', 'false', v_caps->>'content_graph_impact', NULL);

  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', 'd0000001-0000-4000-8000-0000000000a1',
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', sprint12_hash('pre-bootstrap'),
    'supplemental_relationship_hash', sprint12_hash('pre-bootstrap-s'),
    'graph_structural_hash', sprint12_hash('pre-bootstrap-g'),
    'composite_identity', public.content_graph_composite_identity(
      'content-graph-compiler/v1', 1,
      sprint12_hash('pre-bootstrap'), sprint12_hash('pre-bootstrap-s')
    ),
    'canonical_payload', '{}'::jsonb
  ));
  PERFORM sprint12_assert_eq('AX', 'publish_before_bootstrap', 'unauthorised', v_res->>'status', v_res::TEXT);
  PERFORM sprint12_assert_eq('AX', 'publish_before_bootstrap_code', 'missing_publisher', v_res->>'code', NULL);

  SELECT COUNT(*) INTO v_assign_before FROM public.programme_assignments;

  v_res := public.content_graph_bootstrap_cohort_global(NULL);
  PERFORM sprint12_assert_eq('AX', 'bootstrap_missing_principal', 'unauthorised', v_res->>'status', NULL);

  v_res := public.content_graph_bootstrap_cohort_global(v_owner);
  PERFORM sprint12_assert_eq('AX', 'bootstrap_created', 'created', v_res->>'status', v_res::TEXT);

  v_res := public.content_graph_bootstrap_cohort_global(v_owner);
  PERFORM sprint12_assert_eq('AX', 'bootstrap_retry', 'already_exists', v_res->>'status', NULL);
  SELECT COUNT(*) INTO v_count FROM public.content_graph_manifests;
  PERFORM sprint12_assert_eq('AX', 'bootstrap_zero_manifests', '0', v_count::TEXT, NULL);
  SELECT COUNT(*) INTO v_count FROM public.content_graph_reconstruction_jobs;
  PERFORM sprint12_assert_eq('AX', 'bootstrap_zero_recon', '0', v_count::TEXT, NULL);
  SELECT COUNT(*) INTO v_count FROM public.programme_assignments;
  PERFORM sprint12_assert_eq('AX', 'bootstrap_no_assignments', v_assign_before::TEXT, v_count::TEXT, NULL);

  v_res := public.content_graph_bootstrap_cohort_global(
    v_owner, 'owner', 'd0000001-0000-4000-8000-0000000000c9'
  );
  PERFORM sprint12_assert_eq('AX', 'bootstrap_conflict', 'conflict', v_res->>'status', NULL);

  v_hash := sprint12_hash('gate-ax-v1-package');
  v_payload := sprint12_build_package('PROG-GATE-AX', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_v1 := (v_res->>'programme_version_id')::uuid;
  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_v1, 'gate-ax');
  PERFORM public.approve_cohort_global_programme_version(v_v1, 'gate-ax');
  PERFORM set_config('role', 'postgres', true);

  SELECT package_content_hash INTO v_hash FROM public.programme_versions WHERE id = v_v1;
  v_supp := sprint12_hash('gate-ax-v1-supplemental');
  v_graph := sprint12_hash('gate-ax-v1-graph');
  v_composite := public.content_graph_composite_identity(
    'content-graph-compiler/v1', 1, v_hash, v_supp
  );

  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_v1,
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', v_supp,
    'graph_structural_hash', v_graph,
    'composite_identity', v_composite,
    'canonical_payload', jsonb_build_object(
      'resolved_exercise_ids', jsonb_build_array('EX-136'),
      'edges', jsonb_build_array(
        jsonb_build_object(
          'type', 'exerciseUsedByBlock',
          'from_type', 'exercise',
          'from_id', 'EX-136',
          'to_type', 'authoredBlock',
          'to_id', v_block::TEXT
        )
      )
    ),
    'unresolved', '[]'::jsonb
  ));
  PERFORM sprint12_assert_eq('AX', 'publish_v1', 'published', v_res->>'status', v_res::TEXT);
  v_hash_before := v_graph;

  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_v1,
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', v_supp,
    'graph_structural_hash', v_graph,
    'composite_identity', v_composite,
    'canonical_payload', jsonb_build_object('resolved_exercise_ids', jsonb_build_array('EX-136')),
    'unresolved', '[]'::jsonb
  ));
  PERFORM sprint12_assert_eq('AX', 'publish_retry', 'already_published', v_res->>'status', NULL);

  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_v1,
    'compiler_version', 'content-graph-compiler/v9',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', v_supp,
    'graph_structural_hash', v_graph,
    'composite_identity', public.content_graph_composite_identity(
      'content-graph-compiler/v9', 1, v_hash, v_supp
    ),
    'canonical_payload', '{}'::jsonb
  ));
  PERFORM sprint12_assert_eq('AX', 'unsupported_format', 'unsupported_format', v_res->>'status', NULL);

  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_v1,
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', sprint12_hash('other-supp'),
    'graph_structural_hash', v_graph,
    'composite_identity', v_composite,
    'canonical_payload', '{}'::jsonb
  ));
  PERFORM sprint12_assert_eq('AX', 'source_supp_mismatch', 'hash_mismatch', v_res->>'status', NULL);

  BEGIN
    UPDATE public.content_graph_manifests SET graph_structural_hash = repeat('a', 64);
    PERFORM sprint12_record('AX','immutable_published','fail','updated',NULL,FALSE,'mutation allowed');
  EXCEPTION WHEN OTHERS THEN
    PERFORM sprint12_assert_eq('AX','immutable_published','content_graph_published_immutable','content_graph_published_immutable', NULL);
  END;

  INSERT INTO public.programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    current_week_number, current_day_key, current_slot_order, enrolment_source
  ) VALUES (
    v_assign_a, v_athlete_a, v_v1, 'PROG-GATE-AX', 'active', CURRENT_DATE,
    1, 'day_1', 1, 'non_commercial_test'
  );

  SELECT graph_structural_hash INTO v_hash_before
  FROM public.content_graph_manifests WHERE programme_version_id = v_v1;

  v_hash := sprint12_hash('gate-ax-v2-package');
  v_payload := sprint12_build_package('PROG-GATE-AX', 2, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_v2 := (v_res->>'programme_version_id')::uuid;
  UPDATE public.programme_versions
    SET supersedes_version_id = v_v1
    WHERE id = v_v2;
  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_v2, 'gate-ax');
  PERFORM public.replace_approved_cohort_global_programme_version(v_v1, v_v2, 'gate-ax');
  PERFORM set_config('role', 'postgres', true);

  v_supp := sprint12_hash('gate-ax-v2-supplemental');
  v_graph := sprint12_hash('gate-ax-v2-graph');
  SELECT package_content_hash INTO v_hash FROM public.programme_versions WHERE id = v_v2;
  v_composite := public.content_graph_composite_identity(
    'content-graph-compiler/v1', 1, v_hash, v_supp
  );
  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_v2,
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', v_supp,
    'graph_structural_hash', v_graph,
    'composite_identity', v_composite,
    'canonical_payload', jsonb_build_object(
      'resolved_exercise_ids', jsonb_build_array('EX-136')
    ),
    'unresolved', jsonb_build_array('name-only-block')
  ));
  PERFORM sprint12_assert_eq('AX', 'publish_v2', 'published', v_res->>'status', v_res::TEXT);

  SELECT programme_version_id INTO v_pin
  FROM public.programme_assignments WHERE id = v_assign_a;
  PERFORM sprint12_assert_eq('AX', 'athlete_a_still_v1', v_v1::TEXT, v_pin::TEXT, NULL);

  INSERT INTO public.programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    current_week_number, current_day_key, current_slot_order, enrolment_source
  ) VALUES (
    v_assign_b, v_athlete_b, v_v2, 'PROG-GATE-AX', 'active', CURRENT_DATE,
    1, 'day_1', 1, 'non_commercial_test'
  );

  SELECT programme_version_id INTO v_pin
  FROM public.programme_assignments WHERE id = v_assign_b;
  PERFORM sprint12_assert_eq('AX', 'athlete_b_v2', v_v2::TEXT, v_pin::TEXT, NULL);

  BEGIN
    UPDATE public.programme_assignments
      SET programme_version_id = v_v2
      WHERE id = v_assign_a;
    PERFORM sprint12_record('AX','pin_immutable','fail','updated',NULL,FALSE,'repin allowed');
  EXCEPTION WHEN OTHERS THEN
    PERFORM sprint12_assert_eq('AX','pin_immutable','content_graph_assignment_pin_immutable','content_graph_assignment_pin_immutable', NULL);
  END;

  SELECT programme_version_id INTO v_pin
  FROM public.programme_assignments WHERE id = v_assign_a;
  PERFORM sprint12_assert_eq('AX', 'pin_unchanged_after_reject', v_v1::TEXT, v_pin::TEXT, NULL);

  SELECT COUNT(*) INTO v_count
  FROM public.content_exercise_used_by_programme
  WHERE exercise_id = 'EX-136' AND programme_version_id IN (v_v1, v_v2);
  PERFORM sprint12_record(
    'AX', 'used_by_indexed', 'gt0', v_count::TEXT, TRUE, v_count > 0, NULL
  );

  SELECT graph_structural_hash INTO v_hash_after
  FROM public.content_graph_manifests WHERE programme_version_id = v_v1;
  PERFORM sprint12_assert_eq(
    'AX', 'hash_independent_of_assignments', v_hash_before, v_hash_after, NULL
  );

  v_res := public.content_graph_assignment_impact(v_v1);
  PERFORM sprint12_assert_eq('AX', 'impact_service', 'ok', v_res->>'status', NULL);
  PERFORM sprint12_assert_eq('AX', 'impact_active_v1', '1', v_res->>'active_count', NULL);

  v_res := public.content_graph_version_diff(v_v1, v_v2);
  PERFORM sprint12_assert_eq('AX', 'diff_ok', 'ok', v_res->>'status', NULL);

  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_v1,
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', v_supp,
    'graph_structural_hash', v_graph,
    'composite_identity', v_composite,
    'canonical_payload', jsonb_build_object(
      'resolved_exercise_ids', jsonb_build_array('Back Squat')
    )
  ));
  PERFORM sprint12_record(
    'AX', 'name_match_rejected', 'not_published', v_res->>'status', TRUE,
    v_res->>'status' <> 'published', v_res::TEXT
  );

  INSERT INTO public.content_publishers (id, namespace, display_name, first_party, lifecycle)
  VALUES (v_other_pub, 'coach_acme_ax', 'Acme AX', FALSE, 'active')
  ON CONFLICT (namespace) DO NOTHING;
  INSERT INTO public.content_publisher_principals (publisher_id, principal_id, principal_role)
  VALUES (v_other_pub, v_coach, 'publisher')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.programme_lineages (id, code, created_by)
  VALUES (
    'd0000001-0000-4000-8000-0000000000d1',
    'PROG-GATE-AX-PRIVATE',
    v_coach::TEXT
  )
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.programme_versions (
    id, lineage_id, version_number, lifecycle_status, library_scope, owner_type,
    owner_id, name, approved_for_global, approved_for_adaptation, published_at,
    package_schema_version, package_content_hash
  ) VALUES (
    'd0000001-0000-4000-8000-0000000000e1',
    'd0000001-0000-4000-8000-0000000000d1',
    1, 'published', 'coach_private', 'coach', v_coach::TEXT,
    'Gate AX private', FALSE, FALSE, NOW(), 1, sprint12_hash('gate-ax-private')
  )
  ON CONFLICT (id) DO NOTHING;
  v_private_version := 'd0000001-0000-4000-8000-0000000000e1';
  v_hash := sprint12_hash('gate-ax-private');
  v_supp := sprint12_hash('gate-ax-private-s');
  v_graph := sprint12_hash('gate-ax-private-g');
  v_composite := public.content_graph_composite_identity(
    'content-graph-compiler/v1', 1, v_hash, v_supp
  );
  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_private_version,
    'publisher_id', v_other_pub,
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', v_supp,
    'graph_structural_hash', v_graph,
    'composite_identity', v_composite,
    'canonical_payload', '{}'::jsonb
  ));
  PERFORM sprint12_assert_eq('AX', 'publish_private', 'published', v_res->>'status', v_res::TEXT);

  v_job := public.content_graph_record_reconstruction(jsonb_build_object(
    'job_key', 'gate-ax-local',
    'source_fingerprint', sprint12_hash('gate-ax-source'),
    'dry_run', TRUE,
    'classified_resolvable', 1,
    'classified_supplemental', 1,
    'classified_unresolved', 1,
    'classified_invalid', 0,
    'rows_written', 0
  ));
  PERFORM sprint12_assert_eq('AX', 'recon_dry', 'dry_run', v_job->>'status', NULL);

  v_job := public.content_graph_record_reconstruction(jsonb_build_object(
    'job_key', 'gate-ax-local',
    'source_fingerprint', sprint12_hash('gate-ax-source'),
    'dry_run', FALSE,
    'classified_resolvable', 1,
    'classified_supplemental', 1,
    'classified_unresolved', 1,
    'classified_invalid', 0,
    'rows_written', 1
  ));
  PERFORM sprint12_assert_eq('AX', 'recon_apply', 'applied', v_job->>'status', NULL);

  v_job := public.content_graph_record_reconstruction(jsonb_build_object(
    'job_key', 'gate-ax-local',
    'source_fingerprint', sprint12_hash('gate-ax-source'),
    'dry_run', FALSE,
    'rows_written', 0
  ));
  PERFORM sprint12_record(
    'AX', 'recon_second_pass', 'noop_or_applied', v_job->>'status', TRUE,
    v_job->>'second_pass_noop' = 'true' OR v_job->>'status' IN ('applied', 'noop'),
    v_job::TEXT
  );

  v_job := public.content_graph_record_reconstruction(jsonb_build_object(
    'job_key', 'gate-ax-local',
    'source_fingerprint', sprint12_hash('gate-ax-source-changed'),
    'dry_run', FALSE,
    'rows_written', 0
  ));
  PERFORM sprint12_assert_eq('AX', 'recon_resume_reject', 'rejected', v_job->>'status', NULL);

  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', '', true);
  v_caps := public.cohort_athlete_runtime_capabilities();
  PERFORM sprint12_assert_eq(
    'AX', 'caps_unauth_shape', 'authorization_failure', v_caps->>'status', NULL
  );
  PERFORM sprint12_assert_eq(
    'AX', 'caps_graph_keys', 'false', v_caps->>'content_graph_read', NULL
  );
END $$;

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000a2', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_res JSONB;
BEGIN
  SELECT count(*) INTO v_count FROM public.content_graph_manifests;
  IF v_count < 1 THEN
    RAISE EXCEPTION 'AX athlete cannot read assigned published manifest';
  END IF;
  BEGIN
    INSERT INTO public.content_graph_manifests (
      programme_version_id, compiler_version, graph_format_version,
      source_package_hash, supplemental_relationship_hash, graph_structural_hash,
      composite_identity, canonical_payload, publication_state, published_at
    ) VALUES (
      'd0000001-0000-4000-8000-0000000000a1',
      'content-graph-compiler/v1', 1,
      repeat('1', 64), repeat('2', 64), repeat('3', 64), repeat('4', 64),
      '{}'::jsonb, 'published', NOW()
    );
    RAISE EXCEPTION 'AX athlete write should fail';
  EXCEPTION
    WHEN insufficient_privilege OR check_violation OR not_null_violation
      OR foreign_key_violation OR unique_violation THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%AX athlete write should fail%' THEN
        RAISE;
      END IF;
  END;
  v_res := public.content_graph_assignment_impact(
    (SELECT programme_version_id FROM public.programme_assignments
     WHERE id = 'd0000001-0000-4000-8000-0000000000aa')
  );
  IF v_res->>'status' IS DISTINCT FROM 'unauthorised' THEN
    RAISE EXCEPTION 'AX athlete impact leaked: %', v_res;
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','athlete_read_assigned','ok','ok',TRUE,TRUE,NULL);
SELECT sprint12_record('AX','athlete_write_denied','ok','ok',TRUE,TRUE,NULL);
SELECT sprint12_record('AX','athlete_impact_denied','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000c1', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_res JSONB;
  v_v1 UUID;
  v_hash TEXT;
BEGIN
  SELECT v.id INTO v_v1
  FROM public.programme_versions v
  JOIN public.programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'PROG-GATE-AX' AND v.version_number = 1;
  SELECT package_content_hash INTO v_hash FROM public.programme_versions WHERE id = v_v1;
  v_res := public.publish_content_graph_manifest(jsonb_build_object(
    'programme_version_id', v_v1,
    'publisher_id', 'd0000001-0000-4000-8000-0000000000c2',
    'compiler_version', 'content-graph-compiler/v1',
    'graph_format_version', 1,
    'source_package_hash', v_hash,
    'supplemental_relationship_hash', sprint12_hash('stolen'),
    'graph_structural_hash', sprint12_hash('stolen-g'),
    'composite_identity', public.content_graph_composite_identity(
      'content-graph-compiler/v1', 1, v_hash, sprint12_hash('stolen')
    ),
    'canonical_payload', '{}'::jsonb
  ));
  IF v_res->>'status' NOT IN (
    'conflicting_identity',
    'unauthorised',
    'hash_mismatch',
    'unsupported_format'
  ) THEN
    RAISE EXCEPTION 'AX cross-namespace unexpected %', v_res;
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','cross_namespace_blocked','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE anon;
DO $$
DECLARE
  v_res JSONB;
BEGIN
  BEGIN
    v_res := public.publish_content_graph_manifest('{}'::jsonb);
    RAISE EXCEPTION 'AX anon publish executed: %', v_res;
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%AX anon publish executed%' THEN
        RAISE;
      END IF;
  END;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','anon_denied','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000a3', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_v1 UUID;
  v_res JSONB;
BEGIN
  SELECT v.id INTO v_v1
  FROM public.programme_versions v
  JOIN public.programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'PROG-GATE-AX' AND v.version_number = 1;
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_v1;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AX athlete B read unrelated archived manifest';
  END IF;
  SELECT count(*) INTO v_count FROM public.content_graph_unresolved_counts
  WHERE programme_version_id = v_v1;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AX unresolved_counts bypassed manifest RLS';
  END IF;
  v_res := public.content_graph_version_diff(
    v_v1, 'd0000001-0000-4000-8000-0000000000e1'
  );
  IF v_res->>'status' NOT IN ('unauthorised', 'unresolved_reference') THEN
    RAISE EXCEPTION 'AX athlete diff leaked: %', v_res;
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','athlete_unrelated_denied','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000c3', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_private UUID := 'd0000001-0000-4000-8000-0000000000e1';
BEGIN
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_private;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AX unrelated coach read private graph';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','unrelated_coach_denied','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000c1', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_res JSONB;
  v_private UUID := 'd0000001-0000-4000-8000-0000000000e1';
BEGIN
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_private;
  IF v_count < 1 THEN
    RAISE EXCEPTION 'AX owning coach cannot read own private graph';
  END IF;
  v_res := public.content_graph_assignment_impact(v_private);
  IF v_res->>'status' IS DISTINCT FROM 'ok' THEN
    RAISE EXCEPTION 'AX owning publisher impact denied: %', v_res;
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','owning_coach_private_ok','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000c0', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_res JSONB;
  v_caps JSONB;
  v_private UUID := 'd0000001-0000-4000-8000-0000000000e1';
BEGIN
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_private;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AX first-party owner read other namespace private graph';
  END IF;
  v_res := public.content_graph_assignment_impact(v_private);
  IF v_res->>'status' IS DISTINCT FROM 'unauthorised' THEN
    RAISE EXCEPTION 'AX first-party owner impact on other namespace: %', v_res;
  END IF;
  v_caps := public.cohort_athlete_runtime_capabilities();
  IF v_caps->>'status' IS DISTINCT FROM 'authorization_failure' THEN
    NULL; -- owner is coach, not athlete
  END IF;
  IF COALESCE(v_caps->>'content_graph_publish', 'false') = 'true'
     AND v_caps->>'status' = 'ok' THEN
    RAISE EXCEPTION 'AX non-athlete should not get athlete ok publish';
  END IF;
  BEGIN
    INSERT INTO public.content_publisher_principals (
      publisher_id, principal_id, principal_role
    ) VALUES (
      'd0000001-0000-4000-8000-0000000000c2',
      'd0000001-0000-4000-8000-0000000000c0',
      'publisher'
    );
    RAISE EXCEPTION 'AX forged principal insert succeeded';
  EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%AX forged principal insert succeeded%' THEN
        RAISE;
      END IF;
  END;
  BEGIN
    v_res := public.content_graph_bootstrap_cohort_global(
      'd0000001-0000-4000-8000-0000000000c0'::uuid
    );
    IF v_res->>'status' IS DISTINCT FROM 'unauthorised' THEN
      RAISE EXCEPTION 'AX authenticated bootstrap leaked: %', v_res;
    END IF;
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','cross_namespace_read_denied','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000a2', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_caps JSONB;
  v_count INT;
BEGIN
  v_caps := public.cohort_athlete_runtime_capabilities();
  IF v_caps->>'content_graph_read' IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'AX athlete schema read capability missing: %', v_caps;
  END IF;
  IF v_caps->>'content_graph_publish' IS DISTINCT FROM 'false' THEN
    RAISE EXCEPTION 'AX athlete publish capability leaked: %', v_caps;
  END IF;
  IF v_caps->>'schema_version' IS DISTINCT FROM '2' THEN
    RAISE EXCEPTION 'AX schema_version not 2: %', v_caps;
  END IF;
  SELECT count(*) INTO v_count FROM public.content_graph_manifests;
  IF v_count < 1 THEN
    RAISE EXCEPTION 'AX assigned athlete lost catalogue/assigned read';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','athlete_caps_schema_only_keys','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000a4', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_v2 UUID;
  v_private UUID := 'd0000001-0000-4000-8000-0000000000e1';
BEGIN
  SELECT v.id INTO v_v2
  FROM public.programme_versions v
  JOIN public.programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'PROG-GATE-AX' AND v.version_number = 2;
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_v2;
  IF v_count < 1 THEN
    RAISE EXCEPTION 'AX catalogue athlete cannot read eligible published graph';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_private;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AX catalogue athlete read unpublished private graph';
  END IF;
  SELECT count(*) INTO v_count
  FROM public.content_exercise_used_by_programme
  WHERE programme_version_id = v_private;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AX used-by view bypassed private graph';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','athlete_catalogue_visible','ok','ok',TRUE,TRUE,NULL);

BEGIN;
SET LOCAL ROLE anon;
DO $$
DECLARE
  v_count INT;
BEGIN
  BEGIN
    SELECT count(*) INTO v_count FROM public.content_graph_manifests;
    IF v_count <> 0 THEN
      RAISE EXCEPTION 'AX anon selected graph rows';
    END IF;
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%AX anon selected graph rows%' THEN
        RAISE;
      END IF;
  END;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','anon_select_denied','ok','ok',TRUE,TRUE,NULL);

BEGIN;
INSERT INTO public.content_publisher_principals (
  publisher_id, principal_id, principal_role
) VALUES (
  'd0000001-0000-4000-8000-0000000000c2',
  'd0000001-0000-4000-8000-0000000000c3',
  'reader'
)
ON CONFLICT DO NOTHING;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000c3', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_private UUID := 'd0000001-0000-4000-8000-0000000000e1';
BEGIN
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_private;
  IF v_count < 1 THEN
    RAISE EXCEPTION 'AX active reader principal cannot read namespace graph';
  END IF;
END $$;
RESET ROLE;
UPDATE public.content_publishers
  SET lifecycle = 'retired', retired_at = NOW()
  WHERE id = 'd0000001-0000-4000-8000-0000000000c2';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'd0000001-0000-4000-8000-0000000000c3', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
DO $$
DECLARE
  v_count INT;
  v_res JSONB;
  v_private UUID := 'd0000001-0000-4000-8000-0000000000e1';
BEGIN
  SELECT count(*) INTO v_count
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_private;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'AX inactive publisher still reads namespace graph';
  END IF;
  v_res := public.content_graph_assignment_impact(v_private);
  IF v_res->>'status' IS DISTINCT FROM 'unauthorised' THEN
    RAISE EXCEPTION 'AX inactive publisher impact leaked: %', v_res;
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AX','inactive_publisher_denied','ok','ok',TRUE,TRUE,NULL);

SELECT sprint12_fail_if_any_failed();
