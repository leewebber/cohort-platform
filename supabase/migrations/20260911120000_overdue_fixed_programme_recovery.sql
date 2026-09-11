-- Overdue fixed-programme recovery.
--
-- A calendar date passing must not make an incomplete occurrence inaccessible.
-- Overdue is derived from scheduled_date, assignment timezone, and the absence
-- of a terminal disposition/outcome. This migration does not rewrite historical
-- occurrence rows and does not convert leftover disposition='missed' to a
-- terminal outcome.
--
-- Rollback/recovery classification: restore the previous function bodies
-- (reconcile, projection, create-or-resume, resolve, train-today swap).
-- No destructive data rewrite is required; leftover missed dispositions remain
-- readable as derived OVERDUE.

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
  v_overdue INT := 0;
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

  SELECT COUNT(*) INTO v_overdue
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment.id
    AND o.scheduled_date < v_today
    AND o.disposition IN ('scheduled', 'missed')
    AND NOT EXISTS (
      SELECT 1
      FROM public.programme_slot_outcomes x
      WHERE x.assignment_id = o.assignment_id
        AND x.session_slot_id = o.session_slot_id
        AND x.outcome_status IN (
          'in_progress',
          'completed',
          'completed_partial',
          'skipped'
        )
    );

  RETURN jsonb_build_object(
    'status', 'reconciled',
    'today', v_today,
    'missed_count', 0,
    'overdue_count', v_overdue
  );
END;
$$;

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
      WHEN o.disposition = 'skipped'
        OR x.outcome_status = 'skipped'
        THEN 'SKIPPED'
      WHEN x.outcome_status = 'in_progress'
        AND o.scheduled_date < p_today
        THEN 'IN_PROGRESS_OVERDUE'
      WHEN x.outcome_status = 'in_progress'
        THEN 'IN_PROGRESS'
      WHEN o.scheduled_date < p_today
        THEN 'OVERDUE'
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
  IF v_outcome_found AND v_outcome.outcome_status = 'skipped' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_skipped'
    );
  END IF;
  IF v_outcome_found AND v_outcome.outcome_status = 'in_progress' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_session_integrity_failure'
    );
  END IF;

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;
  IF v_occ.disposition = 'completed' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'completed_occurrence'
    );
  END IF;
  IF v_occ.disposition = 'skipped' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_skipped'
    );
  END IF;
  IF v_occ.disposition IS DISTINCT FROM 'scheduled'
     AND v_occ.disposition IS DISTINCT FROM 'missed'
  THEN
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

  -- Leftover auto-missed rows stay recoverable; do not persist a terminal miss
  -- merely because the athlete starts late.
  IF v_occ.disposition = 'missed' THEN
    PERFORM set_config('cohort.allow_schedule_write', 'on', true);
    UPDATE public.programme_schedule_occurrences
    SET disposition = 'scheduled',
        updated_at = NOW()
    WHERE id = v_occ.id
      AND disposition = 'missed';
    v_occ.disposition := 'scheduled';
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

