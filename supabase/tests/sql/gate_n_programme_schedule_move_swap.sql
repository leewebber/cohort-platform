-- Sprint 1.7D Gate N — exact-preview Move/Swap apply, CAS, idempotency, RLS.
-- Requires helpers.sql. Uses auth.users + profiles + request.jwt.claim.sub.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-N-R1';
  v_protocol_b TEXT := 'PROT-GATE-N-R2';
  -- Distinct from Gate M lineages to avoid lineage/revision uniqueness clashes.
  v_lineage UUID := 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  v_lineage_b UUID := 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  v_hash TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_version UUID;
  v_athlete_a UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_athlete_b UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_enrol_a UUID;
  v_count INT;
  v_rev INT;
  v_rev_assign INT;
  v_date DATE;
  v_date_b DATE;
  v_started DATE;
  v_slot_a UUID;
  v_slot_b UUID;
  v_fp TEXT;
  v_fp_payload JSONB;
  v_idem TEXT := 'gate-n-move-idem-1';
  v_tz TEXT := 'Pacific/Auckland';
  v_cursor_week INT;
  v_cursor_day TEXT;
  v_cursor_order INT;
  v_has_exec BOOLEAN;
  v_op_count INT;
BEGIN
  DELETE FROM programme_assignments
  WHERE athlete_id IN (v_athlete_a, v_athlete_b);

  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate N Slot A');
  PERFORM sprint12_ensure_published_session(v_protocol_b, v_lineage_b, 1, 'Gate N Slot B');

  v_hash := sprint12_hash('gate-n-schedule');
  v_payload := sprint12_build_package('PROG-GATE-N-ELIG', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_version := (v_res->>'programme_version_id')::uuid;

  SELECT s.id INTO v_slot_a
  FROM programme_version_weeks w
  JOIN programme_version_days d ON d.week_id = w.id
  JOIN programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_version
  ORDER BY w.week_number, d.day_order, s.session_order
  LIMIT 1;

  IF NOT EXISTS (
    SELECT 1
    FROM programme_version_weeks w
    JOIN programme_version_days d ON d.week_id = w.id
    JOIN programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = v_version
      AND s.id IS DISTINCT FROM v_slot_a
  ) THEN
    INSERT INTO programme_version_days (id, week_id, day_key, day_order, day_type)
    SELECT gen_random_uuid(), w.id, 'day_2', 2, 'training'
    FROM programme_version_weeks w
    WHERE w.version_id = v_version
      AND NOT EXISTS (
        SELECT 1 FROM programme_version_days d
        WHERE d.week_id = w.id AND d.day_key = 'day_2'
      )
    LIMIT 1;

    INSERT INTO programme_version_session_slots (
      id, day_id, session_order, protocol_id, display_title
    )
    SELECT gen_random_uuid(), d.id, 1, v_protocol_b, 'Gate N Slot B'
    FROM programme_version_weeks w
    JOIN programme_version_days d ON d.week_id = w.id
    WHERE w.version_id = v_version
      AND d.day_key = 'day_2'
      AND NOT EXISTS (
        SELECT 1 FROM programme_version_session_slots s WHERE s.day_id = d.id
      )
    LIMIT 1;
  END IF;

  SELECT s.id INTO v_slot_b
  FROM programme_version_weeks w
  JOIN programme_version_days d ON d.week_id = w.id
  JOIN programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_version
    AND s.id IS DISTINCT FROM v_slot_a
  ORDER BY w.week_number, d.day_order, s.session_order
  LIMIT 1;

  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_version, 'gate-n');
  PERFORM public.approve_cohort_global_programme_version(v_version, 'gate-n');
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
     'gate-n-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
     'gate-n-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate N Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate N Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version, v_tz, FALSE
  );
  v_enrol_a := (v_res->>'enrolment_id')::uuid;
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, v_tz);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'materialise_a', 'materialised_or_already',
    v_res->>'status', NULL,
    (v_res->>'status') IN ('materialised', 'already_materialised'),
    v_res::text
  );

  SELECT started_at,
         current_week_number,
         current_day_key,
         current_slot_order
    INTO v_started, v_cursor_week, v_cursor_day, v_cursor_order
  FROM programme_assignments WHERE id = v_enrol_a;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.ensure_programme_schedule_projection(v_enrol_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'ensure_ready', 'ok',
    COALESCE(v_res->>'status', ''), NULL,
    (v_res->>'status') IN ('initialised', 'already_exists'),
    v_res::text
  );

  v_has_exec := has_function_privilege(
    'authenticated',
    'public.apply_programme_schedule_operation(jsonb)',
    'execute'
  );
  PERFORM sprint12_record(
    'N', 'apply_granted_authenticated', 'true', v_has_exec::text, NULL,
    v_has_exec IS TRUE, NULL
  );

  -- Conformance vector: Dart/PostgreSQL apply fingerprint parity.
  v_fp := public.cohort_scheduling_apply_fingerprint(
    '{
      "affected":[{
        "dayKey":"day_1",
        "originalDate":"2026-07-01",
        "originalDisposition":"scheduled",
        "programmedSessionKey":"psk-1",
        "proposedDate":"2026-07-05",
        "proposedDisposition":"scheduled",
        "protocolId":"protocol-1",
        "sessionOrder":0,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      }],
      "assignmentId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "collidingDates":[],
      "operation":{
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "targetDate":"2026-07-05",
        "type":"move"
      },
      "packageContentHash":"hash-conformance-1",
      "policyVersion":"programme.scheduling.policy.v1",
      "programmeVersionId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "scheduleRevision":0,
      "timezone":"Pacific/Auckland"
    }'::jsonb
  );
  PERFORM sprint12_record(
    'N', 'fingerprint_conformance_vector',
    '39d418875d9d57153fed1e8690f40021d72bf10803f5071e19b2d455984699c4',
    v_fp, NULL,
    v_fp = '39d418875d9d57153fed1e8690f40021d72bf10803f5071e19b2d455984699c4',
    NULL
  );

  -- Reject client-nominated projection payload.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', 'deadbeef',
      'idempotency_key', 'gate-n-forbidden-proj',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_started + 3, 'YYYY-MM-DD'),
      'projection', '{}'::jsonb
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'client_projection_forbidden',
    'client_nominated_projection_forbidden',
    v_res->>'code', NULL,
    v_res->>'code' = 'client_nominated_projection_forbidden',
    v_res::text
  );

  -- Push unsupported without mutation.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'push',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', 'x',
      'idempotency_key', 'gate-n-push'
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'push_unsupported', 'unsupported_operation',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'unsupported_operation',
    v_res::text
  );
  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'N', 'push_no_revision', '0', v_rev::text, NULL, v_rev = 0, NULL
  );

  -- Skip unsupported.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'skip',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', 'x',
      'idempotency_key', 'gate-n-skip'
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'skip_unsupported', 'unsupported_operation',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'unsupported_operation',
    v_res::text
  );

  SELECT scheduled_date INTO v_date
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;

  -- Build authoritative move fingerprint on server.
  v_fp_payload := jsonb_build_object(
    'affected', jsonb_build_array(
      jsonb_build_object(
        'dayKey', (SELECT day_key FROM programme_schedule_occurrences
                   WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a),
        'originalDate', to_char(v_date, 'YYYY-MM-DD'),
        'originalDisposition', 'scheduled',
        'programmedSessionKey', (SELECT programmed_session_key FROM programme_schedule_occurrences
                                 WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a),
        'proposedDate', to_char(v_started + 3, 'YYYY-MM-DD'),
        'proposedDisposition', 'scheduled',
        'protocolId', (SELECT protocol_id FROM programme_schedule_occurrences
                       WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a),
        'sessionOrder', (SELECT session_order FROM programme_schedule_occurrences
                         WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a),
        'sessionSlotId', v_slot_a::text,
        'weekNumber', (SELECT week_number FROM programme_schedule_occurrences
                       WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a)
      )
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', '[]'::jsonb,
    'operation', jsonb_build_object(
      'sessionSlotId', v_slot_a::text,
      'targetDate', to_char(v_started + 3, 'YYYY-MM-DD'),
      'type', 'move'
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 0,
    'timezone', v_tz
  );
  -- Recompute colliding dates after proposed move (may be empty).
  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_payload
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id = v_slot_a THEN v_started + 3
               ELSE o.scheduled_date
             END AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND o.disposition = 'scheduled'
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;
  v_fp_payload := jsonb_set(v_fp_payload, '{collidingDates}', v_payload);
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  -- Stale fingerprint fails closed.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', '0000000000000000000000000000000000000000000000000000000000000000',
      'idempotency_key', 'gate-n-bad-fp',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_started + 3, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'stale_fingerprint', 'stale_preview_fingerprint',
    v_res->>'code', NULL,
    v_res->>'code' = 'stale_preview_fingerprint',
    v_res::text
  );
  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'N', 'stale_fp_no_mutation', '0', v_rev::text, NULL, v_rev = 0, NULL
  );

  -- Valid Move apply.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', v_fp,
      'idempotency_key', v_idem,
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_started + 3, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'move_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );
  PERFORM sprint12_record(
    'N', 'move_revision', '1',
    v_res->>'schedule_revision', NULL,
    v_res->>'schedule_revision' = '1',
    NULL
  );

  SELECT scheduled_date INTO v_date
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'N', 'move_date_changed', to_char(v_started + 3, 'YYYY-MM-DD'),
    to_char(v_date, 'YYYY-MM-DD'), NULL,
    v_date = v_started + 3, NULL
  );

  SELECT p.schedule_revision, a.schedule_revision
    INTO v_rev, v_rev_assign
  FROM programme_schedule_projections p
  JOIN programme_assignments a ON a.id = p.assignment_id
  WHERE p.assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'N', 'revision_mirrors_equal', '1=1',
    v_rev::text || '=' || v_rev_assign::text, NULL,
    v_rev = 1 AND v_rev_assign = 1, NULL
  );

  SELECT COUNT(*) INTO v_op_count
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a
    AND operation_type = 'move'
    AND idempotency_key = v_idem;
  PERFORM sprint12_record(
    'N', 'move_op_log_one', '1', v_op_count::text, NULL, v_op_count = 1, NULL
  );

  -- Idempotent replay.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', v_fp,
      'idempotency_key', v_idem,
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_started + 3, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'idempotent_replay', 'already_applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'already_applied',
    v_res::text
  );
  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'N', 'idempotent_no_double_advance', '1', v_rev::text, NULL, v_rev = 1, NULL
  );

  -- Idempotency conflict on reused key with different fingerprint.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 1,
      'preview_fingerprint', 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      'idempotency_key', v_idem,
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_started + 4, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'idempotency_conflict', 'idempotency_key_conflict',
    v_res->>'code', NULL,
    v_res->>'code' = 'idempotency_key_conflict',
    v_res::text
  );

  -- Stale revision.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-n-stale-rev',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_started + 5, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'stale_revision', 'stale_schedule_revision',
    v_res->>'code', NULL,
    v_res->>'code' = 'stale_schedule_revision',
    v_res::text
  );

  -- Cross-athlete apply denied.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 1,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-n-cross',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_started + 6, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'cross_athlete_denied', 'assignment_not_found',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'assignment_not_found',
    v_res::text
  );

  -- Direct table mutation still denied.
  -- Clear any transaction-local RPC write flag left by prior apply calls.
  PERFORM set_config('cohort.allow_schedule_write', '', true);
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    UPDATE programme_schedule_occurrences
    SET scheduled_date = scheduled_date + 1
    WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM set_config('role', 'postgres', true);
    IF v_count > 0 THEN
      PERFORM sprint12_record('N', 'direct_date_update_denied', 'denied', 'allowed', NULL, FALSE, 'update succeeded');
    ELSE
      PERFORM sprint12_record('N', 'direct_date_update_denied', 'denied', 'denied', NULL, TRUE, '0 rows');
    END IF;
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('N', 'direct_date_update_denied', 'denied', 'denied', NULL, TRUE, NULL);
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('N', 'direct_date_update_denied', 'denied', SQLERRM, NULL, TRUE, NULL);
  END;

  BEGIN
    INSERT INTO programme_schedule_operations (
      assignment_id, athlete_id, operation_type, idempotency_key,
      result_revision, prior_snapshot
    ) VALUES (
      v_enrol_a, v_athlete_a, 'move', 'gate-n-direct-op', 99, '{}'::jsonb
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('N', 'direct_op_insert_denied', 'denied', 'allowed', NULL, FALSE, 'insert succeeded');
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('N', 'direct_op_insert_denied', 'denied', 'denied', NULL, TRUE, NULL);
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('N', 'direct_op_insert_denied', 'denied', SQLERRM, NULL, TRUE, NULL);
  END;

  -- Swap: exchange dates of slot A and B.
  SELECT scheduled_date INTO v_date
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  SELECT scheduled_date INTO v_date_b
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_b;

  v_fp_payload := (
    SELECT jsonb_build_object(
      'affected', (
        SELECT jsonb_agg(row_obj ORDER BY row_obj->>'sessionSlotId')
        FROM (
          SELECT jsonb_build_object(
            'dayKey', oa.day_key,
            'originalDate', to_char(oa.scheduled_date, 'YYYY-MM-DD'),
            'originalDisposition', oa.disposition,
            'programmedSessionKey', oa.programmed_session_key,
            'proposedDate', to_char(ob.scheduled_date, 'YYYY-MM-DD'),
            'proposedDisposition', oa.disposition,
            'protocolId', oa.protocol_id,
            'sessionOrder', oa.session_order,
            'sessionSlotId', oa.session_slot_id::text,
            'weekNumber', oa.week_number
          ) AS row_obj
          FROM programme_schedule_occurrences oa
          CROSS JOIN programme_schedule_occurrences ob
          WHERE oa.assignment_id = v_enrol_a AND oa.session_slot_id = v_slot_a
            AND ob.assignment_id = v_enrol_a AND ob.session_slot_id = v_slot_b
          UNION ALL
          SELECT jsonb_build_object(
            'dayKey', ob.day_key,
            'originalDate', to_char(ob.scheduled_date, 'YYYY-MM-DD'),
            'originalDisposition', ob.disposition,
            'programmedSessionKey', ob.programmed_session_key,
            'proposedDate', to_char(oa.scheduled_date, 'YYYY-MM-DD'),
            'proposedDisposition', ob.disposition,
            'protocolId', ob.protocol_id,
            'sessionOrder', ob.session_order,
            'sessionSlotId', ob.session_slot_id::text,
            'weekNumber', ob.week_number
          )
          FROM programme_schedule_occurrences oa
          CROSS JOIN programme_schedule_occurrences ob
          WHERE oa.assignment_id = v_enrol_a AND oa.session_slot_id = v_slot_a
            AND ob.assignment_id = v_enrol_a AND ob.session_slot_id = v_slot_b
        ) q
      ),
      'assignmentId', v_enrol_a::text,
      'collidingDates', '[]'::jsonb,
      'operation', jsonb_build_object(
        'sessionSlotIdA', v_slot_a::text,
        'sessionSlotIdB', v_slot_b::text,
        'type', 'swap'
      ),
      'packageContentHash', v_hash,
      'policyVersion', 'programme.scheduling.policy.v1',
      'programmeVersionId', v_version::text,
      'scheduleRevision', 1,
      'timezone', v_tz
    )
  );
  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_payload
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id = v_slot_a THEN v_date_b
               WHEN o.session_slot_id = v_slot_b THEN v_date
               ELSE o.scheduled_date
             END AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND o.disposition = 'scheduled'
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;
  v_fp_payload := jsonb_set(v_fp_payload, '{collidingDates}', v_payload);
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'swap',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 1,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-n-swap-1',
      'session_slot_id_a', v_slot_a,
      'session_slot_id_b', v_slot_b
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'N', 'swap_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  -- Pre-swap: v_date was A's date, v_date_b was B's date.
  PERFORM sprint12_record(
    'N', 'swap_a_has_former_b_date', 'true',
    (SELECT scheduled_date = v_date_b FROM programme_schedule_occurrences
     WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a)::text,
    NULL,
    (SELECT scheduled_date = v_date_b FROM programme_schedule_occurrences
     WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a),
    NULL
  );
  PERFORM sprint12_record(
    'N', 'swap_b_has_former_a_date', 'true',
    (SELECT scheduled_date = v_date FROM programme_schedule_occurrences
     WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_b)::text,
    NULL,
    (SELECT scheduled_date = v_date FROM programme_schedule_occurrences
     WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_b),
    NULL
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'N', 'swap_revision', '2', v_rev::text, NULL, v_rev = 2, NULL
  );

  -- Cursor unchanged.
  SELECT current_week_number = v_cursor_week
         AND current_day_key IS NOT DISTINCT FROM v_cursor_day
         AND current_slot_order = v_cursor_order
    INTO v_has_exec
  FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'N', 'cursor_untouched', 'true', v_has_exec::text, NULL, v_has_exec IS TRUE, NULL
  );

  -- Disposition still scheduled for both.
  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a
    AND session_slot_id IN (v_slot_a, v_slot_b)
    AND disposition = 'scheduled';
  PERFORM sprint12_record(
    'N', 'dispositions_unchanged', '2', v_count::text, NULL, v_count = 2, NULL
  );

  -- Unauthenticated apply denied.
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('role', 'anon', true);
  BEGIN
    v_res := public.apply_programme_schedule_operation(
      jsonb_build_object('operation_type', 'move')
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record(
      'N', 'unauthenticated_apply', 'authorization_failure',
      COALESCE(v_res->>'status', 'error'), NULL,
      (v_res->>'status') = 'authorization_failure'
        OR (v_res->>'code') IN ('not_authenticated', 'athlete_role_required'),
      v_res::text
    );
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'N', 'unauthenticated_apply', 'denied', 'denied', NULL, TRUE, NULL
      );
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'N', 'unauthenticated_apply', 'denied', SQLERRM, NULL, TRUE, NULL
      );
  END;
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results
WHERE gate = 'N'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
