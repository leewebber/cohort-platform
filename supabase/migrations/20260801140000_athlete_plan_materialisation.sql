-- Sprint 1.4A: Athlete plan materialisation foundation
--
-- Reuses programme_assignments as the durable enrolment + materialisation record.
-- Explicit Start Programme RPC stamps materialisation provenance, resets the
-- schedule anchor to athlete-local today, and initialises the first authored
-- executable cursor from the exact enrolled programme_version_id.
--
-- Does NOT prepare sessions, wire Home/today, create completions, or invoke
-- Coach Brain / generative programmed resolve.
-- Does NOT implement payments, subscriptions, purchases, or ownership.

-- ---------------------------------------------------------------------------
-- 1. Materialisation columns (additive; existing rows stay non-materialised)
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_assignments
  ADD COLUMN IF NOT EXISTS materialised_at TIMESTAMPTZ;

ALTER TABLE public.programme_assignments
  ADD COLUMN IF NOT EXISTS materialisation_source TEXT;

ALTER TABLE public.programme_assignments
  ADD COLUMN IF NOT EXISTS materialised_package_content_hash TEXT;

ALTER TABLE public.programme_assignments
  ADD COLUMN IF NOT EXISTS materialised_package_schema_version TEXT;

ALTER TABLE public.programme_assignments
  DROP CONSTRAINT IF EXISTS programme_assignments_materialisation_source_check;

ALTER TABLE public.programme_assignments
  ADD CONSTRAINT programme_assignments_materialisation_source_check
  CHECK (
    materialisation_source IS NULL
    OR materialisation_source IN ('athlete_start_programme')
  );

ALTER TABLE public.programme_assignments
  DROP CONSTRAINT IF EXISTS programme_assignments_materialisation_pair_check;

ALTER TABLE public.programme_assignments
  ADD CONSTRAINT programme_assignments_materialisation_pair_check
  CHECK (
    (
      materialised_at IS NULL
      AND materialisation_source IS NULL
      AND materialised_package_content_hash IS NULL
      AND materialised_package_schema_version IS NULL
    )
    OR (
      materialised_at IS NOT NULL
      AND materialisation_source IS NOT NULL
      AND materialised_package_content_hash IS NOT NULL
      AND materialised_package_content_hash ~ '^[0-9a-f]{64}$'
    )
  );

COMMENT ON COLUMN public.programme_assignments.materialised_at IS
  'When Start Programme materialised this enrolment into an executable plan. NULL = enrolment only (not executable). Enrolment created_at remains creation provenance; pre-materialisation started_at is inert.';

COMMENT ON COLUMN public.programme_assignments.materialisation_source IS
  'How materialisation was authorised. athlete_start_programme = Sprint 1.4A explicit Start Programme. Not a payment record.';

COMMENT ON COLUMN public.programme_assignments.materialised_package_content_hash IS
  'Server-side snapshot of programme_versions.package_content_hash at materialisation. Exact-version provenance; never client-supplied.';

COMMENT ON COLUMN public.programme_assignments.materialised_package_schema_version IS
  'Optional snapshot of programme_versions.package_schema_version at materialisation.';

COMMENT ON TABLE public.programme_assignments IS
  'Athlete enrolment and (after materialised_at) executable programme plan on a pinned programme_version_id. Lifecycle: enrolled → materialised → prepared (1.4B) → completed. created_at = enrolment creation; started_at becomes the materialisation schedule anchor and is inert before materialised_at.';

-- At most one active materialised programme assignment per athlete.
CREATE UNIQUE INDEX IF NOT EXISTS programme_assignments_one_active_materialised_per_athlete
  ON public.programme_assignments (athlete_id)
  WHERE status = 'active' AND materialised_at IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Protect materialisation-controlled columns from direct authenticated writes
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_assignment_protect_materialisation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  -- RPC sets this local GUC for the transaction; direct PostgREST updates do not.
  IF COALESCE(current_setting('cohort.allow_materialisation_write', true), '') = 'on' THEN
    RETURN NEW;
  END IF;

  IF NEW.materialised_at IS DISTINCT FROM OLD.materialised_at
     OR NEW.materialisation_source IS DISTINCT FROM OLD.materialisation_source
     OR NEW.materialised_package_content_hash IS DISTINCT FROM OLD.materialised_package_content_hash
     OR NEW.materialised_package_schema_version IS DISTINCT FROM OLD.materialised_package_schema_version
     OR NEW.programme_version_id IS DISTINCT FROM OLD.programme_version_id
     OR NEW.lineage_code IS DISTINCT FROM OLD.lineage_code
     OR (
       -- After materialisation, schedule anchor is RPC-controlled.
       OLD.materialised_at IS NOT NULL
       AND NEW.started_at IS DISTINCT FROM OLD.started_at
     )
     OR (
       -- Direct clients must not stamp materialisation by changing started_at
       -- together with materialisation fields (covered above) or inventing
       -- materialisation via started_at alone when materialising.
       NEW.materialised_at IS NOT NULL
       AND OLD.materialised_at IS NULL
     )
  THEN
    RAISE EXCEPTION 'programme_assignments materialisation-controlled columns are RPC-only'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS programme_assignments_protect_materialisation
  ON public.programme_assignments;

