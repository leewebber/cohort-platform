-- Apollo continuous-conditioning execution-format correction.
--
-- `intervals` is reserved for repeated work/recovery structures. Continuous
-- conditioning has its own generic format and uses the existing endurance
-- result contract (duration, distance, derived pace, average heart rate).

ALTER TABLE public.session_blocks
  DROP CONSTRAINT IF EXISTS session_blocks_workout_format_check;

ALTER TABLE public.session_blocks
  ADD CONSTRAINT session_blocks_workout_format_check CHECK (
    workout_format IN (
      'none', 'amrap', 'emom', 'for_time', 'steady_state',
      'intervals', 'tabata', 'rounds', 'other'
    )
  );

DO $$
DECLARE
  v_structural_targets INTEGER;
  v_updated INTEGER;
BEGIN
  SELECT count(*) INTO v_structural_targets
  FROM public.session_blocks b
  WHERE b.session_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
    AND b.block_type = 'conditioning'
    AND b.workout_format IN ('intervals', 'steady_state')
    AND b.timer_config ? 'tracking'
    AND b.timer_config->'tracking' @> '["distance", "average_pace", "average_hr"]'::JSONB
    AND COALESCE(
      (b.timer_config->>'duration_seconds')::INTEGER,
      (b.timer_config->>'durationSeconds')::INTEGER,
      (b.timer_config->>'work_seconds')::INTEGER,
      0
    ) > 0
    AND NOT (b.timer_config ? 'rounds')
    AND NOT (b.timer_config ? 'rest_seconds')
    AND NOT (b.timer_config ? 'recovery_seconds');

  IF v_structural_targets <> 23 THEN
    RAISE EXCEPTION
      'Apollo steady-state correction expected 23 structural targets, found %',
      v_structural_targets;
  END IF;

  UPDATE public.session_blocks b
  SET workout_format = 'steady_state',
      performance_capture_mode = 'endurance',
      timer_config = (b.timer_config - 'work_seconds' - 'durationSeconds') || jsonb_build_object(
        'duration_seconds', COALESCE(
          (b.timer_config->>'duration_seconds')::INTEGER,
          (b.timer_config->>'durationSeconds')::INTEGER,
          (b.timer_config->>'work_seconds')::INTEGER
        )
      ),
      updated_at = NOW()
  WHERE b.session_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
    AND b.block_type = 'conditioning'
    AND b.workout_format IN ('intervals', 'steady_state')
    AND b.timer_config ? 'tracking'
    AND b.timer_config->'tracking' @> '["distance", "average_pace", "average_hr"]'::JSONB
    AND COALESCE(
      (b.timer_config->>'duration_seconds')::INTEGER,
      (b.timer_config->>'durationSeconds')::INTEGER,
      (b.timer_config->>'work_seconds')::INTEGER,
      0
    ) > 0
    AND NOT (b.timer_config ? 'rounds')
    AND NOT (b.timer_config ? 'rest_seconds')
    AND NOT (b.timer_config ? 'recovery_seconds')
    AND (
      b.workout_format <> 'steady_state'
      OR b.performance_capture_mode <> 'endurance'
      OR b.timer_config ? 'work_seconds'
      OR b.timer_config ? 'durationSeconds'
      OR NOT (b.timer_config ? 'duration_seconds')
    );
  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated NOT IN (0, 23) THEN
    RAISE EXCEPTION
      'Apollo steady-state correction expected 0 or 23 updates, changed %',
      v_updated;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.session_blocks b
    WHERE b.session_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
      AND b.workout_format = 'steady_state'
      AND (
        b.block_type <> 'conditioning'
        OR b.performance_capture_mode <> 'endurance'
        OR COALESCE((b.timer_config->>'duration_seconds')::INTEGER, 0) <= 0
        OR b.timer_config ? 'durationSeconds'
        OR b.timer_config ? 'work_seconds'
        OR b.timer_config ? 'rounds'
        OR b.timer_config ? 'rest_seconds'
        OR b.timer_config ? 'recovery_seconds'
      )
  ) THEN
    RAISE EXCEPTION 'Apollo steady-state representation is incomplete';
  END IF;
END $$;

COMMENT ON CONSTRAINT session_blocks_workout_format_check
  ON public.session_blocks IS
  'Execution structure vocabulary; steady_state is continuous timed conditioning, distinct from repeated intervals.';
