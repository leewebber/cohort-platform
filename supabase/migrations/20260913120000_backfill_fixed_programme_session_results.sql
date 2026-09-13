-- Truthful backfill persistence for fixed-programme occurrences.
--
-- Schedule authority remains programme_schedule_occurrences.scheduled_date.
-- This migration does not add a scheduled_date copy onto result rows and does
-- not rewrite existing live completion timestamps or occurrence dispositions.
--
-- recorded_at is not added. For a newly inserted backfill row, created_at is
-- the immutable server submission timestamp. Live rows keep created_at as the
-- original insert time (session start persistence), which is not athletic
-- chronology and must not be back-filled into performed_on.

ALTER TABLE public.training_session_records
  ADD COLUMN IF NOT EXISTS entry_mode TEXT NOT NULL DEFAULT 'live';

ALTER TABLE public.training_session_records
  ADD COLUMN IF NOT EXISTS performed_on DATE;

ALTER TABLE public.training_session_records
  ADD COLUMN IF NOT EXISTS performed_precision TEXT NOT NULL DEFAULT 'timestamp';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'training_session_records_entry_mode_check'
  ) THEN
    ALTER TABLE public.training_session_records
      ADD CONSTRAINT training_session_records_entry_mode_check
      CHECK (entry_mode IN ('live', 'backfill'));
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'training_session_records_performed_precision_check'
  ) THEN
    ALTER TABLE public.training_session_records
      ADD CONSTRAINT training_session_records_performed_precision_check
      CHECK (performed_precision IN ('timestamp', 'date'));
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'training_session_records_entry_truth_check'
  ) THEN
    ALTER TABLE public.training_session_records
      ADD CONSTRAINT training_session_records_entry_truth_check
      CHECK (
        (
          entry_mode = 'live'
          AND performed_on IS NULL
          AND performed_precision = 'timestamp'
        )
        OR (
          entry_mode = 'backfill'
          AND performed_on IS NOT NULL
          AND performed_precision = 'date'
        )
      );
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS training_session_records_one_backfill_per_slot_uidx
  ON public.training_session_records (
    athlete_id,
    assignment_id,
    programme_session_id
  )
  WHERE entry_mode = 'backfill'
    AND programme_session_id IS NOT NULL
    AND status IN ('completed', 'partially_completed');

COMMENT ON COLUMN public.training_session_records.entry_mode IS
  'live = captured during an executable session; backfill = historical results entered later.';
COMMENT ON COLUMN public.training_session_records.performed_on IS
  'Athlete-declared local calendar date for backfill only. Live chronology stays on started_at/completed_at.';
COMMENT ON COLUMN public.training_session_records.performed_precision IS
  'timestamp for live clocked sessions; date for backfill. Do not invent clock time for date precision.';
COMMENT ON COLUMN public.training_session_records.created_at IS
  'Immutable insert time. For backfill this is the server recorded-at / entered timestamp.';

