-- Narrow completed-performance correction authority.
-- Does not reopen a completed session and does not add a broad UPDATE
-- policy on completed training sets.

CREATE TABLE IF NOT EXISTS public.performance_result_corrections (
  correction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id UUID NOT NULL
    REFERENCES public.training_session_records (record_id) ON DELETE CASCADE,
  training_session_id BIGINT
    REFERENCES public.training_sessions (id) ON DELETE SET NULL,
  athlete_id TEXT NOT NULL,
  actor_id UUID NOT NULL,
  corrected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  before_values JSONB NOT NULL,
  after_values JSONB NOT NULL,
  correction_note TEXT,
  implausible_running_pace_acknowledged BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT performance_result_corrections_values_object
    CHECK (jsonb_typeof(before_values) = 'object'
       AND jsonb_typeof(after_values) = 'object')
);

CREATE INDEX IF NOT EXISTS performance_result_corrections_record_idx
  ON public.performance_result_corrections (record_id, corrected_at DESC);

CREATE INDEX IF NOT EXISTS performance_result_corrections_athlete_idx
  ON public.performance_result_corrections (athlete_id, corrected_at DESC);

ALTER TABLE public.performance_result_corrections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS performance_result_corrections_athlete_select
  ON public.performance_result_corrections;
CREATE POLICY performance_result_corrections_athlete_select
  ON public.performance_result_corrections
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid()::TEXT);

REVOKE INSERT, UPDATE, DELETE ON public.performance_result_corrections
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.performance_result_corrections TO authenticated;

CREATE OR REPLACE FUNCTION public.cohort_guard_performance_result_corrections()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'performance_result_corrections is append-only'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS performance_result_corrections_append_only
  ON public.performance_result_corrections;
CREATE TRIGGER performance_result_corrections_append_only
  BEFORE UPDATE OR DELETE ON public.performance_result_corrections
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_guard_performance_result_corrections();

