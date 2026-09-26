-- Private occurrence-backed enrolments receive fixed_schedule at creation.
-- Bounded service-role repair for already-used private assignments that
-- inherited the legacy_cursor default. Forward-only. Does not edit
-- 20260926120000-20260926190000.

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
    timezone, current_week_number, current_day_key, current_slot_order, enrolment_source,
    schedule_mode
  ) VALUES (
    v_new_id, v_athlete_id, p_programme_version_id, v_lineage_code, 'active', v_started,
    v_tz, v_week, v_day_key, v_slot, v_source,
    'fixed_schedule'
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
    'materialised', TRUE,
    'schedule_mode', 'fixed_schedule'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, BOOLEAN) IS
  'Authenticated private exact-version enrol. Occurrence-backed materialised assignments are created as fixed_schedule. Replace-active retains the prior assignment as reassigned. Catalogue versions are rejected.';

CREATE OR REPLACE FUNCTION public.enrol_athlete_in_private_programme_version(
  p_programme_version_id UUID,
  p_timezone TEXT,
  p_started_at DATE,
  p_replace_active BOOLEAN
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
  IF p_programme_version_id IS NULL OR p_started_at IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_args');
  END IF;

  SELECT * INTO v_version FROM public.programme_versions WHERE id = p_programme_version_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'version_not_found');
  END IF;
  IF public.cohort_programme_version_is_catalogue_eligible(p_programme_version_id) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'use_catalogue_enrolment');
  END IF;
  IF v_version.lifecycle_status IS DISTINCT FROM 'published'
     OR v_version.archived_at IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'version_not_private_eligible');
  END IF;
  IF NOT public.cohort_programme_version_is_private_assignable(p_programme_version_id) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'version_not_private_eligible');
  END IF;
  IF NOT public.cohort_athlete_may_enrol_private_programme_version(p_programme_version_id) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'private_enrolment_not_authorised');
  END IF;

  SELECT l.code INTO v_lineage_code FROM public.programme_lineages l WHERE l.id = v_version.lineage_id;
  IF v_lineage_code IS NULL OR length(trim(v_lineage_code)) = 0 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'lineage_missing');
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
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_timezone');
  END IF;

  v_started := p_started_at;

  PERFORM pg_advisory_xact_lock(84202613, hashtext(v_athlete_id::text));

  SELECT * INTO v_active
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete_id AND status = 'active'
  FOR UPDATE;

  IF FOUND THEN
    IF v_active.programme_version_id = p_programme_version_id THEN
      IF v_active.timezone IS NOT DISTINCT FROM v_tz
         AND v_active.started_at IS NOT DISTINCT FROM v_started THEN
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
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'start_date_mismatch',
        'enrolment_id', v_active.id,
        'programme_version_id', v_active.programme_version_id,
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
    timezone, current_week_number, current_day_key, current_slot_order, enrolment_source,
    schedule_mode
  ) VALUES (
    v_new_id, v_athlete_id, p_programme_version_id, v_lineage_code, 'active', v_started,
    v_tz, v_week, v_day_key, v_slot, v_source,
    'fixed_schedule'
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
    'materialised', TRUE,
    'schedule_mode', 'fixed_schedule'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, DATE, BOOLEAN)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, DATE, BOOLEAN)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, DATE, BOOLEAN) IS
  'Authenticated private enrol with an explicit athlete-local civil start date. Occurrence-backed materialised assignments are created as fixed_schedule.';

-- Bounded service-role repair: schedule_mode only.

