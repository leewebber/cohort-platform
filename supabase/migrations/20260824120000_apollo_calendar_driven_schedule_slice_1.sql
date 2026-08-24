-- Apollo Calendar-Driven Schedule Slice 1.
--
-- Adds a fixed-calendar lifecycle to the existing programme schedule
-- projection. Authored prescription and Plan Package v1 remain unchanged.

ALTER TABLE public.programme_assignments
  ADD COLUMN IF NOT EXISTS schedule_mode TEXT NOT NULL DEFAULT 'legacy_cursor';

ALTER TABLE public.programme_assignments
  DROP CONSTRAINT IF EXISTS programme_assignments_schedule_mode_check;
ALTER TABLE public.programme_assignments
  ADD CONSTRAINT programme_assignments_schedule_mode_check
  CHECK (schedule_mode IN ('legacy_cursor', 'fixed_schedule'));

ALTER TABLE public.programme_schedule_occurrences
  ADD COLUMN IF NOT EXISTS original_scheduled_date DATE;

ALTER TABLE public.programme_schedule_occurrences
  DROP CONSTRAINT IF EXISTS programme_schedule_occurrences_disposition_check;
ALTER TABLE public.programme_schedule_occurrences
  ADD CONSTRAINT programme_schedule_occurrences_disposition_check
  CHECK (disposition IN ('scheduled', 'skipped', 'completed', 'missed'));

UPDATE public.programme_schedule_occurrences
SET original_scheduled_date = scheduled_date
WHERE original_scheduled_date IS NULL;

ALTER TABLE public.programme_schedule_occurrences
  ALTER COLUMN original_scheduled_date SET NOT NULL;

CREATE OR REPLACE FUNCTION public.cohort_preserve_occurrence_original_date()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.original_scheduled_date IS NULL THEN
    NEW.original_scheduled_date := NEW.scheduled_date;
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.original_scheduled_date := OLD.original_scheduled_date;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS programme_schedule_occurrences_preserve_original_date
  ON public.programme_schedule_occurrences;
CREATE TRIGGER programme_schedule_occurrences_preserve_original_date
  BEFORE INSERT OR UPDATE ON public.programme_schedule_occurrences
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_preserve_occurrence_original_date();

REVOKE ALL ON FUNCTION public.cohort_preserve_occurrence_original_date()
  FROM PUBLIC;

COMMENT ON COLUMN public.programme_assignments.schedule_mode IS
  'fixed_schedule uses programme-local calendar occurrence authority; legacy_cursor is retained only as an explicit compatibility path.';
COMMENT ON COLUMN public.programme_schedule_occurrences.original_scheduled_date IS
  'Immutable initial fixed-calendar placement, preserved through reconciliation, execution, and late completion.';

