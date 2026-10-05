-- Gate BH — Plan Package v2 canonical attestation and transactional publication.
TRUNCATE sprint12_gate_results;

CREATE TEMP TABLE gate_bh_canonical_fixture (canonical_text TEXT NOT NULL);
CREATE TEMP TABLE gate_bh_hash_fixture (expected_hash TEXT NOT NULL);
CREATE TEMP TABLE gate_bh_scope_cases (case_data JSONB NOT NULL);
\copy gate_bh_canonical_fixture FROM '/tmp/plan_package_v2.canonical.json'
\copy gate_bh_hash_fixture FROM '/tmp/plan_package_v2.sha256'
\copy gate_bh_scope_cases FROM '/tmp/authored_running_advisory_scope_cases.jsonl'

CREATE OR REPLACE FUNCTION pg_temp.gate_bh_scope_document(p_case JSONB)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
SET search_path = pg_temp
AS $$
  WITH attachments AS (
    SELECT jsonb_agg(
      jsonb_build_object(
        'attachment_id', 'TARGET-' || scope.ordinality::TEXT,
        'step_ids', scope.value,
        'policy', jsonb_build_object(
          'policy_id', 'POLICY-' || scope.ordinality::TEXT,
          'policy_version', 1,
          'method_id', 'PERCENT-BENCHMARK-SPEED',
          'method_version', 1,
          'benchmark_eligibility', jsonb_build_object(
            'cohort_completed_tests_eligible', TRUE,
            'manual_completed_tests_eligible', TRUE,
            'external_completed_tests_eligible', FALSE
          ),
          'freshness_local_civil_days', 90,
          'minimum_speed_basis_points', 8123,
          'maximum_speed_basis_points', 9345,
          'display_rounding', jsonb_build_object(
            'increment_milliseconds_per_kilometre', 1000,
            'direction', 'nearest'
          )
        )
      ) ORDER BY scope.ordinality
    ) AS value
    FROM jsonb_array_elements(p_case->'attachment_scopes')
      WITH ORDINALITY AS scope(value, ordinality)
  )
  SELECT jsonb_build_object(
    'schema_version', 1,
    'workout_id', 'RUN-SCOPE-FIXTURE',
    'step_ids', p_case->'step_ids',
    'advisory_attachments', attachments.value
  )
  FROM attachments;
$$;

