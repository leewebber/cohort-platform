-- Separately authorised first-party publisher bootstrap.
-- NOT a migration. Do not copy into supabase/migrations/.
-- db push / db reset do not apply this file.
--
-- Installing this file creates the function only. It inserts no publisher,
-- principal, manifest, reconstruction, catalogue, or assignment rows.
-- Execute bootstrap with an explicit principal:
--   SELECT public.content_graph_bootstrap_cohort_global('<principal-uuid>'::uuid);
--
-- Does not publish manifests, reconstruct content, change catalogue defaults,
-- or repin assignments.

CREATE OR REPLACE FUNCTION public.content_graph_bootstrap_cohort_global(
  p_principal_id UUID,
  p_principal_role TEXT DEFAULT 'owner',
  p_publisher_id UUID DEFAULT '00000000-0000-4000-8000-00000000c001',
  p_display_name TEXT DEFAULT 'Cohort'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role TEXT := lower(btrim(COALESCE(p_principal_role, 'owner')));
  v_name TEXT := NULLIF(btrim(COALESCE(p_display_name, '')), '');
  v_existing public.content_publishers%ROWTYPE;
  v_principal_existed BOOLEAN := FALSE;
BEGIN
  IF NOT public.content_graph_is_service_role() THEN
    RETURN jsonb_build_object('status', 'unauthorised', 'code', 'unauthorised');
  END IF;

  IF p_principal_id IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised', 'code', 'missing_principal');
  END IF;

  IF p_publisher_id IS NULL THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'missing_publisher_id');
  END IF;

  IF v_role NOT IN ('owner', 'publisher', 'reader') THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'invalid_principal_role');
  END IF;

  IF v_name IS NULL THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'invalid_display_name');
  END IF;

  SELECT * INTO v_existing
  FROM public.content_publishers
  WHERE namespace = 'cohort_global';

  IF FOUND THEN
    IF v_existing.id IS DISTINCT FROM p_publisher_id
       OR v_existing.first_party IS DISTINCT FROM TRUE THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'namespace_conflict',
        'publisher_id', v_existing.id
      );
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM public.content_publisher_principals m
      WHERE m.publisher_id = v_existing.id
        AND m.principal_id = p_principal_id
    ) INTO v_principal_existed;

    INSERT INTO public.content_publisher_principals (
      publisher_id, principal_id, principal_role
    ) VALUES (
      v_existing.id, p_principal_id, v_role
    )
    ON CONFLICT (publisher_id, principal_id) DO NOTHING;

    RETURN jsonb_build_object(
      'status', 'already_exists',
      'publisher_id', v_existing.id,
      'namespace', 'cohort_global',
      'principal_id', p_principal_id,
      'principal_added', NOT v_principal_existed
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.content_publishers WHERE id = p_publisher_id
  ) THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'publisher_id_conflict'
    );
  END IF;

  INSERT INTO public.content_publishers (
    id, namespace, display_name, first_party, lifecycle
  ) VALUES (
    p_publisher_id,
    'cohort_global',
    v_name,
    TRUE,
    'active'
  );

  INSERT INTO public.content_publisher_principals (
    publisher_id, principal_id, principal_role
  ) VALUES (
    p_publisher_id, p_principal_id, v_role
  );

  RETURN jsonb_build_object(
    'status', 'created',
    'publisher_id', p_publisher_id,
    'namespace', 'cohort_global',
    'principal_id', p_principal_id,
    'principal_role', v_role
  );
END;
$$;

REVOKE ALL ON FUNCTION public.content_graph_bootstrap_cohort_global(UUID, TEXT, UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.content_graph_bootstrap_cohort_global(UUID, TEXT, UUID, TEXT)
  TO service_role;

COMMENT ON FUNCTION public.content_graph_bootstrap_cohort_global(UUID, TEXT, UUID, TEXT) IS
  'Separately authorised first-party cohort_global bootstrap. Requires an explicit principal. Does not publish, reconstruct, or repin.';

-- Example (do not uncomment in this file):
-- SELECT public.content_graph_bootstrap_cohort_global('00000000-0000-4000-8000-000000000000'::uuid);