-- Private clock-injectable reconciliation used by disposable database gates.
-- Production callers can reach only the one-argument wrapper below.
CREATE OR REPLACE FUNCTION public.cohort_reconcile_fixed_programme_schedule_at(
  p_assignment_id UUID,
  p_now TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_assignment public.programme_assignments%ROWTYPE;
  v_today DATE;
  v_changed INT := 0;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_role_required'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = p_assignment_id
    AND athlete_id = v_athlete
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_found'
    );
  END IF;
  IF v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.materialised_at IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'fixed_assignment_ineligible'
    );
  END IF;
  IF v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'unsupported_scheduling_mode'
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_timezone_names
    WHERE name = v_assignment.timezone
  ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_unavailable'
    );
  END IF;

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;
  PERFORM set_config('cohort.allow_schedule_write', 'on', true);

  UPDATE public.programme_schedule_occurrences o
  SET disposition = 'missed',
      updated_at = NOW()
  WHERE o.assignment_id = v_assignment.id
    AND o.scheduled_date < v_today
    AND o.disposition = 'scheduled'
    AND NOT EXISTS (
      SELECT 1
      FROM public.programme_slot_outcomes x
      WHERE x.assignment_id = o.assignment_id
        AND x.session_slot_id = o.session_slot_id
        AND x.outcome_status IN (
          'in_progress',
          'completed',
          'completed_partial'
        )
    );
  GET DIAGNOSTICS v_changed = ROW_COUNT;

  RETURN jsonb_build_object(
    'status', 'reconciled',
    'today', v_today,
    'missed_count', v_changed
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_reconcile_fixed_programme_schedule_at(
  UUID,
  TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reconcile_fixed_programme_schedule(
  p_assignment_id UUID
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.cohort_reconcile_fixed_programme_schedule_at(
    p_assignment_id,
    NOW()
  );
$$;

REVOKE ALL ON FUNCTION public.reconcile_fixed_programme_schedule(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_fixed_programme_schedule(UUID)
  TO authenticated;

-- Private typed occurrence JSON projection. Identity and state are derived
-- exclusively from immutable occurrence/authored linkage and server evidence.
CREATE OR REPLACE FUNCTION public.cohort_fixed_occurrence_projection_json(
  p_occurrence_id UUID,
  p_today DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'id', o.id,
    'session_slot_id', o.session_slot_id,
    'programme_version_id', o.programme_version_id,
    'scheduled_date', o.scheduled_date,
    'original_scheduled_date', o.original_scheduled_date,
    'week_number', o.week_number,
    'day_key', o.day_key,
    'session_order', o.session_order,
    'protocol_id', o.protocol_id,
    'programmed_session_key', o.programmed_session_key,
    'session_title', COALESCE(NULLIF(TRIM(p.name), ''), o.protocol_id),
    'session_lineage_id', p.session_lineage_id,
    'session_revision_number', p.revision_number,
    'training_session_id', x.training_session_id,
    'state', CASE
      WHEN o.disposition = 'completed'
        OR x.outcome_status IN ('completed', 'completed_partial')
        THEN 'COMPLETED'
      WHEN x.outcome_status = 'in_progress'
        AND o.scheduled_date < p_today
        THEN 'IN_PROGRESS_OVERDUE'
      WHEN x.outcome_status = 'in_progress'
        THEN 'IN_PROGRESS'
      WHEN o.disposition = 'missed' OR o.scheduled_date < p_today
        THEN 'MISSED'
      WHEN o.scheduled_date = p_today
        THEN 'TODAY'
      ELSE 'PLANNED'
    END
  )
  FROM public.programme_schedule_occurrences o
  JOIN public.performance_protocols p
    ON p.protocol_id = o.protocol_id
  LEFT JOIN public.programme_slot_outcomes x
    ON x.assignment_id = o.assignment_id
   AND x.session_slot_id = o.session_slot_id
  WHERE o.id = p_occurrence_id;
$$;

REVOKE ALL ON FUNCTION public.cohort_fixed_occurrence_projection_json(
  UUID,
  DATE
) FROM PUBLIC, anon, authenticated;

-- Private resolver accepts an injected clock for database proof. Production
-- RPCs below always pass NOW() and expose no client-controlled date.
CREATE OR REPLACE FUNCTION public.cohort_resolve_fixed_programme_calendar_at(
  p_assignment_id UUID,
  p_now TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_assignment public.programme_assignments%ROWTYPE;
  v_version public.programme_versions%ROWTYPE;
  v_today DATE;
  v_week_start DATE;
  v_week_end DATE;
  v_expected_count INT;
  v_actual_count INT;
  v_invalid_count INT;
  v_ensure JSONB;
  v_reconcile JSONB;
  v_occurrences JSONB;
  v_week JSONB;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_role_required'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = p_assignment_id
    AND athlete_id = v_athlete;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_found'
    );
  END IF;
  IF v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.materialised_at IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'fixed_assignment_ineligible'
    );
  END IF;
  IF v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'unsupported_scheduling_mode'
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_timezone_names
    WHERE name = v_assignment.timezone
  ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_unavailable'
    );
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_assignment.programme_version_id
    AND lifecycle_status = 'published'
    AND archived_at IS NULL
    AND package_content_hash = v_assignment.materialised_package_content_hash;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'exact_version_missing'
    );
  END IF;

  v_ensure := public.ensure_programme_schedule_projection(v_assignment.id);
  IF v_ensure->>'status' NOT IN ('initialised', 'already_exists') THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', COALESCE(v_ensure->>'code', 'projection_initialisation_failed')
    );
  END IF;

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;
  v_reconcile := public.cohort_reconcile_fixed_programme_schedule_at(
    v_assignment.id,
    p_now
  );
  IF v_reconcile->>'status' IS DISTINCT FROM 'reconciled' THEN
    RETURN v_reconcile;
  END IF;

  SELECT COUNT(*) INTO v_expected_count
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  JOIN public.programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_assignment.programme_version_id
    AND COALESCE(d.day_type, '') <> 'rest'
    AND NULLIF(TRIM(COALESCE(s.protocol_id, '')), '') IS NOT NULL;

  SELECT COUNT(*) INTO v_actual_count
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment.id;

  SELECT COUNT(*) INTO v_invalid_count
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
      OR o.disposition = 'skipped'
    );

  IF v_expected_count < 1
     OR v_actual_count IS DISTINCT FROM v_expected_count
     OR v_invalid_count <> 0
  THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', 'fixed_schedule_incomplete',
      'expected_occurrences', v_expected_count,
      'actual_occurrences', v_actual_count,
      'invalid_occurrences', v_invalid_count
    );
  END IF;

  SELECT jsonb_agg(
    public.cohort_fixed_occurrence_projection_json(o.id, v_today)
    ORDER BY o.scheduled_date, o.week_number, o.day_key, o.session_order
  ) INTO v_occurrences
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment.id;

  v_week_start := v_today - (EXTRACT(ISODOW FROM v_today)::INT - 1);
  v_week_end := v_week_start + 6;

  SELECT jsonb_agg(
    jsonb_build_object(
      'date', day_date,
      'state', COALESCE(occurrence_json->>'state', 'REST'),
      'occurrence', occurrence_json
    )
    ORDER BY day_date
  ) INTO v_week
  FROM (
    SELECT
      v_week_start + offset_value AS day_date,
      (
        SELECT public.cohort_fixed_occurrence_projection_json(o.id, v_today)
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment.id
          AND o.scheduled_date = v_week_start + offset_value
        ORDER BY o.week_number, o.day_key, o.session_order
        LIMIT 1
      ) AS occurrence_json
    FROM generate_series(0, 6) AS offset_value
  ) week_days;

  RETURN jsonb_build_object(
    'status', 'ok',
    'assignment_id', v_assignment.id,
    'programme_name', v_version.name,
    'scheduling_mode', v_assignment.schedule_mode,
    'today', v_today,
    'programme_timezone', v_assignment.timezone,
    'start_date', v_assignment.started_at,
    'week_start', v_week_start,
    'week_end', v_week_end,
    'occurrences', COALESCE(v_occurrences, '[]'::JSONB),
    'current_week', COALESCE(v_week, '[]'::JSONB)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_resolve_fixed_programme_calendar_at(
  UUID,
  TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.resolve_fixed_programme_calendar(
  p_assignment_id UUID
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.cohort_resolve_fixed_programme_calendar_at(
    p_assignment_id,
    NOW()
  );
$$;

REVOKE ALL ON FUNCTION public.resolve_fixed_programme_calendar(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_fixed_programme_calendar(UUID)
  TO authenticated;

-- Start Programme wrapper: exact selected date/timezone are committed before
-- the existing occurrence projection is materialised. Repeat calls with the
-- same selection are idempotent; changing an active selection fails closed.
CREATE OR REPLACE FUNCTION public.start_fixed_programme_from_enrolment(
  p_programme_assignment_id UUID,
  p_start_date DATE,
  p_timezone TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_result JSONB;
  v_ensure JSONB;
  v_assignment public.programme_assignments%ROWTYPE;
  v_today DATE;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_role_required'
    );
  END IF;
  IF p_start_date IS NULL
     OR NULLIF(TRIM(COALESCE(p_timezone, '')), '') IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'start_date_and_timezone_required'
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = p_timezone) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_unavailable'
    );
  END IF;
  v_today := public.cohort_resolve_athlete_local_date(p_timezone);
  IF p_start_date < v_today THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'start_date_in_past'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = p_programme_assignment_id
    AND athlete_id = v_athlete
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_found'
    );
  END IF;

  IF v_assignment.materialised_at IS NOT NULL THEN
    IF v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule' THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'active_assignment_requires_replacement_flow'
      );
    END IF;
    IF v_assignment.started_at IS DISTINCT FROM p_start_date
       OR v_assignment.timezone IS DISTINCT FROM p_timezone
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'fixed_start_selection_conflict'
      );
    END IF;
    v_ensure := public.ensure_programme_schedule_projection(v_assignment.id);
    IF v_ensure->>'status' NOT IN ('initialised', 'already_exists') THEN
      RETURN jsonb_build_object(
        'status', 'integrity_failure',
        'code', COALESCE(v_ensure->>'code', 'projection_initialisation_failed')
      );
    END IF;
    RETURN jsonb_build_object(
      'status', 'already_materialised',
      'code', 'fixed_start_already_materialised',
      'enrolment_id', v_assignment.id,
      'programme_version_id', v_assignment.programme_version_id,
      'athlete_id', v_assignment.athlete_id,
      'lineage_code', v_assignment.lineage_code,
      'materialised_at', v_assignment.materialised_at,
      'materialisation_source', v_assignment.materialisation_source,
      'materialised_package_content_hash', v_assignment.materialised_package_content_hash,
      'materialised_package_schema_version', v_assignment.materialised_package_schema_version,
      'started_at', v_assignment.started_at,
      'timezone', v_assignment.timezone,
      'schedule_mode', v_assignment.schedule_mode,
      'current_week_number', v_assignment.current_week_number,
      'current_day_key', v_assignment.current_day_key,
      'current_slot_order', v_assignment.current_slot_order
    );
  END IF;

  IF v_assignment.schedule_mode IS DISTINCT FROM 'legacy_cursor' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'unsupported_scheduling_mode'
    );
  END IF;

  v_result := public.materialise_athlete_plan_from_enrolment(
    p_programme_assignment_id,
    p_timezone
  );
  IF v_result->>'status' IS DISTINCT FROM 'materialised' THEN
    RETURN v_result;
  END IF;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  UPDATE public.programme_assignments
  SET started_at = p_start_date,
      timezone = p_timezone,
      schedule_mode = 'fixed_schedule',
      updated_at = NOW()
  WHERE id = p_programme_assignment_id
    AND athlete_id = v_athlete
  RETURNING * INTO v_assignment;

  v_ensure := public.ensure_programme_schedule_projection(v_assignment.id);
  IF v_ensure->>'status' NOT IN ('initialised', 'already_exists') THEN
    RAISE EXCEPTION 'fixed schedule projection failed: %', v_ensure;
  END IF;

  RETURN v_result || jsonb_build_object(
    'started_at', v_assignment.started_at,
    'timezone', v_assignment.timezone,
    'schedule_mode', v_assignment.schedule_mode
  );
