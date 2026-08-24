-- Gate AM — Apollo structured warm-up prescriptions obey the production
-- strength-prescription encoding contract. Local disposable database only.

DO $$
DECLARE
  v_version UUID;
  v_athlete UUID := 'ac000001-0000-4000-8000-000000000001';
  v_assignment UUID;
  v_result JSONB;
  v_count INTEGER;
  v_value TEXT;
BEGIN
  SELECT v.id INTO v_version
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK'
    AND v.version_number = 1
    AND v.lifecycle_status = 'published';

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND (position, exercise_id, prescription) IN (
      (1, 'EX-150', '{"sets":1,"reps":{"type":"exact","exact_reps":5},"tempo":"slow","coach_cue":"Use 2–3 positions."}'::JSONB),
      (2, 'EX-151', '{"sets":1,"reps":{"type":"exact","exact_reps":6},"per_side":true,"coach_cue":"Complete each side."}'::JSONB),
      (3, 'EX-152', '{"sets":2,"reps":{"type":"exact","exact_reps":8}}'::JSONB),
      (4, 'EX-153', '{"sets":2,"reps":{"type":"range","min_reps":8,"max_reps":10},"load":{"type":"freeText","text":"Very light"}}'::JSONB),
      (5, 'EX-154', '{"sets":2,"reps":{"type":"exact","exact_reps":10},"per_side":true,"coach_cue":"Complete each side."}'::JSONB)
    );
  PERFORM sprint12_assert_eq('AM', 'five_exact_structured_prescriptions', '5', v_count::TEXT);

  SELECT string_agg(exercise_id, ',' ORDER BY position) INTO v_value
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID;
  PERFORM sprint12_assert_eq(
    'AM', 'warmup_identity_and_order',
    'EX-150,EX-151,EX-152,EX-153,EX-154', v_value
  );

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND jsonb_typeof(prescription->'sets') = 'number'
    AND jsonb_typeof(prescription->'reps') = 'object'
    AND prescription->'reps'->>'type' IN ('exact', 'range');
  PERFORM sprint12_assert_eq('AM', 'sets_and_reps_are_typed', '5', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND exercise_id IN ('EX-151', 'EX-154')
    AND prescription->>'per_side' = 'true'
    AND prescription->>'coach_cue' = 'Complete each side.';
  PERFORM sprint12_assert_eq('AM', 'laterality_and_instruction_preserved', '2', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND exercise_id = 'EX-150'
    AND prescription->>'tempo' = 'slow'
    AND prescription->>'coach_cue' = 'Use 2–3 positions.';
  PERFORM sprint12_assert_eq('AM', 'slow_tempo_and_positions_preserved', '1', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND exercise_id = 'EX-153'
    AND prescription->'load' = '{"type":"freeText","text":"Very light"}'::JSONB;
  PERFORM sprint12_assert_eq('AM', 'very_light_load_guidance_preserved', '1', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_block_exercises
  WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    AND (
      jsonb_typeof(prescription->'reps') = 'string'
      OR jsonb_typeof(prescription->'load') = 'string'
    );
  PERFORM sprint12_assert_eq('AM', 'no_compressed_prose_in_compact_fields', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM (
    SELECT sb.session_id, sbe.position
    FROM public.session_blocks sb
    JOIN public.session_block_exercises sbe ON sbe.block_id = sb.block_id
    WHERE sb.session_id LIKE 'APOLLO-%'
      AND (
        (
          sbe.prescription ? 'reps'
          AND (
            (jsonb_typeof(sbe.prescription->'reps') = 'string'
              AND NOT ((sbe.prescription->>'reps') ~ '^\d+(?:\s*-\s*\d+)?(?:\s+steps/leg|/(?:side|leg))?$'))
            OR (jsonb_typeof(sbe.prescription->'reps') = 'number'
              AND (sbe.prescription->>'reps')::NUMERIC <= 0)
            OR jsonb_typeof(sbe.prescription->'reps') NOT IN ('string', 'number', 'object')
          )
        )
        OR (
          sbe.prescription ? 'load'
          AND (
            (jsonb_typeof(sbe.prescription->'load') = 'string'
              AND NOT ((sbe.prescription->>'load') ~ '^[a-z][a-z0-9_-]{0,79}$'))
            OR (jsonb_typeof(sbe.prescription->'load') = 'number'
              AND (sbe.prescription->>'load')::NUMERIC <= 0)
            OR jsonb_typeof(sbe.prescription->'load') NOT IN ('string', 'number', 'object')
          )
        )
      )
  ) invalid_decoder_values;
  PERFORM sprint12_assert_eq('AM', 'zero_apollo_decoder_rejections', '0', v_count::TEXT);

  SELECT md5(string_agg(
    position::TEXT || '|' || exercise_id || '|' ||
      COALESCE(display_label_override, '') || '|' || prescription::TEXT,
    E'\n' ORDER BY position
  )) INTO v_value
  FROM public.session_block_exercises
  WHERE block_id = 'b1100002-0000-4000-8000-000000000002'::UUID;
  PERFORM sprint12_assert_eq(
    'AM', 'main_strength_prescriptions_unchanged',
    '1dd1b55ce60f15f95b2fa5d366960c73', v_value
  );

  SELECT count(*) INTO v_count
  FROM (
    SELECT block_id, position
    FROM public.session_block_exercises
    WHERE block_id = 'b1100001-0000-4000-8000-000000000001'::UUID
    GROUP BY block_id, position
    HAVING count(*) > 1
  ) duplicates;
  PERFORM sprint12_assert_eq('AM', 'zero_duplicate_warmup_positions', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM performance_protocols
  WHERE protocol_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-.*-R1$'
    AND lifecycle_status = 'published'
    AND published = 'true';
  PERFORM sprint12_assert_eq('AM', 'apollo_protocols_exactly_84', '84', v_count::TEXT);

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', v_athlete,
    'authenticated', 'authenticated', 'gate-am@example.invalid',
    crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
    '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_athlete, 'Gate AM Athlete', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE SET is_athlete = TRUE, is_coach = FALSE;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, true);
  PERFORM set_config('role', 'authenticated', true);
  v_result := public.enrol_athlete_in_catalogue_programme_version(
    v_version, 'Atlantic/Canary', FALSE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  v_result := public.start_fixed_programme_from_enrolment(
    v_assignment, DATE '2026-09-01', 'Atlantic/Canary'
  );
  PERFORM set_config('role', 'postgres', true);

  SELECT count(*) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  PERFORM sprint12_assert_eq('AM', 'apollo_occurrences_exactly_84', '84', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_version;
  PERFORM sprint12_assert_eq('AM', 'apollo_materialised_links_exactly_84', '84', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM training_session_records
  WHERE athlete_id = v_athlete::TEXT
    AND status IN ('completed', 'abandoned');
  PERFORM sprint12_assert_eq('AM', 'zero_completed_or_abandoned_performances', '0', v_count::TEXT);
END $$;

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results
WHERE gate = 'AM'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
