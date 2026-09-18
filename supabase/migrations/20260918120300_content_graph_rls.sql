-- M9 Sprint 2: least-privilege RLS for publishers, manifests, and reconstruction jobs.

ALTER TABLE public.content_publishers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_publisher_principals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_graph_manifests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.content_publishers FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.content_publisher_principals FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.content_graph_manifests FROM PUBLIC, anon;

GRANT SELECT ON TABLE public.content_publishers TO authenticated, service_role;
GRANT SELECT ON TABLE public.content_publisher_principals TO authenticated, service_role;
GRANT SELECT ON TABLE public.content_graph_manifests TO authenticated, service_role;

GRANT SELECT ON public.content_exercise_used_by_block TO authenticated, service_role;
GRANT SELECT ON public.content_exercise_used_by_session TO authenticated, service_role;
GRANT SELECT ON public.content_exercise_used_by_programme TO authenticated, service_role;
GRANT SELECT ON public.content_session_used_by_programme TO authenticated, service_role;
GRANT SELECT ON public.content_version_supersession TO authenticated, service_role;
GRANT SELECT ON public.content_graph_unresolved_counts TO authenticated, service_role;

DROP POLICY IF EXISTS content_publishers_select ON public.content_publishers;
CREATE POLICY content_publishers_select
  ON public.content_publishers
  FOR SELECT
  TO authenticated
  USING (
    (
      first_party = TRUE
      AND lifecycle = 'active'
    )
    OR EXISTS (
      SELECT 1
      FROM public.content_publisher_principals m
      WHERE m.publisher_id = content_publishers.id
        AND m.principal_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS content_publisher_principals_select
  ON public.content_publisher_principals;
CREATE POLICY content_publisher_principals_select
  ON public.content_publisher_principals
  FOR SELECT
  TO authenticated
  USING (principal_id = auth.uid());

DROP POLICY IF EXISTS content_publisher_principals_no_insert
  ON public.content_publisher_principals;
CREATE POLICY content_publisher_principals_no_insert
  ON public.content_publisher_principals
  FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS content_publisher_principals_no_update
  ON public.content_publisher_principals;
CREATE POLICY content_publisher_principals_no_update
  ON public.content_publisher_principals
  FOR UPDATE
  TO authenticated
  USING (FALSE);

DROP POLICY IF EXISTS content_publisher_principals_no_delete
  ON public.content_publisher_principals;
CREATE POLICY content_publisher_principals_no_delete
  ON public.content_publisher_principals
  FOR DELETE
  TO authenticated
  USING (FALSE);

DROP POLICY IF EXISTS content_graph_manifests_select
  ON public.content_graph_manifests;
CREATE POLICY content_graph_manifests_select
  ON public.content_graph_manifests
  FOR SELECT
  TO authenticated
  USING (
    public.content_graph_actor_may_read_manifest(
      programme_version_id,
      publisher_id,
      publication_state
    )
  );

DROP POLICY IF EXISTS content_graph_manifests_no_insert
  ON public.content_graph_manifests;
CREATE POLICY content_graph_manifests_no_insert
  ON public.content_graph_manifests
  FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS content_graph_manifests_no_update
  ON public.content_graph_manifests;
CREATE POLICY content_graph_manifests_no_update
  ON public.content_graph_manifests
  FOR UPDATE
  TO authenticated
  USING (FALSE);

DROP POLICY IF EXISTS content_graph_manifests_no_delete
  ON public.content_graph_manifests;
CREATE POLICY content_graph_manifests_no_delete
  ON public.content_graph_manifests
  FOR DELETE
  TO authenticated
  USING (FALSE);

DROP POLICY IF EXISTS content_publishers_no_direct_write
  ON public.content_publishers;
CREATE POLICY content_publishers_no_direct_write
  ON public.content_publishers
  FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

DROP POLICY IF EXISTS content_publishers_no_update
  ON public.content_publishers;
CREATE POLICY content_publishers_no_update
  ON public.content_publishers
  FOR UPDATE
  TO authenticated
  USING (FALSE);

DROP POLICY IF EXISTS content_publishers_no_delete
  ON public.content_publishers;
CREATE POLICY content_publishers_no_delete
  ON public.content_publishers
  FOR DELETE
  TO authenticated
  USING (FALSE);

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
BEGIN
  v_graph := EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'publish_content_graph_manifest'
  );
  v_publisher := EXISTS (
    SELECT 1
    FROM public.content_publisher_principals m
    JOIN public.content_publishers p ON p.id = m.publisher_id
    WHERE m.principal_id = v_athlete
      AND m.principal_role IN ('owner', 'publisher')
      AND p.lifecycle = 'active'
  );

  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required',
      'schema_version', 2,
      'overdue_recovery', false,
      'backfill_results', false,
      'content_graph_read', false,
      'content_graph_publish', false,
      'content_graph_impact', false
    );
  END IF;

  RETURN jsonb_build_object(
    'status', 'ok',
    'schema_version', 2,
    'overdue_recovery', EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = 'create_or_resume_fixed_programme_occurrence_session'
    ),
    'backfill_results', true,
    'content_graph_read', v_graph,
    'content_graph_publish',
      v_graph AND v_publisher,
    'content_graph_impact',
      v_graph AND v_publisher
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_athlete_runtime_capabilities()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_athlete_runtime_capabilities()
  TO authenticated;

COMMENT ON FUNCTION public.cohort_athlete_runtime_capabilities() IS
  'Explicit hosted capability probe. content_graph_read means schema exists. content_graph_publish/impact require an active publisher principal, not merely coach. Build 7 treats unknown keys as false.';
