-- Apollo Build local publication lifecycle.
-- Publishes exactly the already-authored deterministic Apollo revisions after
-- proving their identities and executable content are complete. This neither
-- creates nor approves a programme catalogue version.

DO $$
DECLARE
  v_expected_ids TEXT[] := ARRAY(
    SELECT format('APOLLO-W%s-%s-R1', weeks.week_number, day_code)
    FROM generate_series(1, 12) AS weeks(week_number)
    CROSS JOIN unnest(ARRAY['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])
      WITH ORDINALITY AS days(day_code, day_order)
    ORDER BY week_number, day_order
  );
  v_count INT;
BEGIN
  IF cardinality(v_expected_ids) <> 84 THEN
    RAISE EXCEPTION 'Apollo publication expected 84 generated identities';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.performance_protocols
  WHERE protocol_id = ANY (v_expected_ids);
  IF v_count <> 84 THEN
    RAISE EXCEPTION 'Apollo publication requires exactly 84 expected identities, found %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.performance_protocols
  WHERE protocol_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-(MON|TUE|WED|THU|FRI|SAT|SUN)-R1$';
  IF v_count <> 84 THEN
    RAISE EXCEPTION 'Apollo publication found unexpected Apollo identity count %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.performance_protocols p
  WHERE p.protocol_id = ANY (v_expected_ids)
    AND (
      p.content_kind <> 'session'
      OR p.authoring_scope <> 'organisation'
      OR p.endorsement_status <> 'organisation_approved'
      OR p.organisation_id <> 'apollo-dogfood'
      OR p.session_lineage_id IS NULL
      OR p.revision_number <> 1
      OR NOT (
        (p.lifecycle_status = 'draft' AND p.published = 'false')
        OR (p.lifecycle_status = 'published' AND p.published = 'true')
      )
    );
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo publication found % conflicting protocol lifecycle or identity row(s)', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM unnest(v_expected_ids) AS expected(protocol_id)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.session_blocks b WHERE b.session_id = expected.protocol_id
  );
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo publication requires blocks for every protocol, missing %', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises e
  JOIN public.session_blocks b ON b.block_id = e.block_id
  LEFT JOIN public.exercises_v2 x ON x.exercise_id = e.exercise_id
  WHERE b.session_id = ANY (v_expected_ids) AND x.exercise_id IS NULL;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'Apollo publication found % unresolved exercise reference(s)', v_count;
  END IF;

  UPDATE public.performance_protocols
  SET published = 'true',
      lifecycle_status = 'published',
      published_at = COALESCE(published_at, NOW())
  WHERE protocol_id = ANY (v_expected_ids)
    AND lifecycle_status = 'draft'
    AND published = 'false';

  SELECT count(*) INTO v_count
  FROM public.performance_protocols
  WHERE protocol_id = ANY (v_expected_ids)
    AND lifecycle_status = 'published'
    AND published = 'true'
    AND published_at IS NOT NULL;
  IF v_count <> 84 THEN
    RAISE EXCEPTION 'Apollo publication did not yield 84 published revisions, found %', v_count;
  END IF;
END $$;
