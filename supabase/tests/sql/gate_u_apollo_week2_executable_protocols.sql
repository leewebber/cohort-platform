-- Gate U — Apollo Week 2 executable protocols. Local disposable DB only.
TRUNCATE sprint12_gate_results;
DO $$
DECLARE v_count integer; v_conflict text;
BEGIN
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W2-%-R1';
 PERFORM sprint12_assert_eq('U','seven_week2_protocols','7',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' OR protocol_id LIKE 'APOLLO-W2-%-R1';
 PERFORM sprint12_assert_eq('U','fourteen_week1_week2_protocols','14',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W2-%-R1' AND authoring_scope='organisation' AND organisation_id='apollo-dogfood' AND lifecycle_status='draft';
 PERFORM sprint12_assert_eq('U','deterministic_protocol_identities','7',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W2-%-R1';
 PERFORM sprint12_assert_eq('U','ordered_blocks','19',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id LEFT JOIN exercises_v2 x ON x.exercise_id=e.exercise_id WHERE b.session_id LIKE 'APOLLO-W2-%-R1' AND x.exercise_id IS NULL;
 PERFORM sprint12_assert_eq('U','no_dangling_exercise_references','0',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id='APOLLO-W2-MON-R1' AND e.exercise_id='EX-138' AND e.prescription @> '{"sets":4,"reps":"12-15"}'::jsonb;
 PERFORM sprint12_assert_eq('U','monday_lateral_raise_progression','1',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE (session_id='APOLLO-W2-TUE-R1' AND timer_config @> '{"work_seconds":3300,"tracking":["distance","average_pace","average_hr"]}'::jsonb) OR (session_id='APOLLO-W2-SUN-R1' AND timer_config @> '{"work_seconds":4200,"fast_finish":false}'::jsonb) OR (session_id='APOLLO-W2-THU-R1' AND timer_config @> '{"rounds":6,"work_seconds":180,"recovery_seconds":120}'::jsonb) OR (session_id='APOLLO-W2-SAT-R1' AND timer_config @> '{"duration_seconds":480,"interval_seconds":60,"alternating":[{"minute":1,"exercise":"EX-049","calories":12},{"minute":2,"exercise":"EX-009","reps":8}]}'::jsonb);
 PERFORM sprint12_assert_eq('U','week2_progression_and_timers','4',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id='APOLLO-W2-FRI-R1' AND e.exercise_id='EX-143' AND e.prescription @> '{"sets":4,"reps":"10-15"}'::jsonb;
 PERFORM sprint12_assert_eq('U','friday_low_to_high_fly_progression','1',v_count::text);
 SELECT count(*) INTO v_count FROM (SELECT protocol_id FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W2-%-R1' GROUP BY protocol_id HAVING count(*)>1) d;
 PERFORM sprint12_assert_eq('U','no_duplicate_protocol_identities','0',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1';
 PERFORM sprint12_assert_eq('U','week1_protocol_count_unchanged','7',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W1-%-R1';
 PERFORM sprint12_assert_eq('U','week1_block_count_unchanged','19',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id LIKE 'APOLLO-W1-%-R1';
 PERFORM sprint12_assert_eq('U','week1_exercise_row_count_unchanged','39',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE (session_id='APOLLO-W1-TUE-R1' AND timer_config @> '{"work_seconds":3000}'::jsonb) OR (session_id='APOLLO-W1-THU-R1' AND timer_config @> '{"rounds":5,"work_seconds":180,"recovery_seconds":120}'::jsonb) OR (session_id='APOLLO-W1-SUN-R1' AND timer_config @> '{"work_seconds":3900,"fast_finish":false}'::jsonb);
 PERFORM sprint12_assert_eq('U','week1_remains_unchanged','3',v_count::text);
 BEGIN
   INSERT INTO performance_protocols(protocol_id,name) VALUES ('APOLLO-W2-MON-R1','conflicting deterministic Apollo identity');
   PERFORM sprint12_record('U','conflicting_identity_fails_closed','unique violation','no exception',NULL,FALSE);
 EXCEPTION WHEN unique_violation THEN
   GET STACKED DIAGNOSTICS v_conflict = MESSAGE_TEXT;
   PERFORM sprint12_record('U','conflicting_identity_fails_closed','unique violation','unique violation',NULL,TRUE,v_conflict);
 END;
END $$;
SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='U' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
