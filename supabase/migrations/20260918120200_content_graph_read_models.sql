-- M9 Sprint 2: derived used-by / impact read models. Operational counts are separate
-- from structural graph identity.

CREATE OR REPLACE VIEW public.content_exercise_used_by_block
WITH (security_invoker = true) AS
SELECT DISTINCT
  e.exercise_id,
  b.block_id,
  b.session_id AS protocol_id,
  b.position AS block_position,
  b.title AS block_title
FROM public.session_block_exercises e
JOIN public.session_blocks b ON b.block_id = e.block_id;

CREATE OR REPLACE VIEW public.content_exercise_used_by_session
WITH (security_invoker = true) AS
SELECT DISTINCT
  e.exercise_id,
  b.session_id AS protocol_id
FROM public.session_block_exercises e
JOIN public.session_blocks b ON b.block_id = e.block_id;

CREATE OR REPLACE VIEW public.content_exercise_used_by_programme
WITH (security_invoker = true) AS
SELECT DISTINCT
  e.exercise_id,
  w.version_id AS programme_version_id,
  s.protocol_id,
  s.id AS slot_id,
  w.week_number,
  d.day_key,
  s.session_order
FROM public.session_block_exercises e
JOIN public.session_blocks b ON b.block_id = e.block_id
JOIN public.programme_version_session_slots s ON s.protocol_id = b.session_id
JOIN public.programme_version_days d ON d.id = s.day_id
JOIN public.programme_version_weeks w ON w.id = d.week_id;

CREATE OR REPLACE VIEW public.content_session_used_by_programme
WITH (security_invoker = true) AS
SELECT DISTINCT
  s.protocol_id,
  w.version_id AS programme_version_id,
  s.id AS slot_id,
  w.week_number,
  d.day_key,
  s.session_order
FROM public.programme_version_session_slots s
JOIN public.programme_version_days d ON d.id = s.day_id
JOIN public.programme_version_weeks w ON w.id = d.week_id
WHERE s.protocol_id IS NOT NULL;

CREATE OR REPLACE VIEW public.content_version_supersession
WITH (security_invoker = true) AS
SELECT
  v.id AS programme_version_id,
  v.supersedes_version_id,
  v.lineage_id,
  v.version_number,
  v.lifecycle_status
FROM public.programme_versions v
WHERE v.supersedes_version_id IS NOT NULL;

CREATE OR REPLACE VIEW public.content_graph_unresolved_counts
WITH (security_invoker = true) AS
SELECT
  m.programme_version_id,
  m.id AS manifest_id,
  jsonb_array_length(m.unresolved) AS unresolved_count
FROM public.content_graph_manifests m
WHERE m.publication_state = 'published';