CREATE OR REPLACE FUNCTION public.cohort_insert_training_session_result_tree(
  p_record_id UUID,
  p_blocks JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_block JSONB;
  v_exercise JSONB;
  v_set JSONB;
  v_block_id UUID;
  v_exercise_id UUID;
  v_set_id UUID;
  v_position INT := 0;
BEGIN
  IF p_blocks IS NULL OR jsonb_typeof(p_blocks) <> 'array' OR jsonb_array_length(p_blocks) < 1 THEN
    RAISE EXCEPTION 'empty_result_tree' USING ERRCODE = 'P0001';
  END IF;

  FOR v_block IN
    SELECT value FROM jsonb_array_elements(p_blocks)
  LOOP
    v_position := v_position + 1;
    BEGIN
      v_block_id := NULLIF(v_block->>'block_result_id', '')::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
    END;
    IF v_block_id IS NULL THEN
      RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.training_block_results (
      block_result_id,
      session_record_id,
      source_block_id,
      block_snapshot,
      status,
      result_type,
      result_data,
      athlete_note,
      started_at,
      completed_at,
      duration_seconds,
      position
    ) VALUES (
      v_block_id,
      p_record_id,
      NULLIF(v_block->>'source_block_id', ''),
      COALESCE(v_block->'block_snapshot', '{}'::jsonb),
      COALESCE(NULLIF(v_block->>'status', ''), 'completed'),
      COALESCE(NULLIF(v_block->>'result_type', ''), 'completion'),
      v_block->'result_data',
      NULLIF(v_block->>'athlete_note', ''),
      NULLIF(v_block->>'started_at', '')::timestamptz,
      NULLIF(v_block->>'completed_at', '')::timestamptz,
      NULLIF(v_block->>'duration_seconds', '')::integer,
      COALESCE(NULLIF(v_block->>'position', '')::integer, v_position)
    )
    ON CONFLICT (block_result_id) DO NOTHING;

    IF jsonb_typeof(v_block->'exercise_results') = 'array' THEN
      FOR v_exercise IN
        SELECT value FROM jsonb_array_elements(v_block->'exercise_results')
      LOOP
        BEGIN
          v_exercise_id := NULLIF(v_exercise->>'exercise_result_id', '')::UUID;
        EXCEPTION WHEN invalid_text_representation THEN
          RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
        END;
        IF v_exercise_id IS NULL THEN
          RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
        END IF;
        INSERT INTO public.training_exercise_results (
          exercise_result_id,
          block_result_id,
          source_exercise_id,
          exercise_snapshot,
          athlete_note,
          position
        ) VALUES (
          v_exercise_id,
          v_block_id,
          NULLIF(v_exercise->>'source_exercise_id', ''),
          COALESCE(v_exercise->'exercise_snapshot', '{}'::jsonb),
          NULLIF(v_exercise->>'athlete_note', ''),
          COALESCE(NULLIF(v_exercise->>'position', '')::integer, 0)
        )
        ON CONFLICT (exercise_result_id) DO NOTHING;

        IF jsonb_typeof(v_exercise->'set_results') = 'array' THEN
          FOR v_set IN
            SELECT value FROM jsonb_array_elements(v_exercise->'set_results')
          LOOP
            BEGIN
              v_set_id := NULLIF(v_set->>'set_result_id', '')::UUID;
            EXCEPTION WHEN invalid_text_representation THEN
              RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
            END;
            IF v_set_id IS NULL THEN
              RAISE EXCEPTION 'invalid_result_tree' USING ERRCODE = 'P0001';
            END IF;
            INSERT INTO public.training_set_results (
              set_result_id,
              exercise_result_id,
              set_number,
              reps,
              load,
              load_unit,
              distance,
              distance_unit,
              duration_seconds,
              completed,
              rpe,
              note,
              position
            ) VALUES (
              v_set_id,
              v_exercise_id,
              COALESCE(NULLIF(v_set->>'set_number', '')::integer, 0),
              NULLIF(v_set->>'reps', '')::numeric,
              NULLIF(v_set->>'load', '')::numeric,
              NULLIF(v_set->>'load_unit', ''),
              NULLIF(v_set->>'distance', '')::numeric,
              NULLIF(v_set->>'distance_unit', ''),
              NULLIF(v_set->>'duration_seconds', '')::integer,
              COALESCE((v_set->>'completed')::boolean, FALSE),
              NULLIF(v_set->>'rpe', '')::numeric,
              NULLIF(v_set->>'note', ''),
              COALESCE(NULLIF(v_set->>'position', '')::integer, 0)
            )
            ON CONFLICT (set_result_id) DO NOTHING;
          END LOOP;
        END IF;
      END LOOP;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_insert_training_session_result_tree(UUID, JSONB)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.cohort_training_session_record_with_tree(
  p_record_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_record public.training_session_records%ROWTYPE;
BEGIN
  SELECT * INTO v_record
  FROM public.training_session_records
  WHERE record_id = p_record_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN to_jsonb(v_record) || jsonb_build_object(
    'recorded_at', v_record.created_at,
    'block_results', COALESCE((
      SELECT jsonb_agg(
        to_jsonb(b) || jsonb_build_object(
          'exercise_results', COALESCE((
            SELECT jsonb_agg(
              to_jsonb(e) || jsonb_build_object(
                'set_results', COALESCE((
                  SELECT jsonb_agg(to_jsonb(s) ORDER BY s.position)
                  FROM public.training_set_results s
                  WHERE s.exercise_result_id = e.exercise_result_id
                ), '[]'::jsonb)
              )
              ORDER BY e.position
            )
            FROM public.training_exercise_results e
            WHERE e.block_result_id = b.block_result_id
          ), '[]'::jsonb)
        )
        ORDER BY b.position
      )
      FROM public.training_block_results b
      WHERE b.session_record_id = v_record.record_id
    ), '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_training_session_record_with_tree(UUID)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.cohort_complete_backfilled_fixed_occurrence_at(
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
  v_occurrence_id UUID;
  v_assignment_id UUID;
  v_performed_on DATE;
  v_idem TEXT;
  v_actuals_fp TEXT;
  v_status TEXT;
  v_record_id UUID;
  v_expected_key TEXT;
  v_today DATE;
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_assignment public.programme_assignments%ROWTYPE;
  v_outcome public.programme_slot_outcomes%ROWTYPE;
  v_record public.training_session_records%ROWTYPE;
  v_session public.training_sessions%ROWTYPE;
  v_completion JSONB;
  v_blocks JSONB;
  v_outcome_status TEXT;
  v_outcome_found BOOLEAN := FALSE;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required'
    );
  END IF;
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;
  IF payload ? 'athlete_id' OR payload ? 'next_week' OR payload ? 'next_cursor'
     OR payload ? 'scheduled_date' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'client_nominated_authority_forbidden'
    );
  END IF;

  BEGIN
    v_occurrence_id := NULLIF(trim(payload->>'occurrence_id'), '')::UUID;
    v_assignment_id := NULLIF(trim(payload->>'assignment_id'), '')::UUID;
    v_performed_on := NULLIF(trim(payload->>'performed_on'), '')::DATE;
    v_idem := NULLIF(trim(payload->>'idempotency_key'), '');
    v_actuals_fp := NULLIF(trim(payload->>'actuals_fingerprint'), '');
    v_status := NULLIF(trim(payload->>'status'), '');
    v_record_id := NULLIF(trim(payload->>'record_id'), '')::UUID;
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END;

  IF v_occurrence_id IS NULL OR v_assignment_id IS NULL
     OR v_performed_on IS NULL OR v_idem IS NULL
     OR v_actuals_fp IS NULL OR v_record_id IS NULL
     OR v_status IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'completion_validation_failure'
    );
  END IF;
  IF v_status NOT IN ('completed', 'partially_completed') THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'completion_validation_failure'
    );
  END IF;

  v_expected_key := format(
    'backfill:%s:%s:%s',
    v_athlete::text,
    v_assignment_id::text,
    v_occurrence_id::text
  );
  IF v_idem IS DISTINCT FROM v_expected_key THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'idempotency_key_mismatch'
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84260913, hashtext(v_occurrence_id::TEXT));

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
  IF v_occ.assignment_id IS DISTINCT FROM v_assignment_id THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_lineage_mismatch'
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
     OR v_assignment.materialised_at IS NULL THEN
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

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;

  IF v_occ.scheduled_date >= v_today THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'future_occurrence'
    );
  END IF;
  IF v_performed_on > v_today THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'future_date'
    );
  END IF;
  IF v_performed_on < v_occ.scheduled_date THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'before_scheduled'
    );
  END IF;
  IF v_assignment.started_at IS NOT NULL
     AND v_performed_on < (v_assignment.started_at AT TIME ZONE v_assignment.timezone)::DATE
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'before_assignment'
    );
  END IF;

  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_occ.assignment_id
    AND session_slot_id = v_occ.session_slot_id
  FOR UPDATE;
  v_outcome_found := FOUND;

  IF v_outcome_found AND v_outcome.outcome_status = 'skipped' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_skipped'
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
     AND v_occ.disposition IS DISTINCT FROM 'completed' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'fixed_occurrence_ineligible'
    );
  END IF;

  IF v_outcome_found AND v_outcome.idempotency_key IS NOT DISTINCT FROM v_idem THEN
    IF v_outcome.actuals_fingerprint IS DISTINCT FROM v_actuals_fp THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'idempotency_payload_conflict'
      );
    END IF;
    SELECT * INTO v_record
    FROM public.training_session_records
    WHERE record_id = v_outcome.completion_record_id;
    RETURN jsonb_build_object(
      'status', 'already_committed',
      'code', 'idempotent_replay',
      'completion_record_id', v_outcome.completion_record_id,
      'training_session_id', v_outcome.training_session_id,
      'occurrence_id', v_occ.id,
      'original_scheduled_date', v_occ.original_scheduled_date,
      'performed_on', to_char(v_record.performed_on, 'YYYY-MM-DD'),
      'recorded_at', v_record.created_at,
      'entry_mode', v_record.entry_mode,
      'completion_record', public.cohort_training_session_record_with_tree(v_record.record_id)
    );
  END IF;

  IF v_outcome_found AND v_outcome.outcome_status IN ('completed', 'completed_partial') THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'already_completed'
    );
  END IF;
  IF v_occ.disposition = 'completed' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'already_completed'
    );
  END IF;
  IF v_outcome_found AND v_outcome.outcome_status = 'in_progress' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_in_progress'
    );
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.training_session_records r
    WHERE r.athlete_id = v_athlete::text
      AND r.assignment_id = v_assignment.id
      AND r.programme_session_id = v_occ.session_slot_id
      AND r.status = 'in_progress'
  ) THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_in_progress'
    );
  END IF;

  v_completion := COALESCE(payload->'completion_record', '{}'::jsonb);
  v_blocks := v_completion->'block_results';
  IF v_blocks IS NULL OR jsonb_typeof(v_blocks) <> 'array' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'empty_result_tree'
    );
  END IF;

  v_outcome_status := CASE
    WHEN v_status = 'completed' THEN 'completed'
    ELSE 'completed_partial'
  END;

  INSERT INTO public.training_sessions (
    athlete_id,
    protocol_id,
    programme_id,
    week_number,
    status,
    started_at,
    completed_at,
    created_at,
    updated_at
  ) VALUES (
    v_athlete::TEXT,
    v_occ.protocol_id,
    v_assignment.lineage_code,
    v_occ.week_number,
    'completed',
    p_now,
    p_now,
    p_now,
    p_now
  )
  RETURNING * INTO v_session;

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
    entry_mode,
    performed_on,
    performed_precision,
    updated_at
  ) VALUES (
    v_record_id,
    v_athlete::text,
    v_session.id,
    COALESCE(v_completion->>'source_protocol_id', v_occ.protocol_id),
    NULLIF(v_completion->>'programme_id', ''),
    v_assignment.id,
    v_occ.session_slot_id,
    v_status,
    COALESCE(v_completion->'session_snapshot', '{}'::jsonb),
    NULLIF(v_completion->>'active_block_id', ''),
    p_now,
    p_now,
    NULLIF(v_completion->>'duration_seconds', '')::integer,
    NULLIF(v_completion->>'overall_rpe', '')::integer,
    NULLIF(v_completion->>'athlete_note', ''),
    'backfill',
    v_performed_on,
    'date',
    p_now
  );

  BEGIN
    PERFORM public.cohort_insert_training_session_result_tree(v_record_id, v_blocks);
  EXCEPTION WHEN others THEN
    IF SQLERRM IN ('empty_result_tree', 'invalid_result_tree') THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', SQLERRM
      );
    END IF;
    RAISE;
  END;

  IF v_outcome_found THEN
    UPDATE public.programme_slot_outcomes
    SET outcome_status = v_outcome_status,
        training_session_id = v_session.id,
        resolution_note = NULLIF(v_completion->>'athlete_note', ''),
        resolved_at = p_now,
        logical_completion_key = v_idem,
        idempotency_key = v_idem,
        programme_version_id = v_occ.programme_version_id,
        materialised_package_content_hash = v_occ.package_content_hash,
        completion_record_id = v_record_id,
        actuals_fingerprint = v_actuals_fp,
        programmed_session_key = v_occ.programmed_session_key,
        updated_at = NOW()
    WHERE id = v_outcome.id
      AND outcome_status IN ('scheduled', 'in_progress');
    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'already_completed'
      );
    END IF;
  ELSE
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
      v_occ.session_slot_id,
      v_occ.week_number,
      v_occ.day_key,
      v_occ.session_order,
      v_outcome_status,
      v_session.id,
      NULLIF(v_completion->>'athlete_note', ''),
      p_now,
      v_idem,
      v_idem,
      v_occ.programme_version_id,
      v_occ.package_content_hash,
      v_record_id,
      v_actuals_fp,
      v_occ.programmed_session_key
    );
  END IF;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE public.programme_schedule_occurrences
  SET disposition = 'completed',
      updated_at = NOW()
  WHERE id = v_occ.id
    AND disposition IN ('scheduled', 'missed');
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'already_completed'
    );
  END IF;

  SELECT * INTO v_record
  FROM public.training_session_records
  WHERE record_id = v_record_id;

  RETURN jsonb_build_object(
    'status', 'committed',
    'code', 'backfill_committed',
    'completion_record_id', v_record.record_id,
    'training_session_id', v_session.id,
    'occurrence_id', v_occ.id,
    'original_scheduled_date', v_occ.original_scheduled_date,
    'performed_on', to_char(v_record.performed_on, 'YYYY-MM-DD'),
    'recorded_at', v_record.created_at,
    'entry_mode', 'backfill',
    'completion_record', public.cohort_training_session_record_with_tree(v_record.record_id)
  );
