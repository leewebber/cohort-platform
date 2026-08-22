-- Gate T — Apollo Week 1 executable reference slice. Local disposable DB only.
TRUNCATE sprint12_gate_results;
DO $$
DECLARE v_count integer; v_conflict text;
BEGIN
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1';
 PERFORM sprint12_assert_eq('T','seven_protocols','7',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' AND authoring_scope='organisation' AND organisation_id='apollo-dogfood' AND lifecycle_status='published' AND published='true' AND published_at IS NOT NULL;
 PERFORM sprint12_assert_eq('T','deterministic_protocol_identities','7',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id LIKE 'APOLLO-W1-%-R1';
 PERFORM sprint12_assert_eq('T','ordered_blocks','19',v_count::text);
 SELECT count(*) INTO v_count FROM session_block_exercises e JOIN session_blocks b ON b.block_id=e.block_id LEFT JOIN exercises_v2 x ON x.exercise_id=e.exercise_id WHERE b.session_id LIKE 'APOLLO-W1-%-R1' AND x.exercise_id IS NULL;
 PERFORM sprint12_assert_eq('T','no_dangling_exercise_references','0',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE (session_id='APOLLO-W1-THU-R1' AND workout_format='intervals' AND timer_config @> '{"rounds":5,"work_seconds":180,"recovery_seconds":120}'::jsonb) OR (session_id='APOLLO-W1-SAT-R1' AND workout_format='emom' AND timer_config @> '{"duration_seconds":480,"interval_seconds":60}'::jsonb);
 PERFORM sprint12_assert_eq('T','interval_and_emom_timer_config','2',v_count::text);
 SELECT count(*) INTO v_count FROM session_blocks WHERE session_id IN ('APOLLO-W1-TUE-R1','APOLLO-W1-SUN-R1') AND timer_config ? 'tracking';
 PERFORM sprint12_assert_eq('T','zone2_tracking_fields','2',v_count::text);
 SELECT count(*) INTO v_count FROM (SELECT protocol_id FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1' GROUP BY protocol_id HAVING count(*)>1) d;
 PERFORM sprint12_assert_eq('T','no_duplicate_protocol_identities','0',v_count::text);
 SELECT count(*) INTO v_count FROM performance_protocols WHERE lower(coalesce(name,'')) LIKE '%spartan%' AND protocol_id LIKE 'APOLLO-%';
 PERFORM sprint12_assert_eq('T','no_spartan_reclassification','0',v_count::text);
 BEGIN
   INSERT INTO performance_protocols(protocol_id,name) VALUES ('APOLLO-W1-MON-R1','conflicting deterministic Apollo identity');
   PERFORM sprint12_record('T','conflicting_identity_fails_closed','unique violation','no exception',NULL,FALSE);
 EXCEPTION WHEN unique_violation THEN
   GET STACKED DIAGNOSTICS v_conflict = MESSAGE_TEXT;
   PERFORM sprint12_record('T','conflicting_identity_fails_closed','unique violation','unique violation',NULL,TRUE,v_conflict);
 END;
END $$;
SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='T' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
