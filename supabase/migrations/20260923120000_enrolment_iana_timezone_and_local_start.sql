-- Sprint 2: IANA timezone validation and athlete-local enrolment start date.
-- Same signature as 20260817170000 to avoid PostgREST overload.

CREATE OR REPLACE FUNCTION public.enrol_athlete_in_catalogue_programme_version(
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
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'not_authenticated');
  END IF;
  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'athlete_role_required');
  END IF;
  IF NOT public.cohort_athlete_may_use_non_commercial_catalogue_enrolment() THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'catalogue_enrolment_not_authorised');
  END IF;
  IF p_programme_version_id IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_args');
  END IF;

  SELECT * INTO v_version FROM public.programme_versions WHERE id = p_programme_version_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'version_not_found');
  END IF;
  IF NOT public.cohort_programme_version_is_catalogue_eligible(p_programme_version_id) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'version_not_catalogue_eligible');
  END IF;
  SELECT l.code INTO v_lineage_code FROM public.programme_lineages l WHERE l.id = v_version.lineage_id;
  IF v_lineage_code IS NULL OR length(trim(v_lineage_code)) = 0 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'lineage_missing');
  END IF;

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
        'status', 'conflict', 'code', 'active_enrolment_exists',
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
    v_tz, v_week, v_day_key, v_slot, 'non_commercial_test'
  );

  IF v_replaced_id IS NOT NULL THEN
    UPDATE public.programme_assignments
    SET superseded_by_assignment_id = v_new_id, updated_at = NOW()
    WHERE id = v_replaced_id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'enrolled',
    'enrolment_id', v_new_id,
    'programme_version_id', p_programme_version_id,
    'lineage_code', v_lineage_code,
    'enrolment_source', 'non_commercial_test',
    'athlete_id', v_athlete_id,
    'replaced_enrolment_id', v_replaced_id,
    'started_at', v_started,
    'timezone', v_tz
  );
END;
$$;

REVOKE ALL ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) TO service_role;

COMMENT ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) IS
  'Authenticated catalogue enrolment pins one exact eligible version. Timezone must be a validated IANA name. started_at is the athlete-local civil date in that zone. Replacement remains unauthorised for the athlete product.';
