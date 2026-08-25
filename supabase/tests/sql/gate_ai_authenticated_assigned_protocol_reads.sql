-- Gate AI — assigned athlete executable protocol read graph.
-- Runs after AF (Apollo state), AG (profile security) and AH (programme tree).

DO $$
DECLARE
  v_coach UUID := 'a7000002-0000-4000-8000-000000000002';
  v_athlete UUID := 'af000002-0000-4000-8000-000000000002';
BEGIN
  INSERT INTO coach_athlete_relationships (coach_id,athlete_id,status)
  VALUES (v_coach,v_athlete,'active')
  ON CONFLICT (coach_id,athlete_id) WHERE status = 'active' DO NOTHING;
END $$;

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'af000002-0000-4000-8000-000000000002', true);
DO $$
DECLARE
  v_version UUID;
BEGIN
  SELECT v.id INTO v_version
  FROM programme_versions v
  JOIN programme_lineages l ON l.id = v.lineage_id
  WHERE l.code = 'APOLLO-BUILD-12-WEEK' AND v.version_number = 1;

  IF (SELECT count(*)
      FROM performance_protocols p
      JOIN programme_version_session_slots s ON s.protocol_id = p.protocol_id
      JOIN programme_version_days d ON d.id = s.day_id
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE w.version_id = v_version AND w.week_number = 1) <> 7 THEN
    RAISE EXCEPTION 'AI did not resolve all seven assigned Week 1 protocols';
  END IF;
  IF (SELECT count(*) FROM session_blocks
      WHERE session_id LIKE 'APOLLO-W1-%-R1') <> 19 THEN
    RAISE EXCEPTION 'AI did not resolve all Week 1 blocks';
  END IF;
  IF (SELECT count(*) FROM session_block_exercises e
      JOIN session_blocks b ON b.block_id = e.block_id
      WHERE b.session_id LIKE 'APOLLO-W1-%-R1') <> 82 THEN
    RAISE EXCEPTION 'AI did not resolve all Week 1 block exercises';
  END IF;
  IF (SELECT count(*) FROM exercises_v2 WHERE exercise_id IN (
      SELECT e.exercise_id FROM session_block_exercises e
      JOIN session_blocks b ON b.block_id = e.block_id
      WHERE b.session_id = 'APOLLO-W1-MON-R1'
    )) <> 15 THEN
    RAISE EXCEPTION 'AI Monday canonical exercise details unavailable';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM session_blocks
                 WHERE session_id = 'APOLLO-W1-MON-R1'
                   AND position = 1
                   AND title = 'Apollo Shoulder Balance Warm-Up')
     OR NOT EXISTS (SELECT 1 FROM session_blocks
                    WHERE session_id = 'APOLLO-W1-MON-R1'
                      AND position = 2
                      AND title = 'Main strength') THEN
    RAISE EXCEPTION 'AI Monday warm-up/main ordering unavailable';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM session_blocks
                 WHERE session_id = 'APOLLO-W1-THU-R1'
                   AND timer_config @> '{"rounds":5,"work_seconds":180,"recovery_seconds":120}'::jsonb) THEN
    RAISE EXCEPTION 'AI Thursday interval timer unavailable';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM session_blocks
                 WHERE session_id = 'APOLLO-W1-SAT-R1'
                   AND workout_format = 'emom'
                   AND timer_config @> '{"duration_seconds":480,"interval_seconds":60}'::jsonb
                   AND jsonb_array_length(timer_config->'alternating') = 2) THEN
    RAISE EXCEPTION 'AI Saturday alternating EMOM unavailable';
  END IF;
END $$;
ROLLBACK;

SELECT sprint12_record('AI','assigned_week1_protocols','7','7',NULL,TRUE,NULL);
SELECT sprint12_record('AI','assigned_week1_blocks','19','19',NULL,TRUE,NULL);
SELECT sprint12_record('AI','assigned_week1_block_exercises','82','82',NULL,TRUE,NULL);
SELECT sprint12_record('AI','monday_exercise_details_and_order','available','available',NULL,TRUE,NULL);
SELECT sprint12_record('AI','thursday_interval_timer','5x180s_plus_120s','5x180s_plus_120s',NULL,TRUE,NULL);
SELECT sprint12_record('AI','saturday_alternating_emom','480s_alternating','480s_alternating',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'a7000001-0000-4000-8000-000000000001', true);
DO $$
BEGIN
  IF (SELECT count(*) FROM performance_protocols WHERE protocol_id LIKE 'APOLLO-W1-%-R1') <> 0
     OR (SELECT count(*) FROM session_blocks WHERE session_id LIKE 'APOLLO-W1-%-R1') <> 0
     OR (SELECT count(*) FROM session_block_exercises) <> 0 THEN
    RAISE EXCEPTION 'AI unassigned athlete protocol content leakage';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AI','unassigned_athlete_protocols_hidden','0','0',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'af000002-0000-4000-8000-000000000002', true);
DO $$
BEGIN
  IF (SELECT count(*) FROM performance_protocols WHERE lifecycle_status = 'draft') <> 0 THEN
    RAISE EXCEPTION 'AI draft protocol content leakage';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AI','draft_protocols_hidden','0','0',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'a7000002-0000-4000-8000-000000000002', true);
DO $$
BEGIN
  IF (SELECT count(*) FROM performance_protocols WHERE protocol_id = 'APOLLO-W1-MON-R1') <> 1 THEN
    RAISE EXCEPTION 'AI linked coach assigned protocol access regressed';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AI','linked_coach_assigned_protocol_read_retained','1','1',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE postgres;
DO $$
BEGIN
  IF (SELECT count(*) FROM performance_protocols WHERE protocol_id = 'APOLLO-W1-MON-R1') <> 1 THEN
    RAISE EXCEPTION 'AI database admin protocol access regressed';
  END IF;
END $$;
ROLLBACK;
SELECT sprint12_record('AI','database_admin_protocol_read_retained','1','1',NULL,TRUE,NULL);

BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
  PERFORM 1 FROM performance_protocols WHERE protocol_id = 'APOLLO-W1-MON-R1';
  RAISE EXCEPTION 'AI anonymous protocol read unexpectedly permitted';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END $$;
ROLLBACK;
SELECT sprint12_record('AI','anonymous_protocol_read_denied','42501','42501',NULL,TRUE,NULL);

SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='AI' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