CREATE OR REPLACE FUNCTION sprint12_build_v2_publication_payload(
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
  RETURN v_canonical
    || jsonb_build_object(
      'programme',
        (v_canonical->'programme')
          - 'library_scope'::TEXT
          - 'owner_type'::TEXT,
      'package_content_hash',
        encode(digest(convert_to(p_canonical_text, 'UTF8'), 'sha256'), 'hex'),
      'package_canonical_json', p_canonical_text,
      'imported_by', 'gate-bh',
      'publication_kind', 'private_exact_version',
      'programme_version_id', p_version_id,
      'library_scope', 'coach_private',
      'owner_id', p_owner_id,
      'protocol_graphs', jsonb_build_array(
        jsonb_build_object(
          'protocol_id', v_protocol,
          'revision_number', 1,
          'blocks', jsonb_build_array(
            jsonb_build_object(
              'position', 1,
              'block_type', 'conditioning',
              'title', 'Gate BH executable block',
              'content', '',
              'workout_format', 'steady_state',
              'timer_config', jsonb_build_object(
                'format', 'steady_state',
                'duration_seconds', 60
              ),
              'coach_notes', 'Disposable publication proof only',
              'performance_capture_mode', 'auto',
              'exercises', jsonb_build_array(
                jsonb_build_object(
                  'exercise_id', 'gate-bh-movement',
                  'position', 1,
                  'display_label_override', 'Gate BH movement',
                  'prescription', jsonb_build_object(
                    'sets', 1,
                    'reps', jsonb_build_object(
                      'type', 'exact',
                      'exact_reps', 1
                    )
                  )
                )
              )
            )
          )
        )
      )
    );
END;
$$;

DO $$
DECLARE
  v_canonical_text TEXT;
  v_expected_hash TEXT;
  v_owner UUID := 'b2000000-0000-4000-8000-000000000002';
  v_version UUID := 'b2000000-0000-4000-8000-000000000010';
  v_changed_bytes_version UUID := 'b2000000-0000-4000-8000-000000000011';
  v_changed_attachment_version UUID := 'b2000000-0000-4000-8000-000000000012';
  v_malformed_version UUID := 'b2000000-0000-4000-8000-000000000013';
  v_rollback_version UUID := 'b2000000-0000-4000-8000-000000000014';
  v_v1_version UUID := 'b2000000-0000-4000-8000-000000000015';
  v_overlap_version UUID := 'b2000000-0000-4000-8000-000000000016';
  v_payload JSONB;
  v_res JSONB;
  v_canonical JSONB;
  v_running JSONB;
  v_stored JSONB;
  v_hash TEXT;
  v_count INT;
  v_failed BOOLEAN := FALSE;
  v_has_exec BOOLEAN;
  v_case JSONB;
  v_actual_valid BOOLEAN;
  v_expected_valid BOOLEAN;
BEGIN
  SELECT canonical_text INTO STRICT v_canonical_text
  FROM gate_bh_canonical_fixture;
  SELECT trim(expected_hash) INTO STRICT v_expected_hash
  FROM gate_bh_hash_fixture;
  v_hash := encode(digest(convert_to(v_canonical_text, 'UTF8'), 'sha256'), 'hex');
  PERFORM sprint12_record(
    'BH', 'compiler_golden_hash', v_expected_hash, v_hash,
    NULL, v_hash = v_expected_hash, NULL
  );

  FOR v_case IN SELECT case_data FROM gate_bh_scope_cases
  LOOP
    v_expected_valid := (v_case->>'expected_valid')::BOOLEAN;
    v_actual_valid := public.cohort_authored_running_v1_is_valid(
      pg_temp.gate_bh_scope_document(v_case)
    );
    PERFORM sprint12_record(
      'BH', 'advisory_scope_' || (v_case->>'name'),
      v_expected_valid::TEXT, v_actual_valid::TEXT,
      NULL, v_actual_valid = v_expected_valid,
      pg_temp.gate_bh_scope_document(v_case)::TEXT
    );
  END LOOP;

  SELECT
    p.provolatile = 'i'
      AND p.prosecdef = FALSE
      AND p.proconfig = ARRAY['search_path=public, extensions, pg_temp']::TEXT[]
      AND pg_get_userbyid(p.proowner) = 'postgres'
      AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
      AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
      AND has_function_privilege('service_role', p.oid, 'EXECUTE')
  INTO v_has_exec
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'cohort_authored_running_v1_is_valid'
    AND pg_get_function_identity_arguments(p.oid) = 'document jsonb';
  PERFORM sprint12_record(
    'BH', 'advisory_scope_function_contract', 'true', v_has_exec::TEXT,
    NULL, v_has_exec, NULL
  );

  v_payload := sprint12_build_v2_publication_payload(
    v_canonical_text,
    v_version,
    v_owner
  );
  v_running := v_payload #> '{weeks,0,days,0,slots,0,authored_running_v1}';

  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT slot.authored_running_v1 INTO v_stored
  FROM public.programme_version_session_slots slot
  JOIN public.programme_version_days day ON day.id = slot.day_id
  JOIN public.programme_version_weeks week ON week.id = day.week_id
  WHERE week.version_id = v_version;
  PERFORM sprint12_record(
    'BH', 'valid_exact_canonical_publish', 'published', v_res->>'status',
    v_stored IS NOT DISTINCT FROM v_running,
    (v_res->>'status') = 'published'
      AND (v_res->>'package_content_hash') = v_expected_hash
      AND (v_res->>'package_schema_version') = '2'
      AND v_stored IS NOT DISTINCT FROM v_running
      AND EXISTS (
        SELECT 1 FROM public.programme_versions version
        WHERE version.id = v_version
          AND version.package_schema_version = 2
          AND version.package_content_hash = v_expected_hash
          AND version.lifecycle_status = 'published'
      ),
    v_res::TEXT
  );

  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_record(
    'BH', 'v2_idempotent', 'already_published', v_res->>'status',
    v_stored IS NOT DISTINCT FROM v_running,
    (v_res->>'status') = 'already_published',
    v_res::TEXT
  );

  BEGIN
    UPDATE public.programme_version_session_slots slot
    SET authored_running_v1 = jsonb_set(
      authored_running_v1,
      '{workout_id}',
      '"MUTATED"'::JSONB
    )
    FROM public.programme_version_days day,
         public.programme_version_weeks week
    WHERE slot.day_id = day.id
      AND day.week_id = week.id
      AND week.version_id = v_version;
  EXCEPTION WHEN integrity_constraint_violation THEN
    v_failed := TRUE;
  END;
  SELECT slot.authored_running_v1 INTO v_stored
  FROM public.programme_version_session_slots slot
  JOIN public.programme_version_days day ON day.id = slot.day_id
  JOIN public.programme_version_weeks week ON week.id = day.week_id
  WHERE week.version_id = v_version;
  PERFORM sprint12_record(
    'BH', 'published_slot_immutable', 'true', v_failed::TEXT,
    v_stored IS NOT DISTINCT FROM v_running,
    v_failed AND v_stored IS NOT DISTINCT FROM v_running,
    NULL
  );
  v_failed := FALSE;

  v_payload := sprint12_build_v2_publication_payload(
    v_canonical_text || E'\n',
    v_changed_bytes_version,
    v_owner
  ) || jsonb_build_object('package_content_hash', v_expected_hash);
  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count
  FROM public.programme_versions WHERE id = v_changed_bytes_version;
  PERFORM sprint12_record(
    'BH', 'changed_bytes_rejected', 'canonical_hash_mismatch', v_res->>'code',
    v_count = 0,
    (v_res->>'code') = 'canonical_hash_mismatch' AND v_count = 0,
    v_res::TEXT
  );

  v_payload := sprint12_build_v2_publication_payload(
    v_canonical_text,
    v_changed_attachment_version,
    v_owner
  );
  v_payload := jsonb_set(
    v_payload,
    '{weeks,0,days,0,slots,0,authored_running_v1,advisory_attachments,0,attachment_id}',
    '"CHANGED-ATTACHMENT"'::JSONB
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count
  FROM public.programme_versions WHERE id = v_changed_attachment_version;
  PERFORM sprint12_record(
    'BH', 'changed_attachment_rejected', 'canonical_hash_mismatch', v_res->>'code',
    v_count = 0,
    (v_res->>'code') = 'canonical_hash_mismatch' AND v_count = 0,
    v_res::TEXT
  );

  v_canonical := v_canonical_text::JSONB;
  v_canonical := jsonb_set(
    v_canonical,
    '{weeks,0,days,0,slots,0,authored_running_v1,step_ids}',
    '["bad step"]'::JSONB
  );
  v_payload := sprint12_build_v2_publication_payload(
    v_canonical::TEXT,
    v_malformed_version,
    v_owner
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count
  FROM public.programme_versions WHERE id = v_malformed_version;
  PERFORM sprint12_record(
    'BH', 'malformed_steps_rejected', 'invalid_authored_running_v1', v_res->>'code',
    v_count = 0,
    (v_res->>'code') = 'invalid_authored_running_v1' AND v_count = 0,
    v_res::TEXT
  );

  SELECT pg_temp.gate_bh_scope_document(case_data) INTO STRICT v_running
  FROM gate_bh_scope_cases
  WHERE case_data->>'name' = 'partial_overlap';
  v_canonical := v_canonical_text::JSONB;
  v_canonical := jsonb_set(
    v_canonical,
    '{weeks,0,days,0,slots,0,authored_running_v1}',
    v_running
  );
  v_payload := sprint12_build_v2_publication_payload(
    v_canonical::TEXT,
    v_overlap_version,
    v_owner
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count
  FROM public.programme_versions WHERE id = v_overlap_version;
  PERFORM sprint12_record(
    'BH', 'overlapping_advisory_scope_rejected',
    'invalid_authored_running_v1', v_res->>'code',
    v_count = 0,
    (v_res->>'code') = 'invalid_authored_running_v1' AND v_count = 0,
    v_res::TEXT
  );

  v_canonical := v_canonical_text::JSONB;
  v_canonical := jsonb_set(
    v_canonical,
    '{programme,lineage_code}',
    '"PROG-RUNNING-ROLLBACK"'::JSONB
  );
  v_canonical := jsonb_set(
    v_canonical,
    '{sessions,0,protocol_id}',
    '"PROT-RUN-ROLLBACK-R1"'::JSONB
  );
  v_canonical := jsonb_set(
    v_canonical,
    '{sessions,0,session_lineage_id}',
    '"b2000000-0000-4000-8000-000000000099"'::JSONB
  );
  v_payload := sprint12_build_v2_publication_payload(
    v_canonical::TEXT,
    v_rollback_version,
    v_owner
  );
  PERFORM sprint12_install_fail_trigger(
    'public.programme_version_session_slots'::REGCLASS,
    'gate_bh_forced_slot_failure'
  );
  BEGIN
    PERFORM set_config('role', 'service_role', TRUE);
    v_res := public.publish_private_exact_programme_version_v2(v_payload);
  EXCEPTION WHEN others THEN
    v_failed := TRUE;
  END;
  PERFORM set_config('role', 'postgres', TRUE);
  PERFORM sprint12_drop_fail_trigger(
    'public.programme_version_session_slots'::REGCLASS,
    'gate_bh_forced_slot_failure'
  );
  SELECT
    (SELECT count(*) FROM public.programme_versions WHERE id = v_rollback_version)
    + (SELECT count(*) FROM public.programme_lineages WHERE code = 'PROG-RUNNING-ROLLBACK')
    + (SELECT count(*) FROM public.performance_protocols WHERE protocol_id = 'PROT-RUN-ROLLBACK-R1')
    + (SELECT count(*) FROM public.session_lineages WHERE id = 'b2000000-0000-4000-8000-000000000099')
  INTO v_count;
  PERFORM sprint12_record(
    'BH', 'persistence_failure_full_rollback', 'true', v_failed::TEXT,
    v_count = 0,
    v_failed AND v_count = 0,
    'residue_count=' || v_count::TEXT
  );

  v_payload := sprint12_build_package(
    'PROG-GATE-BH-V1',
    1,
    sprint12_hash('gate-bh-v1'),
    'PROT-GATE-BH-V1-R1',
    'b2000000-0000-4000-8000-000000000088'
  ) || jsonb_build_object(
    'publication_kind', 'private_exact_version',
    'programme_version_id', v_v1_version,
    'library_scope', 'coach_private',
    'owner_id', v_owner
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count
  FROM public.programme_version_session_slots slot
  JOIN public.programme_version_days day ON day.id = slot.day_id
  JOIN public.programme_version_weeks week ON week.id = day.week_id
  WHERE week.version_id = v_v1_version
    AND slot.authored_running_v1 IS NULL;
  PERFORM sprint12_record(
    'BH', 'v1_publication_unchanged', 'published', v_res->>'status',
    v_count = 1,
    (v_res->>'status') = 'published'
      AND v_count = 1
      AND EXISTS (
        SELECT 1 FROM public.programme_versions
        WHERE id = v_v1_version AND package_schema_version = 1
      ),
    v_res::TEXT
  );

  SELECT has_function_privilege(
    'anon',
    'public.publish_private_exact_programme_version_v2(jsonb)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BH', 'anon_v2_publish_denied', 'false', v_has_exec::TEXT,
    NULL, NOT v_has_exec, NULL
  );
  SELECT has_function_privilege(
    'authenticated',
    'public.publish_private_exact_programme_version_v2(jsonb)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BH', 'athlete_v2_publish_denied', 'false', v_has_exec::TEXT,
    NULL, NOT v_has_exec, NULL
  );
  SELECT has_function_privilege(
    'service_role',
    'public.publish_private_exact_programme_version_v2(jsonb)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BH', 'service_role_v2_publish_allowed', 'true', v_has_exec::TEXT,
    NULL, v_has_exec, NULL
  );
END $$;

SELECT *
FROM sprint12_gate_results
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