CREATE OR REPLACE FUNCTION public.cohort_recover_overdue_fixed_programme_occurrence_at(
  payload JSONB,
  p_now TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_assignment_id UUID;
  v_source_id UUID;
  v_counterpart_id UUID;
  v_operation TEXT;
  v_dest DATE;
  v_expected_source DATE;
  v_expected_dest DATE;
  v_expected_rev INT;
  v_idem TEXT;
  v_reason TEXT;
  v_assignment public.programme_assignments%ROWTYPE;
  v_projection public.programme_schedule_projections%ROWTYPE;
  v_source public.programme_schedule_occurrences%ROWTYPE;
  v_counterpart public.programme_schedule_occurrences%ROWTYPE;
  v_today DATE;
  v_end DATE;
  v_result_rev INT;
  v_existing public.programme_schedule_operations%ROWTYPE;
  v_source_outcome public.programme_slot_outcomes%ROWTYPE;
  v_counterpart_outcome public.programme_slot_outcomes%ROWTYPE;
  v_occupant_id UUID;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'not_authenticated'
    );
  END IF;
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  BEGIN
    v_assignment_id := NULLIF(trim(payload->>'assignment_id'), '')::UUID;
    v_source_id := NULLIF(trim(payload->>'source_occurrence_id'), '')::UUID;
    v_counterpart_id := NULLIF(trim(payload->>'counterpart_occurrence_id'), '')::UUID;
    v_operation := lower(NULLIF(trim(payload->>'operation'), ''));
    v_dest := NULLIF(trim(payload->>'destination_date'), '')::DATE;
    v_expected_source := NULLIF(trim(payload->>'expected_source_date'), '')::DATE;
    v_expected_dest := NULLIF(trim(payload->>'expected_destination_date'), '')::DATE;
    v_expected_rev := NULLIF(trim(payload->>'expected_schedule_revision'), '')::INT;
    v_idem := NULLIF(trim(payload->>'idempotency_key'), '');
    v_reason := NULLIF(trim(payload->>'reason'), '');
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END;

  IF v_assignment_id IS NULL
     OR v_source_id IS NULL
     OR v_idem IS NULL
     OR v_operation IS NULL
     OR v_operation NOT IN ('move', 'swap', 'skip')
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;
  IF v_operation IN ('move', 'swap') AND v_dest IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;
  IF v_operation = 'swap' AND v_counterpart_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;
  IF v_operation = 'swap' AND v_counterpart_id = v_source_id THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84202510, hashtext(v_assignment_id::TEXT));

  SELECT * INTO v_existing
  FROM public.programme_schedule_operations
  WHERE assignment_id = v_assignment_id
    AND idempotency_key = v_idem;
  IF FOUND THEN
    IF v_existing.operation_type IS DISTINCT FROM v_operation
       OR COALESCE(v_existing.prior_snapshot->>'source_occurrence_id', '')
            IS DISTINCT FROM v_source_id::TEXT
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'idempotency_conflict'
      );
    END IF;
    RETURN jsonb_build_object(
      'status', 'already_applied',
      'code', 'already_applied',
      'assignment_id', v_assignment_id,
      'operation_type', v_existing.operation_type,
      'source_occurrence_id', v_source_id,
      'schedule_revision', v_existing.result_revision,
      'affected_after', v_existing.affected_after
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_assignment.athlete_id IS DISTINCT FROM v_athlete
     OR v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule'
     OR v_assignment.materialised_at IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_authorised'
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

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;

  SELECT * INTO v_projection
  FROM public.programme_schedule_projections
  WHERE assignment_id = v_assignment_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_projection.athlete_id IS DISTINCT FROM v_athlete
     OR v_projection.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'projection_provenance_conflict'
    );
  END IF;
  IF v_expected_rev IS NOT NULL
     AND (
       v_projection.schedule_revision IS DISTINCT FROM v_expected_rev
       OR v_assignment.schedule_revision IS DISTINCT FROM v_expected_rev
     )
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision'
    );
  END IF;

  SELECT * INTO v_source
  FROM public.programme_schedule_occurrences
  WHERE id = v_source_id
  FOR UPDATE;
  IF NOT FOUND OR v_source.assignment_id IS DISTINCT FROM v_assignment_id THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'occurrence_not_found'
    );
  END IF;
  IF v_source.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_source.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_lineage_mismatch'
    );
  END IF;
  IF v_expected_source IS NOT NULL
     AND v_source.scheduled_date IS DISTINCT FROM v_expected_source
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_occurrence_dates'
    );
  END IF;

  SELECT * INTO v_source_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment_id
    AND session_slot_id = v_source.session_slot_id
  FOR UPDATE;

  IF v_source.disposition = 'completed'
     OR v_source_outcome.outcome_status IN ('completed', 'completed_partial')
  THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'occurrence_completed'
    );
  END IF;
  IF v_source.disposition = 'skipped'
     OR v_source_outcome.outcome_status = 'skipped'
  THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'occurrence_skipped'
    );
  END IF;
  IF v_source_outcome.outcome_status = 'in_progress' THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'occurrence_in_progress'
    );
  END IF;
  IF v_source.disposition IS DISTINCT FROM 'scheduled'
     AND v_source.disposition IS DISTINCT FROM 'missed'
  THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'occurrence_ineligible'
    );
  END IF;
  IF v_source.scheduled_date >= v_today THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'source_not_overdue'
    );
  END IF;

  SELECT GREATEST(
    MAX(o.scheduled_date),
    MAX(o.original_scheduled_date),
    v_assignment.started_at
  )
  INTO v_end
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = v_assignment_id;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  v_result_rev := v_projection.schedule_revision + 1;

  IF v_operation = 'skip' THEN
    INSERT INTO public.programme_slot_outcomes (
      assignment_id,
      session_slot_id,
      week_number,
      day_key,
      session_order,
      outcome_status,
      programme_version_id,
      materialised_package_content_hash,
      programmed_session_key,
      resolved_at
    ) VALUES (
      v_assignment_id,
      v_source.session_slot_id,
      v_source.week_number,
      v_source.day_key,
      v_source.session_order,
      'skipped',
      v_source.programme_version_id,
      v_source.package_content_hash,
      v_source.programmed_session_key,
      NOW()
    )
    ON CONFLICT (assignment_id, session_slot_id) DO UPDATE SET
      outcome_status = 'skipped',
      training_session_id = NULL,
      resolved_at = NOW(),
      updated_at = NOW()
    WHERE public.programme_slot_outcomes.outcome_status IN ('scheduled');

    UPDATE public.programme_schedule_occurrences
    SET disposition = 'skipped',
        updated_at = NOW()
    WHERE id = v_source.id
      AND disposition IN ('scheduled', 'missed');
    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'skip_race'
      );
    END IF;
  ELSE
    IF v_dest < v_today THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'destination_in_past'
      );
    END IF;
    IF (v_dest - v_today) > 7 THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'destination_outside_horizon'
      );
    END IF;
    IF v_dest < v_assignment.started_at THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'destination_before_assignment_start'
      );
    END IF;
    IF v_dest > v_end THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'destination_after_assignment_end'
      );
    END IF;
    IF v_dest = v_source.scheduled_date THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'destination_unchanged'
      );
    END IF;

    SELECT o.id INTO v_occupant_id
    FROM public.programme_schedule_occurrences o
    WHERE o.assignment_id = v_assignment_id
      AND o.scheduled_date = v_dest
      AND o.id IS DISTINCT FROM v_source.id
    LIMIT 1;

    IF v_operation = 'move' THEN
      IF v_occupant_id IS NOT NULL THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'destination_occupied'
        );
      END IF;
      UPDATE public.programme_schedule_occurrences
      SET scheduled_date = v_dest,
          disposition = 'scheduled',
          updated_at = NOW()
      WHERE id = v_source.id
        AND disposition IN ('scheduled', 'missed')
        AND scheduled_date = v_source.scheduled_date;
      IF NOT FOUND THEN
        RETURN jsonb_build_object(
          'status', 'conflict',
          'code', 'move_race'
        );
      END IF;
    ELSE
      IF v_occupant_id IS NULL THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'destination_empty'
        );
      END IF;
      IF v_occupant_id IS DISTINCT FROM v_counterpart_id THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'destination_occupied'
        );
      END IF;
      SELECT * INTO v_counterpart
      FROM public.programme_schedule_occurrences
      WHERE id = v_counterpart_id
      FOR UPDATE;
      IF NOT FOUND
         OR v_counterpart.assignment_id IS DISTINCT FROM v_assignment_id
      THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'occurrence_not_found'
        );
      END IF;
      IF v_expected_dest IS NOT NULL
         AND v_counterpart.scheduled_date IS DISTINCT FROM v_expected_dest
      THEN
        RETURN jsonb_build_object(
          'status', 'conflict',
          'code', 'stale_occurrence_dates'
        );
      END IF;
      IF v_counterpart.scheduled_date IS DISTINCT FROM v_dest THEN
        RETURN jsonb_build_object(
          'status', 'conflict',
          'code', 'stale_occurrence_dates'
        );
      END IF;
      IF v_counterpart.disposition IN ('completed', 'skipped')
         OR v_counterpart.disposition IS DISTINCT FROM 'scheduled'
            AND v_counterpart.disposition IS DISTINCT FROM 'missed'
      THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', CASE
            WHEN v_counterpart.disposition = 'completed' THEN 'destination_completed'
            WHEN v_counterpart.disposition = 'skipped' THEN 'destination_skipped'
            ELSE 'destination_ineligible'
          END
        );
      END IF;

      SELECT * INTO v_counterpart_outcome
      FROM public.programme_slot_outcomes
      WHERE assignment_id = v_assignment_id
        AND session_slot_id = v_counterpart.session_slot_id
      FOR UPDATE;
      IF v_counterpart_outcome.outcome_status IN (
        'completed', 'completed_partial'
      ) THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'destination_completed'
        );
      END IF;
      IF v_counterpart_outcome.outcome_status = 'in_progress' THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'destination_in_progress'
        );
      END IF;
      IF v_counterpart_outcome.outcome_status = 'skipped' THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'destination_skipped'
        );
      END IF;

      UPDATE public.programme_schedule_occurrences
      SET scheduled_date = v_dest,
          disposition = 'scheduled',
          updated_at = NOW()
      WHERE id = v_source.id
        AND disposition IN ('scheduled', 'missed')
        AND scheduled_date = v_source.scheduled_date;
      IF NOT FOUND THEN
        RETURN jsonb_build_object(
          'status', 'conflict',
          'code', 'swap_race'
        );
      END IF;
      UPDATE public.programme_schedule_occurrences
      SET scheduled_date = v_source.scheduled_date,
          updated_at = NOW()
      WHERE id = v_counterpart.id
        AND scheduled_date = v_dest;
      IF NOT FOUND THEN
        RETURN jsonb_build_object(
          'status', 'conflict',
          'code', 'swap_race'
        );
      END IF;
    END IF;
  END IF;

  UPDATE public.programme_schedule_projections
  SET schedule_revision = v_result_rev,
      updated_at = NOW()
  WHERE assignment_id = v_assignment_id
    AND schedule_revision = v_projection.schedule_revision;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision'
    );
  END IF;
  UPDATE public.programme_assignments
  SET schedule_revision = v_result_rev,
      updated_at = NOW()
  WHERE id = v_assignment_id
    AND schedule_revision = v_projection.schedule_revision;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision'
    );
  END IF;

  INSERT INTO public.programme_schedule_operations (
    assignment_id,
    athlete_id,
    operation_type,
    idempotency_key,
    base_revision,
    result_revision,
    policy_version,
    affected_before,
    affected_after,
    prior_snapshot
  ) VALUES (
    v_assignment_id,
    v_athlete,
    v_operation,
    v_idem,
    v_projection.schedule_revision,
    v_result_rev,
    'programme.overdue.recovery.v1',
    jsonb_build_array(
      jsonb_build_object(
        'occurrenceId', v_source.id,
        'scheduledDate', to_char(v_source.scheduled_date, 'YYYY-MM-DD'),
        'originalScheduledDate', to_char(v_source.original_scheduled_date, 'YYYY-MM-DD')
      )
    ) || CASE
      WHEN v_operation = 'swap' THEN jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_counterpart.id,
          'scheduledDate', to_char(v_counterpart.scheduled_date, 'YYYY-MM-DD')
        )
      )
      ELSE '[]'::jsonb
    END,
    CASE
      WHEN v_operation = 'skip' THEN jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_source.id,
          'scheduledDate', to_char(v_source.scheduled_date, 'YYYY-MM-DD'),
          'disposition', 'skipped'
        )
      )
      WHEN v_operation = 'move' THEN jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_source.id,
          'scheduledDate', to_char(v_dest, 'YYYY-MM-DD')
        )
      )
      ELSE jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_source.id,
          'scheduledDate', to_char(v_dest, 'YYYY-MM-DD')
        ),
        jsonb_build_object(
          'occurrenceId', v_counterpart.id,
          'scheduledDate', to_char(v_source.scheduled_date, 'YYYY-MM-DD')
        )
      )
    END,
    jsonb_build_object(
      'actor', v_athlete,
      'actor_role', 'athlete',
      'timezone', v_assignment.timezone,
      'reason', v_reason,
      'source', 'overdue_recovery',
      'request_id', v_idem,
      'operation_type', v_operation,
      'source_occurrence_id', v_source.id,
      'counterpart_occurrence_id', v_counterpart_id,
      'original_date', to_char(v_source.scheduled_date, 'YYYY-MM-DD'),
      'resulting_date', CASE
        WHEN v_operation = 'skip' THEN to_char(v_source.scheduled_date, 'YYYY-MM-DD')
        ELSE to_char(v_dest, 'YYYY-MM-DD')
      END
    )
  );

  PERFORM public.cohort_fixed_assignment_refresh_compatibility_cursor(
    v_assignment_id
  );

  RETURN jsonb_build_object(
    'status', 'applied',
    'code', CASE
      WHEN v_operation = 'skip' THEN 'skipped'
      WHEN v_operation = 'move' THEN 'moved'
      ELSE 'swapped'
    END,
    'assignment_id', v_assignment_id,
    'operation_type', v_operation,
    'source_occurrence_id', v_source_id,
    'counterpart_occurrence_id', v_counterpart_id,
    'original_date', to_char(v_source.scheduled_date, 'YYYY-MM-DD'),
    'resulting_date', CASE
      WHEN v_operation = 'skip' THEN to_char(v_source.scheduled_date, 'YYYY-MM-DD')
      ELSE to_char(v_dest, 'YYYY-MM-DD')
    END,
    'timezone', v_assignment.timezone,
    'schedule_revision', v_result_rev
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_recover_overdue_fixed_programme_occurrence_at(
  JSONB,
  TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.recover_overdue_fixed_programme_occurrence(
  payload JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.cohort_recover_overdue_fixed_programme_occurrence_at(
    payload,
    NOW()
  );
$$;

REVOKE ALL ON FUNCTION public.recover_overdue_fixed_programme_occurrence(JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recover_overdue_fixed_programme_occurrence(JSONB)
  TO authenticated;

COMMENT ON FUNCTION public.recover_overdue_fixed_programme_occurrence(JSONB) IS
  'Explicit overdue recovery: move or swap an incomplete overdue occurrence within the next seven athlete-local days, or skip it. Late execution is not a reschedule.';
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


CREATE OR REPLACE FUNCTION public.swap_future_fixed_programme_session_and_begin(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_assignment_id UUID;
  v_today_id UUID;
  v_selected_id UUID;
  v_expected_today DATE;
  v_expected_selected DATE;
  v_expected_rev INT;
  v_assignment public.programme_assignments%ROWTYPE;
  v_projection public.programme_schedule_projections%ROWTYPE;
  v_today_occ public.programme_schedule_occurrences%ROWTYPE;
  v_selected public.programme_schedule_occurrences%ROWTYPE;
  v_today DATE;
  v_active_count INT;
  v_in_progress INT;
  v_already_swapped BOOLEAN := FALSE;
  v_result_rev INT;
  v_idem TEXT;
  v_start JSONB;
  v_today_found BOOLEAN := FALSE;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'not_authenticated'
    );
  END IF;

  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  BEGIN
    v_assignment_id := NULLIF(trim(payload->>'assignment_id'), '')::UUID;
    v_today_id := NULLIF(trim(payload->>'today_occurrence_id'), '')::UUID;
    v_selected_id := NULLIF(trim(payload->>'selected_occurrence_id'), '')::UUID;
    v_expected_today := NULLIF(trim(payload->>'expected_today_date'), '')::DATE;
    v_expected_selected := NULLIF(trim(payload->>'expected_selected_date'), '')::DATE;
    v_expected_rev := NULLIF(trim(payload->>'expected_schedule_revision'), '')::INT;
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END;

  IF v_assignment_id IS NULL
     OR v_today_id IS NULL
     OR v_selected_id IS NULL
     OR v_expected_today IS NULL
     OR v_expected_selected IS NULL
     OR v_today_id = v_selected_id
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete
    AND status = 'active';
  IF v_active_count IS DISTINCT FROM 1 THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'multiple_active_assignments'
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84202509, hashtext(v_assignment_id::TEXT));

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_assignment.athlete_id IS DISTINCT FROM v_athlete
     OR v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule'
     OR v_assignment.materialised_at IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_authorised'
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

  v_today := (NOW() AT TIME ZONE v_assignment.timezone)::DATE;

  SELECT * INTO v_projection
  FROM public.programme_schedule_projections
  WHERE assignment_id = v_assignment_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_projection.athlete_id IS DISTINCT FROM v_athlete
     OR v_projection.started_at IS DISTINCT FROM v_assignment.started_at
     OR v_projection.timezone IS DISTINCT FROM v_assignment.timezone
     OR v_projection.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
     OR v_projection.programme_version_id
          IS DISTINCT FROM v_assignment.programme_version_id
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'projection_provenance_conflict'
    );
  END IF;

  IF v_expected_rev IS NOT NULL
     AND (
       v_projection.schedule_revision IS DISTINCT FROM v_expected_rev
       OR v_assignment.schedule_revision IS DISTINCT FROM v_expected_rev
     )
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision'
    );
  END IF;

  SELECT * INTO v_today_occ
  FROM public.programme_schedule_occurrences
  WHERE id = v_today_id
  FOR UPDATE;
  v_today_found := FOUND;
  SELECT * INTO v_selected
  FROM public.programme_schedule_occurrences
  WHERE id = v_selected_id
  FOR UPDATE;

  IF NOT v_today_found
     OR NOT FOUND
     OR v_today_occ.assignment_id IS DISTINCT FROM v_assignment_id
     OR v_selected.assignment_id IS DISTINCT FROM v_assignment_id
  THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'occurrence_not_found'
    );
  END IF;

  IF v_today_occ.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_selected.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_today_occ.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
     OR v_selected.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_lineage_mismatch'
    );
  END IF;

  v_already_swapped :=
    v_selected.scheduled_date = v_expected_today
    AND v_today_occ.scheduled_date = v_expected_selected
    AND v_expected_today = v_today
    AND v_expected_selected > v_today;

  IF NOT v_already_swapped THEN
    IF v_today_occ.scheduled_date IS DISTINCT FROM v_expected_today
       OR v_selected.scheduled_date IS DISTINCT FROM v_expected_selected
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'stale_occurrence_dates'
      );
    END IF;
    IF v_expected_today IS DISTINCT FROM v_today THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'today_date_mismatch'
      );
    END IF;
    IF v_expected_selected <= v_today THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'selected_not_future'
      );
    END IF;
    -- Athlete-local calendar dates, not elapsed UTC hours.
    IF (v_expected_selected - v_today) > 7 THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'selected_outside_train_today_horizon'
      );
    END IF;
  END IF;

  -- Overdue leftover occurrences no longer block a clean train-today swap.

  IF v_today_occ.disposition IS DISTINCT FROM 'scheduled'
     OR v_selected.disposition IS DISTINCT FROM 'scheduled'
  THEN
    RETURN jsonb_build_object(
      'status',
      'ineligible',
      'code',
      CASE
        WHEN v_today_occ.disposition = 'completed'
          OR v_selected.disposition = 'completed'
          THEN 'occurrence_completed'
        WHEN v_today_occ.disposition = 'skipped'
          OR v_selected.disposition = 'skipped'
          THEN 'occurrence_skipped'
        ELSE 'occurrence_ineligible'
      END
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.programme_slot_outcomes o
    WHERE o.assignment_id = v_assignment_id
      AND o.session_slot_id IN (
        v_today_occ.session_slot_id,
        v_selected.session_slot_id
      )
      AND o.outcome_status IN (
        'completed',
        'completed_partial',
        'skipped',
        'in_progress'
      )
  ) THEN
    IF NOT (
      v_already_swapped
      AND EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes o
        WHERE o.assignment_id = v_assignment_id
          AND o.session_slot_id = v_selected.session_slot_id
          AND o.outcome_status = 'in_progress'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes o
        WHERE o.assignment_id = v_assignment_id
          AND o.session_slot_id = v_today_occ.session_slot_id
          AND o.outcome_status IN (
            'completed',
            'completed_partial',
            'skipped',
            'in_progress'
          )
      )
    ) THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_has_session_state'
      );
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_in_progress
  FROM public.training_sessions ts
  JOIN public.programme_slot_outcomes o ON o.training_session_id = ts.id
  JOIN public.programme_assignments a ON a.id = o.assignment_id
  WHERE a.athlete_id = v_athlete
    AND ts.status = 'in_progress'
    AND o.outcome_status = 'in_progress';
  IF v_in_progress > 0 AND NOT v_already_swapped THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'in_progress_session_exists'
    );
  END IF;
  IF v_in_progress > 1 THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'in_progress_session_exists'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
    GROUP BY scheduled_date
    HAVING COUNT(*) > 1
  ) THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'duplicate_scheduled_dates'
    );
  END IF;

  BEGIN
  IF NOT v_already_swapped THEN
    PERFORM set_config('cohort.allow_schedule_write', 'on', true);
    v_result_rev := v_projection.schedule_revision + 1;

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_expected_selected,
        updated_at = NOW()
    WHERE id = v_today_occ.id
      AND disposition = 'scheduled'
      AND scheduled_date = v_expected_today;
    IF NOT FOUND THEN
      v_start := jsonb_build_object('status', 'conflict', 'code', 'swap_race');
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_expected_today,
        updated_at = NOW()
    WHERE id = v_selected.id
      AND disposition = 'scheduled'
      AND scheduled_date = v_expected_selected;
    IF NOT FOUND THEN
      v_start := jsonb_build_object('status', 'conflict', 'code', 'swap_race');
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    UPDATE public.programme_schedule_projections
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND schedule_revision = v_projection.schedule_revision;
    IF NOT FOUND THEN
      v_start := jsonb_build_object(
        'status', 'conflict',
        'code', 'stale_schedule_revision'
      );
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    UPDATE public.programme_assignments
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE id = v_assignment_id
      AND schedule_revision = v_projection.schedule_revision;
    IF NOT FOUND THEN
      v_start := jsonb_build_object(
        'status', 'conflict',
        'code', 'stale_schedule_revision'
      );
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    v_idem :=
      'future_train_today:'
      || v_today_id::TEXT
      || ':'
      || v_selected_id::TEXT
      || ':'
      || to_char(v_expected_today, 'YYYY-MM-DD')
      || ':'
      || to_char(v_expected_selected, 'YYYY-MM-DD');

    INSERT INTO public.programme_schedule_operations (
      assignment_id,
      athlete_id,
      operation_type,
      idempotency_key,
      base_revision,
      result_revision,
      policy_version,
      affected_before,
      affected_after,
      prior_snapshot
    ) VALUES (
      v_assignment_id,
      v_athlete,
      'future_train_today_swap',
      v_idem,
      v_projection.schedule_revision,
      v_result_rev,
      'programme.scheduling.policy.v1',
      jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_today_occ.id,
          'scheduledDate', to_char(v_expected_today, 'YYYY-MM-DD')
        ),
        jsonb_build_object(
          'occurrenceId', v_selected.id,
          'scheduledDate', to_char(v_expected_selected, 'YYYY-MM-DD')
        )
      ),
      jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_today_occ.id,
          'scheduledDate', to_char(v_expected_selected, 'YYYY-MM-DD')
        ),
        jsonb_build_object(
          'occurrenceId', v_selected.id,
          'scheduledDate', to_char(v_expected_today, 'YYYY-MM-DD')
        )
      ),
      jsonb_build_object(
        'operation_type', 'future_train_today_swap',
        'today_occurrence_id', v_today_id,
        'selected_occurrence_id', v_selected_id
      )
    )
    ON CONFLICT (assignment_id, idempotency_key) DO NOTHING;
  END IF;

  SELECT * INTO v_selected
  FROM public.programme_schedule_occurrences
  WHERE id = v_selected_id;
  IF v_selected.scheduled_date IS DISTINCT FROM v_today THEN
    v_start := jsonb_build_object(
      'status', 'conflict',
      'code', 'selected_not_on_today'
    );
    RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
  END IF;

  v_start := public.cohort_create_or_resume_fixed_occurrence_at(
    v_selected_id,
    NOW()
  );
  IF v_start->>'status' NOT IN ('created', 'resumed') THEN
    RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
  END IF;

  PERFORM public.cohort_fixed_assignment_refresh_compatibility_cursor(
    v_assignment_id
  );

  SELECT * INTO v_today_occ
  FROM public.programme_schedule_occurrences
  WHERE id = v_today_id;
  SELECT * INTO v_selected
  FROM public.programme_schedule_occurrences
  WHERE id = v_selected_id;

  RETURN jsonb_build_object(
    'status', v_start->>'status',
    'code', CASE
      WHEN v_already_swapped THEN 'already_applied'
      ELSE 'swapped_and_begun'
    END,
    'assignment_id', v_assignment_id,
    'today_occurrence_id', v_today_id,
    'selected_occurrence_id', v_selected_id,
    'today_scheduled_date', to_char(v_selected.scheduled_date, 'YYYY-MM-DD'),
    'displaced_scheduled_date', to_char(v_today_occ.scheduled_date, 'YYYY-MM-DD'),
    'training_session', v_start->'training_session',
    'programmed_session_key', v_selected.programmed_session_key,
    'schedule_revision', (
      SELECT schedule_revision
      FROM public.programme_schedule_projections
      WHERE assignment_id = v_assignment_id
    )
  );
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM = 'SWAP_BEGIN_FAILED' THEN
        RETURN COALESCE(v_start, jsonb_build_object()) || jsonb_build_object(
          'swap_status',
          CASE WHEN v_already_swapped THEN 'already_applied' ELSE 'rolled_back' END
        );
      END IF;
      RAISE;
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.swap_future_fixed_programme_session_and_begin(
  JSONB
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.swap_future_fixed_programme_session_and_begin(
  JSONB
) TO authenticated;


COMMENT ON FUNCTION public.swap_future_fixed_programme_session_and_begin(JSONB) IS
  'Atomically swap today’s unstarted fixed occurrence with a future scheduled occurrence 1–7 athlete-local calendar days ahead, then create or resume the selected session. Overdue leftovers do not block this destination-horizon swap.';
