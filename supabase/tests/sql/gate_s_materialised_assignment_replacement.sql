-- Gate S — replacement of an active materialised catalogue assignment.
-- Gate J/K retain anonymous/direct-write/eligibility coverage; this gate proves
-- the new authorised lifecycle transition, rollback, and GUC containment.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-S-REPLACE-R1';
  v_lineage UUID := '91919191-9191-4191-8191-919191919191';
  v_hash_v1 TEXT := sprint12_hash('gate-s-v1');
  v_hash_v2 TEXT := sprint12_hash('gate-s-v2');
  v_hash_v3 TEXT := sprint12_hash('gate-s-v3');
  v_payload JSONB;
  v_res JSONB;
  v_v1 UUID;
  v_v2 UUID;
  v_v3 UUID;
  v_athlete UUID := '92929292-9292-4292-8292-929292929292';
  v_other UUID := '93939393-9393-4393-8393-939393939393';
  v_old UUID;
  v_new UUID;
  v_active UUID;
  v_count INT;
  v_error TEXT;
BEGIN
  DELETE FROM programme_assignments WHERE athlete_id IN (v_athlete, v_other);
  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Replacement Gate S session');

  v_payload := sprint12_build_package('PROG-GATE-S-REPLACE-V1', 1, v_hash_v1, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  v_v1 := (v_res->>'programme_version_id')::uuid;
  v_payload := sprint12_build_package('PROG-GATE-S-REPLACE-V2', 1, v_hash_v2, v_protocol, v_lineage);
  v_res := public.import_authored_plan_package(v_payload);
  v_v2 := (v_res->>'programme_version_id')::uuid;
  v_payload := sprint12_build_package('PROG-GATE-S-REPLACE-V3', 1, v_hash_v3, v_protocol, v_lineage);
  v_res := public.import_authored_plan_package(v_payload);
  v_v3 := (v_res->>'programme_version_id')::uuid;
  PERFORM public.publish_cohort_global_programme_version(v_v1, 'gate-s');
  PERFORM public.approve_cohort_global_programme_version(v_v1, 'gate-s');
  PERFORM public.publish_cohort_global_programme_version(v_v2, 'gate-s');
  PERFORM public.approve_cohort_global_programme_version(v_v2, 'gate-s');
  PERFORM public.publish_cohort_global_programme_version(v_v3, 'gate-s');
  PERFORM public.approve_cohort_global_programme_version(v_v3, 'gate-s');
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete, 'authenticated', 'authenticated',
     'gate-s@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_other, 'authenticated', 'authenticated',
     'gate-s-other@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_athlete, 'Gate S Athlete', TRUE, FALSE), (v_other, 'Gate S Other', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_v1, 'UTC', FALSE);
  v_old := (v_res->>'enrolment_id')::uuid;
  v_res := public.materialise_athlete_plan_from_enrolment(v_old, 'UTC');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('S','materialised_fixture','materialised',v_res->>'status',NULL,
    (v_res->>'status') = 'materialised' AND (v_res->>'materialised_package_content_hash') = v_hash_v1,v_res::text);

  -- Audit data remains linked to the historical assignment; no completion/actuals are fabricated.
  INSERT INTO training_session_records (
    record_id, athlete_id, assignment_id, programme_session_id, status, session_snapshot, started_at
  ) VALUES (gen_random_uuid(), v_athlete::text, v_old, NULL, 'in_progress', '{}'::jsonb, NOW());

  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
    PERFORM set_config('role', 'authenticated', true);
    UPDATE programme_assignments SET status = 'reassigned' WHERE id = v_old;
    PERFORM sprint12_record('S','direct_materialised_status_denied','denied','updated',NULL,FALSE,NULL);
  EXCEPTION WHEN OTHERS THEN
    PERFORM sprint12_record('S','direct_materialised_status_denied','denied',SQLSTATE,NULL,SQLSTATE = '42501',SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_v2, 'UTC', TRUE);
  PERFORM set_config('role', 'postgres', true);
  v_new := (v_res->>'enrolment_id')::uuid;
  PERFORM sprint12_record('S','materialised_replace_authorised','enrolled',v_res->>'status',NULL,
    (v_res->>'status') = 'enrolled' AND (v_res->>'replaced_enrolment_id') = v_old::text
      AND (v_res->>'programme_version_id') = v_v2::text,v_res::text);
  SELECT count(*) INTO v_count FROM programme_assignments
  WHERE id = v_old AND status = 'reassigned' AND superseded_by_assignment_id = v_new
    AND programme_version_id = v_v1 AND materialised_package_content_hash = v_hash_v1;
  PERFORM sprint12_record('S','old_materialised_history_preserved','1',v_count::text,NULL,v_count = 1,NULL);
  SELECT count(*) INTO v_count FROM training_session_records
  WHERE assignment_id = v_old AND athlete_id = v_athlete::text AND status = 'in_progress';
  PERFORM sprint12_record('S','historical_session_audit_resolvable','1',v_count::text,NULL,v_count = 1,NULL);
  SELECT count(*) INTO v_count FROM programme_assignments
  WHERE id = v_new AND athlete_id = v_athlete AND status = 'active'
    AND programme_version_id = v_v2 AND materialised_at IS NULL;
  PERFORM sprint12_record('S','replacement_exact_version','1',v_count::text,NULL,v_count = 1,NULL);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE athlete_id = v_athlete AND status = 'active';
  PERFORM sprint12_record('S','duplicate_active_impossible','1',v_count::text,NULL,v_count = 1,NULL);

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_v1, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('S','replace_false_conflict','active_enrolment_exists',v_res->>'code',NULL,
    (v_res->>'status') = 'conflict' AND (v_res->>'code') = 'active_enrolment_exists',v_res::text);

  -- The unmaterialised replacement path remains valid.
  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_v1, 'UTC', FALSE);
  v_active := (v_res->>'enrolment_id')::uuid;
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_v2, 'UTC', TRUE);
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO v_count FROM programme_assignments
  WHERE id = v_active AND status = 'reassigned' AND materialised_at IS NULL;
  PERFORM sprint12_record('S','unmaterialised_replace_preserved','1',v_count::text,NULL,
    (v_res->>'status') = 'enrolled' AND v_count = 1,v_res::text);

  -- A later insertion failure rolls the supersession update back with it.
  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_v1, 'UTC', TRUE);
  v_active := (v_res->>'enrolment_id')::uuid;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_install_fail_trigger('public.programme_assignments'::regclass, 'sprint12_s_replace_fail', 'check_violation');
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
    PERFORM set_config('role', 'authenticated', true);
    PERFORM public.enrol_athlete_in_catalogue_programme_version(v_v3, 'UTC', TRUE);
  EXCEPTION WHEN OTHERS THEN v_error := SQLSTATE;
  END;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_drop_fail_trigger('public.programme_assignments'::regclass, 'sprint12_s_replace_fail');
  SELECT count(*) INTO v_count FROM programme_assignments WHERE id = v_active AND status = 'active';
  PERFORM sprint12_record('S','failure_rolls_back_reassignment','active old assignment',coalesce(v_error,'no error'),NULL,
    v_error = '23514' AND v_count = 1,NULL);
END;
$$;

INSERT INTO sprint12_gate_results(gate, case_id, expected, actual, pass)
VALUES ('S','guc_transaction_local','off after transaction',
  COALESCE(current_setting('cohort.allow_materialisation_write', true), ''),
  COALESCE(current_setting('cohort.allow_materialisation_write', true), '') <> 'on');

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results WHERE gate = 'S' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
