-- Gate BN — exact local B3 device-validation publication and activation proof.
TRUNCATE sprint12_gate_results;

CREATE TEMP TABLE gate_bn_canonical_fixture (canonical_text TEXT NOT NULL);
CREATE TEMP TABLE gate_bn_hash_fixture (expected_hash TEXT NOT NULL);
CREATE TEMP TABLE gate_bn_graph_fixture (source_line TEXT NOT NULL);
\copy gate_bn_canonical_fixture FROM '/tmp/b3_device_validation.canonical.json'
\copy gate_bn_hash_fixture FROM '/tmp/b3_device_validation.sha256'
\copy gate_bn_graph_fixture FROM '/tmp/b3_device_validation.protocol_graphs.json'

DO $$
DECLARE
  v_coach UUID := 'b3d00000-0000-4000-8000-000000000002';
  v_athlete UUID := 'b3d00000-0000-4000-8000-000000000003';
  v_version UUID := 'b3d00000-0000-4000-8000-000000000001';
  v_old_version UUID := 'b3d00000-0000-4000-8000-000000000004';
  v_old_record UUID := 'b3d00000-0000-4000-8000-000000000006';
  v_old_assignment UUID;
  v_old_slot UUID;
  v_assignment UUID;
  v_occurrence UUID;
  v_unavailable_occurrence UUID;
  v_canonical_text TEXT;
  v_expected_hash TEXT;
  v_payload JSONB;
  v_result JSONB;
  v_retry JSONB;
  v_snapshot JSONB;
  v_graphs JSONB;
  v_old_occurrences INT;
  v_history_digest TEXT;
  v_today DATE := (NOW() AT TIME ZONE 'Asia/Makassar')::DATE;
