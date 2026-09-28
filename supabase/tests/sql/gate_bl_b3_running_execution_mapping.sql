-- Gate BL — B3 slice 1 hash-attested exact executable-block mapping.
TRUNCATE sprint12_gate_results;

CREATE TEMP TABLE gate_bl_canonical_fixture (canonical_text TEXT NOT NULL);
CREATE TEMP TABLE gate_bl_hash_fixture (expected_hash TEXT NOT NULL);
\copy gate_bl_canonical_fixture FROM '/tmp/plan_package_v2_b3.canonical.json'
\copy gate_bl_hash_fixture FROM '/tmp/plan_package_v2_b3.sha256'

CREATE OR REPLACE FUNCTION sprint12_build_b3_publication_payload(
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
    'programme', (v_canonical->'programme') - 'library_scope'::TEXT - 'owner_type'::TEXT,
    'package_content_hash', encode(digest(convert_to(p_canonical_text, 'UTF8'), 'sha256'), 'hex'),
    'package_canonical_json', p_canonical_text,
    'imported_by', 'gate-bl',
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
        'title', 'Non-authoritative display title',
        'content', '',
        'workout_format', 'steady_state',
        'timer_config', jsonb_build_object(
          'format', 'steady_state',
          'duration_seconds', 60
        ),
        'coach_notes', 'Disposable B3 mapping proof only',
        'performance_capture_mode', 'auto',
        'exercises', '[]'::JSONB
      ))
    ))
  );
END;
$$;

DO $$
DECLARE
  v_canonical_text TEXT;
  v_expected_hash TEXT;
  v_owner UUID := 'b3000000-0000-4000-8000-000000000002';
  v_version UUID := 'b3000000-0000-4000-8000-000000000010';
  v_bad_hash_version UUID := 'b3000000-0000-4000-8000-000000000011';
  v_bad_scope_version UUID := 'b3000000-0000-4000-8000-000000000012';
  v_payload JSONB;
  v_mutated JSONB;
  v_res JSONB;
  v_stored JSONB;
  v_count INT;
  v_failed BOOLEAN := FALSE;
  v_has_exec BOOLEAN;
BEGIN
  SELECT canonical_text INTO STRICT v_canonical_text FROM gate_bl_canonical_fixture;
  SELECT trim(expected_hash) INTO STRICT v_expected_hash FROM gate_bl_hash_fixture;
  v_payload := sprint12_build_b3_publication_payload(v_canonical_text, v_version, v_owner);

  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT slot.authored_running_v1 INTO v_stored
  FROM public.programme_version_session_slots slot
  JOIN public.programme_version_days day ON day.id = slot.day_id
  JOIN public.programme_version_weeks week ON week.id = day.week_id
  WHERE week.version_id = v_version;
  PERFORM sprint12_record(
    'BL', 'exact_block_mapping_published', 'published', v_res->>'status',
    v_stored#>>'{executable_step_bindings,0,session_block_id}' =
      '2d8f9c46-60dc-422b-8d0e-4d94028617ca',
    v_res->>'status' = 'published'
      AND v_res->>'package_content_hash' = v_expected_hash
      AND public.cohort_running_execution_mapping_matches_protocol(
        v_stored, 'PROT-RUN-A-R1'
      ),
    v_res::TEXT
  );

  v_mutated := v_canonical_text::JSONB;
  v_mutated := jsonb_set(
    v_mutated,
    '{weeks,0,days,0,slots,0,authored_running_v1,execution_mapping_sha256}',
    to_jsonb(repeat('0', 64))
  );
  v_payload := sprint12_build_b3_publication_payload(
    v_mutated::TEXT,
    v_bad_hash_version,
    v_owner
  );
  PERFORM set_config('role', 'service_role', TRUE);
  v_res := public.publish_private_exact_programme_version_v2(v_payload);
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count FROM public.programme_versions WHERE id = v_bad_hash_version;
  PERFORM sprint12_record(
    'BL', 'mapping_hash_tamper_rejected', 'invalid_authored_running_v1', v_res->>'code',
    v_count = 0,
    v_res->>'code' = 'invalid_authored_running_v1' AND v_count = 0,
    v_res::TEXT
  );

  v_mutated := v_canonical_text::JSONB;
  v_mutated := jsonb_set(
    v_mutated,
    '{programme,lineage_code}',
    '"PROG-RUNNING-B3-BAD-SCOPE"'::JSONB
  );
  v_mutated := jsonb_set(
    v_mutated,
    '{weeks,0,days,0,slots,0,authored_running_v1,executable_step_bindings,0,session_block_id}',
    '"2d8f9c46-60dc-422b-8d0e-4d94028617cb"'::JSONB
  );
  v_mutated := jsonb_set(
    v_mutated,
    '{weeks,0,days,0,slots,0,authored_running_v1,execution_mapping_sha256}',
    to_jsonb(encode(digest(convert_to(
      'cohort.running_execution_mapping.v1|workout_id=rw1:p:7e50ec7208a5dd0f'
      || '|step_id=rw1:p:7e50ec7208a5dd0f:s:0,session_block_id=2d8f9c46-60dc-422b-8d0e-4d94028617cb',
      'UTF8'
    ), 'sha256'), 'hex'))
  );
  v_payload := sprint12_build_b3_publication_payload(
    v_mutated::TEXT,
    v_bad_scope_version,
    v_owner
  );
  BEGIN
    PERFORM set_config('role', 'service_role', TRUE);
    v_res := public.publish_private_exact_programme_version_v2(v_payload);
  EXCEPTION WHEN integrity_constraint_violation THEN
    v_failed := TRUE;
  END;
  PERFORM set_config('role', 'postgres', TRUE);
  SELECT count(*) INTO v_count FROM public.programme_versions WHERE id = v_bad_scope_version;
  PERFORM sprint12_record(
    'BL', 'nonexistent_block_mapping_rolls_back', 'true', v_failed::TEXT,
    v_count = 0,
    v_failed AND v_count = 0,
    NULL
  );

  SELECT has_function_privilege(
    'anon',
    'public.cohort_running_execution_mapping_matches_protocol(jsonb,text)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BL', 'anon_mapping_validator_denied', 'false', v_has_exec::TEXT,
    NULL, NOT v_has_exec, NULL
  );
  SELECT has_function_privilege(
    'authenticated',
    'public.cohort_running_execution_mapping_matches_protocol(jsonb,text)',
    'EXECUTE'
  ) INTO v_has_exec;
  PERFORM sprint12_record(
    'BL', 'athlete_mapping_validator_denied', 'false', v_has_exec::TEXT,
    NULL, NOT v_has_exec, NULL
  );
END $$;

SELECT * FROM sprint12_gate_results ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
