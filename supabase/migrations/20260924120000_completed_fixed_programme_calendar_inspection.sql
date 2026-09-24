-- Sprint 3: read-only inspection of a completed fixed-programme calendar.
-- Widens cohort_resolve_fixed_programme_calendar_at so the owning athlete
-- may resolve status IN ('active','completed') when materialised.
-- Completed path does not call ensure or reconcile (no occurrence writes).
-- Execution RPCs remain active-only. No new columns. No hosted apply.

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
IS 'Read projection of an athlete-owned fixed calendar. Active is unchanged. Completed is inspection-only and does not mutate. Other statuses remain ineligible.';
