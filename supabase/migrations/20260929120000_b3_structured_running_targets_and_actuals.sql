-- Structured Running B3 slice 3: server-authoritative frozen targets in
-- completed History and exact authored work-repetition actual identities.
--
-- This is intentionally dormant unless an occurrence has both the immutable
-- B2 target snapshot and the hash-attested B3 execution mapping. Existing v1,
-- unattached v2, Bali, Apollo, and non-running result rows are unchanged.

CREATE OR REPLACE FUNCTION public.cohort_b3_running_completion_authority(
  p_training_session_id BIGINT,
  p_record_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_record public.training_session_records%ROWTYPE;
  v_snapshot public.programme_occurrence_running_target_snapshots%ROWTYPE;
  v_occurrence public.programme_schedule_occurrences%ROWTYPE;
  v_slot public.programme_version_session_slots%ROWTYPE;
  v_authored JSONB;
  v_block public.session_blocks%ROWTYPE;
  v_workout_id TEXT;
  v_work_step_id TEXT;
  v_block_id UUID;
  v_repetitions JSONB;
  v_rounds INT;
  v_work_seconds INT;
BEGIN
  SELECT * INTO v_record
  FROM public.training_session_records
  WHERE record_id = p_record_id
    AND training_session_id = p_training_session_id;
  IF NOT FOUND OR v_record.assignment_id IS NULL
     OR v_record.programme_session_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT snapshot_row.* INTO v_snapshot
  FROM public.programme_occurrence_running_target_snapshots snapshot_row
  WHERE snapshot_row.training_session_id = p_training_session_id
    AND snapshot_row.assignment_id = v_record.assignment_id
    AND snapshot_row.athlete_id::TEXT = v_record.athlete_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  SELECT * INTO v_occurrence
  FROM public.programme_schedule_occurrences
  WHERE id = v_snapshot.occurrence_id;
  IF NOT FOUND
     OR v_occurrence.assignment_id IS DISTINCT FROM v_record.assignment_id
     OR v_occurrence.session_slot_id IS DISTINCT FROM v_record.programme_session_id
  THEN
    RAISE EXCEPTION 'structured_running_occurrence_record_mismatch'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  SELECT * INTO v_slot
  FROM public.programme_version_session_slots
  WHERE id = v_record.programme_session_id;
  IF NOT FOUND OR v_slot.authored_running_v1 IS NULL
     OR NOT (v_slot.authored_running_v1 ? 'executable_step_bindings') THEN
    RETURN NULL;
  END IF;
  v_authored := v_slot.authored_running_v1;
  IF NOT public.cohort_authored_running_v1_is_valid(v_authored)
     OR NOT public.cohort_running_execution_mapping_matches_protocol(
       v_authored,
       v_slot.protocol_id
     )
     OR (v_snapshot.snapshot->>'programme_version_id')::UUID IS DISTINCT FROM (
       SELECT w.version_id
       FROM public.programme_version_days d
       JOIN public.programme_version_weeks w ON w.id = d.week_id
       WHERE d.id = v_slot.day_id
     )
     OR v_snapshot.snapshot->>'session_slot_id' IS DISTINCT FROM v_slot.id::TEXT
     OR v_snapshot.snapshot->>'package_content_hash'
        IS DISTINCT FROM v_occurrence.package_content_hash
     OR v_snapshot.snapshot->>'workout_id'
        IS DISTINCT FROM v_authored->>'workout_id' THEN
    RAISE EXCEPTION 'structured_running_completion_authority_mismatch'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  v_workout_id := v_authored->>'workout_id';
  v_block_id := (v_authored#>>'{executable_step_bindings,0,session_block_id}')::UUID;
  SELECT * INTO v_block
  FROM public.session_blocks
  WHERE block_id = v_block_id
    AND session_id = v_slot.protocol_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'structured_running_mapped_block_missing'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  IF v_block.workout_format = 'steady_state' THEN
    v_work_step_id := v_workout_id || ':s:0';
    v_rounds := 1;
    v_work_seconds := COALESCE(
      NULLIF(v_block.timer_config->>'durationSeconds', '')::INT,
      NULLIF(v_block.timer_config->>'duration_seconds', '')::INT
    );
  ELSIF v_block.workout_format = 'intervals' THEN
    v_work_step_id := v_workout_id || ':s:work';
    v_rounds := NULLIF(v_block.timer_config->>'rounds', '')::INT;
    v_work_seconds := COALESCE(
      NULLIF(v_block.timer_config->>'workSeconds', '')::INT,
      NULLIF(v_block.timer_config->>'work_seconds', '')::INT
    );
  ELSE
    RAISE EXCEPTION 'structured_running_unsupported_block'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  IF v_rounds IS NULL OR v_rounds < 1
     OR v_work_seconds IS NULL OR v_work_seconds < 1
     OR NOT EXISTS (
       SELECT 1
       FROM jsonb_array_elements(v_authored->'executable_step_bindings') binding
       WHERE binding->>'step_id' = v_work_step_id
         AND binding->>'session_block_id' = v_block_id::TEXT
     ) THEN
    RAISE EXCEPTION 'structured_running_work_identity_mismatch'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(v_snapshot.snapshot->'targets') target
    CROSS JOIN LATERAL jsonb_array_elements_text(target#>'{scope,step_ids}') step_id
    WHERE target->>'state' = 'calculated'
      AND step_id <> v_work_step_id
  ) OR EXISTS (
    SELECT step_id
    FROM jsonb_array_elements(v_snapshot.snapshot->'targets') target
    CROSS JOIN LATERAL jsonb_array_elements_text(target#>'{scope,step_ids}') step_id
    GROUP BY step_id
    HAVING count(*) > 1
  ) OR EXISTS (
    SELECT 1
    FROM jsonb_array_elements(v_snapshot.snapshot->'targets') target
    WHERE target->>'state' = 'calculated'
      AND target#>>'{calculated_exact_range,unit}'
          IS DISTINCT FROM 'milliseconds_per_kilometre'
  ) THEN
    RAISE EXCEPTION 'structured_running_target_scope_invalid'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'workout_id', v_workout_id,
      'session_block_id', v_block_id::TEXT,
      'authored_step_id', v_work_step_id,
      'repeat_ordinal', ordinal,
      'work_seconds', v_work_seconds
    ) ORDER BY ordinal
  ) INTO v_repetitions
  FROM generate_series(1, v_rounds) ordinal;

  RETURN jsonb_build_object(
    'schema_version', 1,
    'workout_id', v_workout_id,
    'execution_mapping_sha256', v_authored->>'execution_mapping_sha256',
    'session_block_id', v_block_id::TEXT,
    'package_content_hash', v_snapshot.snapshot->>'package_content_hash',
    'frozen_target_snapshot', v_snapshot.snapshot,
    'work_repetitions', v_repetitions
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_b3_running_actuals_match_authority(
  p_result JSONB,
  p_authority JSONB,
  p_allow_pending BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row JSONB;
  v_expected JSONB;
  v_identity TEXT;
  v_seen TEXT[] := ARRAY[]::TEXT[];
  v_state TEXT;
  v_pace NUMERIC;
BEGIN
  IF p_result IS NULL OR jsonb_typeof(p_result) <> 'object'
     OR p_result->>'resultType' IS DISTINCT FROM 'interval'
     OR COALESCE(p_result->>'paceUnit', 'sec_per_km')
        NOT IN ('sec_per_km', 's/km', 'sec/km')
     OR jsonb_typeof(p_result->'intervals') <> 'array'
     OR jsonb_typeof(p_authority->'work_repetitions') <> 'array'
     OR jsonb_array_length(p_result->'intervals')
        <> jsonb_array_length(p_authority->'work_repetitions') THEN
    RETURN FALSE;
  END IF;

  FOR v_row IN SELECT value FROM jsonb_array_elements(p_result->'intervals')
  LOOP
    v_identity := concat_ws('|',
      v_row->>'workoutId',
      v_row->>'sessionBlockId',
      v_row->>'authoredStepId',
      v_row->>'repeatOrdinal'
    );
    IF v_identity = ANY(v_seen) THEN
      RETURN FALSE;
    END IF;
    v_seen := array_append(v_seen, v_identity);
    SELECT repetition INTO v_expected
    FROM jsonb_array_elements(p_authority->'work_repetitions') repetition
    WHERE repetition->>'workout_id' = v_row->>'workoutId'
      AND repetition->>'session_block_id' = v_row->>'sessionBlockId'
      AND repetition->>'authored_step_id' = v_row->>'authoredStepId'
      AND (repetition->>'repeat_ordinal')::INT
          = NULLIF(v_row->>'repeatOrdinal', '')::INT;
    IF v_expected IS NULL
       OR (v_expected->>'work_seconds')::INT
          IS DISTINCT FROM NULLIF(v_row->>'workSeconds', '')::INT
       OR COALESCE(v_row->>'paceUnit', 'sec_per_km')
          NOT IN ('sec_per_km', 's/km', 'sec/km') THEN
      RETURN FALSE;
    END IF;
    v_state := COALESCE(v_row->>'state', 'pending');
    v_pace := NULLIF(v_row->>'paceSecondsPerKm', '')::NUMERIC;
    IF v_state NOT IN ('pending', 'completed', 'skipped', 'pace_unavailable')
       OR (NOT p_allow_pending AND v_state = 'pending')
       OR (v_state = 'completed' AND (v_pace IS NULL OR v_pace <= 0))
       OR (v_state <> 'completed' AND v_pace IS NOT NULL) THEN
      RETURN FALSE;
    END IF;
  END LOOP;
  RETURN cardinality(v_seen) = jsonb_array_length(
    p_authority->'work_repetitions'
  );
EXCEPTION WHEN others THEN
  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_guard_b3_running_result_authority()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status TEXT;
  v_training_session_id BIGINT;
  v_expected_authority JSONB;
  v_authority JSONB := NEW.block_snapshot->'structuredRunningV1';
BEGIN
  SELECT status, training_session_id
  INTO v_status, v_training_session_id
  FROM public.training_session_records
  WHERE record_id = NEW.session_record_id;
  IF OLD.block_snapshot ? 'structuredRunningV1'
     AND NEW.block_snapshot->'structuredRunningV1'
         IS DISTINCT FROM OLD.block_snapshot->'structuredRunningV1'
  THEN
    IF v_status NOT IN ('completed', 'partially_completed')
       OR v_training_session_id IS NULL THEN
      RAISE EXCEPTION 'structured_running_prescription_immutable'
        USING ERRCODE = '42501';
    END IF;
    v_expected_authority := public.cohort_b3_running_completion_authority(
      v_training_session_id,
      NEW.session_record_id
    );
    IF v_expected_authority IS NULL
       OR NEW.block_snapshot->'structuredRunningV1'
          IS DISTINCT FROM v_expected_authority THEN
      RAISE EXCEPTION 'structured_running_prescription_immutable'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  IF v_status IN ('completed', 'partially_completed')
     AND v_authority IS NOT NULL
     AND NOT public.cohort_b3_running_actuals_match_authority(
       NEW.result_data,
       v_authority,
       FALSE
     ) THEN
    RAISE EXCEPTION 'structured_running_actuals_authority_mismatch'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS b3_running_result_authority
  ON public.training_block_results;
CREATE TRIGGER b3_running_result_authority
  BEFORE UPDATE OF block_snapshot, result_data
  ON public.training_block_results
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_guard_b3_running_result_authority();

CREATE OR REPLACE FUNCTION public.cohort_freeze_b3_running_completion_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_authority JSONB;
  v_block_id TEXT;
  v_rows INT;
  v_has_skipped BOOLEAN;
BEGIN
  IF NEW.status NOT IN ('completed', 'partially_completed')
     OR NEW.training_session_id IS NULL THEN
    RETURN NEW;
  END IF;
  v_authority := public.cohort_b3_running_completion_authority(
    NEW.training_session_id,
    NEW.record_id
  );
  IF v_authority IS NULL THEN
    RETURN NEW;
  END IF;
  v_block_id := v_authority->>'session_block_id';
  UPDATE public.training_block_results
  SET block_snapshot = jsonb_set(
        COALESCE(block_snapshot, '{}'::JSONB),
        '{structuredRunningV1}',
        v_authority,
        TRUE
      ),
      updated_at = NOW()
  WHERE session_record_id = NEW.record_id
    AND source_block_id = v_block_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'structured_running_completed_block_missing'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.training_block_results block_result
    CROSS JOIN LATERAL jsonb_array_elements(
      block_result.result_data->'intervals'
    ) interval_row
    WHERE block_result.session_record_id = NEW.record_id
      AND block_result.source_block_id = v_block_id
      AND interval_row->>'state' = 'skipped'
  ) INTO v_has_skipped;
  IF v_has_skipped AND NEW.status IS DISTINCT FROM 'partially_completed' THEN
    RAISE EXCEPTION 'structured_running_skipped_requires_partial_session'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS freeze_b3_running_completion_history
  ON public.training_session_records;
CREATE TRIGGER freeze_b3_running_completion_history
  AFTER INSERT OR UPDATE OF status
  ON public.training_session_records
  FOR EACH ROW
  WHEN (NEW.status IN ('completed', 'partially_completed'))
  EXECUTE FUNCTION public.cohort_freeze_b3_running_completion_history();

REVOKE ALL ON FUNCTION public.cohort_b3_running_completion_authority(BIGINT, UUID)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_b3_running_actuals_match_authority(JSONB, JSONB, BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_guard_b3_running_result_authority()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_freeze_b3_running_completion_history()
  FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.cohort_freeze_b3_running_completion_history() IS
  'B3 slice 3: injects only server-derived occurrence target authority into completed structured-running History and rejects mismatched actual identities.';
