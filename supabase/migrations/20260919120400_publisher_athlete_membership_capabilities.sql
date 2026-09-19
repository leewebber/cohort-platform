-- M10 Sprint 2: additive runtime capabilities. Build 7 ignores unknown keys.

CREATE OR REPLACE FUNCTION public.cohort_athlete_runtime_capabilities()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_graph BOOLEAN;
  v_publisher BOOLEAN;
  v_membership BOOLEAN;
BEGIN
  v_graph := EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'publish_content_graph_manifest'
  );
  v_membership := EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'cohort_publisher_athlete_invite'
  );
  v_publisher := EXISTS (
    SELECT 1
    FROM public.content_publisher_principals m
    JOIN public.content_publishers p ON p.id = m.publisher_id
    WHERE m.principal_id = v_athlete
      AND m.principal_role IN ('owner', 'publisher')
      AND p.lifecycle = 'active'
  );

  IF v_athlete IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required',
      'schema_version', 3,
      'overdue_recovery', false,
      'backfill_results', false,
      'content_graph_read', false,
      'content_graph_publish', false,
      'content_graph_impact', false,
      'publisher_athlete_membership_read', false,
      'publisher_athlete_membership_invite', false,
      'publisher_athlete_membership_manage', false
    );
  END IF;

  RETURN jsonb_build_object(
    'status', 'ok',
    'schema_version', 3,
    'overdue_recovery', EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = 'create_or_resume_fixed_programme_occurrence_session'
    ),
    'backfill_results', true,
    'content_graph_read', v_graph,
    'content_graph_publish', v_graph AND v_publisher,
    'content_graph_impact', v_graph AND v_publisher,
    'publisher_athlete_membership_read',
      v_membership AND (
        v_publisher
        OR public.cohort_auth_is_athlete()
      ),
    'publisher_athlete_membership_invite',
      v_membership AND v_publisher,
    'publisher_athlete_membership_manage',
      v_membership AND (
        v_publisher
        OR public.cohort_auth_is_athlete()
      )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_athlete_runtime_capabilities()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_athlete_runtime_capabilities()
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cohort_athlete_runtime_capabilities() IS
  'Capability probe. schema_version 3 adds publisher_athlete_membership_* reflecting actor authority, including publisher principals who are not athletes. Build 7 treats unknown keys as false.';
