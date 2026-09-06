-- Version Apollo W5 Athletic conditioning as explicit fixed-work rounds.
-- Station work stays prescribed; capture strategy is authored, not inferred.
-- Protocol revision stays 1: the frozen Plan Package pins published R1.
-- The executable distinction is timer_config.capture_strategy plus load type.

UPDATE public.session_blocks
SET timer_config = COALESCE(timer_config, '{}'::JSONB) ||
      jsonb_build_object('capture_strategy', 'fixed_work'),
    updated_at = NOW()
WHERE session_id = 'APOLLO-W5-SAT-R1'
  AND block_type = 'conditioning'
  AND workout_format = 'rounds';

UPDATE public.session_block_exercises
SET prescription = COALESCE(prescription, '{}'::JSONB) ||
      jsonb_build_object(
        'load',
        jsonb_build_object('type', 'athleteSelected', 'unit', 'kg')
      )
WHERE block_id IN (
  SELECT block_id
  FROM public.session_blocks
  WHERE session_id = 'APOLLO-W5-SAT-R1'
    AND block_type = 'conditioning'
)
  AND exercise_id IN ('EX-131', 'EX-132');