CREATE OR REPLACE FUNCTION public.repair_private_materialised_assignment_schedule_mode(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $repair$
DECLARE
  v_assignment_id UUID;
  v_version_id UUID;
  v_hash TEXT;
  v_assignment public.programme_assignments%ROWTYPE;
  v_version public.programme_versions%ROWTYPE;
  v_expected INT;
  v_actual INT;
  v_invalid INT;
  v_completed_occ INT;
  v_evidence INT;
  v_before_mode TEXT;
  v_after public.programme_assignments%ROWTYPE;
  v_records_before INT;
  v_records_after INT;
  v_outcomes_before INT;
  v_outcomes_after INT;
  v_sessions_before INT;
  v_sessions_after INT;
  v_occ_fp_before TEXT;
  v_occ_fp_after TEXT;
BEGIN
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_payload');
  END IF;

  BEGIN
    v_assignment_id := (payload->>'assignment_id')::UUID;
    v_version_id := (payload->>'programme_version_id')::UUID;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_identity');
  END;

  v_hash := lower(trim(COALESCE(payload->>'package_content_hash', '')));
  IF v_assignment_id IS NULL OR v_version_id IS NULL OR v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_identity');
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'not_found', 'code', 'assignment_not_found');
  END IF;

  IF v_assignment.programme_version_id IS DISTINCT FROM v_version_id
     OR v_assignment.materialised_package_content_hash IS DISTINCT FROM v_hash THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'assignment_not_repairable');
  END IF;

  IF v_assignment.status IS DISTINCT FROM 'active'
     AND v_assignment.status IS DISTINCT FROM 'completed' THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'assignment_not_repairable');
  END IF;

  IF v_assignment.materialised_at IS NULL THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'assignment_not_materialised');
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_version_id;

  IF NOT FOUND
     OR v_version.package_content_hash IS DISTINCT FROM v_hash
     OR v_version.lifecycle_status IS DISTINCT FROM 'published'
     OR v_version.archived_at IS NOT NULL
     OR NOT public.cohort_programme_version_is_private_assignable(v_version_id) THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'version_not_repairable');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_timezone_names WHERE name = v_assignment.timezone
  ) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'timezone_unavailable');
  END IF;

  SELECT COUNT(*) INTO v_expected
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  JOIN public.programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_assignment.programme_version_id
    AND COALESCE(d.day_type, '') <> 'rest'
    AND NULLIF(TRIM(COALESCE(s.protocol_id, '')), '') IS NOT NULL;

  SELECT COUNT(*) INTO v_actual
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment.id;

  SELECT COUNT(*) INTO v_invalid
  FROM public.programme_schedule_occurrences o
  LEFT JOIN public.programme_version_session_slots s
    ON s.id = o.session_slot_id
  LEFT JOIN public.programme_version_days d ON d.id = s.day_id
  LEFT JOIN public.programme_version_weeks w ON w.id = d.week_id
  LEFT JOIN public.performance_protocols p ON p.protocol_id = o.protocol_id
  WHERE o.assignment_id = v_assignment.id
    AND (
      o.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
      OR o.package_content_hash IS DISTINCT FROM v_assignment.materialised_package_content_hash
      OR w.version_id IS DISTINCT FROM v_assignment.programme_version_id
      OR w.week_number IS DISTINCT FROM o.week_number
      OR d.day_key IS DISTINCT FROM o.day_key
      OR s.session_order IS DISTINCT FROM o.session_order
      OR s.protocol_id IS DISTINCT FROM o.protocol_id
      OR o.programmed_session_key IS DISTINCT FROM
        public.cohort_programme_schedule_programmed_session_key(
          o.assignment_id,
          o.programme_version_id,
          o.week_number,
          o.day_key,
          o.session_order,
          o.protocol_id
        )
      OR p.protocol_id IS NULL
      OR p.lifecycle_status IS DISTINCT FROM 'published'
      OR p.archived_at IS NOT NULL
    );

  IF v_expected < 1
     OR v_actual IS DISTINCT FROM v_expected
     OR v_invalid <> 0 THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', 'fixed_schedule_incomplete',
      'expected_occurrences', v_expected,
      'actual_occurrences', v_actual,
      'invalid_occurrences', v_invalid
    );
  END IF;

  SELECT COUNT(*) INTO v_completed_occ
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment.id
    AND o.disposition = 'completed';

  SELECT
    (
      SELECT COUNT(*)
      FROM public.programme_slot_outcomes so
      WHERE so.assignment_id = v_assignment.id
        AND so.outcome_status = 'completed'
    )
    + (
      SELECT COUNT(*)
      FROM public.training_session_records r
      WHERE r.assignment_id = v_assignment.id
        AND r.status = 'completed'
    )
    + (
      SELECT COUNT(*)
      FROM public.training_sessions t
      WHERE t.athlete_id = v_assignment.athlete_id::text
        AND t.status = 'completed'
        AND t.protocol_id IN (
          SELECT o.protocol_id
          FROM public.programme_schedule_occurrences o
          WHERE o.assignment_id = v_assignment.id
        )
    )
  INTO v_evidence;

  IF v_completed_occ > 0 AND COALESCE(v_evidence, 0) < v_completed_occ THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', 'session_evidence_incomplete',
      'completed_occurrences', v_completed_occ,
      'evidenced_completions', v_evidence
    );
  END IF;

  SELECT COUNT(*) INTO v_records_before
  FROM public.training_session_records
  WHERE assignment_id = v_assignment.id;

  SELECT COUNT(*) INTO v_outcomes_before
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment.id;

  SELECT COUNT(*) INTO v_sessions_before
  FROM public.training_sessions t
  WHERE t.athlete_id = v_assignment.athlete_id::text
    AND t.protocol_id IN (
      SELECT o.protocol_id
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment.id
    );

  SELECT md5(string_agg(o.id::text || '|' || o.scheduled_date::text || '|'
      || o.disposition || '|' || o.session_order::text, ',' ORDER BY o.session_order, o.id))
    INTO v_occ_fp_before
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment.id;

  v_before_mode := v_assignment.schedule_mode;

  IF v_before_mode = 'fixed_schedule' THEN
    RETURN jsonb_build_object(
      'status', 'already_repaired',
      'assignment_id', v_assignment.id,
      'programme_version_id', v_assignment.programme_version_id,
      'schedule_mode', v_before_mode,
      'expected_occurrences', v_expected,
      'actual_occurrences', v_actual,
      'invalid_occurrences', v_invalid,
      'session_records', v_records_before,
      'slot_outcomes', v_outcomes_before,
      'training_sessions', v_sessions_before,
      'completed_occurrences', v_completed_occ
    );
  END IF;

  IF v_before_mode IS DISTINCT FROM 'legacy_cursor' THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'assignment_not_repairable');
  END IF;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  UPDATE public.programme_assignments
  SET schedule_mode = 'fixed_schedule',
      updated_at = NOW()
  WHERE id = v_assignment.id
    AND schedule_mode = 'legacy_cursor'
    AND programme_version_id = v_version_id
    AND materialised_package_content_hash = v_hash
    AND materialised_at IS NOT NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'assignment_not_repairable');
  END IF;

  SELECT * INTO v_after
  FROM public.programme_assignments
  WHERE id = v_assignment.id;

  SELECT COUNT(*) INTO v_records_after
  FROM public.training_session_records
  WHERE assignment_id = v_assignment.id;

  SELECT COUNT(*) INTO v_outcomes_after
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment.id;

  SELECT COUNT(*) INTO v_sessions_after
  FROM public.training_sessions t
  WHERE t.athlete_id = v_assignment.athlete_id::text
    AND t.protocol_id IN (
      SELECT o.protocol_id
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment.id
    );

  SELECT md5(string_agg(o.id::text || '|' || o.scheduled_date::text || '|'
      || o.disposition || '|' || o.session_order::text, ',' ORDER BY o.session_order, o.id))
    INTO v_occ_fp_after
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment.id;

  IF v_after.schedule_mode IS DISTINCT FROM 'fixed_schedule'
     OR v_after.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_after.materialised_package_content_hash IS DISTINCT FROM v_assignment.materialised_package_content_hash
     OR v_after.materialised_at IS DISTINCT FROM v_assignment.materialised_at
     OR v_after.lineage_code IS DISTINCT FROM v_assignment.lineage_code
     OR v_after.started_at IS DISTINCT FROM v_assignment.started_at
     OR v_after.timezone IS DISTINCT FROM v_assignment.timezone
     OR v_after.current_week_number IS DISTINCT FROM v_assignment.current_week_number
     OR v_after.current_day_key IS DISTINCT FROM v_assignment.current_day_key
     OR v_after.current_slot_order IS DISTINCT FROM v_assignment.current_slot_order
     OR v_after.last_progressed_training_session_id
          IS DISTINCT FROM v_assignment.last_progressed_training_session_id
     OR v_after.status IS DISTINCT FROM v_assignment.status
     OR v_after.completed_at IS DISTINCT FROM v_assignment.completed_at
     OR v_occ_fp_after IS DISTINCT FROM v_occ_fp_before
     OR v_records_after IS DISTINCT FROM v_records_before
     OR v_outcomes_after IS DISTINCT FROM v_outcomes_before
     OR v_sessions_after IS DISTINCT FROM v_sessions_before THEN
    RAISE EXCEPTION 'schedule_mode repair mutated protected assignment state'
      USING ERRCODE = '40001';
  END IF;

  RETURN jsonb_build_object(
    'status', 'repaired',
    'assignment_id', v_after.id,
    'programme_version_id', v_after.programme_version_id,
    'schedule_mode', v_after.schedule_mode,
    'previous_schedule_mode', v_before_mode,
    'expected_occurrences', v_expected,
    'actual_occurrences', v_actual,
    'invalid_occurrences', v_invalid,
    'session_records', v_records_after,
    'slot_outcomes', v_outcomes_after,
    'training_sessions', v_sessions_after,
    'completed_occurrences', v_completed_occ
  );
END;
$repair$;

REVOKE ALL ON FUNCTION public.repair_private_materialised_assignment_schedule_mode(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.repair_private_materialised_assignment_schedule_mode(JSONB)
  TO service_role;

COMMENT ON FUNCTION public.repair_private_materialised_assignment_schedule_mode(JSONB) IS
  'Service-role only. Sets schedule_mode to fixed_schedule for a verified private materialised assignment. Preserves pin, cursor, dates, occurrences, sessions, and outcomes.';
