-- Interval results reuse training_set_results as the per-ordinal authority.
-- No new result table. Completed edits remain RPC-only.

CREATE UNIQUE INDEX IF NOT EXISTS training_set_results_exercise_set_number_uidx
  ON public.training_set_results (exercise_result_id, set_number);

CREATE OR REPLACE FUNCTION public.cohort_canonicalize_interval_result_data(
  p_result JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total INT;
  v_unit TEXT;
  v_row JSONB;
  v_ordinal INT;
  v_pace NUMERIC;
  v_state TEXT;
  v_recorded INT := 0;
  v_seen INT[] := ARRAY[]::INT[];
BEGIN
  IF p_result IS NULL OR jsonb_typeof(p_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'invalid_result_data' USING ERRCODE = '22023';
  END IF;

  v_total := NULLIF(p_result->>'totalIntervals', '')::INT;
  v_unit := COALESCE(NULLIF(p_result->>'paceUnit', ''), 'sec_per_km');
  IF v_unit NOT IN ('sec_per_km', 's/km', 'sec/km') THEN
    RAISE EXCEPTION 'invalid_pace_unit' USING ERRCODE = '22023';
  END IF;

  IF p_result ? 'intervals'
     AND jsonb_typeof(p_result->'intervals') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'invalid_result_data' USING ERRCODE = '22023';
  END IF;

  IF v_total IS NOT NULL AND (v_total < 1 OR v_total > 100) THEN
    RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
  END IF;

  IF p_result ? 'intervals' THEN
    IF v_total IS NOT NULL
       AND jsonb_array_length(p_result->'intervals') > v_total THEN
      RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
    END IF;
    FOR v_row IN SELECT value FROM jsonb_array_elements(p_result->'intervals')
    LOOP
      v_ordinal := NULLIF(v_row->>'ordinal', '')::INT;
      v_state := COALESCE(v_row->>'state', 'pending');
      v_pace := NULLIF(v_row->>'paceSecondsPerKm', '')::NUMERIC;
      IF v_ordinal IS NULL OR v_ordinal < 1 THEN
        RAISE EXCEPTION 'invalid_interval_ordinal' USING ERRCODE = '22023';
      END IF;
      IF v_total IS NOT NULL AND v_ordinal > v_total THEN
        RAISE EXCEPTION 'invalid_interval_ordinal' USING ERRCODE = '22023';
      END IF;
      IF v_ordinal = ANY (v_seen) THEN
        RAISE EXCEPTION 'duplicate_interval_ordinal' USING ERRCODE = '22023';
      END IF;
      v_seen := array_append(v_seen, v_ordinal);
      IF v_state NOT IN ('pending', 'completed', 'skipped', 'pace_unavailable') THEN
        RAISE EXCEPTION 'invalid_interval_state' USING ERRCODE = '22023';
      END IF;
      IF v_pace IS NOT NULL AND v_pace <= 0 THEN
        RAISE EXCEPTION 'invalid_pace' USING ERRCODE = '22023';
      END IF;
      IF v_state = 'completed' AND (v_pace IS NULL OR v_pace <= 0) THEN
        RAISE EXCEPTION 'invalid_pace' USING ERRCODE = '22023';
      END IF;
      IF v_state IN ('completed', 'pace_unavailable') THEN
        v_recorded := v_recorded + 1;
      END IF;
    END LOOP;
    p_result := jsonb_set(p_result, '{intervalsCompleted}', to_jsonb(v_recorded));
  ELSIF p_result ? 'intervalsCompleted' THEN
    v_recorded := NULLIF(p_result->>'intervalsCompleted', '')::INT;
    IF v_recorded IS NULL OR v_recorded < 0 OR v_recorded > 1000 THEN
      RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
    END IF;
    IF v_total IS NOT NULL AND v_recorded > v_total THEN
      RAISE EXCEPTION 'invalid_interval_count' USING ERRCODE = '22023';
    END IF;
  END IF;

  RETURN p_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_guard_interval_set_ordinal()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_block public.training_block_results%ROWTYPE;
  v_total INT;
BEGIN
  SELECT b.* INTO v_block
  FROM public.training_exercise_results e
  JOIN public.training_block_results b
    ON b.block_result_id = e.block_result_id
  WHERE e.exercise_result_id = NEW.exercise_result_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;
  IF v_block.result_type IS DISTINCT FROM 'interval' THEN
    RETURN NEW;
  END IF;
  v_total := NULLIF(v_block.result_data->>'totalIntervals', '')::INT;
  IF v_total IS NOT NULL AND (NEW.set_number < 1 OR NEW.set_number > v_total) THEN
    RAISE EXCEPTION 'invalid_interval_ordinal' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS training_set_results_interval_ordinal
  ON public.training_set_results;
CREATE TRIGGER training_set_results_interval_ordinal
  BEFORE INSERT OR UPDATE ON public.training_set_results
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_guard_interval_set_ordinal();