-- Operational assignment counts. Not part of graph structural identity.
CREATE OR REPLACE FUNCTION public.content_graph_assignment_impact(
  p_programme_version_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_publisher UUID;
  v_active INT;
  v_paused INT;
  v_completed INT;
BEGIN
  IF p_programme_version_id IS NULL THEN
    RETURN jsonb_build_object('status', 'unresolved_reference');
  END IF;

  SELECT publisher_id INTO v_publisher
  FROM public.content_graph_manifests
  WHERE programme_version_id = p_programme_version_id
    AND publication_state = 'published'
  LIMIT 1;

  IF NOT public.content_graph_is_service_role() THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('status', 'unauthorised', 'code', 'unauthenticated');
    END IF;
    IF public.cohort_auth_is_athlete() AND NOT public.cohort_auth_is_coach() THEN
      RETURN jsonb_build_object('status', 'unauthorised', 'code', 'private_impact_denied');
    END IF;
    IF v_publisher IS NOT NULL
       AND NOT public.content_graph_publisher_may_operate(v_publisher) THEN
      RETURN jsonb_build_object('status', 'unauthorised', 'code', 'namespace_isolation');
    END IF;
    IF v_publisher IS NULL AND NOT public.cohort_auth_is_coach() THEN
      RETURN jsonb_build_object('status', 'unauthorised', 'code', 'unauthorised');
    END IF;
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE status = 'active'),
    COUNT(*) FILTER (WHERE status = 'paused'),
    COUNT(*) FILTER (WHERE status = 'completed')
  INTO v_active, v_paused, v_completed
  FROM public.programme_assignments
  WHERE programme_version_id = p_programme_version_id;

  RETURN jsonb_build_object(
    'status', 'ok',
    'programme_version_id', p_programme_version_id,
    'active_count', v_active,
    'paused_count', v_paused,
    'completed_count', v_completed
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.content_graph_version_diff(
  p_from_version_id UUID,
  p_to_version_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_from public.content_graph_manifests%ROWTYPE;
  v_to public.content_graph_manifests%ROWTYPE;
  v_added INT;
  v_removed INT;
  v_from_sessions INT;
  v_to_sessions INT;
  v_class TEXT;
  v_unresolved_delta INT;
BEGIN
  IF auth.uid() IS NULL AND NOT public.content_graph_is_service_role() THEN
    RETURN jsonb_build_object('status', 'unauthorised', 'code', 'unauthenticated');
  END IF;

  SELECT * INTO v_from
  FROM public.content_graph_manifests
  WHERE programme_version_id = p_from_version_id
    AND publication_state = 'published';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'unresolved_reference', 'code', 'from_manifest_missing');
  END IF;

  SELECT * INTO v_to
  FROM public.content_graph_manifests
  WHERE programme_version_id = p_to_version_id
    AND publication_state = 'published';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'unresolved_reference', 'code', 'to_manifest_missing');
  END IF;

  SELECT COUNT(*) INTO v_from_sessions
  FROM public.content_session_used_by_programme
  WHERE programme_version_id = p_from_version_id;

  SELECT COUNT(*) INTO v_to_sessions
  FROM public.content_session_used_by_programme
  WHERE programme_version_id = p_to_version_id;

  SELECT COUNT(*) INTO v_added
  FROM (
    SELECT protocol_id FROM public.content_session_used_by_programme
    WHERE programme_version_id = p_to_version_id
    EXCEPT
    SELECT protocol_id FROM public.content_session_used_by_programme
    WHERE programme_version_id = p_from_version_id
  ) x;

  SELECT COUNT(*) INTO v_removed
  FROM (
    SELECT protocol_id FROM public.content_session_used_by_programme
    WHERE programme_version_id = p_from_version_id
    EXCEPT
    SELECT protocol_id FROM public.content_session_used_by_programme
    WHERE programme_version_id = p_to_version_id
  ) x;

  v_unresolved_delta := jsonb_array_length(v_to.unresolved)
    - jsonb_array_length(v_from.unresolved);

  IF v_added > 0 OR v_removed > 0 THEN
    v_class := 'breaking_execution';
  ELSIF v_from.graph_structural_hash IS DISTINCT FROM v_to.graph_structural_hash THEN
    v_class := 'material_training';
  ELSIF v_from.source_package_hash IS DISTINCT FROM v_to.source_package_hash THEN
    v_class := 'material_training';
  ELSE
    v_class := 'metadata_presentation';
  END IF;

  RETURN jsonb_build_object(
    'status', 'ok',
    'from_version_id', p_from_version_id,
    'to_version_id', p_to_version_id,
    'classification', v_class,
    'sessions_added', v_added,
    'sessions_removed', v_removed,
    'from_session_count', v_from_sessions,
    'to_session_count', v_to_sessions,
    'unresolved_delta', v_unresolved_delta,
    'source_hash_changed', v_from.source_package_hash IS DISTINCT FROM v_to.source_package_hash,
    'graph_hash_changed', v_from.graph_structural_hash IS DISTINCT FROM v_to.graph_structural_hash,
    'identical_content',
      v_from.source_package_hash = v_to.source_package_hash
      AND v_from.supplemental_relationship_hash = v_to.supplemental_relationship_hash
  );
END;
$$;

COMMENT ON VIEW public.content_exercise_used_by_programme IS
  'Derived exercise→programme used-by. Keys are EX-* and version UUID, never display names.';
COMMENT ON FUNCTION public.content_graph_assignment_impact(UUID) IS
  'Operational assignment counts. Changing these must not change graph_structural_hash.';

REVOKE ALL ON FUNCTION public.content_graph_assignment_impact(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.content_graph_version_diff(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.content_graph_assignment_impact(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.content_graph_version_diff(UUID, UUID) TO authenticated, service_role;
