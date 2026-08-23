-- Apollo Week 1 Monday warm-up was seeded as one prose-only block. Keep its
-- existing authoring intact while making every movement independently
-- executable and discoverable through the canonical Exercise path.

DO $$
DECLARE
  v_existing INTEGER;
  v_exact INTEGER;
  v_conflicts INTEGER;
BEGIN
  SELECT count(*) INTO v_existing
  FROM public.exercises_v2
  WHERE exercise_id IN ('EX-150', 'EX-151', 'EX-152', 'EX-153', 'EX-154');

  SELECT count(*) INTO v_exact
  FROM public.exercises_v2
  WHERE (exercise_id, name, slug, published) IN (
    ('EX-150', 'Thoracic Extension Over Foam Roller', 'thoracic-extension-over-foam-roller', TRUE),
    ('EX-151', 'Open-Book Thoracic Rotation', 'open-book-thoracic-rotation', TRUE),
    ('EX-152', 'Serratus Wall Slide + Reach', 'serratus-wall-slide-reach', TRUE),
    ('EX-153', 'Wall Y / Lower-Trap Raise', 'wall-y-lower-trap-raise', TRUE),
    ('EX-154', 'Single-Arm Cable/Band Row with Reach', 'single-arm-cable-band-row-with-reach', TRUE)
  );

  SELECT count(*) INTO v_conflicts
  FROM public.exercises_v2
  WHERE exercise_id NOT IN ('EX-150', 'EX-151', 'EX-152', 'EX-153', 'EX-154')
    AND (
      lower(btrim(COALESCE(name, ''))) IN (
        'thoracic extension over foam roller',
        'open-book thoracic rotation',
        'serratus wall slide + reach',
        'wall y / lower-trap raise',
        'single-arm cable/band row with reach'
      )
      OR lower(btrim(COALESCE(slug, ''))) IN (
        'thoracic-extension-over-foam-roller',
        'open-book-thoracic-rotation',
        'serratus-wall-slide-reach',
        'wall-y-lower-trap-raise',
        'single-arm-cable-band-row-with-reach'
      )
    );

  IF v_conflicts <> 0 THEN
    RAISE EXCEPTION
      'Apollo Week 1 warm-up canonical exercise seed refused: an existing canonical name or slug must be reused explicitly';
  END IF;

  IF v_existing = 5 AND v_exact = 5 THEN
    RETURN;
  END IF;

  IF v_existing <> 0 THEN
    RAISE EXCEPTION
      'Apollo Week 1 warm-up canonical exercise seed conflict: EX-150..EX-154 must be absent or exactly expected';
  END IF;

  INSERT INTO public.exercises_v2 (
    exercise_id, name, slug, published, category, movement_pattern,
    equipment, primary_capability, purpose
  ) VALUES
    ('EX-150', 'Thoracic Extension Over Foam Roller', 'thoracic-extension-over-foam-roller', TRUE, 'Mobility', 'Thoracic Extension', 'Foam Roller', 'Mobility', 'Canonical identity required by Apollo Week 1 Monday warm-up.'),
    ('EX-151', 'Open-Book Thoracic Rotation', 'open-book-thoracic-rotation', TRUE, 'Mobility', 'Thoracic Rotation', 'Bodyweight', 'Mobility', 'Canonical identity required by Apollo Week 1 Monday warm-up.'),
    ('EX-152', 'Serratus Wall Slide + Reach', 'serratus-wall-slide-reach', TRUE, 'Mobility', 'Scapular Upward Rotation', 'Wall', 'Shoulder Control', 'Canonical identity required by Apollo Week 1 Monday warm-up.'),
    ('EX-153', 'Wall Y / Lower-Trap Raise', 'wall-y-lower-trap-raise', TRUE, 'Mobility', 'Scapular Upward Rotation', 'Wall', 'Shoulder Control', 'Canonical identity required by Apollo Week 1 Monday warm-up.'),
    ('EX-154', 'Single-Arm Cable/Band Row with Reach', 'single-arm-cable-band-row-with-reach', TRUE, 'Pull', 'Horizontal Pull', 'Cable Machine or Resistance Band', 'Shoulder Control', 'Canonical identity required by Apollo Week 1 Monday warm-up.');