END;
$$;

REVOKE ALL ON FUNCTION public.start_fixed_programme_from_enrolment(
  UUID,
  DATE,
  TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_fixed_programme_from_enrolment(
  UUID,
  DATE,
  TEXT
) TO authenticated;

-- Private clock-injectable occurrence-bound create/resume implementation.
CREATE OR REPLACE FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(
  p_occurrence_id UUID,
  p_now TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_assignment public.programme_assignments%ROWTYPE;
  v_version public.programme_versions%ROWTYPE;
  v_outcome public.programme_slot_outcomes%ROWTYPE;
  v_session public.training_sessions%ROWTYPE;
  v_authored RECORD;
  v_today DATE;
  v_expected_key TEXT;
  v_outcome_found BOOLEAN := FALSE;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required'
    );
  END IF;
  IF p_occurrence_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_occurrence_id'
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84202408, hashtext(p_occurrence_id::TEXT));

  SELECT * INTO v_occ
  FROM public.programme_schedule_occurrences
  WHERE id = p_occurrence_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_missing'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_occ.assignment_id
  FOR UPDATE;
  IF NOT FOUND OR v_assignment.athlete_id IS DISTINCT FROM v_athlete THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'cross_athlete_occurrence'
    );
  END IF;
  IF v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.materialised_at IS NULL
     OR v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'fixed_assignment_ineligible'
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_timezone_names WHERE name = v_assignment.timezone
  ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_unavailable'
    );
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_assignment.programme_version_id
    AND lifecycle_status = 'published'
    AND archived_at IS NULL
    AND package_content_hash = v_assignment.materialised_package_content_hash;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'exact_version_missing'
    );
  END IF;

  SELECT
    w.version_id,
    w.week_number,
    d.day_key,
    s.session_order,
    s.protocol_id,
    p.lifecycle_status,
    p.archived_at
  INTO v_authored
  FROM public.programme_version_session_slots s
  JOIN public.programme_version_days d ON d.id = s.day_id
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  JOIN public.performance_protocols p ON p.protocol_id = s.protocol_id
  WHERE s.id = v_occ.session_slot_id;

  v_expected_key := public.cohort_programme_schedule_programmed_session_key(
    v_occ.assignment_id,
    v_occ.programme_version_id,
    v_occ.week_number,
    v_occ.day_key,
    v_occ.session_order,
    v_occ.protocol_id
  );
  IF v_authored.version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_authored.week_number IS DISTINCT FROM v_occ.week_number
     OR v_authored.day_key IS DISTINCT FROM v_occ.day_key
     OR v_authored.session_order IS DISTINCT FROM v_occ.session_order
     OR v_authored.protocol_id IS DISTINCT FROM v_occ.protocol_id
     OR v_authored.lifecycle_status IS DISTINCT FROM 'published'
     OR v_authored.archived_at IS NOT NULL
     OR v_occ.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_occ.package_content_hash IS DISTINCT FROM v_assignment.materialised_package_content_hash
     OR v_occ.programmed_session_key IS DISTINCT FROM v_expected_key
  THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', 'occurrence_lineage_mismatch'
    );
  END IF;

  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_occ.assignment_id
    AND session_slot_id = v_occ.session_slot_id
  FOR UPDATE;
  v_outcome_found := FOUND;

  IF v_outcome_found
     AND v_outcome.training_session_id IS NOT NULL
  THEN
    SELECT * INTO v_session
    FROM public.training_sessions
    WHERE id = v_outcome.training_session_id
    FOR UPDATE;
    IF NOT FOUND
       OR v_outcome.outcome_status IS DISTINCT FROM 'in_progress'
       OR v_session.athlete_id IS DISTINCT FROM v_athlete::TEXT
       OR v_session.status IS DISTINCT FROM 'in_progress'
       OR v_session.protocol_id IS DISTINCT FROM v_occ.protocol_id
       OR v_session.programme_id NOT IN (
         v_assignment.lineage_code,
         v_assignment.programme_version_id::TEXT
       )
       OR v_session.week_number IS DISTINCT FROM v_occ.week_number
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'occurrence_session_integrity_failure'
      );
    END IF;
    RETURN jsonb_build_object(
      'status', 'resumed',
      'code', 'existing_session',
      'training_session', to_jsonb(v_session) || jsonb_build_object('day', v_occ.day_key),
      'occurrence_id', v_occ.id,
      'original_scheduled_date', v_occ.original_scheduled_date,
      'programmed_session_key', v_occ.programmed_session_key
    );
  END IF;

  IF v_outcome_found
     AND v_outcome.outcome_status IN ('completed', 'completed_partial')
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'completed_occurrence'
    );
  END IF;
  IF v_outcome_found AND v_outcome.outcome_status = 'in_progress' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_session_integrity_failure'
    );
  END IF;

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;
  IF v_occ.disposition = 'missed' OR v_occ.scheduled_date < v_today THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'missed_occurrence'
    );
  END IF;
  IF v_occ.disposition = 'completed' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'completed_occurrence'
    );
  END IF;
  IF v_occ.disposition IS DISTINCT FROM 'scheduled' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'fixed_occurrence_ineligible'
    );
  END IF;
  IF v_occ.scheduled_date > v_today THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'future_occurrence'
    );
  END IF;

  INSERT INTO public.training_sessions (
    athlete_id,
    protocol_id,
    programme_id,
    week_number,
    status,
    started_at,
    created_at,
    updated_at
  ) VALUES (
    v_athlete::TEXT,
    v_occ.protocol_id,
    v_assignment.lineage_code,
    v_occ.week_number,
    'in_progress',
    NOW(),
    NOW(),
    NOW()
  )
  RETURNING * INTO v_session;

  IF v_outcome_found THEN
    UPDATE public.programme_slot_outcomes
    SET outcome_status = 'in_progress',
        training_session_id = v_session.id,
        programme_version_id = v_occ.programme_version_id,
        materialised_package_content_hash = v_occ.package_content_hash,
        programmed_session_key = v_occ.programmed_session_key,
        resolved_at = NULL
    WHERE id = v_outcome.id;
  ELSE
    INSERT INTO public.programme_slot_outcomes (
      assignment_id,
      session_slot_id,
      week_number,
      day_key,
      session_order,
      outcome_status,
      training_session_id,
      programme_version_id,
      materialised_package_content_hash,
      programmed_session_key
    ) VALUES (
      v_occ.assignment_id,
      v_occ.session_slot_id,
      v_occ.week_number,
      v_occ.day_key,
      v_occ.session_order,
      'in_progress',
      v_session.id,
      v_occ.programme_version_id,
      v_occ.package_content_hash,
      v_occ.programmed_session_key
    );
  END IF;

  RETURN jsonb_build_object(
    'status', 'created',
    'code', 'session_created',
    'training_session', to_jsonb(v_session) || jsonb_build_object('day', v_occ.day_key),
    'occurrence_id', v_occ.id,
    'original_scheduled_date', v_occ.original_scheduled_date,
    'programmed_session_key', v_occ.programmed_session_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(
  UUID,
  TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_or_resume_fixed_programme_occurrence_session(
  p_occurrence_id UUID
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.cohort_create_or_resume_fixed_occurrence_at(
    p_occurrence_id,
    NOW()
  );
$$;

REVOKE ALL ON FUNCTION public.create_or_resume_fixed_programme_occurrence_session(
  UUID
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_or_resume_fixed_programme_occurrence_session(
  UUID
) TO authenticated;

-- Fixed completion validates the occurrence linkage, then delegates actuals
-- persistence to the established atomic completion function. The cursor is
-- retained only as monotonic compatibility history and never selects Today.
CREATE OR REPLACE FUNCTION public.complete_fixed_programme_occurrence_and_advance(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_occurrence_id UUID;
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_assignment public.programme_assignments%ROWTYPE;
  v_outcome public.programme_slot_outcomes%ROWTYPE;
  v_result JSONB;
  v_old_week INT;
  v_old_day TEXT;
  v_old_slot INT;
  v_old_status TEXT;
  v_old_completed_at TIMESTAMPTZ;
  v_old_order BIGINT;
  v_occ_order BIGINT;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required'
    );
  END IF;
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object'
     OR NULLIF(payload->>'occurrence_id', '') IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_occurrence_id'
    );
  END IF;
  BEGIN
    v_occurrence_id := (payload->>'occurrence_id')::UUID;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_occurrence_id'
    );
  END;

  PERFORM pg_advisory_xact_lock(84202409, hashtext(v_occurrence_id::TEXT));
  SELECT * INTO v_occ
  FROM public.programme_schedule_occurrences
  WHERE id = v_occurrence_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_missing'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_occ.assignment_id
  FOR UPDATE;
  IF NOT FOUND OR v_assignment.athlete_id IS DISTINCT FROM v_athlete THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'cross_athlete_occurrence'
    );
  END IF;
  IF v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule'
     OR v_assignment.materialised_at IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'fixed_assignment_ineligible'
    );
  END IF;

  IF payload->>'assignment_id' IS DISTINCT FROM v_occ.assignment_id::TEXT
     OR payload->>'session_slot_id' IS DISTINCT FROM v_occ.session_slot_id::TEXT
     OR payload->>'programme_version_id' IS DISTINCT FROM v_occ.programme_version_id::TEXT
     OR payload->>'materialised_package_content_hash' IS DISTINCT FROM v_occ.package_content_hash
     OR payload->>'programmed_session_key' IS DISTINCT FROM v_occ.programmed_session_key
     OR payload->>'logical_completion_key' IS DISTINCT FROM v_occ.programmed_session_key
     OR payload->>'protocol_id' IS DISTINCT FROM v_occ.protocol_id
     OR (payload->>'expected_week')::INT IS DISTINCT FROM v_occ.week_number
     OR payload->>'expected_day_key' IS DISTINCT FROM v_occ.day_key
     OR (payload->>'expected_slot_order')::INT IS DISTINCT FROM v_occ.session_order
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_lineage_mismatch'
    );
  END IF;

  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_occ.assignment_id
    AND session_slot_id = v_occ.session_slot_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_outcome.training_session_id::TEXT IS DISTINCT FROM payload->>'training_session_id'
     OR v_outcome.programme_version_id IS DISTINCT FROM v_occ.programme_version_id
     OR v_outcome.materialised_package_content_hash IS DISTINCT FROM v_occ.package_content_hash
     OR v_outcome.programmed_session_key IS DISTINCT FROM v_occ.programmed_session_key
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_session_integrity_failure'
    );
  END IF;

  v_old_week := v_assignment.current_week_number;
  v_old_day := v_assignment.current_day_key;
  v_old_slot := v_assignment.current_slot_order;
  v_old_status := v_assignment.status;
  v_old_completed_at := v_assignment.completed_at;

  WITH ordered AS (
    SELECT
      w.week_number,
      d.day_key,
      s.session_order,
      ROW_NUMBER() OVER (
        ORDER BY w.week_number, d.day_order, s.session_order
      ) AS ordinal
    FROM public.programme_version_weeks w
    JOIN public.programme_version_days d ON d.week_id = w.id
    JOIN public.programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = v_assignment.programme_version_id
      AND COALESCE(d.day_type, '') <> 'rest'
      AND NULLIF(TRIM(COALESCE(s.protocol_id, '')), '') IS NOT NULL
  )
  SELECT
    MAX(ordinal) FILTER (
      WHERE week_number = v_old_week
        AND day_key = v_old_day
        AND session_order = v_old_slot
    ),
    MAX(ordinal) FILTER (
      WHERE week_number = v_occ.week_number
        AND day_key = v_occ.day_key
        AND session_order = v_occ.session_order
    )
  INTO v_old_order, v_occ_order
  FROM ordered;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  UPDATE public.programme_assignments
  SET current_week_number = v_occ.week_number,
      current_day_key = v_occ.day_key,
      current_slot_order = v_occ.session_order,
      updated_at = NOW()
  WHERE id = v_assignment.id;

  v_result := public.complete_programme_session_and_advance(
    payload - 'occurrence_id'
  );

  IF v_result->>'status' IN ('committed', 'already_committed') THEN
    PERFORM set_config('cohort.allow_schedule_write', 'on', true);
    UPDATE public.programme_schedule_occurrences
    SET disposition = 'completed',
        updated_at = NOW()
    WHERE id = v_occ.id;

    IF v_old_order IS NOT NULL
       AND v_occ_order IS NOT NULL
       AND v_old_order > v_occ_order
    THEN
      PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
      UPDATE public.programme_assignments
      SET current_week_number = v_old_week,
          current_day_key = v_old_day,
          current_slot_order = v_old_slot,
          status = v_old_status,
          completed_at = v_old_completed_at,
          updated_at = NOW()
      WHERE id = v_assignment.id;
    END IF;

    RETURN v_result || jsonb_build_object(
      'occurrence_id', v_occ.id,
      'original_scheduled_date', v_occ.original_scheduled_date
    );
  END IF;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  UPDATE public.programme_assignments
  SET current_week_number = v_old_week,
      current_day_key = v_old_day,
      current_slot_order = v_old_slot,
      status = v_old_status,
      completed_at = v_old_completed_at,
      updated_at = NOW()
  WHERE id = v_assignment.id;
  RETURN v_result;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_lineage_mismatch'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_fixed_programme_occurrence_and_advance(
  JSONB
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_fixed_programme_occurrence_and_advance(
  JSONB
) TO authenticated;

CREATE OR REPLACE FUNCTION public.resolve_active_fixed_programme_calendar()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_assignment public.programme_assignments%ROWTYPE;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete
    AND status = 'active'
  ORDER BY updated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'absent',
      'code', 'no_active_assignment'
    );
  END IF;
  IF v_assignment.schedule_mode = 'legacy_cursor' THEN
    RETURN jsonb_build_object(
      'status', 'absent',
      'code', 'legacy_cursor_assignment'
    );
  END IF;
  IF v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule' THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', 'unsupported_scheduling_mode'
    );
  END IF;
  RETURN public.resolve_fixed_programme_calendar(v_assignment.id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_active_fixed_programme_calendar()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_active_fixed_programme_calendar()
  TO authenticated;
