-- M10 Sprint 2: roster/read projections. Assignment shown only when the pin
-- belongs to the managing publisher. Foreign pins are hidden.

CREATE OR REPLACE FUNCTION public.publisher_athlete_assignment_is_own(
  p_publisher_id UUID,
  p_programme_version_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.content_graph_manifests m
    WHERE m.programme_version_id = p_programme_version_id
      AND m.publisher_id = p_publisher_id
      AND m.publication_state = 'published'
  )
  OR EXISTS (
    SELECT 1
    FROM public.programme_versions v
    JOIN public.content_publishers p ON p.id = p_publisher_id
    WHERE v.id = p_programme_version_id
      AND (
        (p.first_party AND v.library_scope = 'cohort_global')
        OR (v.owner_id = p_publisher_id::TEXT)
      )
  );
$$;

CREATE OR REPLACE VIEW public.publisher_athlete_roster
WITH (security_invoker = true)
AS
SELECT
  m.id AS membership_id,
  m.publisher_id,
  m.athlete_id,
  pr.display_name AS athlete_display_name,
  m.state AS membership_state,
  m.activated_at,
  m.revoked_at,
  CASE
    WHEN a.id IS NULL THEN 'none'
    WHEN public.publisher_athlete_assignment_is_own(
      m.publisher_id, a.programme_version_id
    ) THEN 'own'
    ELSE 'foreign_hidden'
  END AS assignment_visibility,
  CASE
    WHEN a.id IS NOT NULL AND public.publisher_athlete_assignment_is_own(
      m.publisher_id, a.programme_version_id
    ) THEN a.id
  END AS assignment_id,
  CASE
    WHEN a.id IS NOT NULL AND public.publisher_athlete_assignment_is_own(
      m.publisher_id, a.programme_version_id
    ) THEN a.programme_version_id
  END AS programme_version_id,
  CASE
    WHEN a.id IS NOT NULL AND public.publisher_athlete_assignment_is_own(
      m.publisher_id, a.programme_version_id
    ) THEN v.name
  END AS programme_version_name,
  CASE
    WHEN a.id IS NOT NULL AND public.publisher_athlete_assignment_is_own(
      m.publisher_id, a.programme_version_id
    ) THEN v.lifecycle_status
  END AS programme_version_lifecycle,
  CASE
    WHEN a.id IS NULL
      OR NOT public.publisher_athlete_assignment_is_own(
        m.publisher_id, a.programme_version_id
      )
    THEN NULL
    WHEN g.composite_identity IS NULL THEN 'missing'
    ELSE 'published'
  END AS graph_status,
  CASE
    WHEN a.id IS NOT NULL AND public.publisher_athlete_assignment_is_own(
      m.publisher_id, a.programme_version_id
    ) THEN g.composite_identity
  END AS graph_composite_identity
FROM public.publisher_athlete_memberships m
JOIN public.profiles pr ON pr.id = m.athlete_id
LEFT JOIN LATERAL (
  SELECT pa.id, pa.programme_version_id
  FROM public.programme_assignments pa
  WHERE pa.athlete_id = m.athlete_id
    AND pa.status = 'active'
  ORDER BY pa.started_at DESC NULLS LAST
  LIMIT 1
) a ON TRUE
LEFT JOIN public.programme_versions v ON v.id = a.programme_version_id
LEFT JOIN LATERAL (
  SELECT mg.composite_identity
  FROM public.content_graph_manifests mg
  WHERE mg.programme_version_id = a.programme_version_id
    AND mg.publisher_id = m.publisher_id
    AND mg.publication_state = 'published'
  ORDER BY mg.published_at DESC NULLS LAST
  LIMIT 1
) g ON TRUE;

