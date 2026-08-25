-- Gate AN — all Apollo warm-ups/preparation/mobility are structured and
-- athlete-facing. Local disposable database only.

DO $$
DECLARE
  v_version UUID;
  v_assignment UUID;
  v_count INTEGER;
  v_value TEXT;
BEGIN
  SELECT v.id INTO v_version
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK'
    AND v.version_number = 1
    AND v.lifecycle_status = 'published';

  SELECT id INTO v_assignment
  FROM programme_assignments
  WHERE athlete_id = 'ac000001-0000-4000-8000-000000000001'
    AND programme_version_id = v_version
    AND status = 'active';

  WITH target_blocks AS (
    SELECT block_id, title
    FROM session_blocks
    WHERE session_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
      AND title IN (
        'Apollo Shoulder Balance Warm-Up', 'Run preparation',
        'Full Apollo mobility flow', 'Apollo mobility',
        'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
      )
  ) SELECT count(*) INTO v_count FROM target_blocks;
  PERFORM sprint12_assert_eq('AN', 'apollo_preparation_blocks_exactly_106', '106', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM performance_protocols p
  WHERE p.protocol_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
    AND NOT EXISTS (
      SELECT 1 FROM session_blocks b
      WHERE b.session_id = p.protocol_id
        AND b.title IN (
          'Apollo Shoulder Balance Warm-Up', 'Run preparation',
          'Full Apollo mobility flow', 'Apollo mobility',
          'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
        )
    );
  PERFORM sprint12_assert_eq('AN', 'protocols_with_no_authored_warmup_exactly_one', '1', v_count::TEXT);

  WITH target_blocks AS (
    SELECT block_id, title
    FROM session_blocks
    WHERE session_id LIKE 'APOLLO-%'
      AND title IN (
        'Apollo Shoulder Balance Warm-Up', 'Run preparation',
        'Full Apollo mobility flow', 'Apollo mobility',
        'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
      )
  )
  SELECT count(*) INTO v_count
  FROM session_block_exercises x JOIN target_blocks b USING (block_id);
  PERFORM sprint12_assert_eq('AN', 'ordered_structured_warmup_links_exactly_514', '514', v_count::TEXT);

  WITH target_blocks AS (
    SELECT block_id, title
    FROM session_blocks
    WHERE session_id LIKE 'APOLLO-%'
      AND title IN (
        'Apollo Shoulder Balance Warm-Up', 'Run preparation',
        'Full Apollo mobility flow', 'Apollo mobility',
        'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
      )
  ), invalid AS (
    SELECT b.block_id
    FROM target_blocks b
    LEFT JOIN session_block_exercises x USING (block_id)
    GROUP BY b.block_id, b.title
    HAVING count(x.exercise_id) <> CASE b.title
      WHEN 'Apollo Shoulder Balance Warm-Up' THEN 5
      WHEN 'Run preparation' THEN 1
      WHEN 'Full Apollo mobility flow' THEN 8
      WHEN 'Apollo mobility' THEN 8
      WHEN 'Lower-body warm-up' THEN 6
      WHEN 'Interval warm-up' THEN 4
      WHEN 'Athletic warm-up' THEN 5
    END
  ) SELECT count(*) INTO v_count FROM invalid;
  PERFORM sprint12_assert_eq('AN', 'every_authored_movement_has_ordered_link', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM session_blocks
  WHERE session_id LIKE 'APOLLO-%'
    AND title IN (
      'Apollo Shoulder Balance Warm-Up', 'Run preparation',
      'Full Apollo mobility flow', 'Apollo mobility',
      'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
    )
    AND btrim(content) <> '';
  PERFORM sprint12_assert_eq('AN', 'zero_prose_only_apollo_preparation_blocks', '0', v_count::TEXT);

  WITH target_links AS (
    SELECT x.*
    FROM session_block_exercises x
    JOIN session_blocks b USING (block_id)
    WHERE b.session_id LIKE 'APOLLO-%'
      AND b.title IN (
        'Apollo Shoulder Balance Warm-Up', 'Run preparation',
        'Full Apollo mobility flow', 'Apollo mobility',
        'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
      )
  )
  SELECT count(*) INTO v_count
  FROM target_links
  WHERE jsonb_typeof(prescription->'sets') <> 'number'
    OR (prescription->>'sets')::INTEGER <= 0
    OR jsonb_typeof(prescription->'reps') <> 'object'
    OR prescription->'reps'->>'type' NOT IN ('exact', 'range', 'duration', 'distance')
    OR (prescription->'reps'->>'type' = 'exact' AND COALESCE((prescription->'reps'->>'exact_reps')::INTEGER, 0) <= 0)
    OR (prescription->'reps'->>'type' = 'range' AND (
      COALESCE((prescription->'reps'->>'min_reps')::INTEGER, 0) <= 0
      OR COALESCE((prescription->'reps'->>'max_reps')::INTEGER, 0) < COALESCE((prescription->'reps'->>'min_reps')::INTEGER, 0)
    ))
    OR (prescription->'reps'->>'type' IN ('duration', 'distance')
      AND btrim(COALESCE(prescription->'reps'->>'text', '')) = '');
  PERFORM sprint12_assert_eq('AN', 'all_warmup_prescriptions_pass_decoder_shape', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM session_block_exercises x
  JOIN session_blocks b USING (block_id)
  WHERE b.session_id LIKE 'APOLLO-%'
    AND b.title IN (
      'Apollo Shoulder Balance Warm-Up', 'Run preparation',
      'Full Apollo mobility flow', 'Apollo mobility',
      'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
    )
    AND (
      jsonb_typeof(x.prescription->'reps') = 'string'
      OR jsonb_typeof(x.prescription->'load') = 'string'
    );
  PERFORM sprint12_assert_eq('AN', 'zero_descriptive_compact_reps_or_load_fields', '0', v_count::TEXT);

  WITH target_links AS (
    SELECT x.*
    FROM session_block_exercises x
    JOIN session_blocks b USING (block_id)
    WHERE b.session_id LIKE 'APOLLO-%'
      AND b.title IN (
        'Apollo Shoulder Balance Warm-Up', 'Run preparation',
        'Full Apollo mobility flow', 'Apollo mobility',
        'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
      )
  ), duplicates AS (
    SELECT block_id, position::TEXT FROM target_links GROUP BY block_id, position HAVING count(*) > 1
    UNION ALL
    SELECT block_id, exercise_id FROM target_links GROUP BY block_id, exercise_id HAVING count(*) > 1
  ) SELECT count(*) INTO v_count FROM duplicates;
  PERFORM sprint12_assert_eq('AN', 'zero_duplicate_warmup_identity_or_position', '0', v_count::TEXT);

  WITH target_links AS (
    SELECT x.*
    FROM session_block_exercises x
    JOIN session_blocks b USING (block_id)
    WHERE b.session_id LIKE 'APOLLO-%'
      AND b.title IN (
        'Apollo Shoulder Balance Warm-Up', 'Run preparation',
        'Full Apollo mobility flow', 'Apollo mobility',
        'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
      )
  )
  SELECT string_agg(exercise_id || ':' || uses, ',' ORDER BY exercise_id) INTO v_value
  FROM (
    SELECT exercise_id, count(*)::TEXT AS uses
    FROM target_links
    WHERE exercise_id IN ('EX-111', 'EX-129', 'EX-150', 'EX-151', 'EX-152')
    GROUP BY exercise_id
  ) reused;
  PERFORM sprint12_assert_eq(
    'AN', 'canonical_reuse_counts',
    'EX-111:25,EX-129:11,EX-150:24,EX-151:49,EX-152:49', v_value
  );

  WITH target_exercises AS (
    SELECT DISTINCT x.exercise_id
    FROM session_block_exercises x
    JOIN session_blocks b USING (block_id)
    WHERE b.session_id LIKE 'APOLLO-%'
      AND b.title IN (
        'Apollo Shoulder Balance Warm-Up', 'Run preparation',
        'Full Apollo mobility flow', 'Apollo mobility',
        'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
      )
  )
  SELECT count(*) INTO v_count
  FROM exercises_v2 x JOIN target_exercises t USING (exercise_id)
  WHERE btrim(COALESCE(x.purpose, '')) <> '';
  PERFORM sprint12_assert_eq('AN', 'warmup_exercises_with_athlete_purpose', '22', v_count::TEXT);

  WITH athlete_text AS (
    SELECT purpose AS value FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-%'
    UNION ALL SELECT coaching_notes FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-%'
    UNION ALL SELECT title FROM session_blocks WHERE session_id LIKE 'APOLLO-%'
    UNION ALL SELECT content FROM session_blocks WHERE session_id LIKE 'APOLLO-%'
    UNION ALL SELECT coach_notes FROM session_blocks WHERE session_id LIKE 'APOLLO-%'
    UNION ALL
    SELECT x.purpose FROM exercises_v2 x
    WHERE x.exercise_id IN (
      SELECT DISTINCT e.exercise_id
      FROM session_block_exercises e
      JOIN session_blocks b USING (block_id)
      WHERE b.session_id LIKE 'APOLLO-%'
        AND b.title IN (
          'Apollo Shoulder Balance Warm-Up', 'Run preparation',
          'Full Apollo mobility flow', 'Apollo mobility',
          'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
        )
    )
  ) SELECT count(*) INTO v_count FROM athlete_text
    WHERE value ~* '(canonical identity required|reference slice|seed|fixture|migration|no programme version|test[- ]only)';
  PERFORM sprint12_assert_eq('AN', 'zero_prohibited_athlete_facing_phrases', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM session_block_exercises x
  JOIN session_blocks b USING (block_id)
  WHERE b.session_id LIKE 'APOLLO-%'
    AND b.title NOT IN (
      'Apollo Shoulder Balance Warm-Up', 'Run preparation',
      'Full Apollo mobility flow', 'Apollo mobility',
      'Lower-body warm-up', 'Interval warm-up', 'Athletic warm-up'
    );
  PERFORM sprint12_assert_eq('AN', 'main_workout_links_unchanged', '477', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM performance_protocols
  WHERE protocol_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
    AND published = 'true' AND lifecycle_status = 'published';
  PERFORM sprint12_assert_eq('AN', 'apollo_protocols_84', '84', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_version;
  PERFORM sprint12_assert_eq('AN', 'apollo_materialised_links_84', '84', v_count::TEXT);

  SELECT count(*) INTO v_count FROM programme_schedule_occurrences WHERE assignment_id = v_assignment;
  PERFORM sprint12_assert_eq('AN', 'apollo_occurrences_84', '84', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM programme_assignments
  WHERE athlete_id = 'ac000001-0000-4000-8000-000000000001'
    AND programme_version_id = v_version AND status = 'active';
  PERFORM sprint12_assert_eq('AN', 'one_active_apollo_assignment', '1', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM (
    SELECT assignment_id, session_slot_id, count(*)
    FROM programme_schedule_occurrences
    WHERE assignment_id = v_assignment
    GROUP BY assignment_id, session_slot_id HAVING count(*) > 1
  ) duplicates;
  PERFORM sprint12_assert_eq('AN', 'zero_occurrence_duplicates', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id = 'ac000001-0000-4000-8000-000000000001'
    AND status IN ('completed', 'abandoned');
  PERFORM sprint12_assert_eq('AN', 'zero_synthetic_terminal_performances', '0', v_count::TEXT);

  SELECT package_content_hash INTO v_value FROM programme_versions WHERE id = v_version;
  PERFORM sprint12_assert_eq(
    'AN', 'apollo_plan_package_hash_unchanged',
    '7264703a8db56edd6685e97e736405ffa99124fd4c419a676a1246653ea52b87', v_value
  );
END $$;

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results WHERE gate = 'AN' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
