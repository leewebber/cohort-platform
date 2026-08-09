-- Phase 3.1F Part 2 — founder-approved canonical catalogue additions.
-- Local authoring artifact only. Hosted apply is NOT authorised in this sprint.
--
-- Fail-closed seed (conflict targets are refused; no silent skip or overwrite):
--   * If EX-128..EX-132 are all absent → insert the five approved rows.
--   * If all five already exist with exact approved identity fields → no-op.
--   * If any id exists with mismatched identity fields → RAISE (abort).
--   * If a partial subset of the five ids exists → RAISE (abort).
-- Catalogue data seed only — no schema objects (tables/columns/functions/policies).
-- Does not touch athlete, programme, completion, evidence, or payment data.
--
-- Allocates contiguous next ids after Part 1b export max EX-127:
--   EX-128 Lat Pulldown
--   EX-129 Running (generic locomotion; not intensity-specific)
--   EX-130 Burpee Broad Jump (combined; not Burpee or Broad Jump alone)
--   EX-131 Sled Push (distinct from Sled Pull)
--   EX-132 Sled Pull (distinct from Sled Push)

DO $$
DECLARE
  v_existing int;
  v_exact int;
  v_conflict text;
BEGIN
  SELECT count(*)::int
  INTO v_existing
  FROM public.exercises_v2
  WHERE exercise_id IN ('EX-128', 'EX-129', 'EX-130', 'EX-131', 'EX-132');

  SELECT count(*)::int
  INTO v_exact
  FROM public.exercises_v2
  WHERE (exercise_id, name, slug, published, category, movement_pattern, equipment,
         primary_muscles, primary_capability, loading_options, purpose)
    IN (
      (
        'EX-128',
        'Lat Pulldown',
        'lat-pulldown',
        true,
        'Pull',
        'Vertical Pull',
        'Cable Machine',
        'Latissimus Dorsi, Biceps',
        'Strength',
        'Load, Reps, RPE',
        'Founder-approved Phase 3.1F Part 2 canonical addition. Cable vertical-pull identity; not Pull Up.'
      ),
      (
        'EX-129',
        'Running',
        'running',
        true,
        'Running',
        'Locomotion',
        'Running Shoes',
        'Calves, Quadriceps, Hamstrings, Glutes',
        'Endurance',
        'Distance, Time, Pace',
        'Founder-approved Phase 3.1F Part 2 generic Running identity (F-01 A). Not Easy/Threshold/Sprint intensity; outdoor vs treadmill remain environment/equipment/context, not separate identity. Comparability remains protocol-governed.'
      ),
      (
        'EX-130',
        'Burpee Broad Jump',
        'burpee-broad-jump',
        true,
        'Plyometric',
        'Jump',
        'Bodyweight',
        'Quadriceps, Glutes, Chest, Core',
        'Power',
        'Reps, Distance, Time',
        'Founder-approved Phase 3.1F Part 2 combined Burpee Broad Jump identity. Distinct from Burpee (EX-009) and Broad Jump (EX-024); do not merge performance histories.'
      ),
      (
        'EX-131',
        'Sled Push',
        'sled-push',
        true,
        'Running',
        'Locomotion',
        'Sled',
        'Quadriceps, Glutes, Calves',
        'Power',
        'Load, Distance, Time',
        'Founder-approved Phase 3.1F Part 2 Sled Push identity. Distinct from Sled Pull. Load, distance and surface remain prescription/context.'
      ),
      (
        'EX-132',
        'Sled Pull',
        'sled-pull',
        true,
        'Running',
        'Locomotion',
        'Sled',
        'Hamstrings, Glutes, Grip, Core',
        'Strength',
        'Load, Distance, Time',
        'Founder-approved Phase 3.1F Part 2 Sled Pull identity. Distinct from Sled Push. Load, distance, rope and surface remain prescription/context.'
      )
    );

  IF v_existing = 5 AND v_exact = 5 THEN
    -- Exact approved seed already present; idempotent no-op.
    RETURN;
  END IF;

  IF v_existing > 0 THEN
    SELECT string_agg(exercise_id, ', ' ORDER BY exercise_id)
    INTO v_conflict
    FROM public.exercises_v2
    WHERE exercise_id IN ('EX-128', 'EX-129', 'EX-130', 'EX-131', 'EX-132');
    RAISE EXCEPTION
      'Phase 3.1F Part 2 seed refused: conflicting or partial EX-128..EX-132 rows present (%). Fail closed; no overwrite.',
      v_conflict;
  END IF;

  INSERT INTO public.exercises_v2 (
    exercise_id, name, slug, published, category, movement_pattern, equipment,
    primary_muscles, primary_capability, loading_options, purpose
  ) VALUES
    (
      'EX-128',
      'Lat Pulldown',
      'lat-pulldown',
      true,
      'Pull',
      'Vertical Pull',
      'Cable Machine',
      'Latissimus Dorsi, Biceps',
      'Strength',
      'Load, Reps, RPE',
      'Founder-approved Phase 3.1F Part 2 canonical addition. Cable vertical-pull identity; not Pull Up.'
    ),
    (
      'EX-129',
      'Running',
      'running',
      true,
      'Running',
      'Locomotion',
      'Running Shoes',
      'Calves, Quadriceps, Hamstrings, Glutes',
      'Endurance',
      'Distance, Time, Pace',
      'Founder-approved Phase 3.1F Part 2 generic Running identity (F-01 A). Not Easy/Threshold/Sprint intensity; outdoor vs treadmill remain environment/equipment/context, not separate identity. Comparability remains protocol-governed.'
    ),
    (
      'EX-130',
      'Burpee Broad Jump',
      'burpee-broad-jump',
      true,
      'Plyometric',
      'Jump',
      'Bodyweight',
      'Quadriceps, Glutes, Chest, Core',
      'Power',
      'Reps, Distance, Time',
      'Founder-approved Phase 3.1F Part 2 combined Burpee Broad Jump identity. Distinct from Burpee (EX-009) and Broad Jump (EX-024); do not merge performance histories.'
    ),
    (
      'EX-131',
      'Sled Push',
      'sled-push',
      true,
      'Running',
      'Locomotion',
      'Sled',
      'Quadriceps, Glutes, Calves',
      'Power',
      'Load, Distance, Time',
      'Founder-approved Phase 3.1F Part 2 Sled Push identity. Distinct from Sled Pull. Load, distance and surface remain prescription/context.'
    ),
    (
      'EX-132',
      'Sled Pull',
      'sled-pull',
      true,
      'Running',
      'Locomotion',
      'Sled',
      'Hamstrings, Glutes, Grip, Core',
      'Strength',
      'Load, Distance, Time',
      'Founder-approved Phase 3.1F Part 2 Sled Pull identity. Distinct from Sled Push. Load, distance, rope and surface remain prescription/context.'
    );
  -- Unexpected primary-key collision aborts the transaction (fail closed).
END $$;