COMMENT ON VIEW public.publisher_athlete_roster IS
  'M10 management projection. Foreign-publisher assignments are hidden. Not a result tree.';

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_inspect_roster(
  p_publisher_id UUID,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit INTEGER := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
  v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
  v_rows JSONB;
  v_total INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  IF NOT public.content_graph_publisher_may_operate(p_publisher_id) THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT COUNT(*) INTO v_total
  FROM public.publisher_athlete_memberships
  WHERE publisher_id = p_publisher_id AND state = 'active';
  SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r.activated_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT *
    FROM public.publisher_athlete_roster
    WHERE publisher_id = p_publisher_id
      AND membership_state = 'active'
    ORDER BY activated_at DESC
    LIMIT v_limit OFFSET v_offset
  ) r;
  RETURN jsonb_build_object(
    'status', CASE WHEN v_total = 0 THEN 'empty' ELSE 'ready' END,
    'total', v_total,
    'limit', v_limit,
    'offset', v_offset,
    'entries', v_rows
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_list_pending_invitations(
  p_publisher_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_limit INTEGER := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
  v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
  v_rows JSONB;
BEGIN
  PERFORM public.publisher_athlete_expire_pending();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  IF p_publisher_id IS NOT NULL THEN
    IF NOT public.content_graph_publisher_may_operate(p_publisher_id) THEN
      RETURN jsonb_build_object('status', 'unauthorised');
    END IF;
    SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.invited_at DESC), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT id, publisher_id, athlete_id, state, invited_at, expires_at
      FROM public.publisher_athlete_invitations
      WHERE publisher_id = p_publisher_id AND state = 'pending'
      ORDER BY invited_at DESC
      LIMIT v_limit OFFSET v_offset
    ) i;
  ELSE
    SELECT COALESCE(jsonb_agg(to_jsonb(i) ORDER BY i.invited_at DESC), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT id, publisher_id, athlete_id, state, invited_at, expires_at
      FROM public.publisher_athlete_invitations
      WHERE athlete_id = v_uid AND state = 'pending'
      ORDER BY invited_at DESC
      LIMIT v_limit OFFSET v_offset
    ) i;
  END IF;
  RETURN jsonb_build_object(
    'status', CASE WHEN v_rows = '[]'::jsonb THEN 'empty' ELSE 'ready' END,
    'entries', v_rows
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_inspect_memberships()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rows JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.activated_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT id, publisher_id, state, activated_at, revoked_at
    FROM public.publisher_athlete_memberships
    WHERE athlete_id = v_uid
  ) m;
  RETURN jsonb_build_object(
    'status', CASE WHEN v_rows = '[]'::jsonb THEN 'empty' ELSE 'ready' END,
    'entries', v_rows
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_inspect_audit(
  p_membership_id UUID DEFAULT NULL,
  p_invitation_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_limit INTEGER := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
  v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
  v_rows JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(e) ORDER BY e.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      e.id, e.invitation_id, e.membership_id, e.publisher_id, e.athlete_id,
      e.actor_type, e.transition, e.previous_state, e.new_state,
      e.reason_category, e.created_at
    FROM public.publisher_athlete_membership_events e
    WHERE (p_membership_id IS NULL OR e.membership_id = p_membership_id)
      AND (p_invitation_id IS NULL OR e.invitation_id = p_invitation_id)
      AND (
        e.athlete_id = v_uid
        OR public.content_graph_publisher_may_operate(e.publisher_id)
      )
    ORDER BY e.created_at DESC
    LIMIT v_limit OFFSET v_offset
  ) e;
  RETURN jsonb_build_object('status', 'ready', 'entries', v_rows);
END;
$$;

GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_inspect_roster(UUID, INTEGER, INTEGER)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_list_pending_invitations(UUID, INTEGER, INTEGER)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_inspect_memberships()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_inspect_audit(UUID, UUID, INTEGER, INTEGER)
  TO authenticated;
REVOKE ALL ON FUNCTION public.publisher_athlete_assignment_is_own(UUID, UUID)
  FROM PUBLIC, anon;
