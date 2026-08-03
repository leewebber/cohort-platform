-- Sprint 1.7F: Scheduling horizon bound + one-level acceptance-free Undo.
--
-- Adds programme_schedule_projections.scheduling_horizon_end (NULL = unbounded)
-- and extends the exact-preview apply RPC with operation_type = 'undo'.
-- Move/Swap/Push/Skip behaviour from 1.7D/1.7E is preserved. Undo is an inverse
-- of a single prior athlete scheduling operation; it is not a prescription
-- change, an adaptation, or a progression event.

-- ---------------------------------------------------------------------------
-- 1. Scheduling horizon bound (never derived from duration_weeks)
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_schedule_projections
  ADD COLUMN IF NOT EXISTS scheduling_horizon_end DATE NULL;

COMMENT ON COLUMN public.programme_schedule_projections.scheduling_horizon_end IS
  'Sprint 1.7F: NULL = explicitly unbounded scheduling horizon; non-null = inclusive last permitted athlete-local date for scheduling placement. Never derived from duration_weeks. Existing rows remain NULL.';

-- ---------------------------------------------------------------------------
-- 2. Projection JSON now surfaces the horizon
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_schedule_projection_json(
  p_assignment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_header public.programme_schedule_projections%ROWTYPE;
  v_occurrences JSONB;
BEGIN
  SELECT * INTO v_header
  FROM public.programme_schedule_projections
  WHERE assignment_id = p_assignment_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'session_slot_id', o.session_slot_id,
        'programme_version_id', o.programme_version_id,
        'package_content_hash', o.package_content_hash,
        'week_number', o.week_number,
        'day_key', o.day_key,
        'session_order', o.session_order,
        'protocol_id', o.protocol_id,
        'programmed_session_key', o.programmed_session_key,
        'scheduled_date', o.scheduled_date,
        'disposition', o.disposition
      )
      ORDER BY o.week_number ASC,
               (substring(o.day_key from 5))::INT ASC,
               o.session_order ASC
    ),
    '[]'::jsonb
  )
  INTO v_occurrences
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = p_assignment_id;

  RETURN jsonb_build_object(
    'assignment_id', v_header.assignment_id,
    'athlete_id', v_header.athlete_id,
    'programme_version_id', v_header.programme_version_id,
    'package_content_hash', v_header.package_content_hash,
    'timezone', v_header.timezone,
    'started_at', v_header.started_at,
    'schedule_revision', v_header.schedule_revision,
    'schema_version', v_header.schema_version,
    'scheduling_horizon_end', v_header.scheduling_horizon_end,
    'created_at', v_header.created_at,
    'updated_at', v_header.updated_at,
    'occurrences', v_occurrences
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_schedule_projection_json(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_schedule_projection_json(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_schedule_projection_json(UUID) TO service_role;

-- ---------------------------------------------------------------------------
-- 3. Ensure path writes an explicit unbounded horizon for current packages
-- ---------------------------------------------------------------------------

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
  v_day_offset INT := 0;
  v_scheduled DATE;
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

  v_day_offset := 0;
  FOR v_slot IN
    SELECT
      s.id AS session_slot_id,
      w.week_number,
      d.day_key,
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
    v_scheduled := v_assignment.started_at + v_day_offset;
    v_day_offset := v_day_offset + 1;

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
  'Sprint 1.7F: atomic idempotent baseline schedule projection initialisation / reload. Writes scheduling_horizon_end NULL (explicitly unbounded) for current packages.';

-- ---------------------------------------------------------------------------
-- 4. Apply Move / Swap / Push / Skip / Undo (exact preview, horizon-bounded)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.apply_programme_schedule_operation(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_op TEXT;
  v_assignment_id UUID;
  v_expected_rev INT;
  v_version_id UUID;
  v_hash TEXT;
  v_policy TEXT;
  v_fingerprint TEXT;
  v_idem TEXT;
  v_slot_id UUID;
  v_slot_a UUID;
  v_slot_b UUID;
  v_target DATE;
  v_day_delta INT;
  v_anchor_order INT;
  v_horizon DATE;
  v_assignment public.programme_assignments%ROWTYPE;
  v_projection public.programme_schedule_projections%ROWTYPE;
  v_prior public.programme_schedule_operations%ROWTYPE;
  v_target_op public.programme_schedule_operations%ROWTYPE;
  v_target_op_id UUID;
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_occ_a public.programme_schedule_occurrences%ROWTYPE;
  v_occ_b public.programme_schedule_occurrences%ROWTYPE;
  v_next_occ public.programme_schedule_occurrences%ROWTYPE;
  v_affected JSONB := '[]'::jsonb;
  v_collisions JSONB := '[]'::jsonb;
  v_fp_payload JSONB;
  v_server_fp TEXT;
  v_operation JSONB;
  v_date_a DATE;
  v_date_b DATE;
  v_projection_json JSONB;
  v_keys TEXT[] := ARRAY[]::TEXT[];
  v_undo_expires TIMESTAMPTZ;
  v_result_rev INT;
  v_prior_snapshot JSONB;
  v_snapshot JSONB;
  v_restore JSONB;
  v_restore_count INT;
  v_cursor_before JSONB;
  v_cursor_after JSONB;
  v_has_next BOOLEAN := FALSE;
  v_outcome_existed BOOLEAN := FALSE;
  v_outcome_status_before TEXT;
  v_status_after TEXT;
  v_completed_after TIMESTAMPTZ;
  v_rows INT;
  v_result JSONB;
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

  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  -- Reject client-supplied proposed projections / occurrence rows / cursor /
  -- impacts, and (1.7F) client-nominated inverse or snapshot state.
  IF payload ? 'projection'
     OR payload ? 'proposed_projection'
     OR payload ? 'occurrences'
     OR payload ? 'affected'
     OR payload ? 'impacts'
     OR payload ? 'colliding_dates'
     OR payload ? 'cursor_after'
     OR payload ? 'resulting_disposition'
     OR payload ? 'before'
     OR payload ? 'after'
     OR payload ? 'prior_snapshot'
     OR payload ? 'snapshot'
     OR payload ? 'inverse'
     OR payload ? 'inverse_affected'
     OR payload ? 'restore'
     OR payload ? 'dates_before'
     OR payload ? 'cursor_before'
     OR payload ? 'disposition_before'
     OR payload ? 'outcome_existed_before'
     OR payload ? 'outcome_status_before'
     OR payload ? 'assignment_status_before'
     OR payload ? 'assignment_completed_at_before'
     OR payload ? 'scheduling_horizon_end'
     OR payload ? 'result_revision'
     OR payload ? 'undo_expires_at'
     OR payload ? 'undo_consumed_at'
     OR payload ? 'undo_invalidated_at'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'client_nominated_projection_forbidden'
    );
  END IF;

  v_op := lower(nullif(trim(COALESCE(payload->>'operation_type', '')), ''));
  v_assignment_id := NULLIF(trim(COALESCE(payload->>'assignment_id', '')), '')::uuid;
  v_expected_rev := NULLIF(payload->>'expected_schedule_revision', '')::INT;
  v_version_id := NULLIF(trim(COALESCE(payload->>'programme_version_id', '')), '')::uuid;
  v_hash := nullif(trim(COALESCE(payload->>'package_content_hash', '')), '');
  v_policy := COALESCE(
    nullif(trim(COALESCE(payload->>'policy_version', '')), ''),
    'programme.scheduling.policy.v1'
  );
  v_fingerprint := nullif(trim(COALESCE(payload->>'preview_fingerprint', '')), '');
  v_idem := nullif(trim(COALESCE(payload->>'idempotency_key', '')), '');

  IF v_op IS NULL OR v_assignment_id IS NULL OR v_expected_rev IS NULL
     OR v_version_id IS NULL OR v_hash IS NULL OR v_fingerprint IS NULL
     OR v_idem IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  IF v_op NOT IN ('move', 'swap', 'push', 'skip', 'undo') THEN
    RETURN jsonb_build_object(
      'status', 'unsupported',
      'code', 'unsupported_operation',
      'operation_type', v_op
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84201704, hashtext(v_assignment_id::text));

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
    AND athlete_id = v_athlete_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_found'
    );
  END IF;

  IF v_assignment.status = 'paused' THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'assignment_paused'
    );
  END IF;

  IF v_op = 'undo' THEN
    -- A terminal Skip may have completed the assignment; its inverse must
    -- remain reachable inside the undo window.
    IF v_assignment.status NOT IN ('active', 'completed') THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'assignment_ineligible',
        'assignment_status', v_assignment.status
      );
    END IF;
  ELSIF v_assignment.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'assignment_ineligible',
      'assignment_status', v_assignment.status
    );
  END IF;

  IF v_assignment.materialised_at IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'assignment_not_materialised'
    );
  END IF;

  IF v_assignment.programme_version_id IS DISTINCT FROM v_version_id
     OR v_assignment.materialised_package_content_hash IS DISTINCT FROM v_hash
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'provenance_mismatch'
    );
  END IF;

  SELECT * INTO v_projection
  FROM public.programme_schedule_projections
  WHERE assignment_id = v_assignment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'projection_absent'
    );
  END IF;

  v_horizon := v_projection.scheduling_horizon_end;

  -- Idempotency check before revision CAS.
  SELECT * INTO v_prior
  FROM public.programme_schedule_operations
  WHERE assignment_id = v_assignment_id
    AND idempotency_key = v_idem
  FOR UPDATE;

  IF FOUND THEN
    IF v_prior.operation_type = v_op
       AND v_prior.preview_fingerprint IS NOT DISTINCT FROM v_fingerprint
    THEN
      v_projection_json := public.cohort_programme_schedule_projection_json(v_assignment_id);
      v_result := jsonb_build_object(
        'status', 'already_applied',
        'code', 'idempotent_replay',
        'assignment_id', v_assignment_id,
        'schedule_revision', v_projection.schedule_revision,
        'operation_id', v_prior.id,
        'cleared_programmed_session_keys', COALESCE(v_prior.affected_after->'cleared_programmed_session_keys', '[]'::jsonb),
        'projection', v_projection_json
      );
      IF v_prior.operation_type = 'skip'
         OR (v_prior.affected_after ? 'cursor_after')
      THEN
        v_result := v_result || jsonb_build_object(
          'cursor_after', v_prior.affected_after->'cursor_after'
        );
      END IF;
      IF v_prior.operation_type = 'undo' THEN
        v_result := v_result || jsonb_build_object(
          'undone_operation_id', v_prior.affected_after->'undone_operation_id',
          'undoable', FALSE
        );
      END IF;
      RETURN v_result;
    END IF;
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'idempotency_key_conflict'
    );
  END IF;

  IF v_projection.schedule_revision IS DISTINCT FROM v_expected_rev
     OR v_assignment.schedule_revision IS DISTINCT FROM v_expected_rev
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision',
      'expected_schedule_revision', v_expected_rev,
      'current_schedule_revision', v_projection.schedule_revision
    );
  END IF;

  -- =========================================================================
  -- UNDO: inverse of exactly one prior athlete scheduling operation.
  -- =========================================================================
  IF v_op = 'undo' THEN
    v_target_op_id := NULLIF(trim(COALESCE(payload->>'operation_id', '')), '')::uuid;
    IF v_target_op_id IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;

    SELECT * INTO v_target_op
    FROM public.programme_schedule_operations
    WHERE id = v_target_op_id
      AND assignment_id = v_assignment_id
      AND athlete_id = v_athlete_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'operation_not_found',
        'operation_id', v_target_op_id
      );
    END IF;

    IF v_target_op.operation_type NOT IN ('move', 'swap', 'push', 'skip') THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'undo_unavailable',
        'reason', 'operation_type_not_undoable',
        'operation_id', v_target_op_id,
        'operation_type', v_target_op.operation_type
      );
    END IF;

    IF v_target_op.undo_consumed_at IS NOT NULL THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'undo_already_consumed',
        'operation_id', v_target_op_id
      );
    END IF;

    IF v_target_op.undo_invalidated_at IS NOT NULL THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'undo_unavailable',
        'reason', 'undo_invalidated',
        'operation_id', v_target_op_id
      );
    END IF;

    IF v_target_op.undo_expires_at IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'undo_unavailable',
        'reason', 'operation_not_undoable',
        'operation_id', v_target_op_id
      );
    END IF;

    IF NOW() >= v_target_op.undo_expires_at THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'undo_expired',
        'operation_id', v_target_op_id,
        'undo_expires_at', v_target_op.undo_expires_at
      );
    END IF;

    IF v_target_op.result_revision IS DISTINCT FROM v_projection.schedule_revision THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'undo_unavailable',
        'reason', 'superseded_revision',
        'operation_id', v_target_op_id,
        'operation_result_revision', v_target_op.result_revision,
        'current_schedule_revision', v_projection.schedule_revision
      );
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.programme_schedule_operations o
      WHERE o.assignment_id = v_assignment_id
        AND o.operation_type IN ('move', 'swap', 'push', 'skip')
        AND o.undo_consumed_at IS NULL
        AND o.undo_invalidated_at IS NULL
        AND o.undo_expires_at IS NOT NULL
        AND o.result_revision > v_target_op.result_revision
    ) THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'undo_unavailable',
        'reason', 'not_latest_undoable',
        'operation_id', v_target_op_id
      );
    END IF;

    v_snapshot := v_target_op.prior_snapshot;
    IF v_snapshot IS NULL OR jsonb_typeof(v_snapshot) <> 'object' THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'incomplete_inverse_snapshot',
        'operation_id', v_target_op_id
      );
    END IF;

    -- After-state proof: every recorded affected row must still match the
    -- committed result of the operation being undone.
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements(COALESCE(v_target_op.affected_before, '[]'::jsonb)) e(value)
      LEFT JOIN public.programme_schedule_occurrences o
        ON o.assignment_id = v_assignment_id
       AND o.session_slot_id = (e.value->>'sessionSlotId')::uuid
      WHERE o.session_slot_id IS NULL
         OR o.scheduled_date IS DISTINCT FROM (e.value->>'proposedDate')::date
         OR o.disposition IS DISTINCT FROM (e.value->>'proposedDisposition')
    ) THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'undo_state_drift',
        'operation_id', v_target_op_id
      );
    END IF;

    -- Build the restore instruction set from the recorded prior snapshot.
    IF v_target_op.operation_type = 'move' THEN
      IF NOT (v_snapshot ? 'session_slot_id' AND v_snapshot ? 'scheduled_date') THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'incomplete_inverse_snapshot',
          'operation_id', v_target_op_id
        );
      END IF;
      v_restore := jsonb_build_array(
        jsonb_build_object(
          'sessionSlotId', v_snapshot->>'session_slot_id',
          'restoreDate', v_snapshot->>'scheduled_date',
          'restoreDisposition', 'scheduled'
        )
      );

    ELSIF v_target_op.operation_type = 'swap' THEN
      IF NOT (v_snapshot ? 'session_slot_id_a' AND v_snapshot ? 'session_slot_id_b'
              AND v_snapshot ? 'scheduled_date_a' AND v_snapshot ? 'scheduled_date_b')
      THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'incomplete_inverse_snapshot',
          'operation_id', v_target_op_id
        );
      END IF;
      v_restore := jsonb_build_array(
        jsonb_build_object(
          'sessionSlotId', v_snapshot->>'session_slot_id_a',
          'restoreDate', v_snapshot->>'scheduled_date_a',
          'restoreDisposition', 'scheduled'
        ),
        jsonb_build_object(
          'sessionSlotId', v_snapshot->>'session_slot_id_b',
          'restoreDate', v_snapshot->>'scheduled_date_b',
          'restoreDisposition', 'scheduled'
        )
      );

    ELSIF v_target_op.operation_type = 'push' THEN
      IF NOT (v_snapshot ? 'dates_before')
         OR jsonb_typeof(v_snapshot->'dates_before') <> 'array'
         OR jsonb_array_length(v_snapshot->'dates_before') = 0
      THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'incomplete_inverse_snapshot',
          'operation_id', v_target_op_id
        );
      END IF;

      SELECT jsonb_agg(
        jsonb_build_object(
          'sessionSlotId', e.value->>'session_slot_id',
          'restoreDate', e.value->>'scheduled_date',
          'restoreDisposition', 'scheduled'
        )
      )
      INTO v_restore
      FROM jsonb_array_elements(v_snapshot->'dates_before') e(value);

      IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(v_snapshot->'dates_before') e(value)
        WHERE nullif(trim(COALESCE(e.value->>'session_slot_id', '')), '') IS NULL
           OR nullif(trim(COALESCE(e.value->>'scheduled_date', '')), '') IS NULL
      ) THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'incomplete_inverse_snapshot',
          'operation_id', v_target_op_id
        );
      END IF;

    ELSE
      -- skip
      IF NOT (v_snapshot ? 'session_slot_id'
              AND v_snapshot ? 'disposition_before'
              AND v_snapshot ? 'outcome_existed_before'
              AND v_snapshot ? 'outcome_status_before'
              AND v_snapshot ? 'cursor_before'
              AND v_snapshot ? 'assignment_status_before'
              AND v_snapshot ? 'assignment_completed_at_before'
              AND jsonb_typeof(v_snapshot->'cursor_before') = 'object'
              AND (v_snapshot->'cursor_before') ? 'week_number'
              AND (v_snapshot->'cursor_before') ? 'day_key'
              AND (v_snapshot->'cursor_before') ? 'session_order')
      THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'incomplete_inverse_snapshot',
          'operation_id', v_target_op_id
        );
      END IF;

      v_slot_id := (v_snapshot->>'session_slot_id')::uuid;

      SELECT * INTO v_occ
      FROM public.programme_schedule_occurrences
      WHERE assignment_id = v_assignment_id
        AND session_slot_id = v_slot_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RETURN jsonb_build_object(
          'status', 'conflict',
          'code', 'undo_state_drift',
          'operation_id', v_target_op_id
        );
      END IF;

      IF NOT EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes so
        WHERE so.assignment_id = v_assignment_id
          AND so.session_slot_id = v_slot_id
          AND so.outcome_status = 'skipped'
      ) THEN
        RETURN jsonb_build_object(
          'status', 'conflict',
          'code', 'undo_state_drift',
          'reason', 'outcome_not_skipped',
          'operation_id', v_target_op_id
        );
      END IF;

      IF (v_target_op.affected_after ? 'cursor_after')
         AND jsonb_typeof(v_target_op.affected_after->'cursor_after') = 'object'
      THEN
        IF v_assignment.current_week_number
             IS DISTINCT FROM (v_target_op.affected_after->'cursor_after'->>'weekNumber')::int
           OR v_assignment.current_day_key
             IS DISTINCT FROM (v_target_op.affected_after->'cursor_after'->>'dayKey')
           OR v_assignment.current_slot_order
             IS DISTINCT FROM (v_target_op.affected_after->'cursor_after'->>'sessionOrder')::int
        THEN
          RETURN jsonb_build_object(
            'status', 'conflict',
            'code', 'undo_state_drift',
            'reason', 'cursor_moved',
            'operation_id', v_target_op_id
          );
        END IF;
      END IF;

      v_restore := jsonb_build_array(
        jsonb_build_object(
          'sessionSlotId', v_slot_id::text,
          'restoreDate', to_char(v_occ.scheduled_date, 'YYYY-MM-DD'),
          'restoreDisposition', v_snapshot->>'disposition_before'
        )
      );
    END IF;

    v_restore_count := jsonb_array_length(COALESCE(v_restore, '[]'::jsonb));
    IF v_restore_count = 0 THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'incomplete_inverse_snapshot',
        'operation_id', v_target_op_id
      );
    END IF;

    -- Inverse affected rows (same shape as move/swap affected rows).
    SELECT COALESCE(
      jsonb_agg(row_obj ORDER BY row_obj->>'sessionSlotId'),
      '[]'::jsonb
    )
    INTO v_affected
    FROM (
      SELECT jsonb_build_object(
        'dayKey', o.day_key,
        'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
        'originalDisposition', o.disposition,
        'programmedSessionKey', o.programmed_session_key,
        'proposedDate', to_char((r.value->>'restoreDate')::date, 'YYYY-MM-DD'),
        'proposedDisposition', r.value->>'restoreDisposition',
        'protocolId', o.protocol_id,
        'sessionOrder', o.session_order,
        'sessionSlotId', o.session_slot_id::text,
        'weekNumber', o.week_number
      ) AS row_obj
      FROM jsonb_array_elements(v_restore) r(value)
      JOIN public.programme_schedule_occurrences o
        ON o.assignment_id = v_assignment_id
       AND o.session_slot_id = (r.value->>'sessionSlotId')::uuid
    ) q;

    IF jsonb_array_length(v_affected) <> v_restore_count THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'undo_state_drift',
        'reason', 'restore_target_missing',
        'operation_id', v_target_op_id
      );
    END IF;

    -- Collisions implied by the inverse placement.
    SELECT COALESCE(
      jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
      '[]'::jsonb
    )
    INTO v_collisions
    FROM (
      SELECT s.d AS collision_date
      FROM (
        SELECT COALESCE((r.value->>'restoreDate')::date, o.scheduled_date) AS d,
               COALESCE(r.value->>'restoreDisposition', o.disposition) AS disp
        FROM public.programme_schedule_occurrences o
        LEFT JOIN LATERAL (
          SELECT e.value
          FROM jsonb_array_elements(v_restore) e(value)
          WHERE (e.value->>'sessionSlotId')::uuid = o.session_slot_id
          LIMIT 1
        ) r ON TRUE
        WHERE o.assignment_id = v_assignment_id
      ) s
      WHERE s.disp = 'scheduled'
      GROUP BY s.d
      HAVING COUNT(*) > 1
    ) c;

    SELECT COALESCE(
      array_agg(e.value->>'programmedSessionKey' ORDER BY e.value->>'sessionSlotId'),
      ARRAY[]::TEXT[]
    )
    INTO v_keys
    FROM jsonb_array_elements(v_affected) e(value);

    v_operation := jsonb_build_object(
      'type', 'undo',
      'operationId', v_target_op_id::text
    );

    v_fp_payload := jsonb_build_object(
      'affected', v_affected,
      'assignmentId', v_assignment_id::text,
      'collidingDates', v_collisions,
      'operation', v_operation,
      'packageContentHash', v_hash,
      'policyVersion', v_policy,
      'programmeVersionId', v_version_id::text,
      'scheduleRevision', v_expected_rev,
      'timezone', v_projection.timezone
    );

    IF v_target_op.operation_type = 'skip' THEN
      -- Restore direction: cursorBefore = current cursor, cursorAfter = restored.
      SELECT jsonb_build_object(
        'dayKey', o.day_key,
        'sessionOrder', o.session_order,
        'sessionSlotId', o.session_slot_id::text,
        'weekNumber', o.week_number
      )
      INTO v_cursor_before
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.week_number = v_assignment.current_week_number
        AND o.day_key IS NOT DISTINCT FROM v_assignment.current_day_key
        AND o.session_order = v_assignment.current_slot_order;

      SELECT jsonb_build_object(
        'dayKey', o.day_key,
        'sessionOrder', o.session_order,
        'sessionSlotId', o.session_slot_id::text,
        'weekNumber', o.week_number
      )
      INTO v_cursor_after
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.week_number = (v_snapshot->'cursor_before'->>'week_number')::int
        AND o.day_key IS NOT DISTINCT FROM (v_snapshot->'cursor_before'->>'day_key')
        AND o.session_order = (v_snapshot->'cursor_before'->>'session_order')::int;

      IF v_cursor_after IS NULL THEN
        RETURN jsonb_build_object(
          'status', 'ineligible',
          'code', 'incomplete_inverse_snapshot',
          'reason', 'cursor_before_unresolvable',
          'operation_id', v_target_op_id
        );
      END IF;

      v_fp_payload := v_fp_payload || jsonb_build_object(
        'cursorAfter', v_cursor_after,
        'cursorBefore', v_cursor_before
      );
    END IF;

    v_server_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

    IF v_server_fp IS DISTINCT FROM v_fingerprint THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'stale_preview_fingerprint',
        'expected_fingerprint', v_fingerprint,
        'server_fingerprint', v_server_fp
      );
    END IF;

    PERFORM set_config('cohort.allow_schedule_write', 'on', true);
    IF v_target_op.operation_type = 'skip' THEN
      PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    END IF;

    v_result_rev := v_expected_rev + 1;

    IF v_target_op.operation_type = 'skip' THEN
      UPDATE public.programme_schedule_occurrences
      SET disposition = v_snapshot->>'disposition_before',
          updated_at = NOW()
      WHERE assignment_id = v_assignment_id
        AND session_slot_id = v_slot_id
        AND disposition = 'skipped';

      IF NOT FOUND THEN
        RAISE EXCEPTION 'undo_skip_disposition_race' USING ERRCODE = 'serialization_failure';
      END IF;

      IF COALESCE((v_snapshot->>'outcome_existed_before')::boolean, FALSE) THEN
        UPDATE public.programme_slot_outcomes
        SET outcome_status = COALESCE(v_snapshot->>'outcome_status_before', 'scheduled'),
            resolved_at = NULL,
            updated_at = NOW()
        WHERE assignment_id = v_assignment_id
          AND session_slot_id = v_slot_id;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'undo_skip_outcome_race' USING ERRCODE = 'serialization_failure';
        END IF;
      ELSE
        DELETE FROM public.programme_slot_outcomes
        WHERE assignment_id = v_assignment_id
          AND session_slot_id = v_slot_id;
      END IF;
    ELSE
      UPDATE public.programme_schedule_occurrences o
      SET scheduled_date = (r.value->>'restoreDate')::date,
          updated_at = NOW()
      FROM jsonb_array_elements(v_restore) r(value)
      WHERE o.assignment_id = v_assignment_id
        AND o.session_slot_id = (r.value->>'sessionSlotId')::uuid
        AND o.disposition = 'scheduled';

      GET DIAGNOSTICS v_rows = ROW_COUNT;
      IF v_rows <> v_restore_count THEN
        RAISE EXCEPTION 'undo_restore_race' USING ERRCODE = 'serialization_failure';
      END IF;
    END IF;

    UPDATE public.programme_schedule_projections
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND schedule_revision = v_expected_rev;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'projection_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;

    IF v_target_op.operation_type = 'skip' THEN
      UPDATE public.programme_assignments
      SET current_week_number = (v_snapshot->'cursor_before'->>'week_number')::int,
          current_day_key = v_snapshot->'cursor_before'->>'day_key',
          current_slot_order = (v_snapshot->'cursor_before'->>'session_order')::int,
          status = COALESCE(v_snapshot->>'assignment_status_before', status),
          completed_at = (v_snapshot->>'assignment_completed_at_before')::timestamptz,
          schedule_revision = v_result_rev,
          updated_at = NOW()
      WHERE id = v_assignment_id
        AND schedule_revision = v_expected_rev;
    ELSE
      UPDATE public.programme_assignments
      SET schedule_revision = v_result_rev,
          updated_at = NOW()
      WHERE id = v_assignment_id
        AND schedule_revision = v_expected_rev;
    END IF;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'assignment_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;

    UPDATE public.programme_schedule_operations
    SET undo_consumed_at = NOW()
    WHERE id = v_target_op_id
      AND undo_consumed_at IS NULL
      AND undo_invalidated_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'undo_consume_race' USING ERRCODE = 'serialization_failure';
    END IF;

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
      operated_at,
      undo_expires_at
    ) VALUES (
      v_assignment_id,
      v_athlete_id,
      'undo',
      v_idem,
      v_fingerprint,
      v_expected_rev,
      v_result_rev,
      v_policy,
      v_affected,
      jsonb_build_object(
        'cleared_programmed_session_keys', to_jsonb(v_keys),
        'colliding_dates', v_collisions,
        'local_prepared_clear_required', true,
        'undone_operation_id', v_target_op_id,
        'undone_operation_type', v_target_op.operation_type,
        'cursor_after', v_cursor_after
      ),
      jsonb_build_object(
        'operation_type', 'undo',
        'undone_operation_id', v_target_op_id,
        'undone_operation_type', v_target_op.operation_type,
        'undone_result_revision', v_target_op.result_revision
      ),
      NOW(),
      NULL
    );

    v_projection_json := public.cohort_programme_schedule_projection_json(v_assignment_id);

    v_result := jsonb_build_object(
      'status', 'applied',
      'code', 'applied',
      'assignment_id', v_assignment_id,
      'schedule_revision', v_result_rev,
      'operation_type', 'undo',
      'preview_fingerprint', v_fingerprint,
      'cleared_programmed_session_keys', to_jsonb(v_keys),
      'colliding_dates', v_collisions,
      'undone_operation_id', v_target_op_id,
      'undone_operation_type', v_target_op.operation_type,
      'undo_expires_at', NULL,
      'undoable', FALSE,
      'projection', v_projection_json
    );

    IF v_target_op.operation_type = 'skip' THEN
      v_result := v_result || jsonb_build_object('cursor_after', v_cursor_after);
    END IF;

    RETURN v_result;
  END IF;

  -- =========================================================================
  -- FORWARD OPERATIONS
  -- =========================================================================
  IF v_op = 'move' THEN
    v_slot_id := NULLIF(trim(COALESCE(payload->>'session_slot_id', '')), '')::uuid;
    v_target := NULLIF(trim(COALESCE(payload->>'target_date', '')), '')::date;
    IF v_slot_id IS NULL OR v_target IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;

    SELECT * INTO v_occ
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF v_occ.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ.disposition IS DISTINCT FROM 'scheduled' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    IF v_target < v_assignment.started_at THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'before_assignment_start');
    END IF;

    IF v_occ.scheduled_date = v_target THEN
      RETURN jsonb_build_object(
        'status', 'no_change',
        'code', 'no_change',
        'assignment_id', v_assignment_id,
        'schedule_revision', v_projection.schedule_revision
      );
    END IF;

    -- Horizon is inclusive: a proposed date equal to the horizon is valid.
    IF v_horizon IS NOT NULL AND v_target > v_horizon THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'horizon_exceeded',
        'scheduling_horizon_end', to_char(v_horizon, 'YYYY-MM-DD'),
        'proposed_date', to_char(v_target, 'YYYY-MM-DD')
      );
    END IF;

    v_operation := jsonb_build_object(
      'sessionSlotId', v_slot_id::text,
      'targetDate', to_char(v_target, 'YYYY-MM-DD'),
      'type', 'move'
    );

    v_affected := jsonb_build_array(
      jsonb_build_object(
        'dayKey', v_occ.day_key,
        'originalDate', to_char(v_occ.scheduled_date, 'YYYY-MM-DD'),
        'originalDisposition', v_occ.disposition,
        'programmedSessionKey', v_occ.programmed_session_key,
        'proposedDate', to_char(v_target, 'YYYY-MM-DD'),
        'proposedDisposition', v_occ.disposition,
        'protocolId', v_occ.protocol_id,
        'sessionOrder', v_occ.session_order,
        'sessionSlotId', v_occ.session_slot_id::text,
        'weekNumber', v_occ.week_number
      )
    );

    -- Collisions after proposed move (uncompleted only).
    SELECT COALESCE(
      jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
      '[]'::jsonb
    )
    INTO v_collisions
    FROM (
      SELECT d AS collision_date
      FROM (
        SELECT CASE
                 WHEN o.session_slot_id = v_slot_id THEN v_target
                 ELSE o.scheduled_date
               END AS d
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
      ) s
      GROUP BY d
      HAVING COUNT(*) > 1
    ) c;

    v_keys := array_append(v_keys, v_occ.programmed_session_key);

  ELSIF v_op = 'swap' THEN
    v_slot_a := NULLIF(trim(COALESCE(payload->>'session_slot_id_a', '')), '')::uuid;
    v_slot_b := NULLIF(trim(COALESCE(payload->>'session_slot_id_b', '')), '')::uuid;
    IF v_slot_a IS NULL OR v_slot_b IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;
    IF v_slot_a = v_slot_b THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'swap_requires_distinct_occurrences'
      );
    END IF;

    SELECT * INTO v_occ_a
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_a
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_not_found');
    END IF;

    SELECT * INTO v_occ_b
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_b
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_not_found');
    END IF;

    IF v_occ_a.disposition = 'completed' OR v_occ_b.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ_a.disposition = 'skipped' OR v_occ_b.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ_a.disposition IS DISTINCT FROM 'scheduled'
       OR v_occ_b.disposition IS DISTINCT FROM 'scheduled'
    THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    IF v_occ_a.package_content_hash IS DISTINCT FROM v_hash
       OR v_occ_b.package_content_hash IS DISTINCT FROM v_hash
       OR v_occ_a.programme_version_id IS DISTINCT FROM v_version_id
       OR v_occ_b.programme_version_id IS DISTINCT FROM v_version_id
    THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'cross_assignment_or_version_swap');
    END IF;

    IF v_occ_a.scheduled_date = v_occ_b.scheduled_date THEN
      RETURN jsonb_build_object(
        'status', 'no_change',
        'code', 'no_change',
        'assignment_id', v_assignment_id,
        'schedule_revision', v_projection.schedule_revision
      );
    END IF;

    v_date_a := v_occ_a.scheduled_date;
    v_date_b := v_occ_b.scheduled_date;

    v_operation := jsonb_build_object(
      'sessionSlotIdA', v_slot_a::text,
      'sessionSlotIdB', v_slot_b::text,
      'type', 'swap'
    );

    v_affected := (
      SELECT jsonb_agg(row_obj ORDER BY row_obj->>'sessionSlotId')
      FROM (
        SELECT jsonb_build_object(
          'dayKey', v_occ_a.day_key,
          'originalDate', to_char(v_date_a, 'YYYY-MM-DD'),
          'originalDisposition', v_occ_a.disposition,
          'programmedSessionKey', v_occ_a.programmed_session_key,
          'proposedDate', to_char(v_date_b, 'YYYY-MM-DD'),
          'proposedDisposition', v_occ_a.disposition,
          'protocolId', v_occ_a.protocol_id,
          'sessionOrder', v_occ_a.session_order,
          'sessionSlotId', v_occ_a.session_slot_id::text,
          'weekNumber', v_occ_a.week_number
        ) AS row_obj
        UNION ALL
        SELECT jsonb_build_object(
          'dayKey', v_occ_b.day_key,
          'originalDate', to_char(v_date_b, 'YYYY-MM-DD'),
          'originalDisposition', v_occ_b.disposition,
          'programmedSessionKey', v_occ_b.programmed_session_key,
          'proposedDate', to_char(v_date_a, 'YYYY-MM-DD'),
          'proposedDisposition', v_occ_b.disposition,
          'protocolId', v_occ_b.protocol_id,
          'sessionOrder', v_occ_b.session_order,
          'sessionSlotId', v_occ_b.session_slot_id::text,
          'weekNumber', v_occ_b.week_number
        )
      ) q
    );

    SELECT COALESCE(
      jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
      '[]'::jsonb
    )
    INTO v_collisions
    FROM (
      SELECT d AS collision_date
      FROM (
        SELECT CASE
                 WHEN o.session_slot_id = v_slot_a THEN v_date_b
                 WHEN o.session_slot_id = v_slot_b THEN v_date_a
                 ELSE o.scheduled_date
               END AS d
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
      ) s
      GROUP BY d
      HAVING COUNT(*) > 1
    ) c;

    v_keys := ARRAY[v_occ_a.programmed_session_key, v_occ_b.programmed_session_key];

  ELSIF v_op = 'push' THEN
    v_slot_id := NULLIF(trim(COALESCE(payload->>'session_slot_id', '')), '')::uuid;
    v_day_delta := NULLIF(payload->>'day_delta', '')::INT;
    IF v_slot_id IS NULL OR v_day_delta IS NULL OR v_day_delta <= 0 THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;

    PERFORM 1
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
    FOR UPDATE;

    SELECT * INTO v_occ
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF v_occ.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ.disposition IS DISTINCT FROM 'scheduled' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    v_anchor_order :=
      (v_occ.week_number * 1000000)
      + (COALESCE((regexp_match(v_occ.day_key, '^day_(\d+)$'))[1]::int, v_occ.week_number * 100) * 1000)
      + v_occ.session_order;

    SELECT COALESCE(
      jsonb_agg(row_obj ORDER BY row_obj->>'sessionSlotId'),
      '[]'::jsonb
    )
    INTO v_affected
    FROM (
      SELECT jsonb_build_object(
        'dayKey', o.day_key,
        'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
        'originalDisposition', o.disposition,
        'programmedSessionKey', o.programmed_session_key,
        'proposedDate', to_char(o.scheduled_date + v_day_delta, 'YYYY-MM-DD'),
        'proposedDisposition', o.disposition,
        'protocolId', o.protocol_id,
        'sessionOrder', o.session_order,
        'sessionSlotId', o.session_slot_id::text,
        'weekNumber', o.week_number
      ) AS row_obj
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.disposition = 'scheduled'
        AND (
          (o.week_number * 1000000)
          + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
          + o.session_order
        ) >= v_anchor_order
    ) q;

    IF v_affected = '[]'::jsonb THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.disposition = 'scheduled'
        AND (
          (o.week_number * 1000000)
          + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
          + o.session_order
        ) >= v_anchor_order
        AND (o.scheduled_date + v_day_delta) < v_assignment.started_at
    ) THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'before_assignment_start');
    END IF;

    -- Horizon is inclusive: a proposed date equal to the horizon is valid.
    IF v_horizon IS NOT NULL AND EXISTS (
      SELECT 1
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.disposition = 'scheduled'
        AND (
          (o.week_number * 1000000)
          + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
          + o.session_order
        ) >= v_anchor_order
        AND (o.scheduled_date + v_day_delta) > v_horizon
    ) THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'horizon_exceeded',
        'scheduling_horizon_end', to_char(v_horizon, 'YYYY-MM-DD')
      );
    END IF;

    v_operation := jsonb_build_object(
      'type', 'push',
      'fromSessionSlotId', v_slot_id::text,
      'dayDelta', v_day_delta
    );

    SELECT COALESCE(
      jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
      '[]'::jsonb
    )
    INTO v_collisions
    FROM (
      SELECT d AS collision_date
      FROM (
        SELECT CASE
                 WHEN (
                   (o.week_number * 1000000)
                   + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
                   + o.session_order
                 ) >= v_anchor_order
                   AND o.disposition = 'scheduled'
                 THEN o.scheduled_date + v_day_delta
                 ELSE o.scheduled_date
               END AS d
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
      ) s
      GROUP BY d
      HAVING COUNT(*) > 1
    ) c;

    SELECT COALESCE(array_agg(o.programmed_session_key ORDER BY o.session_slot_id::text), ARRAY[]::TEXT[])
    INTO v_keys
    FROM public.programme_schedule_occurrences o
    WHERE o.assignment_id = v_assignment_id
      AND o.disposition = 'scheduled'
      AND (
        (o.week_number * 1000000)
        + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
        + o.session_order
      ) >= v_anchor_order;

  ELSIF v_op = 'skip' THEN
    v_slot_id := NULLIF(trim(COALESCE(payload->>'session_slot_id', '')), '')::uuid;
    IF v_slot_id IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;

    SELECT * INTO v_occ
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF v_occ.week_number IS DISTINCT FROM v_assignment.current_week_number
       OR v_occ.day_key IS DISTINCT FROM v_assignment.current_day_key
       OR v_occ.session_order IS DISTINCT FROM v_assignment.current_slot_order
    THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_current'
      );
    END IF;

    IF v_occ.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ.disposition IS DISTINCT FROM 'scheduled' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    v_anchor_order :=
      (v_occ.week_number * 1000000)
      + (COALESCE((regexp_match(v_occ.day_key, '^day_(\d+)$'))[1]::int, v_occ.week_number * 100) * 1000)
      + v_occ.session_order;

    v_cursor_before := jsonb_build_object(
      'dayKey', v_occ.day_key,
      'sessionOrder', v_occ.session_order,
      'sessionSlotId', v_occ.session_slot_id::text,
      'weekNumber', v_occ.week_number
    );

    SELECT * INTO v_next_occ
    FROM public.programme_schedule_occurrences o
    WHERE o.assignment_id = v_assignment_id
      AND o.disposition = 'scheduled'
      AND o.session_slot_id IS DISTINCT FROM v_slot_id
      AND (
        (o.week_number * 1000000)
        + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
        + o.session_order
      ) > v_anchor_order
    ORDER BY o.week_number,
             COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100),
             o.session_order
    LIMIT 1;

    IF NOT FOUND THEN
      SELECT * INTO v_next_occ
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.disposition = 'scheduled'
        AND o.session_slot_id IS DISTINCT FROM v_slot_id
      ORDER BY o.week_number,
               COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100),
               o.session_order
      LIMIT 1;
    END IF;

    v_has_next := FOUND;

    IF v_has_next THEN
      v_cursor_after := jsonb_build_object(
        'dayKey', v_next_occ.day_key,
        'sessionOrder', v_next_occ.session_order,
        'sessionSlotId', v_next_occ.session_slot_id::text,
        'weekNumber', v_next_occ.week_number
      );
    ELSE
      v_cursor_after := NULL;
    END IF;

    v_operation := jsonb_build_object(
      'type', 'skip',
      'sessionSlotId', v_slot_id::text
    );

    v_affected := jsonb_build_array(
      jsonb_build_object(
        'dayKey', v_occ.day_key,
        'originalDate', to_char(v_occ.scheduled_date, 'YYYY-MM-DD'),
        'originalDisposition', v_occ.disposition,
        'programmedSessionKey', v_occ.programmed_session_key,
        'proposedDate', to_char(v_occ.scheduled_date, 'YYYY-MM-DD'),
        'proposedDisposition', 'skipped',
        'protocolId', v_occ.protocol_id,
        'sessionOrder', v_occ.session_order,
        'sessionSlotId', v_occ.session_slot_id::text,
        'weekNumber', v_occ.week_number
      )
    );

    v_collisions := '[]'::jsonb;
    v_keys := ARRAY[v_occ.programmed_session_key];
  END IF;

  v_fp_payload := jsonb_build_object(
    'affected', v_affected,
    'assignmentId', v_assignment_id::text,
    'collidingDates', v_collisions,
    'operation', v_operation,
    'packageContentHash', v_hash,
    'policyVersion', v_policy,
    'programmeVersionId', v_version_id::text,
    'scheduleRevision', v_expected_rev,
    'timezone', v_projection.timezone
  );

  IF v_op = 'skip' THEN
    v_fp_payload := v_fp_payload || jsonb_build_object(
      'cursorAfter', v_cursor_after,
      'cursorBefore', v_cursor_before
    );
  END IF;

  -- A NULL horizon contributes no key, preserving the 1.7D/1.7E conformance
  -- vectors for Move/Swap/Push/Skip.
  IF v_horizon IS NOT NULL AND v_op IN ('move', 'push') THEN
    v_fp_payload := v_fp_payload || jsonb_build_object(
      'schedulingHorizonEnd', to_char(v_horizon, 'YYYY-MM-DD')
    );
  END IF;

  v_server_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  IF v_server_fp IS DISTINCT FROM v_fingerprint THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_preview_fingerprint',
      'expected_fingerprint', v_fingerprint,
      'server_fingerprint', v_server_fp
    );
  END IF;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  IF v_op = 'skip' THEN
    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  END IF;

  v_result_rev := v_expected_rev + 1;
  v_undo_expires := NOW() + INTERVAL '72 hours';

  IF v_op = 'move' THEN
    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'move',
      'session_slot_id', v_slot_id,
      'scheduled_date', to_char(v_occ.scheduled_date, 'YYYY-MM-DD')
    );

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_target,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
      AND disposition = 'scheduled'
      AND scheduled_date = v_occ.scheduled_date;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'move_update_race' USING ERRCODE = 'serialization_failure';
    END IF;

  ELSIF v_op = 'swap' THEN
    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'swap',
      'session_slot_id_a', v_slot_a,
      'session_slot_id_b', v_slot_b,
      'scheduled_date_a', to_char(v_date_a, 'YYYY-MM-DD'),
      'scheduled_date_b', to_char(v_date_b, 'YYYY-MM-DD')
    );

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_date_b,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_a
      AND disposition = 'scheduled'
      AND scheduled_date = v_date_a;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'swap_update_race_a' USING ERRCODE = 'serialization_failure';
    END IF;

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_date_a,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_b
      AND disposition = 'scheduled'
      AND scheduled_date = v_date_b;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'swap_update_race_b' USING ERRCODE = 'serialization_failure';
    END IF;

  ELSIF v_op = 'push' THEN
    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'push',
      'session_slot_id', v_slot_id,
      'day_delta', v_day_delta,
      'dates_before', (
        SELECT COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'session_slot_id', o.session_slot_id,
              'scheduled_date', to_char(o.scheduled_date, 'YYYY-MM-DD')
            )
            ORDER BY o.session_slot_id::text
          ),
          '[]'::jsonb
        )
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
          AND (
            (o.week_number * 1000000)
            + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
            + o.session_order
          ) >= v_anchor_order
      )
    );

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = scheduled_date + v_day_delta,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND disposition = 'scheduled'
      AND (
        (week_number * 1000000)
        + (COALESCE((regexp_match(day_key, '^day_(\d+)$'))[1]::int, week_number * 100) * 1000)
        + session_order
      ) >= v_anchor_order;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      RAISE EXCEPTION 'push_update_race' USING ERRCODE = 'serialization_failure';
    END IF;

  ELSIF v_op = 'skip' THEN
    -- Sprint 1.7F: capture the complete inverse snapshot before mutation.
    v_outcome_status_before := NULL;
    v_outcome_existed := FALSE;
    SELECT so.outcome_status INTO v_outcome_status_before
    FROM public.programme_slot_outcomes so
    WHERE so.assignment_id = v_assignment_id
      AND so.session_slot_id = v_slot_id;

    v_outcome_existed := FOUND;

    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'skip',
      'session_slot_id', v_slot_id,
      'disposition_before', v_occ.disposition,
      'outcome_existed_before', v_outcome_existed,
      'outcome_status_before', v_outcome_status_before,
      'cursor_before', jsonb_build_object(
        'week_number', v_assignment.current_week_number,
        'day_key', v_assignment.current_day_key,
        'session_order', v_assignment.current_slot_order
      ),
      'assignment_status_before', v_assignment.status,
      'assignment_completed_at_before', v_assignment.completed_at
    );

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
      v_slot_id,
      v_occ.week_number,
      v_occ.day_key,
      v_occ.session_order,
      'skipped',
      v_version_id,
      v_hash,
      v_occ.programmed_session_key,
      NOW()
    )
    ON CONFLICT (assignment_id, session_slot_id) DO UPDATE SET
      outcome_status = EXCLUDED.outcome_status,
      training_session_id = NULL,
      completion_record_id = NULL,
      actuals_fingerprint = NULL,
      logical_completion_key = NULL,
      idempotency_key = NULL,
      programme_version_id = EXCLUDED.programme_version_id,
      materialised_package_content_hash = EXCLUDED.materialised_package_content_hash,
      programmed_session_key = EXCLUDED.programmed_session_key,
      resolved_at = EXCLUDED.resolved_at,
      updated_at = NOW()
    WHERE public.programme_slot_outcomes.outcome_status IN ('scheduled', 'in_progress');

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      RAISE EXCEPTION 'skip_outcome_race' USING ERRCODE = 'serialization_failure';
    END IF;

    UPDATE public.programme_schedule_occurrences
    SET disposition = 'skipped',
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
      AND disposition = 'scheduled';

    IF NOT FOUND THEN
      RAISE EXCEPTION 'skip_occurrence_race' USING ERRCODE = 'serialization_failure';
    END IF;

    IF v_cursor_after IS NULL THEN
      UPDATE public.programme_assignments
      SET status = 'completed',
          completed_at = COALESCE(completed_at, NOW()),
          schedule_revision = v_result_rev,
          updated_at = NOW()
      WHERE id = v_assignment_id
        AND schedule_revision = v_expected_rev
        AND status = 'active'
        AND current_week_number = v_occ.week_number
        AND current_day_key IS NOT DISTINCT FROM v_occ.day_key
        AND current_slot_order = v_occ.session_order;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'skip_terminal_cursor_cas_failed' USING ERRCODE = 'serialization_failure';
      END IF;
    ELSE
      UPDATE public.programme_assignments
      SET current_week_number = (v_cursor_after->>'weekNumber')::int,
          current_day_key = v_cursor_after->>'dayKey',
          current_slot_order = (v_cursor_after->>'sessionOrder')::int,
          schedule_revision = v_result_rev,
          updated_at = NOW()
      WHERE id = v_assignment_id
        AND schedule_revision = v_expected_rev
        AND current_week_number = v_occ.week_number
        AND current_day_key IS NOT DISTINCT FROM v_occ.day_key
        AND current_slot_order = v_occ.session_order;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'skip_cursor_cas_failed' USING ERRCODE = 'serialization_failure';
      END IF;
    END IF;

    SELECT status, completed_at
      INTO v_status_after, v_completed_after
    FROM public.programme_assignments
    WHERE id = v_assignment_id;
  END IF;

  IF v_op <> 'skip' THEN
    UPDATE public.programme_schedule_projections
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND schedule_revision = v_expected_rev;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'projection_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;

    UPDATE public.programme_assignments
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE id = v_assignment_id
      AND schedule_revision = v_expected_rev;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'assignment_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;
  ELSE
    UPDATE public.programme_schedule_projections
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND schedule_revision = v_expected_rev;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'projection_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;
  END IF;

  -- Sprint 1.7F: only the newest successful operation stays undoable.
  UPDATE public.programme_schedule_operations
  SET undo_invalidated_at = NOW()
  WHERE assignment_id = v_assignment_id
    AND undo_consumed_at IS NULL
    AND undo_invalidated_at IS NULL
    AND operation_type IN ('move', 'swap', 'push', 'skip')
    AND undo_expires_at IS NOT NULL;

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
    operated_at,
    undo_expires_at
  ) VALUES (
    v_assignment_id,
    v_athlete_id,
    v_op,
    v_idem,
    v_fingerprint,
    v_expected_rev,
    v_result_rev,
    v_policy,
    v_affected,
    CASE
      WHEN v_op = 'skip' THEN
        jsonb_build_object(
          'cleared_programmed_session_keys', to_jsonb(v_keys),
          'colliding_dates', v_collisions,
          'local_prepared_clear_required', true,
          'cursor_after', v_cursor_after,
          'disposition_after', 'skipped',
          'outcome_existed_after', true,
          'outcome_status_after', 'skipped',
          'assignment_status_after', v_status_after,
          'assignment_completed_at_after', v_completed_after
        )
      ELSE
        jsonb_build_object(
          'cleared_programmed_session_keys', to_jsonb(v_keys),
          'colliding_dates', v_collisions,
          'local_prepared_clear_required', true
        )
    END,
    v_prior_snapshot,
    NOW(),
    v_undo_expires
  );

  v_projection_json := public.cohort_programme_schedule_projection_json(v_assignment_id);

  v_result := jsonb_build_object(
    'status', 'applied',
    'code', 'applied',
    'assignment_id', v_assignment_id,
    'schedule_revision', v_result_rev,
    'operation_type', v_op,
    'preview_fingerprint', v_fingerprint,
    'cleared_programmed_session_keys', to_jsonb(v_keys),
    'colliding_dates', v_collisions,
    'undo_expires_at', v_undo_expires,
    'undoable', TRUE,
    'projection', v_projection_json
  );

  IF v_op = 'skip' THEN
    v_result := v_result || jsonb_build_object('cursor_after', v_cursor_after);
  END IF;

  RETURN v_result;
EXCEPTION
  WHEN serialization_failure THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM anon;
GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO service_role;

COMMENT ON FUNCTION public.apply_programme_schedule_operation(JSONB) IS
  'Sprint 1.7F: exact-preview Move/Swap/Push/Skip apply plus one-level Undo of the newest successful operation, bounded by scheduling_horizon_end. Undo consumes its target, appends a non-undoable undo row, and advances both revision mirrors. Does not mutate prescription or apply progression.';
