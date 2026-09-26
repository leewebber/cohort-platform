-- Private exact-version enrol / replace-active.
-- Uses existing publication fields: published + coach_private/organisation.
-- Does not require cohort_global or approved_for_global.
-- Does not change catalogue discovery or the public enrol RPC.
-- No hosted apply.

CREATE OR REPLACE FUNCTION public.cohort_programme_version_is_private_assignable(
  p_version_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.programme_versions v
    WHERE v.id = p_version_id
      AND v.lifecycle_status = 'published'
      AND v.archived_at IS NULL
      AND v.library_scope IN ('coach_private', 'organisation')
      AND NOT public.cohort_programme_version_is_catalogue_eligible(v.id)
  );
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_is_private_assignable(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_private_assignable(UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cohort_programme_version_is_private_assignable(UUID) IS
  'TRUE when a published non-catalogue version may be privately assigned. Drafts are never executable.';

CREATE OR REPLACE FUNCTION public.cohort_athlete_may_enrol_private_programme_version(
  p_version_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_version public.programme_versions%ROWTYPE;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN FALSE;
  END IF;
  IF NOT public.cohort_programme_version_is_private_assignable(p_version_id) THEN
    RETURN FALSE;
  END IF;
  SELECT * INTO v_version FROM public.programme_versions WHERE id = p_version_id;
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  IF nullif(trim(COALESCE(v_version.owner_id, '')), '') IS NOT NULL
     AND v_version.owner_id = v_athlete::text THEN
    RETURN TRUE;
  END IF;
  RETURN EXISTS (
    SELECT 1
    FROM public.coach_athlete_relationships r
    WHERE r.status = 'active'
      AND r.athlete_id = v_athlete
      AND r.coach_id::text = v_version.owner_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_athlete_may_enrol_private_programme_version(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_athlete_may_enrol_private_programme_version(UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cohort_athlete_may_enrol_private_programme_version(UUID) IS
  'Athlete may privately enrol only when they own the version or have an active link to the owning coach.';

CREATE OR REPLACE FUNCTION public.enrol_athlete_in_private_programme_version(
  p_programme_version_id UUID,
  p_timezone TEXT DEFAULT NULL,
  p_replace_active BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_version public.programme_versions%ROWTYPE;
  v_lineage_code TEXT;
  v_active public.programme_assignments%ROWTYPE;
  v_replaced_id UUID := NULL;
  v_new_id UUID;
  v_week INT;
  v_day_key TEXT;
  v_slot INT;
  v_tz TEXT;
  v_started DATE;
  v_source TEXT;
  v_materialise JSONB;
  v_ensure JSONB;
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'not_authenticated');
  END IF;
  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'athlete_role_required');
  END IF;
  IF p_programme_version_id IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_args');
  END IF;

  SELECT * INTO v_version FROM public.programme_versions WHERE id = p_programme_version_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'version_not_found');
  END IF;
  IF public.cohort_programme_version_is_catalogue_eligible(p_programme_version_id) THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'use_catalogue_enrolment'
    );
  END IF;
  IF v_version.lifecycle_status IS DISTINCT FROM 'published'
     OR v_version.archived_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'version_not_private_eligible'
    );
  END IF;
  IF NOT public.cohort_programme_version_is_private_assignable(p_programme_version_id) THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'version_not_private_eligible'
    );
  END IF;
  IF NOT public.cohort_athlete_may_enrol_private_programme_version(p_programme_version_id) THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'private_enrolment_not_authorised'
    );
  END IF;

  SELECT l.code INTO v_lineage_code FROM public.programme_lineages l WHERE l.id = v_version.lineage_id;
  IF v_lineage_code IS NULL OR length(trim(v_lineage_code)) = 0 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'lineage_missing');
  END IF;

  PERFORM pg_advisory_xact_lock(84202613, hashtext(v_athlete_id::text));

  SELECT * INTO v_active
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete_id AND status = 'active'
  FOR UPDATE;

  IF FOUND THEN
    IF v_active.programme_version_id = p_programme_version_id THEN
      RETURN jsonb_build_object(
        'status', 'already_enrolled',
        'enrolment_id', v_active.id,
        'programme_version_id', v_active.programme_version_id,
        'lineage_code', v_active.lineage_code,
        'enrolment_source', v_active.enrolment_source,
        'athlete_id', v_athlete_id,
        'started_at', v_active.started_at,
        'timezone', v_active.timezone
      );
    END IF;
    IF NOT COALESCE(p_replace_active, FALSE) THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'active_enrolment_exists',
        'enrolment_id', v_active.id,
        'programme_version_id', v_active.programme_version_id
      );
    END IF;
    v_replaced_id := v_active.id;
  END IF;

  SELECT w.week_number, d.day_key,
         COALESCE((
           SELECT MIN(s.session_order)
           FROM public.programme_version_session_slots s
           WHERE s.day_id = d.id
         ), 1)
    INTO v_week, v_day_key, v_slot
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  WHERE w.version_id = p_programme_version_id
  ORDER BY w.week_number ASC, d.day_order ASC
  LIMIT 1;
  IF v_week IS NULL OR v_day_key IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'empty_programme_structure');
  END IF;

  v_tz := nullif(trim(COALESCE(p_timezone, '')), '');
  IF v_tz IS NULL
     OR v_tz !~ '^[A-Za-z_]+/[A-Za-z0-9_+\-]+(/[A-Za-z0-9_+\-]+)*$'
     OR v_tz LIKE 'Etc/%'
     OR v_tz LIKE 'posix/%'
     OR v_tz LIKE 'right/%'
     OR NOT EXISTS (
       SELECT 1 FROM pg_timezone_names WHERE name = v_tz
     ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_timezone'
    );
  END IF;

  v_started := (now() AT TIME ZONE v_tz)::date;
  v_new_id := gen_random_uuid();
  IF nullif(trim(COALESCE(v_version.owner_id, '')), '') = v_athlete_id::text THEN
    v_source := 'dual_role_self';
  ELSE
    v_source := 'coach_assigned';
  END IF;

  IF v_replaced_id IS NOT NULL THEN
    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    UPDATE public.programme_assignments
    SET status = 'reassigned', updated_at = NOW()
    WHERE id = v_replaced_id
      AND athlete_id = v_athlete_id
      AND status = 'active';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'active assignment replacement lost concurrent ownership'
        USING ERRCODE = '40001';
    END IF;
  END IF;

  INSERT INTO public.programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    timezone, current_week_number, current_day_key, current_slot_order, enrolment_source
  ) VALUES (
    v_new_id, v_athlete_id, p_programme_version_id, v_lineage_code, 'active', v_started,
    v_tz, v_week, v_day_key, v_slot, v_source
  );

  IF v_replaced_id IS NOT NULL THEN
    UPDATE public.programme_assignments
    SET superseded_by_assignment_id = v_new_id, updated_at = NOW()
    WHERE id = v_replaced_id;
  END IF;

  v_materialise := public.materialise_athlete_plan_from_enrolment(v_new_id, v_tz);
  IF v_materialise->>'status' IS DISTINCT FROM 'materialised'
     AND v_materialise->>'status' IS DISTINCT FROM 'already_materialised' THEN
    RAISE EXCEPTION 'private enrolment materialisation failed: %', v_materialise::text
      USING ERRCODE = '40001';
  END IF;

  v_ensure := public.ensure_programme_schedule_projection(v_new_id);
  IF v_ensure->>'status' NOT IN ('initialised', 'already_exists') THEN
    RAISE EXCEPTION 'private enrolment projection failed: %', v_ensure::text
      USING ERRCODE = '40001';
  END IF;

  RETURN jsonb_build_object(
    'status', 'enrolled',
    'enrolment_id', v_new_id,
    'programme_version_id', p_programme_version_id,
    'lineage_code', v_lineage_code,
    'enrolment_source', v_source,
    'athlete_id', v_athlete_id,
    'replaced_enrolment_id', v_replaced_id,
    'started_at', v_started,
    'timezone', v_tz,
    'materialised', TRUE
  );
