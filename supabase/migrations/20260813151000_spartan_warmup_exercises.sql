-- Founder-authorised canonical identities required by Spartan Upper Strength.
-- Fail closed on partial or conflicting EX-133..EX-135 allocations.

DO $$
DECLARE
  v_existing INT;
  v_exact INT;
  v_name_or_slug_conflicts INT;
BEGIN
  SELECT count(*)::INT INTO v_existing
  FROM public.exercises_v2
  WHERE exercise_id IN ('EX-133', 'EX-134', 'EX-135');

  SELECT count(*)::INT INTO v_exact
  FROM public.exercises_v2
  WHERE (exercise_id, name, slug, published) IN (
    ('EX-133', 'Easy Bike', 'easy-bike', TRUE),
    ('EX-134', 'Band Pull Apart', 'band-pull-apart', TRUE),
    ('EX-135', 'Scapular Push-Up', 'scapular-push-up', TRUE)
  );

  SELECT count(*)::INT INTO v_name_or_slug_conflicts
  FROM public.exercises_v2
  WHERE exercise_id NOT IN ('EX-133', 'EX-134', 'EX-135')
    AND (
      lower(btrim(COALESCE(name, ''))) IN (
        'easy bike',
        'band pull apart',
        'scapular push-up',
        'scapular push up'
      )
      OR lower(btrim(COALESCE(slug, ''))) IN (
        'easy-bike',
        'band-pull-apart',
        'scapular-push-up'
      )
    );

  IF v_name_or_slug_conflicts > 0 THEN
    RAISE EXCEPTION
      'Spartan warm-up exercise seed refused: an existing canonical name or slug must be reused.';
  END IF;

  IF v_existing = 3 AND v_exact = 3 THEN
    RETURN;
  END IF;

  IF v_existing > 0 THEN
    RAISE EXCEPTION
      'Spartan warm-up exercise seed refused: conflicting or partial EX-133..EX-135 allocation.';
  END IF;

  INSERT INTO public.exercises_v2 (
    exercise_id,
    name,
    slug,
    published,
    coaching_cues
  ) VALUES
    (
      'EX-133',
      'Easy Bike',
      'easy-bike',
      TRUE,
      'Gradually increase cadence and body temperature.'
    ),
    ('EX-134', 'Band Pull Apart', 'band-pull-apart', TRUE, NULL),
    ('EX-135', 'Scapular Push-Up', 'scapular-push-up', TRUE, NULL);
END $$;
