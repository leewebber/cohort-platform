-- Sprint 1.5A: atomic programme session completion + authored cursor advancement.
--
-- One authenticated SECURITY DEFINER RPC commits:
--   1) exactly one terminal training_session_records completion
--   2) exactly one programme_slot_outcomes terminal row for the authored slot
--   3) exactly-once compare-and-swap cursor advancement on programme_assignments
--
-- Next-session preparation remains a separate Sprint 1.4B boundary after commit.

-- ---------------------------------------------------------------------------
-- 1. Outcome provenance for logical completion identity / idempotency
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_slot_outcomes
  ADD COLUMN IF NOT EXISTS logical_completion_key TEXT,
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS programme_version_id UUID
    REFERENCES public.programme_versions (id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS materialised_package_content_hash TEXT,
  ADD COLUMN IF NOT EXISTS completion_record_id UUID,
  ADD COLUMN IF NOT EXISTS actuals_fingerprint TEXT,
  ADD COLUMN IF NOT EXISTS programmed_session_key TEXT;

COMMENT ON COLUMN public.programme_slot_outcomes.logical_completion_key IS
  'Sprint 1.5A stable logical completion identity for an authored assignment/version/cursor/protocol.';
COMMENT ON COLUMN public.programme_slot_outcomes.idempotency_key IS
  'Sprint 1.5A request idempotency key. Replays reconcile; conflicting payloads reject.';
COMMENT ON COLUMN public.programme_slot_outcomes.actuals_fingerprint IS
  'Sprint 1.5A fingerprint of athlete-entered actuals for conflict detection on replay.';

CREATE UNIQUE INDEX IF NOT EXISTS programme_slot_outcomes_logical_completion_uidx
  ON public.programme_slot_outcomes (assignment_id, logical_completion_key)
  WHERE logical_completion_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS programme_slot_outcomes_idempotency_uidx
  ON public.programme_slot_outcomes (assignment_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. Protect cursor / progression columns (same privileged GUC bypass)
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

  -- Authorised path: SECURITY DEFINER RPCs owned by postgres/supabase_admin set
  -- cohort.allow_materialisation_write=on. Authenticated athletes may set the GUC
  -- but current_user remains 'authenticated', so they cannot bypass.
  IF COALESCE(current_setting('cohort.allow_materialisation_write', true), '') = 'on'
     AND current_user IN ('postgres', 'supabase_admin')
  THEN
    RETURN NEW;
  END IF;

  IF NEW.materialised_at IS DISTINCT FROM OLD.materialised_at
     OR NEW.materialisation_source IS DISTINCT FROM OLD.materialisation_source
     OR NEW.materialised_package_content_hash IS DISTINCT FROM OLD.materialised_package_content_hash
     OR NEW.materialised_package_schema_version IS DISTINCT FROM OLD.materialised_package_schema_version
     OR NEW.programme_version_id IS DISTINCT FROM OLD.programme_version_id
     OR NEW.lineage_code IS DISTINCT FROM OLD.lineage_code
     OR (
       OLD.materialised_at IS NOT NULL
       AND NEW.started_at IS DISTINCT FROM OLD.started_at
     )
     OR (
       NEW.materialised_at IS NOT NULL
       AND OLD.materialised_at IS NULL
     )
     -- Sprint 1.5A: cursor / progression fields are RPC-only after materialisation.
     OR (
       OLD.materialised_at IS NOT NULL
       AND (
         NEW.current_week_number IS DISTINCT FROM OLD.current_week_number
         OR NEW.current_day_key IS DISTINCT FROM OLD.current_day_key
         OR NEW.current_slot_order IS DISTINCT FROM OLD.current_slot_order
         OR NEW.last_progressed_training_session_id IS DISTINCT FROM OLD.last_progressed_training_session_id
         OR NEW.status IS DISTINCT FROM OLD.status
         OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
       )
     )
  THEN
    RAISE EXCEPTION 'programme_assignments materialisation-controlled columns are RPC-only'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.cohort_programme_assignment_protect_materialisation() IS
  'Blocks direct authenticated updates to materialisation and post-materialisation cursor/progression columns. Bypass requires cohort.allow_materialisation_write=on AND current_user in (postgres, supabase_admin).';

-- ---------------------------------------------------------------------------
-- 3. Next authored executable slot (package order only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_version_next_executable_slot(
  p_version_id UUID,
  p_week INT,
  p_day_key TEXT,
  p_slot_order INT,
  OUT o_week INT,
  OUT o_day_key TEXT,
  OUT o_slot_order INT,
  OUT o_protocol_id TEXT,
  OUT o_session_slot_id UUID
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cur_week INT;
  v_cur_day_order INT;
  v_cur_slot INT;
BEGIN
  SELECT w.week_number, d.day_order, s.session_order
    INTO v_cur_week, v_cur_day_order, v_cur_slot
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  JOIN public.programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = p_version_id
    AND w.week_number = p_week
    AND d.day_key = p_day_key
    AND s.session_order = p_slot_order
  LIMIT 1;

  IF v_cur_week IS NULL THEN
    RETURN;
  END IF;

  SELECT w.week_number,
         d.day_key,
         s.session_order,
         s.protocol_id,
         s.id
    INTO o_week, o_day_key, o_slot_order, o_protocol_id, o_session_slot_id
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  JOIN public.programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = p_version_id
    AND COALESCE(d.day_type, '') <> 'rest'
    AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
    AND (
      w.week_number > v_cur_week
      OR (w.week_number = v_cur_week AND d.day_order > v_cur_day_order)
      OR (
        w.week_number = v_cur_week
        AND d.day_order = v_cur_day_order
        AND s.session_order > v_cur_slot
      )
    )
  ORDER BY w.week_number ASC, d.day_order ASC, s.session_order ASC
  LIMIT 1;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_next_executable_slot(UUID, INT, TEXT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_next_executable_slot(UUID, INT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_next_executable_slot(UUID, INT, TEXT, INT) TO service_role;

COMMENT ON FUNCTION public.cohort_programme_version_next_executable_slot(UUID, INT, TEXT, INT) IS
  'Sprint 1.5A: immediate next authored executable slot after the current cursor, using package week/day_order/session_order. Returns NULL outs when terminal.';

-- ---------------------------------------------------------------------------
-- 4. Atomic completion + cursor advancement RPC
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.complete_programme_session_and_advance(
  payload JSONB
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
  v_slot public.programme_version_session_slots%ROWTYPE;
  v_day public.programme_version_days%ROWTYPE;
  v_week public.programme_version_weeks%ROWTYPE;
  v_outcome public.programme_slot_outcomes%ROWTYPE;
  v_record public.training_session_records%ROWTYPE;

  v_assignment_id UUID := NULLIF(payload->>'assignment_id', '')::UUID;
  v_session_slot_id UUID := NULLIF(payload->>'session_slot_id', '')::UUID;
  v_programme_version_id UUID := NULLIF(payload->>'programme_version_id', '')::UUID;
  v_package_hash TEXT := nullif(trim(COALESCE(payload->>'materialised_package_content_hash', '')), '');
  v_programmed_key TEXT := nullif(trim(COALESCE(payload->>'programmed_session_key', '')), '');
  v_logical_key TEXT := nullif(trim(COALESCE(payload->>'logical_completion_key', '')), '');
  v_idempotency_key TEXT := nullif(trim(COALESCE(payload->>'idempotency_key', '')), '');
  v_actuals_fp TEXT := nullif(trim(COALESCE(payload->>'actuals_fingerprint', '')), '');
  v_protocol_id TEXT := nullif(trim(COALESCE(payload->>'protocol_id', '')), '');
  v_expected_week INT := NULLIF(payload->>'expected_week', '')::INT;
  v_expected_day TEXT := nullif(trim(COALESCE(payload->>'expected_day_key', '')), '');
  v_expected_slot INT := NULLIF(payload->>'expected_slot_order', '')::INT;
  v_training_session_id BIGINT := NULLIF(payload->>'training_session_id', '')::BIGINT;
  v_record_id UUID := NULLIF(payload->>'record_id', '')::UUID;
  v_status TEXT := nullif(trim(COALESCE(payload->>'status', '')), '');
  v_completion JSONB := COALESCE(payload->'completion_record', '{}'::jsonb);

  v_expected_key TEXT;
  v_next_week INT;
  v_next_day TEXT;
  v_next_slot INT;
  v_next_protocol TEXT;
  v_next_slot_id UUID;
  v_rows INT;
  v_outcome_status TEXT;
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'authentication_required');
  END IF;

  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'athlete_role_required');
  END IF;

  -- Reject client-nominated athlete id / next cursor.
  IF payload ? 'athlete_id' OR payload ? 'next_week' OR payload ? 'next_day_key'
     OR payload ? 'next_slot_order' OR payload ? 'next_cursor' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'client_nominated_authority_forbidden');
  END IF;

  IF v_assignment_id IS NULL OR v_session_slot_id IS NULL
     OR v_programme_version_id IS NULL OR v_package_hash IS NULL
     OR v_programmed_key IS NULL OR v_logical_key IS NULL
     OR v_idempotency_key IS NULL OR v_actuals_fp IS NULL
     OR v_protocol_id IS NULL OR v_expected_week IS NULL
     OR v_expected_day IS NULL OR v_expected_slot IS NULL
     OR v_training_session_id IS NULL OR v_record_id IS NULL
     OR v_status IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'completion_validation_failure');
  END IF;

  IF v_status NOT IN ('completed', 'partially_completed', 'abandoned') THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'completion_validation_failure');
  END IF;

  v_outcome_status := CASE
    WHEN v_status = 'completed' THEN 'completed'
    WHEN v_status = 'partially_completed' THEN 'completed_partial'
    ELSE 'completed_partial'
  END;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'assignment_missing');
  END IF;

  IF v_assignment.athlete_id IS DISTINCT FROM v_athlete_id THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'cross_athlete_assignment');
  END IF;

  IF v_assignment.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'assignment_inactive');
  END IF;

  IF v_assignment.materialised_at IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'assignment_not_materialised');
  END IF;

  IF v_assignment.programme_version_id IS DISTINCT FROM v_programme_version_id THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'exact_version_missing');
  END IF;

  IF v_assignment.materialised_package_content_hash IS DISTINCT FROM v_package_hash THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'package_hash_mismatch');
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_assignment.programme_version_id;

  IF NOT FOUND OR v_version.lifecycle_status IS DISTINCT FROM 'published'
     OR v_version.archived_at IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'exact_version_missing');
  END IF;

  IF v_version.package_content_hash IS DISTINCT FROM v_package_hash THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'package_hash_mismatch');
  END IF;

  -- Idempotency key reconcile (same request identity).
  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment.id
    AND idempotency_key = v_idempotency_key;

  IF FOUND THEN
    IF v_outcome.actuals_fingerprint IS DISTINCT FROM v_actuals_fp
       OR v_outcome.logical_completion_key IS DISTINCT FROM v_logical_key THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'idempotency_payload_conflict',
        'logical_completion_key', v_outcome.logical_completion_key
      );
    END IF;

    SELECT * INTO v_assignment FROM public.programme_assignments WHERE id = v_assignment.id;
    SELECT * INTO v_record FROM public.training_session_records
    WHERE record_id = v_outcome.completion_record_id;

    RETURN jsonb_build_object(
      'status', 'already_committed',
      'code', 'idempotent_replay',
      'completion_record_id', v_outcome.completion_record_id,
      'training_session_id', v_outcome.training_session_id,
      'outcome_id', v_outcome.id,
      'logical_completion_key', v_outcome.logical_completion_key,
      'programmed_session_key', v_outcome.programmed_session_key,
      'assignment', jsonb_build_object(
        'id', v_assignment.id,
        'athlete_id', v_assignment.athlete_id,
        'lineage_code', v_assignment.lineage_code,
        'status', v_assignment.status,
        'programme_version_id', v_assignment.programme_version_id,
        'materialised_package_content_hash', v_assignment.materialised_package_content_hash,
        'started_at', v_assignment.started_at,
        'materialised_at', v_assignment.materialised_at,
        'materialisation_source', v_assignment.materialisation_source,
        'current_week_number', v_assignment.current_week_number,
        'current_day_key', v_assignment.current_day_key,
        'current_slot_order', v_assignment.current_slot_order,
        'last_progressed_training_session_id', v_assignment.last_progressed_training_session_id,
        'completed_at', v_assignment.completed_at
      ),
      'completion_record', CASE WHEN v_record.record_id IS NULL THEN NULL ELSE to_jsonb(v_record) END
    );
  END IF;

  -- Logical completion already committed (possibly different request key).
  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment.id
    AND logical_completion_key = v_logical_key;

  IF FOUND THEN
    IF v_outcome.actuals_fingerprint IS DISTINCT FROM v_actuals_fp THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'logical_completion_payload_conflict',
        'logical_completion_key', v_outcome.logical_completion_key
      );
    END IF;

    SELECT * INTO v_assignment FROM public.programme_assignments WHERE id = v_assignment.id;
    SELECT * INTO v_record FROM public.training_session_records
    WHERE record_id = v_outcome.completion_record_id;

    RETURN jsonb_build_object(
      'status', 'already_committed',
      'code', 'logical_completion_replay',
      'completion_record_id', v_outcome.completion_record_id,
      'training_session_id', v_outcome.training_session_id,
      'outcome_id', v_outcome.id,
      'logical_completion_key', v_outcome.logical_completion_key,
      'programmed_session_key', v_outcome.programmed_session_key,
      'assignment', jsonb_build_object(
        'id', v_assignment.id,
        'athlete_id', v_assignment.athlete_id,
        'lineage_code', v_assignment.lineage_code,
        'status', v_assignment.status,
        'programme_version_id', v_assignment.programme_version_id,
        'materialised_package_content_hash', v_assignment.materialised_package_content_hash,
        'started_at', v_assignment.started_at,
        'materialised_at', v_assignment.materialised_at,
        'materialisation_source', v_assignment.materialisation_source,
        'current_week_number', v_assignment.current_week_number,
        'current_day_key', v_assignment.current_day_key,
        'current_slot_order', v_assignment.current_slot_order,
        'last_progressed_training_session_id', v_assignment.last_progressed_training_session_id,
        'completed_at', v_assignment.completed_at
      ),
      'completion_record', CASE WHEN v_record.record_id IS NULL THEN NULL ELSE to_jsonb(v_record) END
    );
  END IF;

  -- Cursor compare-and-swap precondition.
  IF v_assignment.current_week_number IS DISTINCT FROM v_expected_week
     OR v_assignment.current_day_key IS DISTINCT FROM v_expected_day
     OR v_assignment.current_slot_order IS DISTINCT FROM v_expected_slot THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_cursor',
      'current_week_number', v_assignment.current_week_number,
      'current_day_key', v_assignment.current_day_key,
      'current_slot_order', v_assignment.current_slot_order
    );
  END IF;

  SELECT w.* INTO v_week
  FROM public.programme_version_weeks w
  WHERE w.version_id = v_version.id
    AND w.week_number = v_expected_week;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_current_cursor');
  END IF;

  SELECT d.* INTO v_day
  FROM public.programme_version_days d
  WHERE d.week_id = v_week.id
    AND d.day_key = v_expected_day;

  IF NOT FOUND OR COALESCE(v_day.day_type, '') = 'rest' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_current_cursor');
  END IF;

  SELECT s.* INTO v_slot
  FROM public.programme_version_session_slots s
  WHERE s.day_id = v_day.id
    AND s.id = v_session_slot_id
    AND s.session_order = v_expected_slot;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_current_cursor');
  END IF;

  IF nullif(trim(COALESCE(v_slot.protocol_id, '')), '') IS DISTINCT FROM v_protocol_id THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'authored_protocol_mismatch');
  END IF;

  v_expected_key := format(
    'prog:%s@%s:w%s:%s:s%s:%s',
    v_assignment.id::text,
    v_version.id::text,
    v_expected_week,
    v_expected_day,
    v_expected_slot,
    v_protocol_id
  );

  IF v_programmed_key IS DISTINCT FROM v_expected_key
     OR v_logical_key IS DISTINCT FROM v_expected_key THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'programme_key_mismatch',
      'expected', v_expected_key
    );
  END IF;

  -- Next authored cursor (or terminal via existing assignment completed contract).
  SELECT n.o_week, n.o_day_key, n.o_slot_order, n.o_protocol_id, n.o_session_slot_id
    INTO v_next_week, v_next_day, v_next_slot, v_next_protocol, v_next_slot_id
  FROM public.cohort_programme_version_next_executable_slot(
    v_version.id, v_expected_week, v_expected_day, v_expected_slot
  ) AS n;

  -- Upsert terminal completion record (athlete identity forced from auth.uid()).
  INSERT INTO public.training_session_records (
    record_id,
    athlete_id,
    training_session_id,
    source_protocol_id,
    programme_id,
    assignment_id,
    programme_session_id,
    status,
    session_snapshot,
    active_block_id,
    started_at,
    completed_at,
    duration_seconds,
    overall_rpe,
    athlete_note,
    updated_at
  ) VALUES (
    v_record_id,
    v_athlete_id::text,
    v_training_session_id,
    COALESCE(v_completion->>'source_protocol_id', v_protocol_id),
    NULLIF(v_completion->>'programme_id', ''),
    v_assignment.id,
    v_session_slot_id,
    v_status,
    COALESCE(v_completion->'session_snapshot', '{}'::jsonb),
    NULLIF(v_completion->>'active_block_id', ''),
    COALESCE(NULLIF(v_completion->>'started_at', '')::timestamptz, NOW()),
    COALESCE(NULLIF(v_completion->>'completed_at', '')::timestamptz, NOW()),
    NULLIF(v_completion->>'duration_seconds', '')::integer,
    NULLIF(v_completion->>'overall_rpe', '')::integer,
    NULLIF(v_completion->>'athlete_note', ''),
    NOW()
  )
  ON CONFLICT (record_id) DO UPDATE SET
    status = EXCLUDED.status,
    completed_at = EXCLUDED.completed_at,
    duration_seconds = EXCLUDED.duration_seconds,
    overall_rpe = EXCLUDED.overall_rpe,
    athlete_note = EXCLUDED.athlete_note,
    session_snapshot = EXCLUDED.session_snapshot,
    updated_at = NOW()
  WHERE public.training_session_records.athlete_id = v_athlete_id::text
    AND public.training_session_records.status = 'in_progress';

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    SELECT * INTO v_record
    FROM public.training_session_records
    WHERE record_id = v_record_id
      AND athlete_id = v_athlete_id::text;
    IF NOT FOUND THEN
      -- Insert path may have succeeded on first write without prior row.
      SELECT * INTO v_record
      FROM public.training_session_records
      WHERE record_id = v_record_id
        AND athlete_id = v_athlete_id::text;
    END IF;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'completion_validation_failure');
    END IF;
    IF v_record.status = 'in_progress' THEN
      UPDATE public.training_session_records
      SET status = v_status,
          completed_at = COALESCE(NULLIF(v_completion->>'completed_at', '')::timestamptz, NOW()),
          duration_seconds = NULLIF(v_completion->>'duration_seconds', '')::integer,
          overall_rpe = NULLIF(v_completion->>'overall_rpe', '')::integer,
          athlete_note = NULLIF(v_completion->>'athlete_note', ''),
          session_snapshot = COALESCE(v_completion->'session_snapshot', session_snapshot),
          updated_at = NOW()
      WHERE record_id = v_record_id
        AND athlete_id = v_athlete_id::text;
      SELECT * INTO v_record FROM public.training_session_records WHERE record_id = v_record_id;
    ELSIF v_record.status IS DISTINCT FROM v_status THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'completion_validation_failure');
    END IF;
  ELSE
    SELECT * INTO v_record FROM public.training_session_records WHERE record_id = v_record_id;
  END IF;

  INSERT INTO public.programme_slot_outcomes (
    assignment_id,
    session_slot_id,
    week_number,
    day_key,
    session_order,
    outcome_status,
    training_session_id,
    resolution_note,
    resolved_at,
    logical_completion_key,
    idempotency_key,
    programme_version_id,
    materialised_package_content_hash,
    completion_record_id,
    actuals_fingerprint,
    programmed_session_key
  ) VALUES (
    v_assignment.id,
    v_session_slot_id,
    v_expected_week,
    v_expected_day,
    v_expected_slot,
    v_outcome_status,
    v_training_session_id,
    NULLIF(v_completion->>'athlete_note', ''),
    COALESCE(v_record.completed_at, NOW()),
    v_logical_key,
    v_idempotency_key,
    v_version.id,
    v_package_hash,
    v_record.record_id,
    v_actuals_fp,
    v_programmed_key
  )
  ON CONFLICT (assignment_id, session_slot_id) DO UPDATE SET
    outcome_status = EXCLUDED.outcome_status,
    training_session_id = EXCLUDED.training_session_id,
    resolution_note = EXCLUDED.resolution_note,
    resolved_at = EXCLUDED.resolved_at,
    logical_completion_key = COALESCE(public.programme_slot_outcomes.logical_completion_key, EXCLUDED.logical_completion_key),
    idempotency_key = COALESCE(public.programme_slot_outcomes.idempotency_key, EXCLUDED.idempotency_key),
    programme_version_id = EXCLUDED.programme_version_id,
    materialised_package_content_hash = EXCLUDED.materialised_package_content_hash,
    completion_record_id = EXCLUDED.completion_record_id,
    actuals_fingerprint = COALESCE(public.programme_slot_outcomes.actuals_fingerprint, EXCLUDED.actuals_fingerprint),
    programmed_session_key = EXCLUDED.programmed_session_key,
    updated_at = NOW()
  WHERE public.programme_slot_outcomes.outcome_status IN ('scheduled', 'in_progress')
     OR (
       public.programme_slot_outcomes.logical_completion_key IS NOT DISTINCT FROM EXCLUDED.logical_completion_key
       AND public.programme_slot_outcomes.actuals_fingerprint IS NOT DISTINCT FROM EXCLUDED.actuals_fingerprint
     );

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'logical_completion_payload_conflict');
  END IF;

  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment.id
    AND session_slot_id = v_session_slot_id;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);

  IF v_next_week IS NULL THEN
    -- Existing terminal assignment contract (status=completed). No invented lifecycle.
    UPDATE public.programme_assignments
    SET status = 'completed',
        completed_at = COALESCE(completed_at, NOW()),
        last_progressed_training_session_id = v_training_session_id,
        updated_at = NOW()
    WHERE id = v_assignment.id
      AND athlete_id = v_athlete_id
      AND status = 'active'
      AND current_week_number = v_expected_week
      AND current_day_key = v_expected_day
      AND current_slot_order = v_expected_slot;
  ELSE
    UPDATE public.programme_assignments
    SET current_week_number = v_next_week,
        current_day_key = v_next_day,
        current_slot_order = v_next_slot,
        last_progressed_training_session_id = v_training_session_id,
        updated_at = NOW()
    WHERE id = v_assignment.id
      AND athlete_id = v_athlete_id
      AND status = 'active'
      AND current_week_number = v_expected_week
      AND current_day_key = v_expected_day
      AND current_slot_order = v_expected_slot;
  END IF;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RAISE EXCEPTION 'cursor_cas_failed' USING ERRCODE = '40001';
  END IF;

  SELECT * INTO v_assignment FROM public.programme_assignments WHERE id = v_assignment_id;

  RETURN jsonb_build_object(
    'status', 'committed',
    'code', 'completed_and_advanced',
    'completion_record_id', v_record.record_id,
    'training_session_id', v_training_session_id,
    'outcome_id', v_outcome.id,
    'logical_completion_key', v_logical_key,
    'programmed_session_key', v_programmed_key,
    'terminal_programme', (v_next_week IS NULL),
    'next_cursor', CASE
      WHEN v_next_week IS NULL THEN NULL
      ELSE jsonb_build_object(
        'week_number', v_next_week,
        'day_key', v_next_day,
        'slot_order', v_next_slot,
        'protocol_id', v_next_protocol,
        'session_slot_id', v_next_slot_id
      )
    END,
    'assignment', jsonb_build_object(
      'id', v_assignment.id,
      'athlete_id', v_assignment.athlete_id,
      'lineage_code', v_assignment.lineage_code,
      'status', v_assignment.status,
      'programme_version_id', v_assignment.programme_version_id,
      'materialised_package_content_hash', v_assignment.materialised_package_content_hash,
      'started_at', v_assignment.started_at,
      'materialised_at', v_assignment.materialised_at,
      'materialisation_source', v_assignment.materialisation_source,
      'current_week_number', v_assignment.current_week_number,
      'current_day_key', v_assignment.current_day_key,
      'current_slot_order', v_assignment.current_slot_order,
      'last_progressed_training_session_id', v_assignment.last_progressed_training_session_id,
      'completed_at', v_assignment.completed_at
    ),
    'completion_record', to_jsonb(v_record)
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'logical_completion_payload_conflict');
  WHEN serialization_failure OR deadlock_detected THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'stale_cursor');
  WHEN others THEN
    IF SQLERRM = 'cursor_cas_failed' THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'stale_cursor');
    END IF;
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_programme_session_and_advance(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.complete_programme_session_and_advance(JSONB) FROM anon;
GRANT EXECUTE ON FUNCTION public.complete_programme_session_and_advance(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_programme_session_and_advance(JSONB) TO service_role;

COMMENT ON FUNCTION public.complete_programme_session_and_advance(JSONB) IS
  'Sprint 1.5A: athlete-explicit atomic completion + authored cursor advancement. Identity from auth.uid(); rejects client-nominated athlete/next cursor; exactly-once via logical completion uniqueness and cursor CAS.';
