-- Disposable local-only publication of committed graph artifacts.
-- Never run against hosted Field Manual.
\set ON_ERROR_STOP on

CREATE TEMP TABLE m9_pub_results (
  step TEXT PRIMARY KEY,
  status TEXT,
  code TEXT,
  extra TEXT
);

DO $$
DECLARE
  v_owner UUID := '79853f15-eac4-42eb-acfd-384bf2a87976';
  v_apollo UUID := '2ba018bd-7dc2-4dfd-8d8e-e35823158920';
  v_spartan UUID := '32986922-47d1-46b0-b391-a7931d73033e';
  v_lineage_a UUID := 'aaaaaaaa-0000-4000-8000-0000000000a1';
  v_lineage_s UUID := 'aaaaaaaa-0000-4000-8000-0000000000a2';
  v_boot JSONB;
  v_res JSONB;
  v_apollo_payload JSONB;
  v_spartan_payload JSONB;
  v_jobs_before BIGINT;
  v_jobs_after BIGINT;
  v_manifests_after_apollo BIGINT;
  v_catalogue_before BIGINT;
  v_catalogue_after BIGINT;
  v_pins_before BIGINT;
  v_pins_after BIGINT;
  v_defaults_before BIGINT;
  v_defaults_after BIGINT;
BEGIN
  PERFORM set_config('role', 'postgres', true);

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_owner) THEN
    INSERT INTO auth.users (
      instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
      created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
      confirmation_token,recovery_token,email_change_token_new,email_change
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
      'm9-art-owner@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
      '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''
    );
  END IF;

  v_boot := public.content_graph_bootstrap_cohort_global(v_owner);
  IF v_boot->>'status' NOT IN ('created', 'already_exists') THEN
    RAISE EXCEPTION 'bootstrap failed %', v_boot;
  END IF;

  INSERT INTO public.programme_lineages (id, code, created_by)
  VALUES
    (v_lineage_a, 'M9-ART-APOLLO', 'm9-art'),
    (v_lineage_s, 'M9-ART-SPARTAN', 'm9-art')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.programme_versions (
    id, lineage_id, version_number, lifecycle_status, library_scope, owner_type,
    name, package_schema_version, package_content_hash, approved_for_global, published_at
  ) VALUES (
    v_apollo, v_lineage_a, 2, 'published', 'cohort_global', 'global',
    'M9 Art Apollo', 1,
    '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
    TRUE, NOW()
  )
  ON CONFLICT (id) DO UPDATE
    SET package_content_hash = EXCLUDED.package_content_hash,
        lifecycle_status = 'published';

  INSERT INTO public.programme_versions (
    id, lineage_id, version_number, lifecycle_status, library_scope, owner_type,
    name, package_schema_version, package_content_hash, approved_for_global, published_at
  ) VALUES (
    v_spartan, v_lineage_s, 3, 'published', 'cohort_global', 'global',
    'M9 Art Spartan', 1,
    'b4bfaab4f6cd25417d52b6f0b2604d9f98b3e10b074c3d58896acde3db05473e',
    TRUE, NOW()
  )
  ON CONFLICT (id) DO UPDATE
    SET package_content_hash = EXCLUDED.package_content_hash,
        lifecycle_status = 'published';

  SELECT payload INTO v_apollo_payload FROM m9_art_payloads WHERE name = 'apollo';
  SELECT payload INTO v_spartan_payload FROM m9_art_payloads WHERE name = 'spartan';

  SELECT COUNT(*) INTO v_jobs_before FROM public.content_graph_reconstruction_jobs;
  SELECT COUNT(*) INTO v_catalogue_before FROM public.exercises_v2;
  SELECT COUNT(*) INTO v_pins_before FROM public.programme_assignments;
  SELECT COUNT(*) INTO v_defaults_before
  FROM public.programme_versions
  WHERE approved_for_global IS TRUE;

  v_res := public.publish_content_graph_manifest(v_spartan_payload);
  INSERT INTO m9_pub_results VALUES (
    'spartan_first', v_res->>'status', v_res->>'code', NULL
  );
  INSERT INTO m9_pub_results VALUES (
    'independence_after_spartan',
    CASE
      WHEN (SELECT COUNT(*) FROM public.content_graph_manifests) = 1
        AND NOT EXISTS (
          SELECT 1 FROM public.content_graph_manifests
          WHERE programme_version_id = v_apollo
        )
      THEN 'independent'
      ELSE 'failed'
    END,
    NULL,
    (SELECT COUNT(*)::text FROM public.content_graph_manifests)
  );
  v_res := public.publish_content_graph_manifest(v_spartan_payload);
  INSERT INTO m9_pub_results VALUES (
    'spartan_retry', v_res->>'status', v_res->>'code', NULL
  );
  v_res := public.publish_content_graph_manifest(
    v_spartan_payload || jsonb_build_object(
      'graph_structural_hash', repeat('ef', 32)
    )
  );
  INSERT INTO m9_pub_results VALUES (
    'spartan_mismatch', v_res->>'status', v_res->>'code', NULL
  );

  v_res := public.publish_content_graph_manifest(
    v_apollo_payload || jsonb_build_object('require_full_resolution', true)
  );
  INSERT INTO m9_pub_results VALUES (
    'apollo_require_full_first', v_res->>'status', v_res->>'code', NULL
  );

  v_res := public.publish_content_graph_manifest(v_apollo_payload);
  INSERT INTO m9_pub_results VALUES (
    'apollo_first', v_res->>'status', v_res->>'code', NULL
  );

  SELECT COUNT(*) INTO v_manifests_after_apollo FROM public.content_graph_manifests;
  INSERT INTO m9_pub_results VALUES (
    'independence_after_apollo',
    CASE
      WHEN v_manifests_after_apollo = 2
        AND EXISTS (
          SELECT 1 FROM public.content_graph_manifests
          WHERE programme_version_id = v_apollo
        )
        AND EXISTS (
          SELECT 1 FROM public.content_graph_manifests
          WHERE programme_version_id = v_spartan
        )
      THEN 'independent'
      ELSE 'failed'
    END,
    NULL,
    v_manifests_after_apollo::text
  );

  v_res := public.publish_content_graph_manifest(v_apollo_payload);
  INSERT INTO m9_pub_results VALUES (
    'apollo_retry', v_res->>'status', v_res->>'code', NULL
  );

  v_res := public.publish_content_graph_manifest(
    v_apollo_payload || jsonb_build_object(
      'graph_structural_hash', repeat('ab', 32),
      'composite_identity', public.content_graph_composite_identity(
        'content-graph-compiler/v1', 1,
        v_apollo_payload->>'source_package_hash',
        v_apollo_payload->>'supplemental_relationship_hash'
      )
    )
  );
  INSERT INTO m9_pub_results VALUES (
    'apollo_changed_graph', v_res->>'status', v_res->>'code', NULL
  );

  v_res := public.publish_content_graph_manifest(
    v_apollo_payload || jsonb_build_object(
      'source_package_hash', repeat('cd', 32),
      'composite_identity', public.content_graph_composite_identity(
        'content-graph-compiler/v1', 1,
        repeat('cd', 32),
        v_apollo_payload->>'supplemental_relationship_hash'
      )
    )
  );
  INSERT INTO m9_pub_results VALUES (
    'apollo_hash_mismatch', v_res->>'status', v_res->>'code', NULL
  );

  SELECT COUNT(*) INTO v_jobs_after FROM public.content_graph_reconstruction_jobs;
  SELECT COUNT(*) INTO v_catalogue_after FROM public.exercises_v2;
  SELECT COUNT(*) INTO v_pins_after FROM public.programme_assignments;
  SELECT COUNT(*) INTO v_defaults_after
  FROM public.programme_versions
  WHERE approved_for_global IS TRUE;

  INSERT INTO m9_pub_results VALUES (
    'reconstruction_jobs',
    CASE WHEN v_jobs_before = 0 AND v_jobs_after = 0 THEN 'none' ELSE 'created' END,
    NULL,
    v_jobs_after::text
  );
  INSERT INTO m9_pub_results VALUES (
    'catalogue_unchanged',
    CASE WHEN v_catalogue_before = v_catalogue_after THEN 'unchanged' ELSE 'changed' END,
    NULL,
    v_catalogue_after::text
  );
  INSERT INTO m9_pub_results VALUES (
    'pins_unchanged',
    CASE WHEN v_pins_before = v_pins_after THEN 'unchanged' ELSE 'changed' END,
    NULL,
    v_pins_after::text
  );
  INSERT INTO m9_pub_results VALUES (
    'defaults_unchanged',
    CASE WHEN v_defaults_before = v_defaults_after THEN 'unchanged' ELSE 'changed' END,
    NULL,
    v_defaults_after::text
  );
  INSERT INTO m9_pub_results VALUES (
    'manifest_count',
    (SELECT COUNT(*)::text FROM public.content_graph_manifests),
    NULL,
    NULL
  );
END $$;

SELECT step, status, code, extra
FROM m9_pub_results
ORDER BY step;
