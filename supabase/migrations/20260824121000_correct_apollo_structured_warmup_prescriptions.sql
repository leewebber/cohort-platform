-- Correct Apollo Week 1 Monday warm-up prescription encoding without changing
-- canonical exercise identity, order, or authored dosage. The prior additive
-- migration compressed execution prose into the compact `reps` field; the
-- production decoder intentionally rejects that representation.

DO $$
DECLARE
  v_existing_count INTEGER;
  v_pre_correction_count INTEGER;
  v_corrected_count INTEGER;
  v_updated_count INTEGER;
BEGIN
  SELECT count(*) INTO v_existing_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID;

  SELECT count(*) INTO v_pre_correction_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND (position, exercise_id, prescription) IN (
      (1, 'EX-150', '{"sets":1,"reps":"5 slow reps at 2-3 positions"}'::JSONB),
      (2, 'EX-151', '{"sets":1,"reps":"6/side"}'::JSONB),
      (3, 'EX-152', '{"sets":2,"reps":8}'::JSONB),
      (4, 'EX-153', '{"sets":2,"reps":"8-10","coach_cue":"Very light."}'::JSONB),
      (5, 'EX-154', '{"sets":2,"reps":"10/side"}'::JSONB)
    );

  SELECT count(*) INTO v_corrected_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND (position, exercise_id, prescription) IN (
      (1, 'EX-150', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"tempo":"slow","coach_cue":"Use 2–3 positions."}'::JSONB),
      (2, 'EX-151', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true,"coach_cue":"Complete each side."}'::JSONB),
      (3, 'EX-152', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'::JSONB),
      (4, 'EX-153', '{"sets":2,"reps":{"type":"range","min_reps":8,"max_reps":10},"load":{"type":"freeText","text":"Very light"}}'::JSONB),
      (5, 'EX-154', '{"sets":2,"reps":{"type":"exact","exact_reps":10},"per_side":true,"coach_cue":"Complete each side."}'::JSONB)
    );

  IF v_existing_count = 5 AND v_corrected_count = 5 THEN
    RETURN;
  END IF;

  IF v_existing_count <> 5 OR v_pre_correction_count <> 5 THEN
    RAISE EXCEPTION
      'Apollo warm-up prescription correction refused: expected exactly five original EX-150..EX-154 rows';
  END IF;

  UPDATE public.session_block_exercises AS target
  SET prescription = correction.prescription
  FROM (
    VALUES
      ('EX-150', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"tempo":"slow","coach_cue":"Use 2–3 positions."}'::JSONB),
      ('EX-151', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true,"coach_cue":"Complete each side."}'::JSONB),
      ('EX-152', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'::JSONB),
      ('EX-153', '{"sets":2,"reps":{"type":"range","min_reps":8,"max_reps":10},"load":{"type":"freeText","text":"Very light"}}'::JSONB),
      ('EX-154', '{"sets":2,"reps":{"type":"exact","exact_reps":10},"per_side":true,"coach_cue":"Complete each side."}'::JSONB)
  ) AS correction(exercise_id, prescription)
  WHERE target.block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND target.exercise_id = correction.exercise_id;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count <> 5 THEN
    RAISE EXCEPTION
      'Apollo warm-up prescription correction updated % rows, expected 5',
      v_updated_count;
  END IF;
END $$;