END $$;

DO $$
DECLARE
  v_preexisting_links INTEGER;
  v_expected_links INTEGER;
  v_prestate BOOLEAN;
  v_poststate BOOLEAN;
BEGIN
  SELECT count(*) INTO v_preexisting_links
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID;

  SELECT count(*) INTO v_expected_links
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND (position, exercise_id, display_label_override, prescription) IN (
      (1, 'EX-150', 'Thoracic extension over foam roller', '{"sets":1,"reps":"5 slow reps at 2-3 positions"}'::JSONB),
      (2, 'EX-151', 'Open-book rotation', '{"sets":1,"reps":"6/side"}'::JSONB),
      (3, 'EX-152', 'Serratus wall slide + reach', '{"sets":2,"reps":8}'::JSONB),
      (4, 'EX-153', 'Wall Y/lower-trap raise', '{"sets":2,"reps":"8-10","coach_cue":"Very light."}'::JSONB),
      (5, 'EX-154', 'Single-arm cable/band row with reach', '{"sets":2,"reps":"10/side"}'::JSONB)
    );

  SELECT EXISTS (
    SELECT 1
    FROM public.session_blocks
    WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
      AND session_id = 'APOLLO-W1-MON-R1'
      AND block_type = 'warm_up'
      AND title = 'Apollo Shoulder Balance Warm-Up'
      AND content = 'Thoracic extension over foam roller: 5 slow reps at 2-3 positions; Open-book rotation: 6/side; Serratus wall slide + reach: 2x8; Wall Y/lower-trap raise: 2x8-10 very light; Single-arm cable/band row with reach: 2x10/side; then 2-4 progressive sets for first compound.'
      AND coach_notes = 'Do not cue permanent shoulders down and back.'
  ) INTO v_prestate;

  SELECT EXISTS (
    SELECT 1
    FROM public.session_blocks
    WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
      AND session_id = 'APOLLO-W1-MON-R1'
      AND block_type = 'warm_up'
      AND title = 'Apollo Shoulder Balance Warm-Up'
      AND content = ''
      AND coach_notes = 'Then 2-4 progressive sets for first compound. Do not cue permanent shoulders down and back.'
  ) INTO v_poststate;

  IF v_poststate AND v_preexisting_links = 5 AND v_expected_links = 5 THEN
    RETURN;
  END IF;

  IF NOT v_prestate OR v_preexisting_links <> 0 THEN
    RAISE EXCEPTION
      'Apollo Week 1 Monday warm-up correction refused: expected the original prose-only block or the exact corrected state';
  END IF;

  UPDATE public.session_blocks
  SET content = '',
      coach_notes = 'Then 2-4 progressive sets for first compound. Do not cue permanent shoulders down and back.'
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID;

  INSERT INTO public.session_block_exercises (
    block_id, exercise_id, position, display_label_override, prescription
  ) VALUES
    ('b1100001-0000-4000-8000-000000000001'::UUID, 'EX-150', 1, 'Thoracic extension over foam roller', '{"sets":1,"reps":"5 slow reps at 2-3 positions"}'::JSONB),
    ('b1100001-0000-4000-8000-000000000001'::UUID, 'EX-151', 2, 'Open-book rotation', '{"sets":1,"reps":"6/side"}'::JSONB),
    ('b1100001-0000-4000-8000-000000000001'::UUID, 'EX-152', 3, 'Serratus wall slide + reach', '{"sets":2,"reps":8}'::JSONB),
    ('b1100001-0000-4000-8000-000000000001'::UUID, 'EX-153', 4, 'Wall Y/lower-trap raise', '{"sets":2,"reps":"8-10","coach_cue":"Very light."}'::JSONB),
    ('b1100001-0000-4000-8000-000000000001'::UUID, 'EX-154', 5, 'Single-arm cable/band row with reach', '{"sets":2,"reps":"10/side"}'::JSONB);
END $$;
