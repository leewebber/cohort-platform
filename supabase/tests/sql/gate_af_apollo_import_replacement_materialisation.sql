-- Gate AF — Apollo trusted import, catalogue replacement and materialisation.
-- Disposable local DB only. The runner supplies the exact compiler-produced
-- payload at /tmp/sprint12_apollo_import_payload.json.
TRUNCATE sprint12_gate_results;
CREATE TEMP TABLE sprint12_apollo_import_payload (payload JSONB NOT NULL);
\copy sprint12_apollo_import_payload FROM '/tmp/sprint12_apollo_import_payload.json'

DO $$
DECLARE
  v_payload JSONB := (SELECT payload FROM sprint12_apollo_import_payload);
  v_expected_hash TEXT := '7264703a8db56edd6685e97e736405ffa99124fd4c419a676a1246653ea52b87';
  v_legacy_protocol TEXT := 'APOLLO-GATE-AF-LEGACY-R1';
  v_legacy_session_lineage UUID := 'af000001-0000-4000-8000-000000000001';
  v_legacy_hash TEXT := sprint12_hash('apollo-gate-af-legacy');
  v_legacy_payload JSONB;
  v_import JSONB;
  v_res JSONB;
  v_apollo_version UUID;
  v_legacy_version UUID;
  v_athlete UUID := 'af000002-0000-4000-8000-000000000002';
  v_legacy_assignment UUID;
  v_apollo_assignment UUID;
  v_legacy_slot UUID;
  v_count INT;
  v_blocks INT;
  v_ordered BOOLEAN;
