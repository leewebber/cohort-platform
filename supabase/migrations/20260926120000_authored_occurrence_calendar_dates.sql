-- Authored-day schedule dates and same-day week projection.
-- Replaces per-slot date increment. Does not change Plan Package schema.
-- No hosted apply.

CREATE OR REPLACE FUNCTION public.cohort_authored_calendar_offset_days(
  p_week_number INT,
  p_day_order INT
)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_week_number IS NULL OR p_week_number < 1
     OR p_day_order IS NULL OR p_day_order < 1 THEN
    RAISE EXCEPTION 'week_number and day_order must be >= 1'
      USING ERRCODE = 22023;
  END IF;
  RETURN ((p_week_number - 1) * 7) + (p_day_order - 1);
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_authored_calendar_offset_days(INT, INT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_authored_calendar_offset_days(INT, INT)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cohort_authored_calendar_offset_days(INT, INT) IS
  'Civil-day offset: ((week_number - 1) * 7) + (day_order - 1). day_order is not clamped to 7.';

CREATE OR REPLACE FUNCTION public.cohort_authored_occurrence_date(
  p_started_at DATE,
  p_week_number INT,
  p_day_order INT
)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT p_started_at + public.cohort_authored_calendar_offset_days(
    p_week_number,
    p_day_order
  );
$$;

REVOKE ALL ON FUNCTION public.cohort_authored_occurrence_date(DATE, INT, INT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_authored_occurrence_date(DATE, INT, INT)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cohort_authored_occurrence_date(DATE, INT, INT) IS
  'Assignment local start date plus authored week/day offset. No slot-index dating.';


CREATE OR REPLACE FUNCTION public.ensure_programme_schedule_projection(
  p_programme_assignment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_assignment public.programme_assignments%ROWTYPE;
  v_existing public.programme_schedule_projections%ROWTYPE;
  v_hash TEXT;
  v_slot RECORD;
  v_scheduled DATE;
  v_dup INT := 0;
  v_disposition TEXT;
  v_outcome TEXT;
  v_psk TEXT;
  v_count INT := 0;
  v_projection JSONB;
  v_idem TEXT;
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

  -- Serialise ensure attempts per assignment.
  PERFORM pg_advisory_xact_lock(
    84201703,
    hashtext(p_programme_assignment_id::text)
  );

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

  IF v_assignment.materialised_at IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'assignment_not_materialised',
      'assignment_id', v_assignment.id
    );
  END IF;

  IF v_assignment.status IS DISTINCT FROM 'active'
     AND v_assignment.status IS DISTINCT FROM 'paused'
     AND v_assignment.status IS DISTINCT FROM 'completed'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'assignment_ineligible',
      'assignment_id', v_assignment.id,
      'assignment_status', v_assignment.status
    );
  END IF;

  v_hash := nullif(trim(COALESCE(v_assignment.materialised_package_content_hash, '')), '');
  IF v_hash IS NULL OR v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'package_provenance_mismatch',
      'assignment_id', v_assignment.id
    );
  END IF;

  IF nullif(trim(COALESCE(v_assignment.timezone, '')), '') IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_required',
      'assignment_id', v_assignment.id
    );
  END IF;

  SELECT * INTO v_existing
  FROM public.programme_schedule_projections
  WHERE assignment_id = v_assignment.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
       OR v_existing.package_content_hash IS DISTINCT FROM v_hash
       OR v_existing.timezone IS DISTINCT FROM v_assignment.timezone
       OR v_existing.started_at IS DISTINCT FROM v_assignment.started_at
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'projection_provenance_conflict',
        'assignment_id', v_assignment.id,
        'projection', public.cohort_programme_schedule_projection_json(v_assignment.id)
      );
    END IF;

    v_projection := public.cohort_programme_schedule_projection_json(v_assignment.id);
    RETURN jsonb_build_object(
      'status', 'already_exists',
      'code', 'projection_already_exists',
      'assignment_id', v_assignment.id,
      'schedule_revision', v_existing.schedule_revision,
      'projection', v_projection
    );
  END IF;

  -- Count executable slots (non-rest, protocol present).
  SELECT COUNT(*) INTO v_count
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  JOIN public.programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_assignment.programme_version_id
    AND COALESCE(d.day_type, '') <> 'rest'
    AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL;

  IF v_count IS NULL OR v_count < 1 THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'empty_programme_structure',
      'assignment_id', v_assignment.id,
      'programme_version_id', v_assignment.programme_version_id
    );
  END IF;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);

  -- Sprint 1.7F: current packages carry no authored horizon. NULL is an
  -- explicit unbounded statement, never a derivation from duration_weeks.
  INSERT INTO public.programme_schedule_projections (
    assignment_id,
    athlete_id,
    programme_version_id,
    package_content_hash,
    timezone,
    started_at,
    schedule_revision,
    schema_version,
    scheduling_horizon_end
  ) VALUES (
    v_assignment.id,
    v_athlete_id,
    v_assignment.programme_version_id,
    v_hash,
    v_assignment.timezone,
    v_assignment.started_at,
    0,
    'programme.schedule.projection.v1',
    NULL
  );

  SELECT COUNT(*) INTO v_dup
  FROM (
    SELECT w.week_number, d.day_order, s.session_order
    FROM public.programme_version_weeks w
    JOIN public.programme_version_days d ON d.week_id = w.id
    JOIN public.programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = v_assignment.programme_version_id
      AND COALESCE(d.day_type, '') <> 'rest'
      AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
    GROUP BY w.week_number, d.day_order, s.session_order
    HAVING COUNT(*) > 1
  ) ambiguous;
  IF COALESCE(v_dup, 0) > 0 THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'ambiguous_same_day_order',
      'assignment_id', v_assignment.id
    );
  END IF;

  FOR v_slot IN
    SELECT
      s.id AS session_slot_id,
      w.week_number,
      d.day_key,
      d.day_order,
      s.session_order,
      trim(s.protocol_id) AS protocol_id
    FROM public.programme_version_weeks w
    JOIN public.programme_version_days d ON d.week_id = w.id
    JOIN public.programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = v_assignment.programme_version_id
      AND COALESCE(d.day_type, '') <> 'rest'
      AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
    ORDER BY w.week_number ASC, d.day_order ASC, s.session_order ASC
  LOOP
    v_scheduled := public.cohort_authored_occurrence_date(
      v_assignment.started_at,
      v_slot.week_number,
      v_slot.day_order
    );

    SELECT o.outcome_status INTO v_outcome
    FROM public.programme_slot_outcomes o
    WHERE o.assignment_id = v_assignment.id
      AND o.session_slot_id = v_slot.session_slot_id
    LIMIT 1;

    v_disposition := CASE
      WHEN v_outcome IN ('completed', 'completed_partial') THEN 'completed'
      WHEN v_outcome = 'skipped' THEN 'skipped'
      ELSE 'scheduled'
    END;

    v_psk := public.cohort_programme_schedule_programmed_session_key(
      v_assignment.id,
      v_assignment.programme_version_id,
      v_slot.week_number,
      v_slot.day_key,
      v_slot.session_order,
      v_slot.protocol_id
    );

    INSERT INTO public.programme_schedule_occurrences (
      assignment_id,
      session_slot_id,
      programme_version_id,
      package_content_hash,
      week_number,
      day_key,
      session_order,
      protocol_id,
      programmed_session_key,
      scheduled_date,
      disposition
    ) VALUES (
      v_assignment.id,
      v_slot.session_slot_id,
      v_assignment.programme_version_id,
      v_hash,
      v_slot.week_number,
      v_slot.day_key,
      v_slot.session_order,
      v_slot.protocol_id,
      v_psk,
      v_scheduled,
      v_disposition
    );
  END LOOP;

  -- Mirror baseline revision onto assignment (still 0; not an athlete op).
  UPDATE public.programme_assignments
  SET schedule_revision = 0,
      updated_at = NOW()
  WHERE id = v_assignment.id;

  v_idem := format(
    'baseline:%s:%s:%s',
    v_assignment.id::text,
    v_assignment.programme_version_id::text,
    v_hash
  );

  INSERT INTO public.programme_schedule_operations (
    assignment_id,
    athlete_id,
    operation_type,
    idempotency_key,
    preview_fingerprint,
    base_revision,
    result_revision,
    policy_version,
    affected_before,
    affected_after,
    prior_snapshot,
    operated_at
  ) VALUES (
    v_assignment.id,
    v_athlete_id,
    'baseline_initialisation',
    v_idem,
    NULL,
    NULL,
    0,
    'programme.scheduling.policy.v1',
    '[]'::jsonb,
    jsonb_build_object('occurrence_count', v_count, 'schedule_revision', 0),
    NULL,
    NOW()
  )
  ON CONFLICT (assignment_id, idempotency_key) DO NOTHING;

  v_projection := public.cohort_programme_schedule_projection_json(v_assignment.id);

  RETURN jsonb_build_object(
    'status', 'initialised',
    'code', 'projection_initialised',
    'assignment_id', v_assignment.id,
    'schedule_revision', 0,
    'projection', v_projection
  );
