-- Gate BK — occurrence-scoped advisory target snapshot persistence.
TRUNCATE sprint12_gate_results;

CREATE TEMP TABLE gate_bk_canonical_fixture (canonical_text TEXT NOT NULL);
\copy gate_bk_canonical_fixture FROM '/tmp/plan_package_v2.canonical.json'

CREATE OR REPLACE FUNCTION sprint12_build_bk_v2_payload(
  p_canonical_text TEXT,
  p_version_id UUID,
  p_owner_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_canonical JSONB := p_canonical_text::JSONB;
  v_protocol TEXT := v_canonical->'sessions'->0->>'protocol_id';
BEGIN
  RETURN v_canonical || jsonb_build_object(
    'programme',
      (v_canonical->'programme')
        - 'library_scope'::TEXT
        - 'owner_type'::TEXT,
    'package_content_hash',
      encode(digest(convert_to(p_canonical_text, 'UTF8'), 'sha256'), 'hex'),
    'package_canonical_json', p_canonical_text,
    'imported_by', 'gate-bk',
    'publication_kind', 'private_exact_version',
    'programme_version_id', p_version_id,
    'library_scope', 'coach_private',
    'owner_id', p_owner_id,
    'protocol_graphs', jsonb_build_array(jsonb_build_object(
      'protocol_id', v_protocol,
      'revision_number', 1,
      'blocks', jsonb_build_array(jsonb_build_object(
        'position', 1,
        'block_type', 'conditioning',
        'title', 'Gate BK executable block',
        'content', '',
        'workout_format', 'steady_state',
        'timer_config', jsonb_build_object(
          'format', 'steady_state',
          'duration_seconds', 60
        ),
        'coach_notes', 'Disposable occurrence snapshot proof only',
        'performance_capture_mode', 'auto',
        'exercises', jsonb_build_array(jsonb_build_object(
          'exercise_id', 'gate-bk-movement',
          'position', 1,
          'display_label_override', 'Gate BK movement',
          'prescription', jsonb_build_object(
            'sets', 1,
            'reps', jsonb_build_object('type', 'exact', 'exact_reps', 1)
          )
        ))
      ))
    ))
  );
END;
$$;

CREATE TABLE public.sprint12_gate_bk_concurrency_fixture (
  fixture_key TEXT PRIMARY KEY,
  athlete_id UUID NOT NULL,
  occurrence_id UUID NOT NULL
);

DO $$
DECLARE
  v_coach UUID := 'b2300000-0000-4000-8000-000000000001';
  v_calc_athlete UUID := 'b2300000-0000-4000-8000-000000000002';
  v_missing_athlete UUID := 'b2300000-0000-4000-8000-000000000003';
  v_stale_athlete UUID := 'b2300000-0000-4000-8000-000000000004';
  v_failure_athlete UUID := 'b2300000-0000-4000-8000-000000000005';
  v_concurrent_athlete UUID := 'b2300000-0000-4000-8000-000000000006';
  v_unattached_athlete UUID := 'b2300000-0000-4000-8000-000000000007';
  v_v1_athlete UUID := 'b2300000-0000-4000-8000-000000000008';
  v_attached_version UUID := 'b2300000-0000-4000-8000-000000000010';
  v_unattached_version UUID := 'b2300000-0000-4000-8000-000000000011';
  v_v1_version UUID := 'b2300000-0000-4000-8000-000000000012';
  v_canonical_text TEXT;
  v_unattached JSONB;
  v_payload JSONB;
  v_result JSONB;
  v_retry JSONB;
  v_snapshot JSONB;
  v_original_snapshot JSONB;
  v_expected_range JSONB;
  v_assignment UUID;
  v_occurrence UUID;
  v_calc_occurrence UUID;
  v_evidence UUID;
  v_count INT;
  v_failed BOOLEAN := FALSE;
  v_has_privilege BOOLEAN;
  v_today DATE := (NOW() AT TIME ZONE 'Asia/Makassar')::DATE;
BEGIN
  SELECT canonical_text INTO STRICT v_canonical_text
  FROM gate_bk_canonical_fixture;

  INSERT INTO auth.users (
    instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_super_admin,
    confirmation_token,recovery_token,email_change_token_new,email_change
  )
  SELECT
    '00000000-0000-0000-0000-000000000000', identity.id,
    'authenticated','authenticated',identity.email,
    crypt('x',gen_salt('bf')),NOW(),NOW(),NOW(),
    '{"provider":"email","providers":["email"]}','{}',FALSE,'','','',''
  FROM (VALUES
    (v_coach, 'gate-bk-coach@example.invalid'),
    (v_calc_athlete, 'gate-bk-calc@example.invalid'),
    (v_missing_athlete, 'gate-bk-missing@example.invalid'),
    (v_stale_athlete, 'gate-bk-stale@example.invalid'),
    (v_failure_athlete, 'gate-bk-failure@example.invalid'),
    (v_concurrent_athlete, 'gate-bk-concurrent@example.invalid'),
    (v_unattached_athlete, 'gate-bk-unattached@example.invalid'),
    (v_v1_athlete, 'gate-bk-v1@example.invalid')
  ) AS identity(id, email)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles(id, display_name, is_athlete, is_coach)
  SELECT identity.id, identity.label, identity.is_athlete, identity.is_coach
  FROM (VALUES
    (v_coach, 'Gate BK Coach', FALSE, TRUE),
    (v_calc_athlete, 'Gate BK Calculated', TRUE, FALSE),
    (v_missing_athlete, 'Gate BK Missing', TRUE, FALSE),
    (v_stale_athlete, 'Gate BK Stale', TRUE, FALSE),
    (v_failure_athlete, 'Gate BK Failure', TRUE, FALSE),
    (v_concurrent_athlete, 'Gate BK Concurrent', TRUE, FALSE),
    (v_unattached_athlete, 'Gate BK Unattached', TRUE, FALSE),
    (v_v1_athlete, 'Gate BK V1', TRUE, FALSE)
  ) AS identity(id, label, is_athlete, is_coach)
  ON CONFLICT (id) DO UPDATE SET
    is_athlete = EXCLUDED.is_athlete,
    is_coach = EXCLUDED.is_coach;
  INSERT INTO public.coach_athlete_relationships(coach_id, athlete_id, status)
  SELECT v_coach, athlete_id, 'active'
  FROM unnest(ARRAY[
    v_calc_athlete, v_missing_athlete, v_stale_athlete, v_failure_athlete,
    v_concurrent_athlete, v_unattached_athlete, v_v1_athlete
  ]) athlete_id;

  v_payload := sprint12_build_bk_v2_payload(
    v_canonical_text, v_attached_version, v_coach
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_result := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  IF v_result->>'status' <> 'published' THEN
    RAISE EXCEPTION 'gate BK attached publication failed: %', v_result;
  END IF;

  v_unattached := v_canonical_text::JSONB;
  v_unattached := v_unattached #- '{weeks,0,days,0,slots,0,authored_running_v1}';
  v_unattached := jsonb_set(
    v_unattached, '{programme,lineage_code}', '"PROG-RUNNING-UNATTACHED"'
  );
  v_unattached := jsonb_set(
    v_unattached, '{programme,name}', '"Running unattached fixture"'
  );
  v_unattached := jsonb_set(
    v_unattached, '{sessions,0,protocol_id}', '"PROT-RUN-UNATTACHED-R1"'
  );
  v_unattached := jsonb_set(
    v_unattached, '{sessions,0,session_lineage_id}',
    '"b2300000-0000-4000-8000-000000000099"'
  );
  v_payload := sprint12_build_bk_v2_payload(
    v_unattached::TEXT, v_unattached_version, v_coach
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_result := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  IF v_result->>'status' <> 'published' THEN
    RAISE EXCEPTION 'gate BK unattached publication failed: %', v_result;
  END IF;

  v_payload := sprint12_build_package(
    'PROG-GATE-BK-V1', 1, sprint12_hash('gate-bk-v1'),
    'PROT-GATE-BK-V1-R1', 'b2300000-0000-4000-8000-000000000098'
  ) || jsonb_build_object(
    'publication_kind', 'private_exact_version',
    'programme_version_id', v_v1_version,
    'library_scope', 'coach_private',
    'owner_id', v_coach
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_result := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  IF v_result->>'status' <> 'published' THEN
    RAISE EXCEPTION 'gate BK v1 publication failed: %', v_result;
  END IF;

  -- Calculated first start.
  PERFORM set_config('request.jwt.claim.sub', v_calc_athlete::TEXT, TRUE);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.enrol_athlete_in_private_programme_version(
    v_attached_version, 'Asia/Makassar', FALSE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT id INTO STRICT v_calc_occurrence
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_assignment;

  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.record_manual_completed_5k_benchmark(jsonb_build_object(
    'command_id', 'b2300000-0000-4000-8000-000000000020',
    'source_reference', 'manual-gate-bk-first',
    'source', 'manual',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1200000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', (v_today - 10)::TEXT,
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'outdoor'
  ));
  v_evidence := (v_result->>'evidence_id')::UUID;
  v_result := public.create_or_resume_fixed_programme_occurrence_session(
    v_calc_occurrence
  );
  PERFORM set_config('role', 'postgres', TRUE);
  v_snapshot := v_result->'running_target_snapshot';
  v_original_snapshot := v_snapshot;
  v_expected_range := public.cohort_calculate_running_pace_range(
    1200000, 8123, 9345, 1000, 'nearest'
  );
  PERFORM sprint12_record(
    'BK', 'calculated_snapshot_frozen_on_first_start', 'created|calculated',
    COALESCE(v_result->>'status', '') || '|' ||
      COALESCE(v_snapshot#>>'{targets,0,state}', ''),
    EXISTS (
      SELECT 1
      FROM public.programme_occurrence_running_target_snapshots frozen
      WHERE frozen.occurrence_id = v_calc_occurrence
        AND frozen.training_session_id =
          (v_result#>>'{training_session,id}')::BIGINT
    ),
    v_result->>'status' = 'created'
      AND v_snapshot#>>'{targets,0,state}' = 'calculated'
      AND v_snapshot#>>'{targets,0,benchmark,evidence_id}' = v_evidence::TEXT
      AND v_snapshot#>>'{targets,0,benchmark,duration_basis}' =
        'elapsed_including_pauses'
      AND v_snapshot#>'{targets,0,calculated_exact_range,faster,numerator}' =
        v_expected_range#>'{faster_pace,numerator_milliseconds_per_kilometre}'
      AND v_snapshot#>'{targets,0,calculated_exact_range,slower,denominator}' =
        v_expected_range#>'{slower_pace,denominator}',
    v_snapshot::TEXT
  );

  -- A newer result cannot alter the already-frozen aggregate.
  PERFORM set_config('role', 'authenticated', TRUE);
  PERFORM public.record_manual_completed_5k_benchmark(jsonb_build_object(
    'command_id', 'b2300000-0000-4000-8000-000000000021',
    'source_reference', 'manual-gate-bk-later',
    'source', 'manual',
    'declaration', 'completed_five_kilometre_test',
    'distance_metres', 5000,
    'elapsed_duration_milliseconds', 1080000,
    'duration_basis', 'elapsed_including_pauses',
    'local_test_date', (v_today - 1)::TEXT,
    'iana_timezone', 'Asia/Makassar',
    'surface_context', 'treadmill'
  ));
  v_retry := public.create_or_resume_fixed_programme_occurrence_session(
    v_calc_occurrence
  );
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count
  FROM public.programme_occurrence_running_target_snapshots
  WHERE occurrence_id = v_calc_occurrence;
  PERFORM sprint12_record(
    'BK', 'retry_returns_identical_snapshot', 'resumed|identical|1',
    COALESCE(v_retry->>'status', '') || '|' ||
      CASE WHEN v_retry->'running_target_snapshot' = v_original_snapshot
        THEN 'identical' ELSE 'changed' END || '|' || v_count::TEXT,
    NULL,
    v_retry->>'status' = 'resumed'
      AND v_retry->'running_target_snapshot' = v_original_snapshot
      AND v_count = 1,
    v_retry::TEXT
  );

  -- Missing and stale evidence freeze honest intent-only states.
  FOREACH v_occurrence IN ARRAY ARRAY[v_missing_athlete, v_stale_athlete]
  LOOP
    PERFORM set_config('request.jwt.claim.sub', v_occurrence::TEXT, TRUE);
    PERFORM set_config('role', 'authenticated', TRUE);
    v_result := public.enrol_athlete_in_private_programme_version(
      v_attached_version, 'Asia/Makassar', FALSE
    );
    v_assignment := (v_result->>'enrolment_id')::UUID;
    PERFORM set_config('role', 'postgres', TRUE);
    SELECT id INTO STRICT v_occurrence
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment;
    IF v_assignment = (
      SELECT assignment_id FROM public.programme_schedule_occurrences
      WHERE id = v_occurrence
    ) AND EXISTS (
      SELECT 1 FROM public.programme_assignments
      WHERE id = v_assignment AND athlete_id = v_stale_athlete
    ) THEN
      PERFORM set_config('request.jwt.claim.sub', v_stale_athlete::TEXT, TRUE);
      PERFORM set_config('role', 'authenticated', TRUE);
      PERFORM public.record_manual_completed_5k_benchmark(jsonb_build_object(
        'command_id', 'b2300000-0000-4000-8000-000000000022',
        'source_reference', 'manual-gate-bk-stale',
        'source', 'manual',
        'declaration', 'completed_five_kilometre_test',
        'distance_metres', 5000,
        'elapsed_duration_milliseconds', 1260000,
        'duration_basis', 'elapsed_including_pauses',
        'local_test_date', (v_today - 91)::TEXT,
        'iana_timezone', 'Asia/Makassar',
        'surface_context', 'outdoor'
      ));
    END IF;
    PERFORM set_config('role', 'authenticated', TRUE);
    v_result := public.create_or_resume_fixed_programme_occurrence_session(
      v_occurrence
    );
    PERFORM set_config('role', 'postgres', TRUE);
    PERFORM sprint12_record(
      'BK', CASE
        WHEN v_result#>>'{running_target_snapshot,targets,0,reason}' = 'no_evidence'
          THEN 'missing_evidence_freezes_intent_only'
        ELSE 'stale_evidence_freezes_intent_only'
      END,
      'intent_only', v_result#>>'{running_target_snapshot,targets,0,state}',
      EXISTS (
        SELECT 1 FROM public.programme_occurrence_running_target_snapshots
        WHERE occurrence_id = v_occurrence
      ),
      v_result->>'status' = 'created'
        AND v_result#>>'{running_target_snapshot,targets,0,state}' = 'intent_only'
        AND v_result#>>'{running_target_snapshot,targets,0,reason}' IN (
          'no_evidence', 'no_fresh_evidence'
        ),
      v_result::TEXT
    );
  END LOOP;

  -- A persistence failure rolls back session, outcome, and snapshot.
  PERFORM set_config('request.jwt.claim.sub', v_failure_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.enrol_athlete_in_private_programme_version(
    v_attached_version, 'Asia/Makassar', FALSE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT id INTO STRICT v_occurrence
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  PERFORM sprint12_install_fail_trigger(
    'public.programme_occurrence_running_target_snapshots'::REGCLASS,
    'gate_bk_forced_snapshot_failure'
  );
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_failure_athlete::TEXT, TRUE);
    PERFORM set_config('role', 'authenticated', TRUE);
    PERFORM public.create_or_resume_fixed_programme_occurrence_session(
      v_occurrence
    );
  EXCEPTION WHEN others THEN
    v_failed := SQLERRM LIKE '%sprint12_forced_failure_on_%';
  END;
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_drop_fail_trigger(
    'public.programme_occurrence_running_target_snapshots'::REGCLASS,
    'gate_bk_forced_snapshot_failure'
  );
  SELECT
    (SELECT count(*) FROM public.programme_occurrence_running_target_snapshots
      WHERE occurrence_id = v_occurrence)
    + (SELECT count(*) FROM public.programme_slot_outcomes
      WHERE assignment_id = v_assignment)
    + (SELECT count(*) FROM public.training_sessions
      WHERE athlete_id = v_failure_athlete::TEXT)
  INTO v_count;
  PERFORM sprint12_record(
    'BK', 'snapshot_failure_rolls_back_start', 'true|0',
    v_failed::TEXT || '|' || v_count::TEXT, v_count = 0,
    v_failed AND v_count = 0, NULL
  );

  -- Published v2 without an attachment follows the exact legacy response.
  PERFORM set_config('request.jwt.claim.sub', v_unattached_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.enrol_athlete_in_private_programme_version(
    v_unattached_version, 'Asia/Makassar', FALSE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT id INTO STRICT v_occurrence
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.create_or_resume_fixed_programme_occurrence_session(v_occurrence);
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record(
    'BK', 'v2_unattached_legacy_path', 'created|no_snapshot',
    COALESCE(v_result->>'status', '') || '|' ||
      CASE WHEN v_result ? 'running_target_snapshot' THEN 'snapshot' ELSE 'no_snapshot' END,
    NOT EXISTS (
      SELECT 1 FROM public.programme_occurrence_running_target_snapshots
      WHERE occurrence_id = v_occurrence
    ),
    v_result->>'status' = 'created'
      AND NOT (v_result ? 'running_target_snapshot'),
    v_result::TEXT
  );

  -- Plan Package v1 (the Bali publication shape) remains unchanged.
  PERFORM set_config('request.jwt.claim.sub', v_v1_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.enrol_athlete_in_private_programme_version(
    v_v1_version, 'Asia/Makassar', FALSE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT id INTO STRICT v_occurrence
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.create_or_resume_fixed_programme_occurrence_session(v_occurrence);
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record(
    'BK', 'v1_bali_shape_legacy_path', '1|created|no_snapshot',
    (SELECT package_schema_version::TEXT FROM public.programme_versions
      WHERE id = v_v1_version) || '|' || COALESCE(v_result->>'status', '') || '|' ||
      CASE WHEN v_result ? 'running_target_snapshot' THEN 'snapshot' ELSE 'no_snapshot' END,
    NOT EXISTS (
      SELECT 1 FROM public.programme_occurrence_running_target_snapshots
      WHERE occurrence_id = v_occurrence
    ),
    (SELECT package_schema_version FROM public.programme_versions
      WHERE id = v_v1_version) = 1
      AND v_result->>'status' = 'created'
      AND NOT (v_result ? 'running_target_snapshot'),
    v_result::TEXT
  );

  -- Frozen rows are insert-once and not client-readable or writable.
  BEGIN
    UPDATE public.programme_occurrence_running_target_snapshots
    SET snapshot = snapshot || '{"mutated":true}'::JSONB
    WHERE occurrence_id = v_calc_occurrence;
  EXCEPTION WHEN integrity_constraint_violation THEN
    v_failed := TRUE;
  END;
  SELECT snapshot INTO v_snapshot
  FROM public.programme_occurrence_running_target_snapshots
  WHERE occurrence_id = v_calc_occurrence;
  PERFORM sprint12_record(
    'BK', 'snapshot_immutable', 'true|identical',
    v_failed::TEXT || '|' ||
      CASE WHEN v_snapshot = v_original_snapshot THEN 'identical' ELSE 'changed' END,
    NULL, v_failed AND v_snapshot = v_original_snapshot, NULL
  );

  SELECT has_table_privilege(
    'authenticated', 'public.programme_occurrence_running_target_snapshots',
    'SELECT'
  ) INTO v_has_privilege;
  PERFORM sprint12_record(
    'BK', 'athlete_snapshot_table_denied', 'false', v_has_privilege::TEXT,
    NULL, NOT v_has_privilege, NULL
  );
  SELECT has_table_privilege(
    'service_role', 'public.programme_occurrence_running_target_snapshots',
    'INSERT'
  ) INTO v_has_privilege;
  PERFORM sprint12_record(
    'BK', 'service_role_direct_insert_denied', 'false', v_has_privilege::TEXT,
    NULL, NOT v_has_privilege, NULL
  );
  SELECT has_function_privilege(
    'authenticated',
    'public.cohort_build_running_target_snapshot_aggregate(jsonb,uuid,uuid,uuid,uuid,uuid,text,date,text,timestamptz)',
    'EXECUTE'
  ) INTO v_has_privilege;
  PERFORM sprint12_record(
    'BK', 'athlete_builder_denied', 'false', v_has_privilege::TEXT,
    NULL, NOT v_has_privilege, NULL
  );
  SELECT has_function_privilege(
    'authenticated',
    'public.create_or_resume_fixed_programme_occurrence_session(uuid)',
    'EXECUTE'
  ) INTO v_has_privilege;
  PERFORM sprint12_record(
    'BK', 'athlete_start_wrapper_preserved', 'true', v_has_privilege::TEXT,
    NULL, v_has_privilege, NULL
  );
  SELECT has_function_privilege(
    'anon',
    'public.create_or_resume_fixed_programme_occurrence_session(uuid)',
    'EXECUTE'
  ) INTO v_has_privilege;
  PERFORM sprint12_record(
    'BK', 'anon_start_wrapper_denied', 'false', v_has_privilege::TEXT,
    NULL, NOT v_has_privilege, NULL
  );
  SELECT has_function_privilege(
    'authenticated',
    'public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamptz)',
    'EXECUTE'
  ) INTO v_has_privilege;
  PERFORM sprint12_record(
    'BK', 'athlete_internal_start_denied', 'false', v_has_privilege::TEXT,
    NULL, NOT v_has_privilege, NULL
  );

  -- Leave an unstarted attached occurrence for the true concurrent gate.
  PERFORM set_config('request.jwt.claim.sub', v_concurrent_athlete::TEXT, TRUE);
  PERFORM set_config('role', 'authenticated', TRUE);
  v_result := public.enrol_athlete_in_private_programme_version(
    v_attached_version, 'Asia/Makassar', FALSE
  );
  v_assignment := (v_result->>'enrolment_id')::UUID;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT id INTO STRICT v_occurrence
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = v_assignment;
  INSERT INTO public.sprint12_gate_bk_concurrency_fixture(
    fixture_key, athlete_id, occurrence_id
  ) VALUES ('concurrency', v_concurrent_athlete, v_occurrence);
END $$;

SELECT gate, case_id, expected, actual, persisted_ok, pass, detail
FROM sprint12_gate_results
WHERE gate = 'BK'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