BEGIN
  SELECT canonical_text INTO STRICT v_canonical_text FROM gate_bn_canonical_fixture;
  SELECT trim(expected_hash) INTO STRICT v_expected_hash FROM gate_bn_hash_fixture;
  SELECT string_agg(source_line, E'\n')::JSONB INTO STRICT v_graphs
  FROM gate_bn_graph_fixture;

  PERFORM sprint12_record(
    'BN', 'exact_compiler_hash',
    'fe8d2bb2dfa5479a43062deb2974c9106640d652db6e29fa5b3dd02495e6cb4a',
    v_expected_hash, NULL,
    v_expected_hash = 'fe8d2bb2dfa5479a43062deb2974c9106640d652db6e29fa5b3dd02495e6cb4a'
      AND encode(digest(convert_to(v_canonical_text, 'UTF8'), 'sha256'), 'hex') = v_expected_hash,
    NULL
  );

  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_coach,
     'authenticated','authenticated','gate-bn-coach@example.invalid',
     crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
     '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''),
    ('00000000-0000-0000-0000-000000000000', v_athlete,
     'authenticated','authenticated','gate-bn-athlete@example.invalid',
     crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
     '{"provider":"email","providers":["email"]}','{}',FALSE,'','','','');
  INSERT INTO public.profiles(id, display_name, is_athlete, is_coach) VALUES
    (v_coach, 'Gate BN Coach', FALSE, TRUE),
    (v_athlete, 'Gate BN Athlete', TRUE, FALSE);
  INSERT INTO public.coach_athlete_relationships(coach_id, athlete_id, status)
  VALUES (v_coach, v_athlete, 'active');

  v_payload := v_canonical_text::JSONB || jsonb_build_object(
    'programme', (v_canonical_text::JSONB->'programme') - 'library_scope' - 'owner_type',
    'package_content_hash', v_expected_hash,
    'package_canonical_json', v_canonical_text,
    'imported_by', 'gate-bn',
    'publication_kind', 'private_exact_version',
    'programme_version_id', v_version,
    'library_scope', 'coach_private',
    'owner_id', v_coach,
    'protocol_graphs', v_graphs,
    'authorised_timezone', 'Asia/Makassar',
    'authorised_local_start_date', v_today::TEXT
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_result := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record(
    'BN', 'exact_private_v2_publication', 'published|4|3',
    COALESCE(v_result->>'status', '') || '|' ||
      (SELECT count(*) FROM public.programme_version_session_slots slot
       JOIN public.programme_version_days day ON day.id = slot.day_id
       JOIN public.programme_version_weeks week ON week.id = day.week_id
       WHERE week.version_id = v_version)::TEXT || '|' ||
      (SELECT count(*) FROM public.programme_version_session_slots slot
       JOIN public.programme_version_days day ON day.id = slot.day_id
       JOIN public.programme_version_weeks week ON week.id = day.week_id
       WHERE week.version_id = v_version
         AND slot.authored_running_v1#>>'{advisory_attachments,0,policy,benchmark_eligibility,manual_completed_tests_eligible}' = 'true')::TEXT,
    EXISTS (
      SELECT 1 FROM public.programme_versions
      WHERE id = v_version AND package_content_hash = v_expected_hash
        AND package_schema_version = 2 AND lifecycle_status = 'published'
    ),
    v_result->>'status' = 'published'
      AND (SELECT count(*) FROM public.programme_version_session_slots slot
           JOIN public.programme_version_days day ON day.id = slot.day_id
           JOIN public.programme_version_weeks week ON week.id = day.week_id
           WHERE week.version_id = v_version) = 4
      AND (SELECT count(*) FROM public.programme_version_session_slots slot
           JOIN public.programme_version_days day ON day.id = slot.day_id
           JOIN public.programme_version_weeks week ON week.id = day.week_id
           WHERE week.version_id = v_version
             AND slot.authored_running_v1#>>'{advisory_attachments,0,policy,benchmark_eligibility,manual_completed_tests_eligible}' = 'true') = 3,
    v_result::TEXT
  );
  PERFORM sprint12_record(
    'BN', 'exact_timer_and_mapping', '20|15|3|91dac4d3...',
    (SELECT (timer_config->>'work_seconds') || '|' ||
       (timer_config->>'rest_seconds') || '|' || (timer_config->>'rounds')
       FROM public.session_blocks WHERE session_id =
       'B3-DEV-RUN-VALIDATION-R1') || '|' ||
    (SELECT authored_running_v1->>'execution_mapping_sha256'
       FROM public.programme_version_session_slots slot
       JOIN public.programme_version_days day ON day.id = slot.day_id
       JOIN public.programme_version_weeks week ON week.id = day.week_id
       WHERE week.version_id = v_version ORDER BY slot.session_order LIMIT 1),
    NULL,
    EXISTS (
      SELECT 1 FROM public.session_blocks
      WHERE session_id = 'B3-DEV-RUN-VALIDATION-R1'
        AND timer_config->>'work_seconds' = '20'
        AND timer_config->>'rest_seconds' = '15'
        AND timer_config->>'rounds' = '3'
    ) AND NOT EXISTS (
      SELECT 1 FROM public.programme_version_session_slots slot
      JOIN public.programme_version_days day ON day.id = slot.day_id
      JOIN public.programme_version_weeks week ON week.id = day.week_id
      WHERE week.version_id = v_version
        AND slot.authored_running_v1->>'execution_mapping_sha256' <>
          '91dac4d3717737d84ab31c805a9b69be3c28db68500cfbd368176e587af5a421'
    ), NULL
  );

  -- Create a prior supported assignment so replacement preservation is proved.
  v_payload := sprint12_build_package(
    'GATE-BN-PRIOR', 1, sprint12_hash('gate-bn-prior'),
    'PROT-GATE-BN-PRIOR-R1', 'b3d00000-0000-4000-8000-000000000005'
  ) || jsonb_build_object(
    'publication_kind', 'private_exact_version',
    'programme_version_id', v_old_version,
    'library_scope', 'coach_private',
    'owner_id', v_coach
  );
  PERFORM set_config('role', 'service_role', TRUE);
  PERFORM public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('request.jwt.claim.sub', v_athlete::TEXT, TRUE);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.enrol_athlete_in_private_programme_version(
    v_old_version, 'Asia/Makassar', v_today, FALSE
  );
  v_old_assignment := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_old_occurrences
  FROM public.programme_schedule_occurrences WHERE assignment_id = v_old_assignment;
  SELECT session_slot_id INTO STRICT v_old_slot
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_old_assignment;
  INSERT INTO public.training_session_records(
    record_id, athlete_id, source_protocol_id, programme_id, assignment_id,
    programme_session_id, status, session_snapshot, started_at, completed_at,
    athlete_note
  ) VALUES (
    v_old_record, v_athlete::TEXT, 'PROT-GATE-BN-PRIOR-R1',
    v_old_version::TEXT, v_old_assignment, v_old_slot, 'completed',
    '{"gate":"bn","preserved":true}'::JSONB, NOW() - INTERVAL '5 minutes',
    NOW(), 'historical evidence must survive replacement'
  );
  SELECT md5(string_agg(
    record_id::TEXT || '|' || status || '|' || session_snapshot::TEXT || '|' ||
      COALESCE(athlete_note, ''),
    ',' ORDER BY record_id
  )) INTO STRICT v_history_digest
  FROM public.training_session_records
  WHERE assignment_id = v_old_assignment;

  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.enrol_athlete_in_private_programme_version(
    v_version, 'Asia/Makassar', v_today, TRUE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record(
    'BN', 'supported_replace_preserves_prior_assignment_and_evidence',
    'enrolled|reassigned|4|evidence-identical',
    COALESCE(v_result->>'status', '') || '|' ||
      (SELECT status FROM public.programme_assignments WHERE id = v_old_assignment) || '|' ||
      (SELECT count(*) FROM public.programme_schedule_occurrences WHERE assignment_id = v_assignment)::TEXT || '|' ||
      CASE WHEN v_history_digest = (
        SELECT md5(string_agg(
          record_id::TEXT || '|' || status || '|' || session_snapshot::TEXT || '|' ||
            COALESCE(athlete_note, ''),
          ',' ORDER BY record_id
        ))
        FROM public.training_session_records
        WHERE assignment_id = v_old_assignment
      ) THEN 'evidence-identical' ELSE 'evidence-changed' END,
    (SELECT count(*) FROM public.programme_schedule_occurrences
       WHERE assignment_id = v_old_assignment) = v_old_occurrences
      AND EXISTS (
        SELECT 1 FROM public.training_session_records
        WHERE record_id = v_old_record AND assignment_id = v_old_assignment
      ),
    v_result->>'status' = 'enrolled'
      AND v_result->>'replaced_enrolment_id' = v_old_assignment::TEXT
      AND (SELECT status FROM public.programme_assignments WHERE id = v_old_assignment) = 'reassigned'
      AND (SELECT count(*) FROM public.programme_schedule_occurrences WHERE assignment_id = v_assignment) = 4
      AND (SELECT count(*) FROM public.programme_schedule_occurrences
           WHERE assignment_id = v_old_assignment) = v_old_occurrences
      AND v_history_digest = (
        SELECT md5(string_agg(
          record_id::TEXT || '|' || status || '|' || session_snapshot::TEXT || '|' ||
            COALESCE(athlete_note, ''),
          ',' ORDER BY record_id
        ))
        FROM public.training_session_records
        WHERE assignment_id = v_old_assignment
      ),
    v_result::TEXT
  );
  PERFORM sprint12_record(
    'BN', 'four_occurrences_are_exercisable_on_activation_date',
    '4|1|' || v_today::TEXT,
    (SELECT count(*)::TEXT || '|' || count(DISTINCT scheduled_date)::TEXT || '|' ||
       min(scheduled_date)::TEXT
     FROM public.programme_schedule_occurrences
     WHERE assignment_id = v_assignment),
    NULL,
    (SELECT count(*) = 4
       AND count(DISTINCT scheduled_date) = 1
       AND min(scheduled_date) = v_today
       AND max(scheduled_date) = v_today
     FROM public.programme_schedule_occurrences
     WHERE assignment_id = v_assignment),
    NULL
  );

  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.record_manual_completed_5k_benchmark(jsonb_build_object(
    'command_id', 'b3d00000-0000-4000-8000-000000000099',
    'source_reference', 'b3-device-validation:gate-bn',
    'source', 'manual',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1200000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', (v_today - 1)::TEXT,
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'outdoor'
  ));
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT occurrence.id INTO STRICT v_occurrence
  FROM public.programme_schedule_occurrences occurrence
  JOIN public.programme_version_session_slots slot ON slot.id = occurrence.session_slot_id
  WHERE occurrence.assignment_id = v_assignment AND slot.session_order = 1;
  SELECT occurrence.id INTO STRICT v_unavailable_occurrence
  FROM public.programme_schedule_occurrences occurrence
  JOIN public.programme_version_session_slots slot ON slot.id = occurrence.session_slot_id
  WHERE occurrence.assignment_id = v_assignment AND slot.session_order = 4;

  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.create_or_resume_fixed_programme_occurrence_session(v_occurrence);
  PERFORM set_config('role', 'postgres', TRUE);
  v_snapshot := v_result->'running_target_snapshot';
  PERFORM sprint12_record(
    'BN', 'real_manual_evidence_calculates_test_target', 'created|calculated',
    COALESCE(v_result->>'status', '') || '|' || COALESCE(v_snapshot#>>'{targets,0,state}', ''),
    EXISTS (SELECT 1 FROM public.programme_occurrence_running_target_snapshots
            WHERE occurrence_id = v_occurrence),
    v_result->>'status' = 'created'
      AND v_snapshot#>>'{targets,0,state}' = 'calculated'
      AND v_snapshot#>>'{targets,0,policy,policy_id}' = 'B3-DEV-TEST-ONLY-90-100-PERCENT',
    v_snapshot::TEXT
  );
  PERFORM set_config('role', 'authenticated', TRUE);
  v_retry := public.create_or_resume_fixed_programme_occurrence_session(v_occurrence);
  v_result := public.create_or_resume_fixed_programme_occurrence_session(v_unavailable_occurrence);
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record(
    'BN', 'resume_and_no_eligible_evidence_fail_closed', 'resumed|identical|intent_only',
    COALESCE(v_retry->>'status', '') || '|' ||
      CASE WHEN v_retry->'running_target_snapshot' = v_snapshot THEN 'identical' ELSE 'changed' END || '|' ||
      COALESCE(v_result#>>'{running_target_snapshot,targets,0,state}', ''),
    (SELECT count(*) FROM public.programme_occurrence_running_target_snapshots
       WHERE occurrence_id = v_occurrence) = 1,
    v_retry->>'status' = 'resumed'
      AND v_retry->'running_target_snapshot' = v_snapshot
      AND v_result#>>'{running_target_snapshot,targets,0,state}' = 'intent_only'
      AND v_result#>>'{running_target_snapshot,targets,0,policy,policy_id}' =
        'B3-DEV-TEST-ONLY-COHORT-EVIDENCE-ONLY',
    v_result::TEXT
  );
END;
$$;

SELECT gate, case_id, expected, actual, persisted_ok, pass
FROM sprint12_gate_results ORDER BY gate, case_id;
SELECT sprint12_fail_if_any_failed();