CREATE OR REPLACE FUNCTION public.correct_completed_performance_record(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_record_id UUID;
  v_record public.training_session_records%ROWTYPE;
  v_before JSONB := '{}'::JSONB;
  v_after JSONB := '{}'::JSONB;
  v_block JSONB;
  v_set JSONB;
  v_existing_block public.training_block_results%ROWTYPE;
  v_existing_set public.training_set_results%ROWTYPE;
  v_result JSONB;
  v_load_kind TEXT;
  v_reps INT;
  v_load NUMERIC;
  v_unit TEXT;
  v_duration INT;
  v_distance NUMERIC;
  v_hr INT;
  v_rpe INT;
  v_intervals INT;
  v_correction_id UUID;
  v_changed BOOLEAN := FALSE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  IF payload IS NULL OR jsonb_typeof(payload) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'invalid_correction_payload' USING ERRCODE = '22023';
  END IF;

  v_record_id := NULLIF(payload->>'record_id', '')::UUID;
  IF v_record_id IS NULL THEN
    RAISE EXCEPTION 'invalid_correction_payload' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_record
  FROM public.training_session_records
  WHERE record_id = v_record_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'performance_record_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_record.athlete_id IS DISTINCT FROM v_actor::TEXT THEN
    RAISE EXCEPTION 'not_performance_owner' USING ERRCODE = '42501';
  END IF;
  IF v_record.status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'session_not_completed' USING ERRCODE = '22023';
  END IF;

  IF payload ? 'overall_rpe' THEN
    v_rpe := NULLIF(payload->>'overall_rpe', '')::INT;
    IF v_rpe IS NOT NULL AND (v_rpe < 1 OR v_rpe > 10) THEN
      RAISE EXCEPTION 'invalid_rpe' USING ERRCODE = '22023';
    END IF;
    IF v_record.overall_rpe IS DISTINCT FROM v_rpe THEN
      v_before := v_before || jsonb_build_object('overall_rpe', v_record.overall_rpe);
      v_after := v_after || jsonb_build_object('overall_rpe', v_rpe);
      UPDATE public.training_session_records
      SET overall_rpe = v_rpe,
          updated_at = NOW()
      WHERE record_id = v_record.record_id
        AND status = 'completed'
        AND completed_at IS NOT DISTINCT FROM v_record.completed_at
        AND athlete_id = v_record.athlete_id;
      v_changed := TRUE;
    END IF;
  END IF;

  IF payload ? 'athlete_note' THEN
    IF v_record.athlete_note IS DISTINCT FROM NULLIF(payload->>'athlete_note', '') THEN
      v_before := v_before || jsonb_build_object('athlete_note', v_record.athlete_note);
      v_after := v_after || jsonb_build_object(
        'athlete_note', NULLIF(payload->>'athlete_note', '')
      );
      UPDATE public.training_session_records
      SET athlete_note = NULLIF(payload->>'athlete_note', ''),
          updated_at = NOW()
      WHERE record_id = v_record.record_id
        AND status = 'completed'
        AND completed_at IS NOT DISTINCT FROM v_record.completed_at;
      v_changed := TRUE;
    END IF;
  END IF;

  FOR v_block IN
    SELECT value FROM jsonb_array_elements(COALESCE(payload->'blocks', '[]'::JSONB))
  LOOP
    SELECT * INTO v_existing_block
    FROM public.training_block_results
    WHERE block_result_id = (v_block->>'block_result_id')::UUID
      AND session_record_id = v_record.record_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'block_result_not_owned' USING ERRCODE = '42501';
    END IF;

    IF v_block ? 'result_data' THEN
      v_result := v_block->'result_data';
      IF jsonb_typeof(v_result) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'invalid_result_data' USING ERRCODE = '22023';
      END IF;
      IF v_result ? 'durationSeconds' THEN
        v_duration := NULLIF(v_result->>'durationSeconds', '')::INT;
        IF v_duration IS NOT NULL AND (v_duration < 0 OR v_duration > 86400) THEN
          RAISE EXCEPTION 'invalid_duration' USING ERRCODE = '22023';
        END IF;
      END IF;
      IF v_result ? 'distance' THEN
        v_distance := NULLIF(v_result->>'distance', '')::NUMERIC;
        IF v_distance IS NOT NULL AND (v_distance < 0 OR v_distance > 1000) THEN
          RAISE EXCEPTION 'invalid_distance' USING ERRCODE = '22023';
        END IF;
      END IF;
      IF v_result ? 'distanceUnit' AND NULLIF(v_result->>'distanceUnit', '')
         IS NOT NULL
         AND lower(v_result->>'distanceUnit') NOT IN ('km', 'mi', 'm') THEN
        RAISE EXCEPTION 'invalid_distance_unit' USING ERRCODE = '22023';
      END IF;
      IF v_result ? 'averageHeartRate' THEN
        v_hr := NULLIF(v_result->>'averageHeartRate', '')::INT;
        IF v_hr IS NOT NULL AND (v_hr < 20 OR v_hr > 250) THEN
          RAISE EXCEPTION 'invalid_heart_rate' USING ERRCODE = '22023';
        END IF;
      END IF;
      IF v_result ? 'intervalsCompleted' THEN
        v_intervals := NULLIF(v_result->>'intervalsCompleted', '')::INT;
        IF v_intervals IS NOT NULL AND (v_intervals < 0 OR v_intervals > 1000) THEN
          RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
        END IF;
      END IF;
      IF v_existing_block.result_data IS DISTINCT FROM v_result THEN
        v_before := v_before || jsonb_build_object(
          'block:' || v_existing_block.block_result_id::TEXT || ':result_data',
          v_existing_block.result_data
        );
        v_after := v_after || jsonb_build_object(
          'block:' || v_existing_block.block_result_id::TEXT || ':result_data',
          v_result
        );
        UPDATE public.training_block_results
        SET result_data = v_result,
            updated_at = NOW()
        WHERE block_result_id = v_existing_block.block_result_id
          AND session_record_id = v_record.record_id
          AND status = v_existing_block.status
          AND result_type = v_existing_block.result_type
          AND position = v_existing_block.position;
        v_changed := TRUE;
      END IF;
    END IF;
  END LOOP;

  FOR v_set IN
    SELECT value FROM jsonb_array_elements(COALESCE(payload->'sets', '[]'::JSONB))
  LOOP
    SELECT s.* INTO v_existing_set
    FROM public.training_set_results s
    JOIN public.training_exercise_results e
      ON e.exercise_result_id = s.exercise_result_id
    JOIN public.training_block_results b
      ON b.block_result_id = e.block_result_id
    WHERE s.set_result_id = (v_set->>'set_result_id')::UUID
      AND b.session_record_id = v_record.record_id
    FOR UPDATE OF s;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'set_result_not_owned' USING ERRCODE = '42501';
    END IF;

    SELECT e.exercise_snapshot->>'loadKind' INTO v_load_kind
    FROM public.training_exercise_results e
    WHERE e.exercise_result_id = v_existing_set.exercise_result_id;

    v_reps := v_existing_set.reps;
    v_load := v_existing_set.load;
    v_unit := v_existing_set.load_unit;
    IF v_set ? 'reps' THEN
      v_reps := NULLIF(v_set->>'reps', '')::INT;
      IF v_reps IS NOT NULL AND (v_reps < 0 OR v_reps > 1000) THEN
        RAISE EXCEPTION 'invalid_reps' USING ERRCODE = '22023';
      END IF;
    END IF;
    IF v_set ? 'load' THEN
      v_load := NULLIF(v_set->>'load', '')::NUMERIC;
    END IF;
    IF v_set ? 'load_unit' THEN
      v_unit := NULLIF(v_set->>'load_unit', '');
    END IF;
    IF v_load_kind IN ('bodyweight', 'none') THEN
      v_load := NULL;
      v_unit := NULL;
    ELSIF v_load IS NOT NULL AND v_load <= 0 THEN
      v_load := NULL;
      v_unit := NULL;
    ELSIF v_load IS NOT NULL AND v_load > 2000 THEN
      RAISE EXCEPTION 'invalid_load' USING ERRCODE = '22023';
    ELSIF v_unit IS NOT NULL AND lower(v_unit) NOT IN ('kg', 'lb') THEN
      RAISE EXCEPTION 'invalid_load_unit' USING ERRCODE = '22023';
    END IF;

    IF v_reps IS DISTINCT FROM v_existing_set.reps
       OR v_load IS DISTINCT FROM v_existing_set.load
       OR v_unit IS DISTINCT FROM v_existing_set.load_unit
       OR (v_set ? 'completed'
           AND (v_set->>'completed')::BOOLEAN IS DISTINCT FROM v_existing_set.completed)
       OR (v_set ? 'rpe'
           AND NULLIF(v_set->>'rpe', '')::INT IS DISTINCT FROM v_existing_set.rpe)
       OR (v_set ? 'note'
           AND NULLIF(v_set->>'note', '') IS DISTINCT FROM v_existing_set.note) THEN
      IF v_set ? 'rpe' THEN
        v_rpe := NULLIF(v_set->>'rpe', '')::INT;
        IF v_rpe IS NOT NULL AND (v_rpe < 1 OR v_rpe > 10) THEN
          RAISE EXCEPTION 'invalid_rpe' USING ERRCODE = '22023';
        END IF;
      END IF;
      v_before := v_before || jsonb_build_object(
        'set:' || v_existing_set.set_result_id::TEXT,
        jsonb_build_object(
          'reps', v_existing_set.reps,
          'load', v_existing_set.load,
          'load_unit', v_existing_set.load_unit,
          'completed', v_existing_set.completed,
          'rpe', v_existing_set.rpe,
          'note', v_existing_set.note
        )
      );
      UPDATE public.training_set_results
      SET reps = v_reps,
          load = v_load,
          load_unit = v_unit,
          completed = CASE
            WHEN v_set ? 'completed' THEN (v_set->>'completed')::BOOLEAN
            ELSE completed
          END,
          rpe = CASE
            WHEN v_set ? 'rpe' THEN NULLIF(v_set->>'rpe', '')::INT
            ELSE rpe
          END,
          note = CASE
            WHEN v_set ? 'note' THEN NULLIF(v_set->>'note', '')
            ELSE note
          END,
          updated_at = NOW()
      WHERE set_result_id = v_existing_set.set_result_id
        AND exercise_result_id = v_existing_set.exercise_result_id
        AND set_number = v_existing_set.set_number
        AND position = v_existing_set.position;
      v_after := v_after || jsonb_build_object(
        'set:' || v_existing_set.set_result_id::TEXT,
        jsonb_build_object(
          'reps', v_reps,
          'load', v_load,
          'load_unit', v_unit,
          'completed', CASE
            WHEN v_set ? 'completed' THEN (v_set->>'completed')::BOOLEAN
            ELSE v_existing_set.completed
          END
        )
      );
      v_changed := TRUE;
    END IF;
  END LOOP;

  IF NOT v_changed THEN
    RETURN jsonb_build_object(
      'status', 'unchanged',
      'record_id', v_record.record_id,
      'completed_at', v_record.completed_at,
      'session_status', v_record.status
    );
  END IF;

  INSERT INTO public.performance_result_corrections (
    record_id, training_session_id, athlete_id, actor_id,
    before_values, after_values, correction_note,
    implausible_running_pace_acknowledged
  ) VALUES (
    v_record.record_id,
    v_record.training_session_id,
    v_record.athlete_id,
    v_actor,
    v_before,
    v_after,
    NULLIF(payload->>'correction_note', ''),
    COALESCE((payload->>'implausible_running_pace_acknowledged')::BOOLEAN, FALSE)
  ) RETURNING correction_id INTO v_correction_id;

  RETURN jsonb_build_object(
    'status', 'corrected',
    'record_id', v_record.record_id,
    'correction_id', v_correction_id,
    'completed_at', v_record.completed_at,
    'session_status', v_record.status,
    'training_session_id', v_record.training_session_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.correct_completed_performance_record(JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.correct_completed_performance_record(JSONB)
  TO authenticated;

COMMENT ON FUNCTION public.correct_completed_performance_record(JSONB) IS
  'Athlete-owned correction of completed performance actuals. Does not reopen the session, advance the programme, or create duplicate result identities.';

COMMENT ON TABLE public.performance_result_corrections IS
  'Append-only audit of completed-performance corrections. Athletes may read their own rows; writes are RPC-owned.';
