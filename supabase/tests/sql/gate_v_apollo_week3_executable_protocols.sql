-- Gate V — Apollo Week 3 executable protocols. Local disposable DB only.
TRUNCATE sprint12_gate_results;
DO $$
DECLARE v_count integer; v_conflict text;
BEGIN
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W3-%-R1';
 PERFORM sprint12_assert_eq('V','seven_week3_protocols','7',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' OR protocol_id LIKE 'APOLLO-W2-%-R1' OR protocol_id LIKE 'APOLLO-W3-%-R1';
 PERFORM sprint12_assert_eq('V','twenty_one_week1_week3_protocols','21',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W3-%-R1' AND authoring_scope='organisation' AND organisation_id='apollo-dogfood' AND lifecycle_status='draft';
 PERFORM sprint12_assert_eq('V','deterministic_protocol_identities','7',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W3-%-R1';
 PERFORM sprint12_assert_eq('V','ordered_blocks','19',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id LEFT JOIN exercises_v2 x ON x.exercise_id=e.exercise_id WHERE b.session_id LIKE 'APOLLO-W3-%-R1' AND x.exercise_id IS NULL;
 PERFORM sprint12_assert_eq('V','no_dangling_exercise_references','0',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE (b.session_id='APOLLO-W3-MON-R1' AND e.exercise_id='EX-087' AND e.prescription @> '{"sets":4,"reps":"6-10"}'::jsonb) OR (b.session_id='APOLLO-W3-WED-R1' AND e.exercise_id='EX-078' AND e.prescription @> '{"sets":5,"reps":"6-8","eccentric_seconds":3}'::jsonb) OR (b.session_id='APOLLO-W3-FRI-R1' AND e.exercise_id IN ('EX-143','EX-144','EX-139') AND e.prescription @> '{"sets":4}'::jsonb);
 PERFORM sprint12_assert_eq('V','exact_week3_overload_changes','5',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE (session_id='APOLLO-W3-THU-R1' AND timer_config @> '{"rounds":5,"work_seconds":240,"recovery_seconds":120,"total_quality_seconds":1200}'::jsonb) OR (session_id='APOLLO-W3-SAT-R1' AND timer_config @> '{"duration_seconds":600,"interval_seconds":60,"alternating":[{"minute":1,"exercise":"EX-049","calories":12},{"minute":2,"exercise":"EX-009","reps":8}]}'::jsonb) OR (session_id='APOLLO-W3-TUE-R1' AND timer_config @> '{"work_seconds":3600,"tracking":["distance","average_pace","average_hr"]}'::jsonb) OR (session_id='APOLLO-W3-SUN-R1' AND timer_config @> '{"work_seconds":4500,"fast_finish":false}'::jsonb);
 PERFORM sprint12_assert_eq('V','interval_emom_and_zone2_timer_fidelity','4',v_count::text);
 SELECT count(*) INTO v_count FROM (SELECT protocol_id FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W3-%-R1' GROUP BY protocol_id HAVING count(*)>1) d;
 PERFORM sprint12_assert_eq('V','no_duplicate_protocol_identities','0',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' OR protocol_id LIKE 'APOLLO-W2-%-R1';
 PERFORM sprint12_assert_eq('V','week1_week2_protocol_counts_unchanged','14',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W1-%-R1' OR session_id LIKE 'APOLLO-W2-%-R1';
 PERFORM sprint12_assert_eq('V','week1_week2_block_counts_unchanged','38',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id LIKE 'APOLLO-W1-%-R1' OR b.session_id LIKE 'APOLLO-W2-%-R1';
 PERFORM sprint12_assert_eq('V','week1_week2_exercise_row_counts_unchanged','78',v_count::text);
 BEGIN
   INSERT INTO performance_protocols(protocol_id,name) VALUES ('APOLLO-W3-MON-R1','conflicting deterministic Apollo identity');
   PERFORM sprint12_record('V','conflicting_identity_fails_closed','unique violation','no exception',NULL,FALSE);
 EXCEPTION WHEN unique_violation THEN
   GET STACKED DIAGNOSTICS v_conflict = MESSAGE_TEXT;
   PERFORM sprint12_record('V','conflicting_identity_fails_closed','unique violation','unique violation',NULL,TRUE,v_conflict);
 END;
END $$;
SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='V' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
