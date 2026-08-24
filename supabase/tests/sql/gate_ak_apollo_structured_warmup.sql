-- Gate AK — Apollo Week 1 Monday warm-up is structured executable data.
-- Local disposable DB only; runs after AF–AJ.

DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID;
  PERFORM sprint12_assert_eq('AK', 'monday_warmup_has_five_ordered_movements', '5', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND (position, exercise_id, display_label_override, prescription) IN (
      (1, 'EX-150', 'Thoracic extension over foam roller', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"tempo":"slow","coach_cue":"Use 2–3 positions."}'::JSONB),
      (2, 'EX-151', 'Open-book rotation', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true,"coach_cue":"Complete each side."}'::JSONB),
      (3, 'EX-152', 'Serratus wall slide + reach', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'::JSONB),
      (4, 'EX-153', 'Wall Y/lower-trap raise', '{"sets":2,"reps":{"type":"range","min_reps":8,"max_reps":10},"load":{"type":"freeText","text":"Very light"}}'::JSONB),
      (5, 'EX-154', 'Single-arm cable/band row with reach', '{"sets":2,"reps":{"type":"exact","exact_reps":10},"per_side":true,"coach_cue":"Complete each side."}'::JSONB)
    );
  PERFORM sprint12_assert_eq('AK', 'monday_warmup_prescription_order_and_dosage', '5', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.exercises_v2
  WHERE exercise_id IN ('EX-150', 'EX-151', 'EX-152', 'EX-153', 'EX-154')
    AND published = TRUE;
  PERFORM sprint12_assert_eq('AK', 'warmup_canonical_identities_published', '5', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_blocks
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND content = ''
    AND coach_notes = 'Then 2-4 progressive sets for first compound. Do not cue permanent shoulders down and back.';
  PERFORM sprint12_assert_eq('AK', 'no_compressed_warmup_prose_remains', '1', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM (
    SELECT block_id, position
    FROM public.session_block_exercises
    WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    GROUP BY block_id, position
    HAVING count(*) > 1
  ) duplicates;
  PERFORM sprint12_assert_eq('AK', 'no_duplicate_warmup_movements', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100002-0000-4000-8000-000000000002'::UUID;
  PERFORM sprint12_assert_eq('AK', 'main_strength_exercises_unchanged', '10', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.training_session_records
  WHERE athlete_id = 'af000002-0000-4000-8000-000000000002'
    AND status IN ('completed', 'abandoned');
  PERFORM sprint12_assert_eq('AK', 'no_completed_or_abandoned_performances', '0', v_count::TEXT);
END $$;

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results WHERE gate = 'AK' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
