-- Gate X — Apollo Week 5 Phase II Rebuild executable protocols. Local disposable DB only.
TRUNCATE sprint12_gate_results;
DO $$
DECLARE v_count integer; v_conflict text;
BEGIN
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W5-%-R1';
 PERFORM sprint12_assert_eq('X','seven_week5_protocols','7',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' OR protocol_id LIKE 'APOLLO-W2-%-R1' OR protocol_id LIKE 'APOLLO-W3-%-R1' OR protocol_id LIKE 'APOLLO-W4-%-R1' OR protocol_id LIKE 'APOLLO-W5-%-R1';
 PERFORM sprint12_assert_eq('X','thirty_five_apollo_protocols','35',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W5-%-R1' AND authoring_scope='organisation' AND organisation_id='apollo-dogfood' AND lifecycle_status='published' AND published='true' AND published_at IS NOT NULL;
 PERFORM sprint12_assert_eq('X','deterministic_protocol_identities','7',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id LEFT JOIN exercises_v2 x ON x.exercise_id=e.exercise_id WHERE b.session_id LIKE 'APOLLO-W5-%-R1' AND x.exercise_id IS NULL;
 PERFORM sprint12_assert_eq('X','no_dangling_exercise_references','0',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE (b.session_id='APOLLO-W5-MON-R1' AND e.position IN (1,2,3,6) AND e.prescription @> '{"rir":"1-2","compound_failure":false}'::jsonb) OR (b.session_id='APOLLO-W5-WED-R1' AND e.position IN (1,2) AND e.prescription @> '{"rir":"1-2","compound_failure":false}'::jsonb) OR (b.session_id='APOLLO-W5-SAT-R1' AND e.position=3 AND e.prescription @> '{"rir":"1-2","intent":"explosive"}'::jsonb);
 PERFORM sprint12_assert_eq('X','phase2_intensity_and_no_compound_failure','7',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id='APOLLO-W5-SAT-R1' AND e.exercise_id='EX-148' AND e.prescription @> '{"sets":3,"reps":"4/side","per_side":true,"intent":"maximal"}'::jsonb;
 PERFORM sprint12_assert_eq('X','rotational_throw_per_side_semantics','1',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id='APOLLO-W5-SAT-R1' AND timer_config @> '{"rounds":3,"between_round_recovery_seconds":90,"target_rpe":"7-8","round_sequence":["EX-131","EX-132","EX-050","EX-009"]}'::jsonb;
 PERFORM sprint12_assert_eq('X','three_round_conditioning_timer_fidelity','1',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id='APOLLO-W5-SAT-R1' AND b.block_type='conditioning' AND e.execution_group_key='apollo_w5_sat_conditioning' AND e.execution_group_rounds=3 AND ((e.exercise_id='EX-131' AND e.position=1 AND e.prescription @> '{"distance_m":20,"round_position":1}'::jsonb) OR (e.exercise_id='EX-132' AND e.position=2 AND e.prescription @> '{"distance_m":20,"round_position":2}'::jsonb) OR (e.exercise_id='EX-050' AND e.position=3 AND e.prescription @> '{"distance_m":250,"round_position":3}'::jsonb) OR (e.exercise_id='EX-009' AND e.position=4 AND e.prescription @> '{"reps":8,"round_position":4}'::jsonb));
 PERFORM sprint12_assert_eq('X','exact_grouped_sled_ski_burpee_execution','4',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id='APOLLO-W5-THU-R1' AND timer_config @> '{"rounds":5,"work_seconds":240,"recovery_seconds":120,"rpe":"8-9","total_hard_seconds":1200}'::jsonb;
 PERFORM sprint12_assert_eq('X','five_by_four_interval_fidelity','1',v_count::text);
 SELECT count(*) INTO v_count FROM (SELECT protocol_id FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W5-%-R1' GROUP BY protocol_id HAVING count(*)>1) d;
 PERFORM sprint12_assert_eq('X','no_duplicate_protocol_identities','0',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' OR protocol_id LIKE 'APOLLO-W2-%-R1' OR protocol_id LIKE 'APOLLO-W3-%-R1' OR protocol_id LIKE 'APOLLO-W4-%-R1';
 PERFORM sprint12_assert_eq('X','week1_week4_protocol_counts_unchanged','28',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W1-%-R1' OR session_id LIKE 'APOLLO-W2-%-R1' OR session_id LIKE 'APOLLO-W3-%-R1' OR session_id LIKE 'APOLLO-W4-%-R1';
 PERFORM sprint12_assert_eq('X','week1_week4_block_counts_unchanged','75',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id LIKE 'APOLLO-W1-%-R1' OR b.session_id LIKE 'APOLLO-W2-%-R1' OR b.session_id LIKE 'APOLLO-W3-%-R1' OR b.session_id LIKE 'APOLLO-W4-%-R1';
 PERFORM sprint12_assert_eq('X','week1_week4_exercise_row_counts_unchanged','326',v_count::text);
 BEGIN
   INSERT INTO performance_protocols(protocol_id,name) VALUES ('APOLLO-W5-MON-R1','conflicting deterministic Apollo identity');
   PERFORM sprint12_record('X','conflicting_identity_fails_closed','unique violation','no exception',NULL,FALSE);
 EXCEPTION WHEN unique_violation THEN
   GET STACKED DIAGNOSTICS v_conflict = MESSAGE_TEXT;
   PERFORM sprint12_record('X','conflicting_identity_fails_closed','unique violation','unique violation',NULL,TRUE,v_conflict);
 END;
END $$;
SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='X' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