EXCEPTION
  WHEN unique_violation THEN
    SELECT * INTO v_outcome
    FROM public.programme_slot_outcomes
    WHERE assignment_id = v_assignment_id
      AND idempotency_key = v_idem;
    IF FOUND THEN
      RETURN jsonb_build_object(
        'status', 'already_committed',
        'code', 'idempotent_replay',
        'completion_record_id', v_outcome.completion_record_id,
        'training_session_id', v_outcome.training_session_id,
        'occurrence_id', v_occurrence_id,
        'completion_record', public.cohort_training_session_record_with_tree(
          v_outcome.completion_record_id
        )
      );
    END IF;
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'already_completed'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_complete_backfilled_fixed_occurrence_at(
  JSONB,
  TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.complete_backfilled_fixed_programme_occurrence(
  payload JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.cohort_complete_backfilled_fixed_occurrence_at(
    payload,
    clock_timestamp()
  );
$$;

REVOKE ALL ON FUNCTION public.complete_backfilled_fixed_programme_occurrence(JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_backfilled_fixed_programme_occurrence(JSONB)
  TO authenticated;

COMMENT ON FUNCTION public.complete_backfilled_fixed_programme_occurrence(JSONB) IS
  'Atomic historical result save for one past unfinished fixed-programme occurrence. Does not advance the assignment cursor.';

CREATE OR REPLACE FUNCTION public.cohort_athlete_runtime_capabilities()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required',
      'schema_version', 1,
      'overdue_recovery', false,
      'backfill_results', false
    );
  END IF;
  RETURN jsonb_build_object(
    'status', 'ok',
    'schema_version', 1,
    'overdue_recovery', EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = 'create_or_resume_fixed_programme_occurrence_session'
    ),
    'backfill_results', true
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_athlete_runtime_capabilities()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_athlete_runtime_capabilities()
  TO authenticated;

COMMENT ON FUNCTION public.cohort_athlete_runtime_capabilities() IS
  'Explicit hosted capability probe. Absence of this RPC means backfill is unavailable.';