BEGIN
  -- Apollo protocol migrations are deliberately independent of import. AF
  -- proves that their published revisions are eligible before package import.
  SELECT count(*) INTO v_count
  FROM performance_protocols
  WHERE protocol_id ~ '^APOLLO-W(1|2|3|4|5|6|7|8|9|10|11|12)-.*-R1$'
    AND lifecycle_status = 'published' AND published = 'true'
    AND published_at IS NOT NULL;
  PERFORM sprint12_assert_eq('AF', 'apollo_protocols_published', '84', v_count::text);

  PERFORM set_config('role', 'service_role', true);
  v_import := public.import_authored_plan_package(v_payload);
  v_apollo_version := (v_import->>'programme_version_id')::uuid;
  PERFORM public.publish_cohort_global_programme_version(v_apollo_version, 'apollo-local-founder@example.invalid');
  PERFORM public.approve_cohort_global_programme_version(v_apollo_version, 'apollo-local-founder@example.invalid');
  PERFORM set_config('role', 'postgres', true);

  SELECT count(*) INTO v_count FROM programme_lineages WHERE code = 'APOLLO-BUILD-12-WEEK';
  PERFORM sprint12_assert_eq('AF', 'one_apollo_lineage', '1', v_count::text);
  SELECT count(*) INTO v_count FROM programme_versions WHERE id = v_apollo_version AND version_number = 1;
  PERFORM sprint12_assert_eq('AF', 'one_apollo_v1', '1', v_count::text);
  PERFORM sprint12_assert_eq('AF', 'canonical_hash_unchanged', v_expected_hash,
    (SELECT package_content_hash FROM programme_versions WHERE id = v_apollo_version));
  SELECT count(*) INTO v_count FROM programme_version_weeks WHERE version_id = v_apollo_version;
  PERFORM sprint12_assert_eq('AF', 'twelve_weeks', '12', v_count::text);
  SELECT count(*) INTO v_count FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_apollo_version;
  PERFORM sprint12_assert_eq('AF', 'eighty_four_schedule_slots', '84', v_count::text);
  SELECT count(*) INTO v_count FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id JOIN programme_version_weeks w ON w.id = d.week_id
  LEFT JOIN performance_protocols p ON p.protocol_id = s.protocol_id
  WHERE w.version_id = v_apollo_version AND (p.protocol_id IS NULL OR p.lifecycle_status <> 'published');
  PERFORM sprint12_assert_eq('AF', 'all_protocol_references_resolve', '0', v_count::text);
  SELECT count(*) INTO v_count FROM (
    SELECT protocol_id FROM programme_version_session_slots s JOIN programme_version_days d ON d.id=s.day_id
    JOIN programme_version_weeks w ON w.id=d.week_id WHERE w.version_id=v_apollo_version
    GROUP BY protocol_id HAVING count(*) > 1
  ) duplicates;
  PERFORM sprint12_assert_eq('AF', 'no_duplicate_programme_session_links', '0', v_count::text);

  -- Establish a materialised legacy assignment and a non-terminal historical
  -- outcome. The historical link must survive Apollo replacement unchanged.
  PERFORM sprint12_ensure_published_session(v_legacy_protocol, v_legacy_session_lineage, 1, 'Apollo AF legacy session');
  v_legacy_payload := sprint12_build_package('APOLLO-GATE-AF-LEGACY', 1, v_legacy_hash,
    v_legacy_protocol, v_legacy_session_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_legacy_payload);
  v_legacy_version := (v_res->>'programme_version_id')::uuid;
  PERFORM public.publish_cohort_global_programme_version(v_legacy_version, 'apollo-local-founder@example.invalid');
  PERFORM public.approve_cohort_global_programme_version(v_legacy_version, 'apollo-local-founder@example.invalid');
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,confirmation_token,recovery_token,email_change_token_new,email_change)
  VALUES ('00000000-0000-0000-0000-000000000000',v_athlete,'authenticated','authenticated','apollo-local-athlete@example.invalid',crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),'{"provider":"email","providers":["email"]}','{}',FALSE,'','','','')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id,display_name,is_athlete,is_coach) VALUES (v_athlete,'Apollo local athlete',TRUE,FALSE)
  ON CONFLICT (id) DO UPDATE SET is_athlete=TRUE,is_coach=FALSE;
  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_legacy_version, 'UTC', FALSE);
  v_legacy_assignment := (v_res->>'enrolment_id')::uuid;
  v_res := public.materialise_athlete_plan_from_enrolment(v_legacy_assignment, 'UTC');
  PERFORM set_config('role', 'postgres', true);
  SELECT s.id INTO v_legacy_slot FROM programme_version_session_slots s JOIN programme_version_days d ON d.id=s.day_id
  JOIN programme_version_weeks w ON w.id=d.week_id WHERE w.version_id=v_legacy_version LIMIT 1;
  INSERT INTO programme_slot_outcomes (assignment_id,session_slot_id,week_number,day_key,session_order,outcome_status)
  VALUES (v_legacy_assignment,v_legacy_slot,1,'day_1',1,'in_progress');

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_apollo_version, 'UTC', TRUE);
  v_apollo_assignment := (v_res->>'enrolment_id')::uuid;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('AF','replacement_authorised','enrolled',v_res->>'status',NULL,
    (v_res->>'status')='enrolled' AND (v_res->>'replaced_enrolment_id')=v_legacy_assignment::text,v_res::text);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE id=v_legacy_assignment AND status='reassigned' AND superseded_by_assignment_id=v_apollo_assignment;
  PERFORM sprint12_assert_eq('AF', 'legacy_no_longer_active', '1', v_count::text);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE athlete_id=v_athlete AND status='active' AND id=v_apollo_assignment;
  PERFORM sprint12_assert_eq('AF', 'apollo_sole_active_assignment', '1', v_count::text);
  SELECT count(*) INTO v_count FROM programme_slot_outcomes WHERE assignment_id=v_legacy_assignment AND session_slot_id=v_legacy_slot AND outcome_status='in_progress';
  PERFORM sprint12_assert_eq('AF', 'historical_legacy_outcome_resolvable', '1', v_count::text);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE athlete_id=v_athlete;
  PERFORM sprint12_assert_eq('AF', 'no_duplicate_assignments', '2', v_count::text);

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.materialise_athlete_plan_from_enrolment(v_apollo_assignment, 'UTC');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('AF','apollo_materialised','materialised',v_res->>'status',NULL,
    (v_res->>'status')='materialised' AND (v_res->>'materialised_package_content_hash')=v_expected_hash,v_res::text);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE id=v_apollo_assignment AND materialised_at IS NOT NULL;
  PERFORM sprint12_assert_eq('AF', 'one_materialised_apollo_assignment', '1', v_count::text);
  SELECT count(*) INTO v_count FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id=s.day_id JOIN programme_version_weeks w ON w.id=d.week_id
  WHERE w.version_id=v_apollo_version;
  PERFORM sprint12_assert_eq('AF', 'eighty_four_materialised_programme_session_links', '84', v_count::text);

  -- Materialisation binds the exact package; every Week 1 slot then resolves
  -- to a published protocol with non-empty executable block content.
  SELECT count(*) INTO v_count FROM programme_version_session_slots s JOIN programme_version_days d ON d.id=s.day_id
  JOIN programme_version_weeks w ON w.id=d.week_id JOIN performance_protocols p ON p.protocol_id=s.protocol_id
  WHERE w.version_id=v_apollo_version AND w.week_number=1 AND p.lifecycle_status='published'
    AND EXISTS (SELECT 1 FROM session_blocks b WHERE b.session_id=s.protocol_id);
  PERFORM sprint12_assert_eq('AF', 'week1_seven_executable_session_plans', '7', v_count::text);
  PERFORM sprint12_assert_eq('AF', 'monday_resolves_expected_protocol', 'APOLLO-W1-MON-R1', (
    SELECT s.protocol_id FROM programme_version_session_slots s JOIN programme_version_days d ON d.id=s.day_id
    JOIN programme_version_weeks w ON w.id=d.week_id WHERE w.version_id=v_apollo_version AND w.week_number=1 AND d.day_order=1));
  SELECT count(*) INTO v_blocks FROM session_blocks WHERE session_id='APOLLO-W1-MON-R1';
  SELECT bool_and(position = expected_position) INTO v_ordered FROM (
    SELECT position,row_number() over (ORDER BY position) AS expected_position FROM session_blocks WHERE session_id='APOLLO-W1-MON-R1'
  ) ordered_blocks;
  PERFORM sprint12_record('AF','monday_warmup_and_strength_ordered','ordered_executable_blocks',v_blocks::text,NULL,v_blocks >= 2 AND v_ordered, NULL);
  SELECT count(*) INTO v_count FROM session_blocks WHERE session_id='APOLLO-W1-THU-R1' AND timer_config @> '{"rounds":5,"work_seconds":180}'::jsonb;
  PERFORM sprint12_assert_eq('AF', 'thursday_five_by_three_timer', '1', v_count::text);
  SELECT count(*) INTO v_count FROM session_blocks WHERE session_id='APOLLO-W1-THU-R1' AND timer_config @> '{"rounds":5,"work_seconds":180,"recovery_seconds":120}'::jsonb;
  PERFORM sprint12_assert_eq('AF', 'thursday_two_minute_recovery', '1', v_count::text);
  SELECT count(*) INTO v_count FROM session_blocks WHERE session_id='APOLLO-W1-SAT-R1' AND workout_format='emom'
    AND timer_config @> '{"duration_seconds":480,"interval_seconds":60}'::jsonb
    AND jsonb_array_length(timer_config->'alternating') = 2;
  PERFORM sprint12_assert_eq('AF', 'saturday_alternating_eight_minute_emom', '1', v_count::text);
  SELECT count(*) INTO v_count FROM session_blocks WHERE session_id IN ('APOLLO-W1-TUE-R1','APOLLO-W1-SUN-R1')
    AND timer_config ? 'work_seconds' AND timer_config ? 'tracking';
  PERFORM sprint12_assert_eq('AF', 'zone2_duration_and_tracking_survive', '2', v_count::text);

  -- Repeat real safe operations: enrolment and materialisation must not add rows.
  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true); PERFORM set_config('role','authenticated',true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_apollo_version,'UTC',TRUE);
  PERFORM set_config('role','postgres',true);
  PERFORM sprint12_record('AF','replacement_retry_idempotent','already_enrolled',v_res->>'status',NULL,(v_res->>'status')='already_enrolled',v_res::text);
  PERFORM set_config('role','authenticated',true);
  v_res := public.materialise_athlete_plan_from_enrolment(v_apollo_assignment,'UTC');
  PERFORM set_config('role','postgres',true);
  PERFORM sprint12_record('AF','materialisation_retry_idempotent','already_materialised',v_res->>'status',NULL,(v_res->>'status')='already_materialised',v_res::text);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE athlete_id=v_athlete; PERFORM sprint12_assert_eq('AF','repeat_has_no_assignment_duplication','2',v_count::text);
  SELECT count(*) INTO v_count FROM programme_slot_outcomes WHERE assignment_id=v_apollo_assignment; PERFORM sprint12_assert_eq('AF','no_synthetic_apollo_outcomes','0',v_count::text);
  SELECT count(*) INTO v_count FROM programme_slot_outcomes WHERE assignment_id IN (v_legacy_assignment,v_apollo_assignment) AND outcome_status IN ('completed','completed_partial');
  PERFORM sprint12_assert_eq('AF','no_completed_performance','0',v_count::text);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE athlete_id=v_athlete AND status='abandoned';
  PERFORM sprint12_assert_eq('AF','no_abandoned_performance','0',v_count::text);
END $$;

SELECT gate,case_id,expected,actual,pass FROM sprint12_gate_results WHERE gate='AF' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
