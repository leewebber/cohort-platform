-- Gate W — Apollo Week 4 executable reduced-fatigue protocols. Local disposable DB only.
TRUNCATE sprint12_gate_results;
DO $$
DECLARE v_count integer; v_conflict text;
BEGIN
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W4-%-R1';
 PERFORM sprint12_assert_eq('W','seven_week4_protocols','7',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' OR protocol_id LIKE 'APOLLO-W2-%-R1' OR protocol_id LIKE 'APOLLO-W3-%-R1' OR protocol_id LIKE 'APOLLO-W4-%-R1';
 PERFORM sprint12_assert_eq('W','twenty_eight_phase1_protocols','28',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W4-%-R1' AND authoring_scope='organisation' AND organisation_id='apollo-dogfood' AND lifecycle_status='draft';
 PERFORM sprint12_assert_eq('W','deterministic_protocol_identities','7',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W4-%-R1';
 PERFORM sprint12_assert_eq('W','ordered_blocks_without_saturday_conditioning','18',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id LEFT JOIN exercises_v2 x ON x.exercise_id=e.exercise_id WHERE b.session_id LIKE 'APOLLO-W4-%-R1' AND x.exercise_id IS NULL;
 PERFORM sprint12_assert_eq('W','no_dangling_exercise_references','0',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id LIKE 'APOLLO-W4-%-R1' AND b.block_type='strength' AND e.prescription @> '{"rir":3}'::jsonb;
 PERFORM sprint12_assert_eq('W','all_week4_strength_work_approximately_3_rir','34',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id='APOLLO-W4-THU-R1' AND timer_config @> '{"rounds":4,"work_seconds":180,"recovery_seconds":120,"effort":"controlled_approximately_10k","vo2":false}'::jsonb;
 PERFORM sprint12_assert_eq('W','thursday_controlled_10k_not_vo2','1',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id='APOLLO-W4-SAT-R1' AND block_type='conditioning';
 PERFORM sprint12_assert_eq('W','saturday_has_no_conditioning_block','0',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE (session_id='APOLLO-W4-TUE-R1' AND timer_config @> '{"work_seconds":2700,"tracking":["distance","average_pace","average_hr"]}'::jsonb) OR (session_id='APOLLO-W4-SUN-R1' AND timer_config @> '{"work_seconds":3600,"fast_finish":false}'::jsonb);
 PERFORM sprint12_assert_eq('W','zone2_reductions_and_tracking','2',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE (b.session_id='APOLLO-W4-MON-R1' AND ((e.position IN (1,2,5) AND e.prescription @> '{"sets":3}'::jsonb) OR (e.position IN (3,4,6,7) AND e.prescription @> '{"sets":2}'::jsonb) OR (e.position IN (8,9,10) AND e.prescription @> '{"sets":1,"intensity":"light"}'::jsonb))) OR (b.session_id='APOLLO-W4-WED-R1' AND ((e.position IN (1,2) AND e.prescription @> '{"sets":3}'::jsonb) OR (e.position IN (3,4,5,6,7) AND e.prescription @> '{"sets":2}'::jsonb))) OR (b.session_id='APOLLO-W4-FRI-R1' AND ((e.position=5 AND e.prescription @> '{"sets":3}'::jsonb) OR (e.position=8 AND e.prescription @> '{"sets":1}'::jsonb) OR (e.position IN (1,2,3,4,6,7,9) AND e.prescription @> '{"sets":2}'::jsonb) OR (e.position IN (10,11,12) AND e.prescription @> '{"sets":1,"intensity":"light"}'::jsonb))) OR (b.session_id='APOLLO-W4-SAT-R1' AND ((e.position=1 AND e.prescription @> '{"sets":3}'::jsonb) OR (e.position IN (2,3,4,5) AND e.prescription @> '{"sets":2}'::jsonb))) OR (b.session_id='APOLLO-W4-TUE-R1' AND e.prescription @> '{"sets":2,"reps":"8-12"}'::jsonb);
 PERFORM sprint12_assert_eq('W','exact_author_approved_reduced_volume','35',v_count::text);
 SELECT count(*) INTO v_count FROM (SELECT protocol_id FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W4-%-R1' GROUP BY protocol_id HAVING count(*)>1) d;
 PERFORM sprint12_assert_eq('W','no_duplicate_protocol_identities','0',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' OR protocol_id LIKE 'APOLLO-W2-%-R1' OR protocol_id LIKE 'APOLLO-W3-%-R1';
 PERFORM sprint12_assert_eq('W','week1_week3_protocol_counts_unchanged','21',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W1-%-R1' OR session_id LIKE 'APOLLO-W2-%-R1' OR session_id LIKE 'APOLLO-W3-%-R1';
 PERFORM sprint12_assert_eq('W','week1_week3_block_counts_unchanged','57',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id WHERE b.session_id LIKE 'APOLLO-W1-%-R1' OR b.session_id LIKE 'APOLLO-W2-%-R1' OR b.session_id LIKE 'APOLLO-W3-%-R1';
 PERFORM sprint12_assert_eq('W','week1_week3_exercise_row_counts_unchanged','117',v_count::text);
 BEGIN
   INSERT INTO performance_protocols(protocol_id,name) VALUES ('APOLLO-W4-MON-R1','conflicting deterministic Apollo identity');
   PERFORM sprint12_record('W','conflicting_identity_fails_closed','unique violation','no exception',NULL,FALSE);
 EXCEPTION WHEN unique_violation THEN
   GET STACKED DIAGNOSTICS v_conflict = MESSAGE_TEXT;
   PERFORM sprint12_record('W','conflicting_identity_fails_closed','unique violation','unique violation',NULL,TRUE,v_conflict);
 END;
END $$;
SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='W' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