EXCEPTION
  WHEN unique_violation THEN
    -- Concurrent winner: reload if provenance matches.
    SELECT * INTO v_existing
    FROM public.programme_schedule_projections
    WHERE assignment_id = p_programme_assignment_id;

    IF FOUND THEN
      v_projection := public.cohort_programme_schedule_projection_json(p_programme_assignment_id);
      RETURN jsonb_build_object(
        'status', 'already_exists',
        'code', 'projection_already_exists',
        'assignment_id', p_programme_assignment_id,
        'schedule_revision', v_existing.schedule_revision,
        'projection', v_projection
      );
    END IF;

    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'duplicate_occurrence_identity',
      'assignment_id', p_programme_assignment_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_programme_schedule_projection(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ensure_programme_schedule_projection(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.ensure_programme_schedule_projection(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_programme_schedule_projection(UUID) TO service_role;


COMMENT ON FUNCTION public.ensure_programme_schedule_projection(UUID) IS
  'Baseline schedule projection using authored week_number/day_order dates. Same-day slots share a date.';

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
  v_completed BOOLEAN := FALSE;
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
     AND v_assignment.status IS DISTINCT FROM 'completed'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'fixed_assignment_ineligible'
    );
  END IF;
  IF v_assignment.materialised_at IS NULL THEN
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

  v_completed := v_assignment.status = 'completed';

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

  -- Active path unchanged: may initialise projection and derive overdue.
  -- Completed path is inspection-only: never create or rewrite occurrences.
  IF NOT v_completed THEN
    v_ensure := public.ensure_programme_schedule_projection(v_assignment.id);
    IF v_ensure->>'status' NOT IN ('initialised', 'already_exists') THEN
      RETURN jsonb_build_object(
        'status', 'integrity_failure',
        'code', COALESCE(v_ensure->>'code', 'projection_initialisation_failed')
      );
    END IF;

    v_reconcile := public.cohort_reconcile_fixed_programme_schedule_at(
      v_assignment.id,
      p_now
    );
    IF v_reconcile->>'status' IS DISTINCT FROM 'reconciled' THEN
      RETURN v_reconcile;
    END IF;
  END IF;

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;

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
      'state', COALESCE(first_json->>'state', 'REST'),
      'occurrence', first_json,
      'occurrences', COALESCE(occ_list, '[]'::JSONB)
    )
    ORDER BY day_date
  ) INTO v_week
  FROM (
    SELECT
      v_week_start + offset_value AS day_date,
      (
        SELECT jsonb_agg(
          public.cohort_fixed_occurrence_projection_json(o.id, v_today)
          ORDER BY o.week_number, o.day_key, o.session_order
        )
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment.id
          AND o.scheduled_date = v_week_start + offset_value
      ) AS occ_list,
      (
        SELECT public.cohort_fixed_occurrence_projection_json(o.id, v_today)
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment.id
          AND o.scheduled_date = v_week_start + offset_value
        ORDER BY o.week_number, o.day_key, o.session_order
        LIMIT 1
      ) AS first_json
    FROM generate_series(0, 6) AS offset_value
  ) week_days;

  RETURN jsonb_build_object(
    'status', 'ok',
    'assignment_id', v_assignment.id,
    'assignment_status', v_assignment.status,
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

COMMENT ON FUNCTION public.cohort_resolve_fixed_programme_calendar_at(UUID, TIMESTAMPTZ)
IS 'Read projection of an athlete-owned fixed calendar. Week days expose all same-date occurrences. Completed is inspection-only.';