CREATE TRIGGER programme_assignments_protect_materialisation
  BEFORE UPDATE ON public.programme_assignments
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_programme_assignment_protect_materialisation();

REVOKE ALL ON FUNCTION public.cohort_programme_assignment_protect_materialisation() FROM PUBLIC;

COMMENT ON FUNCTION public.cohort_programme_assignment_protect_materialisation() IS
  'Blocks direct authenticated updates to materialisation provenance, package hash snapshot, exact version pin, and post-materialisation started_at. Sprint 1.4A RPC sets cohort.allow_materialisation_write=on.';

-- ---------------------------------------------------------------------------
-- 3. Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_resolve_athlete_local_date(p_timezone TEXT)
RETURNS DATE
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tz TEXT := nullif(trim(COALESCE(p_timezone, '')), '');
  v_date DATE;
BEGIN
  IF v_tz IS NULL THEN
    RAISE EXCEPTION 'timezone_required' USING ERRCODE = '22023';
  END IF;

  BEGIN
    v_date := (CURRENT_TIMESTAMP AT TIME ZONE v_tz)::date;
  EXCEPTION
    WHEN invalid_parameter_value OR datetime_field_overflow OR others THEN
      RAISE EXCEPTION 'timezone_invalid' USING ERRCODE = '22023';
  END;

  RETURN v_date;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_resolve_athlete_local_date(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_resolve_athlete_local_date(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_resolve_athlete_local_date(TEXT) TO service_role;

COMMENT ON FUNCTION public.cohort_resolve_athlete_local_date(TEXT) IS
  'Sprint 1.4A: athlete-local calendar date for Start today, from a validated IANA timezone. Fails closed when timezone is missing or invalid.';

CREATE OR REPLACE FUNCTION public.cohort_programme_version_first_executable_slot(
  p_version_id UUID,
  OUT o_week INT,
  OUT o_day_key TEXT,
  OUT o_slot_order INT,
  OUT o_protocol_id TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  SELECT w.week_number,
         d.day_key,
         s.session_order,
         s.protocol_id
    INTO o_week, o_day_key, o_slot_order, o_protocol_id
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  JOIN public.programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = p_version_id
    AND COALESCE(d.day_type, '') <> 'rest'
    AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
  ORDER BY w.week_number ASC, d.day_order ASC, s.session_order ASC
  LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_first_executable_slot(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_first_executable_slot(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_first_executable_slot(UUID) TO service_role;

COMMENT ON FUNCTION public.cohort_programme_version_first_executable_slot(UUID) IS
  'First authored executable slot (non-rest day with protocol_id) for an exact programme version. Used by materialisation only.';

-- ---------------------------------------------------------------------------
-- 4. Materialisation RPC
-- ---------------------------------------------------------------------------

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

  -- Integrity at materialisation time (exact enrolled version only; never latest).
  IF v_version.lifecycle_status IS DISTINCT FROM 'published'
     OR v_version.archived_at IS NOT NULL
     OR v_version.approved_for_global IS NOT TRUE
     OR v_version.library_scope IS DISTINCT FROM 'cohort_global'
     OR v_version.owner_type IS DISTINCT FROM 'global'
  THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'version_not_catalogue_eligible',
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

REVOKE ALL ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT)
  FROM anon;
GRANT EXECUTE ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT)
  TO service_role;

COMMENT ON FUNCTION public.materialise_athlete_plan_from_enrolment(UUID, TEXT) IS
  'Sprint 1.4A: authenticated athlete starts an enrolled programme today. Identity from auth.uid() only. Pins exact enrolled programme_version_id. Resets started_at to athlete-local today. Idempotent when already materialised. Does not prepare sessions or invoke Coach Brain.';
