-- M9 Sprint 2: typed publication transaction. Hash canonicalisation stays in-app.

CREATE OR REPLACE FUNCTION public.content_graph_is_service_role()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT
    current_setting('role', true) IN ('service_role', 'postgres')
    OR COALESCE(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    OR COALESCE(auth.role(), '') = 'service_role';
$$;

CREATE OR REPLACE FUNCTION public.content_graph_sha256_hex(p_text TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public, extensions, pg_temp
AS $$
  SELECT encode(digest(convert_to(p_text, 'UTF8'), 'sha256'), 'hex');
$$;

CREATE OR REPLACE FUNCTION public.content_graph_composite_identity(
  p_compiler_version TEXT,
  p_graph_format_version INTEGER,
  p_source_package_hash TEXT,
  p_supplemental_relationship_hash TEXT
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT public.content_graph_sha256_hex(
    '{"compiler_version":"' || p_compiler_version
    || '","graph_format_version":' || p_graph_format_version::TEXT
    || ',"source_package_hash":"' || p_source_package_hash
    || '","supplemental_relationship_hash":"' || p_supplemental_relationship_hash
    || '"}'
  );
$$;

CREATE OR REPLACE FUNCTION public.content_graph_publisher_may_operate(
  p_publisher_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF public.content_graph_is_service_role() THEN
    RETURN TRUE;
  END IF;
  IF v_uid IS NULL THEN
    RETURN FALSE;
  END IF;
  RETURN EXISTS (
    SELECT 1
    FROM public.content_publisher_principals m
    JOIN public.content_publishers p ON p.id = m.publisher_id
    WHERE m.publisher_id = p_publisher_id
      AND m.principal_id = v_uid
      AND m.principal_role IN ('owner', 'publisher')
      AND p.lifecycle = 'active'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_content_graph_manifest(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_version_id UUID;
  v_publisher_id UUID;
  v_compiler TEXT;
  v_format INTEGER;
  v_source TEXT;
  v_supp TEXT;
  v_graph TEXT;
  v_composite TEXT;
  v_expected TEXT;
  v_payload JSONB;
  v_unresolved JSONB;
  v_require_full BOOLEAN;
  v_version public.programme_versions%ROWTYPE;
  v_existing public.content_graph_manifests%ROWTYPE;
  v_same_identity public.content_graph_manifests%ROWTYPE;
  v_ex TEXT;
  v_edge JSONB;
  v_from TEXT;
  v_to TEXT;
  v_type TEXT;
  v_from_type TEXT;
  v_block_session TEXT;
  v_cycle BOOLEAN;
  v_id UUID;
BEGIN
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
    RETURN jsonb_build_object('status', 'unsupported_format', 'code', 'invalid_payload');
  END IF;

  v_version_id := NULLIF(p_payload->>'programme_version_id', '')::UUID;
  v_publisher_id := NULLIF(p_payload->>'publisher_id', '')::UUID;
  v_compiler := NULLIF(trim(p_payload->>'compiler_version'), '');
  v_format := NULLIF(p_payload->>'graph_format_version', '')::INTEGER;
  v_source := lower(NULLIF(trim(p_payload->>'source_package_hash'), ''));
  v_supp := lower(NULLIF(trim(p_payload->>'supplemental_relationship_hash'), ''));
  v_graph := lower(NULLIF(trim(p_payload->>'graph_structural_hash'), ''));
  v_composite := lower(NULLIF(trim(p_payload->>'composite_identity'), ''));
  v_payload := p_payload->'canonical_payload';
  v_unresolved := COALESCE(p_payload->'unresolved', '[]'::jsonb);
  v_require_full := COALESCE((p_payload->>'require_full_resolution')::BOOLEAN, FALSE);

  IF v_publisher_id IS NULL THEN
    SELECT id INTO v_publisher_id
    FROM public.content_publishers
    WHERE namespace = 'cohort_global' AND lifecycle = 'active'
    LIMIT 1;
    IF v_publisher_id IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'unauthorised',
        'code', 'missing_publisher'
      );
    END IF;
  ELSIF NOT EXISTS (
    SELECT 1
    FROM public.content_publishers p
    WHERE p.id = v_publisher_id
      AND p.lifecycle = 'active'
  ) THEN
    RETURN jsonb_build_object(
      'status', 'unauthorised',
      'code', 'missing_publisher'
    );
  END IF;

  IF NOT public.content_graph_publisher_may_operate(v_publisher_id) THEN
    RETURN jsonb_build_object('status', 'unauthorised', 'code', 'unauthorised');
  END IF;

  IF v_version_id IS NULL
     OR v_compiler IS NULL
     OR v_format IS NULL
     OR v_source IS NULL
     OR v_supp IS NULL
     OR v_graph IS NULL
     OR v_composite IS NULL
     OR v_payload IS NULL
     OR jsonb_typeof(v_unresolved) <> 'array' THEN
    RETURN jsonb_build_object('status', 'unsupported_format', 'code', 'incomplete_manifest');
  END IF;

  IF v_compiler <> 'content-graph-compiler/v1' OR v_format <> 1 THEN
    RETURN jsonb_build_object('status', 'unsupported_format', 'code', 'unsupported_compiler_or_format');
  END IF;

  IF v_source !~ '^[0-9a-f]{64}$'
     OR v_supp !~ '^[0-9a-f]{64}$'
     OR v_graph !~ '^[0-9a-f]{64}$'
     OR v_composite !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('status', 'hash_mismatch', 'code', 'malformed_hash');
  END IF;

  v_expected := public.content_graph_composite_identity(
    v_compiler, v_format, v_source, v_supp
  );
  IF v_expected IS DISTINCT FROM v_composite THEN
    RETURN jsonb_build_object('status', 'hash_mismatch', 'code', 'composite_mismatch');
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_version_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'unresolved_reference', 'code', 'programme_version_not_found');
  END IF;

  IF v_version.lifecycle_status NOT IN ('published', 'archived') THEN
    RETURN jsonb_build_object('status', 'unresolved_reference', 'code', 'version_not_eligible');
  END IF;

  IF v_version.package_content_hash IS NOT NULL
     AND lower(v_version.package_content_hash) IS DISTINCT FROM v_source THEN
    RETURN jsonb_build_object('status', 'hash_mismatch', 'code', 'source_package_mismatch');
  END IF;

  IF v_version.supersedes_version_id IS NOT NULL THEN
    WITH RECURSIVE chain AS (
      SELECT id, supersedes_version_id, 1 AS depth
      FROM public.programme_versions
      WHERE id = v_version.supersedes_version_id
      UNION ALL
      SELECT v.id, v.supersedes_version_id, chain.depth + 1
      FROM public.programme_versions v
      JOIN chain ON chain.supersedes_version_id = v.id
      WHERE chain.depth < 64
    )
    SELECT EXISTS (SELECT 1 FROM chain WHERE id = v_version_id) INTO v_cycle;
    IF v_cycle THEN
      RETURN jsonb_build_object('status', 'conflicting_identity', 'code', 'supersession_cycle');
    END IF;
  END IF;

  SELECT * INTO v_existing
  FROM public.content_graph_manifests
  WHERE programme_version_id = v_version_id
    AND graph_format_version = v_format
    AND compiler_version = v_compiler
    AND publication_state = 'published';

  IF FOUND THEN
    IF v_existing.composite_identity = v_composite
       AND v_existing.source_package_hash = v_source
       AND v_existing.supplemental_relationship_hash = v_supp
       AND v_existing.graph_structural_hash = v_graph THEN
      RETURN jsonb_build_object(
        'status', 'already_published',
        'manifest_id', v_existing.id,
        'programme_version_id', v_version_id,
        'composite_identity', v_composite
      );
    END IF;
    RETURN jsonb_build_object(
      'status', 'conflicting_identity',
      'code', 'version_already_has_manifest',
      'manifest_id', v_existing.id
    );
  END IF;

  SELECT * INTO v_same_identity
  FROM public.content_graph_manifests
  WHERE composite_identity = v_composite;

  IF FOUND THEN
    IF v_same_identity.programme_version_id = v_version_id
       AND v_same_identity.graph_structural_hash = v_graph THEN
      RETURN jsonb_build_object(
        'status', 'already_published',
        'manifest_id', v_same_identity.id,
        'programme_version_id', v_version_id,
        'composite_identity', v_composite
      );
    END IF;
    RETURN jsonb_build_object(
      'status', 'conflicting_identity',
      'code', 'composite_already_bound'
    );
  END IF;

  IF v_require_full AND jsonb_array_length(v_unresolved) > 0 THEN
    RETURN jsonb_build_object(
      'status', 'unresolved_reference',
      'code', 'full_resolution_required',
      'unresolved', v_unresolved
    );
  END IF;

  FOR v_ex IN
    SELECT DISTINCT trim(value #>> '{}')
    FROM jsonb_array_elements(COALESCE(v_payload->'resolved_exercise_ids', '[]'::jsonb))
  LOOP
    IF v_ex IS NULL OR v_ex = '' THEN
      CONTINUE;
    END IF;
    IF v_ex !~ '^EX-[0-9]{3,}$' THEN
      RETURN jsonb_build_object(
        'status', 'unresolved_reference',
        'code', 'display_name_not_identity',
        'reference', v_ex
      );
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.exercises_v2 WHERE exercise_id = v_ex
    ) THEN
      IF NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements_text(v_unresolved) u
        WHERE u = v_ex
      ) THEN
        RETURN jsonb_build_object(
          'status', 'unresolved_reference',
          'code', 'unknown_exercise',
          'reference', v_ex
        );
      END IF;
    END IF;
  END LOOP;

  FOR v_edge IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(v_payload->'edges', '[]'::jsonb))
  LOOP
    v_type := v_edge->>'type';
    v_from := v_edge->>'from_id';
    v_to := v_edge->>'to_id';
    v_from_type := v_edge->>'from_type';
    IF v_type = 'exerciseUsedByBlock' THEN
      IF v_from_type = 'exercise' AND v_from !~ '^EX-[0-9]{3,}$' THEN
        RETURN jsonb_build_object(
          'status', 'unresolved_reference',
          'code', 'display_name_not_identity',
          'reference', v_from
        );
      END IF;
      IF v_to IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.session_blocks WHERE block_id::TEXT = v_to
      ) THEN
        SELECT session_id INTO v_block_session
        FROM public.session_blocks
        WHERE block_id::TEXT = v_to;
        IF NOT EXISTS (
          SELECT 1
          FROM public.programme_version_session_slots s
          JOIN public.programme_version_days d ON d.id = s.day_id
          JOIN public.programme_version_weeks w ON w.id = d.week_id
          WHERE w.version_id = v_version_id
            AND s.protocol_id = v_block_session
        ) THEN
          RETURN jsonb_build_object(
            'status', 'unresolved_reference',
            'code', 'block_not_in_programme_version'
          );
        END IF;
        IF EXISTS (
          SELECT 1
          FROM public.session_block_exercises
          WHERE block_id::TEXT = v_to
        ) AND NOT EXISTS (
          SELECT 1
          FROM public.session_block_exercises
          WHERE block_id::TEXT = v_to
            AND exercise_id = v_from
        ) THEN
          RETURN jsonb_build_object(
            'status', 'unresolved_reference',
            'code', 'forged_edge_rejected'
          );
        END IF;
      END IF;
    END IF;
  END LOOP;

  INSERT INTO public.content_graph_manifests (
    programme_version_id,
    publisher_id,
    compiler_version,
    graph_format_version,
    source_package_hash,
    supplemental_relationship_hash,
    graph_structural_hash,
    composite_identity,
    canonical_payload,
    publication_state,
    unresolved,
    published_at,
    created_by
  ) VALUES (
    v_version_id,
    v_publisher_id,
    v_compiler,
    v_format,
    v_source,
    v_supp,
    v_graph,
    v_composite,
    v_payload,
    'published',
    v_unresolved,
    NOW(),
    auth.uid()
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'status', 'published',
    'manifest_id', v_id,
    'programme_version_id', v_version_id,
    'composite_identity', v_composite,
    'graph_structural_hash', v_graph
  );
END;
$$;

REVOKE ALL ON FUNCTION public.content_graph_is_service_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.content_graph_sha256_hex(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.content_graph_composite_identity(TEXT, INTEGER, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.content_graph_publisher_may_operate(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.publish_content_graph_manifest(JSONB) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.content_graph_sha256_hex(TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.content_graph_composite_identity(TEXT, INTEGER, TEXT, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.content_graph_is_service_role()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.content_graph_publisher_may_operate(UUID)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.publish_content_graph_manifest(JSONB)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.publish_content_graph_manifest(JSONB) IS
  'Atomically persist an immutable content-graph manifest v1. Does not rewrite assignments or catalogue defaults.';
