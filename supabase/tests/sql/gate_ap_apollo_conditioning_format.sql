-- Gate AP — Apollo conditioning structure and steady-state persistence.

DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.performance_protocols
  WHERE protocol_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$';
  PERFORM sprint12_assert_eq('AP', 'apollo_protocol_inventory', '84', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_blocks
  WHERE session_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-[A-Z]{3}-R1$'
    AND block_type = 'conditioning'
    AND workout_format = 'steady_state'
    AND performance_capture_mode = 'endurance'
    AND COALESCE((timer_config->>'duration_seconds')::INTEGER, 0) > 0
    AND NOT (timer_config ? 'durationSeconds')
    AND timer_config->'tracking' @> '["distance", "average_pace", "average_hr"]'::JSONB
    AND NOT (timer_config ? 'work_seconds')
    AND NOT (timer_config ? 'rounds')
    AND NOT (timer_config ? 'rest_seconds')
    AND NOT (timer_config ? 'recovery_seconds');
  PERFORM sprint12_assert_eq('AP', 'steady_state_blocks', '23', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_blocks
  WHERE session_id LIKE 'APOLLO-%'
    AND workout_format = 'intervals'
    AND timer_config ? 'rounds'
    AND timer_config ? 'work_seconds'
    AND timer_config ? 'recovery_seconds';
  PERFORM sprint12_assert_eq('AP', 'genuine_interval_blocks', '11', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_blocks
  WHERE session_id LIKE 'APOLLO-%'
    AND workout_format = 'intervals'
    AND NOT (timer_config ? 'rounds');
  PERFORM sprint12_assert_eq('AP', 'intervals_without_repetitions', '0', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_blocks
  WHERE session_id LIKE 'APOLLO-%' AND workout_format = 'emom';
  PERFORM sprint12_assert_eq('AP', 'emom_blocks_unchanged', '3', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.session_blocks
  WHERE session_id LIKE 'APOLLO-%' AND workout_format = 'rounds';
  PERFORM sprint12_assert_eq('AP', 'round_blocks_unchanged', '6', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.performance_protocols
  WHERE protocol_id IN ('APOLLO-W12-TUE-R1', 'APOLLO-W12-SAT-R1');
  PERFORM sprint12_assert_eq('AP', 'assessment_protocols_unchanged', '2', v_count::TEXT);

  SELECT count(*) INTO v_count
  FROM public.programme_schedule_occurrences
  WHERE assignment_id IN (
    SELECT id FROM public.programme_assignments
    WHERE programme_version_id IN (
      SELECT v.id
      FROM public.programme_versions v
      JOIN public.programme_lineages l ON l.id = v.lineage_id
      WHERE l.code = 'APOLLO-BUILD-12-WEEK'
    )
  );
  PERFORM sprint12_record(
    'AP', 'materialised_occurrences_preserved', 'multiple_of_84', v_count::TEXT,
    NULL, v_count >= 84 AND v_count % 84 = 0, NULL
  );

  SELECT count(*) INTO v_count
  FROM public.programme_schedule_occurrences o
  LEFT JOIN public.programme_version_session_slots s ON s.id = o.session_slot_id
  WHERE o.protocol_id LIKE 'APOLLO-%'
    AND s.protocol_id IS DISTINCT FROM o.protocol_id;
  PERFORM sprint12_assert_eq('AP', 'occurrence_protocol_links_preserved', '0', v_count::TEXT);
END $$;

SELECT gate, case_id, expected, actual, pass
FROM sprint12_gate_results WHERE gate = 'AP' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