END;
$$;

REVOKE ALL ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN) IS
  'Authenticated private exact-version enrol. Replace-active retains the prior assignment as reassigned. Catalogue versions are rejected.';

CREATE OR REPLACE FUNCTION public.materialise_athlete_plan_from_enrolment(
  p_programme_assignment_id UUID,
  p_timezone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_assignment public.programme_assignments%ROWTYPE;
  v_version public.programme_versions%ROWTYPE;
  v_tz TEXT;
  v_start DATE;
  v_week INT;
  v_day_key TEXT;
  v_slot INT;
  v_protocol TEXT;
  v_other UUID;
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'not_authenticated'
    );
  END IF;

  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_role_required'
    );
  END IF;

  IF p_programme_assignment_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_args'
    );
  END IF;

  -- Serialise materialisation attempts for this athlete.
  PERFORM pg_advisory_xact_lock(84201401, hashtext(v_athlete_id::text));

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = p_programme_assignment_id
    AND athlete_id = v_athlete_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_found'
    );
  END IF;

  IF v_assignment.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'inactive_enrolment',
      'enrolment_id', v_assignment.id
    );
  END IF;

  IF v_assignment.materialised_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'already_materialised',
      'enrolment_id', v_assignment.id,
      'programme_version_id', v_assignment.programme_version_id,
      'lineage_code', v_assignment.lineage_code,
      'materialised_at', v_assignment.materialised_at,
      'materialisation_source', v_assignment.materialisation_source,
      'materialised_package_content_hash', v_assignment.materialised_package_content_hash,
      'materialised_package_schema_version', v_assignment.materialised_package_schema_version,
      'started_at', v_assignment.started_at,
      'timezone', v_assignment.timezone,
      'current_week_number', v_assignment.current_week_number,
      'current_day_key', v_assignment.current_day_key,
      'current_slot_order', v_assignment.current_slot_order,
      'athlete_id', v_athlete_id
    );
  END IF;

  SELECT a.id INTO v_other
  FROM public.programme_assignments a
  WHERE a.athlete_id = v_athlete_id
    AND a.status = 'active'
    AND a.materialised_at IS NOT NULL
    AND a.id IS DISTINCT FROM v_assignment.id
  LIMIT 1;

  IF v_other IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'active_materialised_programme_exists',
      'conflicting_enrolment_id', v_other
    );
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_assignment.programme_version_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'version_not_found',
      'programme_version_id', v_assignment.programme_version_id
    );
  END IF;

  IF NOT public.cohort_programme_version_is_immutable(v_version.id) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'version_not_immutable',
      'programme_version_id', v_version.id
    );
  END IF;

  -- Exact enrolled version only. Catalogue or private-assignable; never latest.
  IF public.cohort_programme_version_is_catalogue_eligible(v_version.id) THEN
    NULL;
  ELSIF public.cohort_programme_version_is_private_assignable(v_version.id) THEN
    NULL;
  ELSE
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'version_not_execution_eligible',
      'programme_version_id', v_version.id
    );
  END IF;

  IF v_version.package_content_hash IS NULL
     OR v_version.package_content_hash !~ '^[0-9a-f]{64}$'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_package_integrity',
      'programme_version_id', v_version.id
    );
  END IF;

  SELECT f.o_week, f.o_day_key, f.o_slot_order, f.o_protocol_id
    INTO v_week, v_day_key, v_slot, v_protocol
  FROM public.cohort_programme_version_first_executable_slot(v_version.id) AS f;

  IF v_week IS NULL OR v_day_key IS NULL OR v_slot IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'empty_programme_structure',
      'programme_version_id', v_version.id
    );
  END IF;

  IF nullif(trim(COALESCE(v_protocol, '')), '') IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'unresolvable_first_slot',
      'programme_version_id', v_version.id
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.performance_protocols p
    WHERE p.protocol_id = v_protocol
      AND (
        COALESCE(p.lifecycle_status, '') = 'published'
        OR lower(COALESCE(p.published::text, 'false')) IN ('true', 't', '1')
      )
  ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'unresolvable_first_slot',
      'programme_version_id', v_version.id,
      'protocol_id', v_protocol
    );
  END IF;

  v_tz := nullif(trim(COALESCE(p_timezone, '')), '');
  IF v_tz IS NULL THEN
    v_tz := nullif(trim(COALESCE(v_assignment.timezone, '')), '');
  END IF;

  BEGIN
    v_start := public.cohort_resolve_athlete_local_date(v_tz);
  EXCEPTION
    WHEN others THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'timezone_unavailable',
        'message', 'A valid programme timezone is required to start today.'
      );
  END;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);

  UPDATE public.programme_assignments
  SET started_at = v_start,
      timezone = v_tz,
      current_week_number = v_week,
      current_day_key = v_day_key,
      current_slot_order = v_slot,
      materialised_at = NOW(),
      materialisation_source = 'athlete_start_programme',
      materialised_package_content_hash = v_version.package_content_hash,
      materialised_package_schema_version = v_version.package_schema_version,
      updated_at = NOW()
  WHERE id = v_assignment.id
    AND athlete_id = v_athlete_id
    AND status = 'active'
    AND materialised_at IS NULL;

  IF NOT FOUND THEN
    -- Race: another session materialised this row; return authoritative state.
    SELECT * INTO v_assignment
    FROM public.programme_assignments
    WHERE id = p_programme_assignment_id
      AND athlete_id = v_athlete_id;

    IF v_assignment.materialised_at IS NOT NULL THEN
      RETURN jsonb_build_object(
        'status', 'already_materialised',
        'enrolment_id', v_assignment.id,
        'programme_version_id', v_assignment.programme_version_id,
        'lineage_code', v_assignment.lineage_code,
        'materialised_at', v_assignment.materialised_at,
        'materialisation_source', v_assignment.materialisation_source,
        'materialised_package_content_hash', v_assignment.materialised_package_content_hash,
        'materialised_package_schema_version', v_assignment.materialised_package_schema_version,
        'started_at', v_assignment.started_at,
        'timezone', v_assignment.timezone,
        'current_week_number', v_assignment.current_week_number,
        'current_day_key', v_assignment.current_day_key,
        'current_slot_order', v_assignment.current_slot_order,
        'athlete_id', v_athlete_id
      );
    END IF;

    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'materialisation_race',
      'enrolment_id', p_programme_assignment_id
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = p_programme_assignment_id;

  RETURN jsonb_build_object(
    'status', 'materialised',
    'enrolment_id', v_assignment.id,
    'programme_version_id', v_assignment.programme_version_id,
    'lineage_code', v_assignment.lineage_code,
    'materialised_at', v_assignment.materialised_at,
    'materialisation_source', v_assignment.materialisation_source,
    'materialised_package_content_hash', v_assignment.materialised_package_content_hash,
    'materialised_package_schema_version', v_assignment.materialised_package_schema_version,
    'started_at', v_assignment.started_at,
    'timezone', v_assignment.timezone,
    'current_week_number', v_assignment.current_week_number,
    'current_day_key', v_assignment.current_day_key,
    'current_slot_order', v_assignment.current_slot_order,
    'athlete_id', v_athlete_id
  );
END;
$$;


REVOKE ALL ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT) TO authenticated, service_role;
COMMENT ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT) IS
  'Start Programme materialisation. Accepts catalogue-eligible or private-assignable published versions.';
