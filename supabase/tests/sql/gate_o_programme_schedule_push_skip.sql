-- Sprint 1.7E Gate O — Push/Skip apply, cursor transition, fingerprint parity, RLS.
-- Requires helpers.sql. Uses auth.users + profiles + request.jwt.claim.sub.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-O-R1';
  v_protocol_b TEXT := 'PROT-GATE-O-R2';
  -- Distinct from Gate N lineages to avoid lineage/revision uniqueness clashes.
  v_lineage UUID := 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  v_lineage_b UUID := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  v_hash TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_version UUID;
  v_athlete_a UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_athlete_b UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_enrol_a UUID;
  v_count INT;
  v_rev INT;
  v_started DATE;
  v_slot_a UUID;
  v_slot_b UUID;
  v_fp TEXT;
  v_fp_payload JSONB;
  v_idem TEXT := 'gate-o-push-idem-1';
  v_tz TEXT := 'Pacific/Auckland';
  v_cursor_week INT;
  v_cursor_day TEXT;
  v_cursor_order INT;
  v_has_exec BOOLEAN;
  v_date_before DATE;
  v_date_after DATE;
  v_next_week INT;
  v_next_day TEXT;
  v_next_order INT;
  v_disposition TEXT;
BEGIN
  DELETE FROM programme_assignments
  WHERE athlete_id IN (v_athlete_a, v_athlete_b);

  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate O Slot A');
  PERFORM sprint12_ensure_published_session(v_protocol_b, v_lineage_b, 1, 'Gate O Slot B');

  v_hash := sprint12_hash('gate-o-schedule');
  v_payload := sprint12_build_package('PROG-GATE-O-ELIG', 1, v_hash, v_protocol, v_lineage);
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
    SELECT gen_random_uuid(), d.id, 1, v_protocol_b, 'Gate O Slot B'
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
  PERFORM public.publish_cohort_global_programme_version(v_version, 'gate-o');
  PERFORM public.approve_cohort_global_programme_version(v_version, 'gate-o');
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
     'gate-o-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
     'gate-o-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate O Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate O Athlete B', TRUE, FALSE)
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
    'O', 'materialise_a', 'materialised_or_already',
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
    'O', 'ensure_ready', 'ok',
    COALESCE(v_res->>'status', ''), NULL,
    (v_res->>'status') IN ('initialised', 'already_exists'),
    v_res::text
  );

  -- Conformance vector: Push apply fingerprint (no cursor keys).
  v_fp := public.cohort_scheduling_apply_fingerprint(
    '{
      "affected":[{
        "dayKey":"day_1",
        "originalDate":"2026-07-01",
        "originalDisposition":"scheduled",
        "programmedSessionKey":"psk-push-1",
        "proposedDate":"2026-07-03",
        "proposedDisposition":"scheduled",
        "protocolId":"protocol-push-1",
        "sessionOrder":1,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      }],
      "assignmentId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "collidingDates":[],
      "operation":{
        "type":"push",
        "fromSessionSlotId":"11111111-1111-4111-8111-111111111111",
        "dayDelta":2
      },
      "packageContentHash":"hash-conformance-push",
      "policyVersion":"programme.scheduling.policy.v1",
      "programmeVersionId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "scheduleRevision":0,
      "timezone":"Pacific/Auckland"
    }'::jsonb
  );
  PERFORM sprint12_record(
    'O', 'fingerprint_push_vector',
    '4b2dfec57b1db700813029778f717734c0f6d7a0f12130274dfc11b09a973a3a',
    v_fp, NULL,
    v_fp = '4b2dfec57b1db700813029778f717734c0f6d7a0f12130274dfc11b09a973a3a',
    NULL
  );

  -- Conformance vector: Skip apply fingerprint (cursor before/after bound).
  v_fp := public.cohort_scheduling_apply_fingerprint(
    '{
      "affected":[{
        "dayKey":"day_1",
        "originalDate":"2026-07-01",
        "originalDisposition":"scheduled",
        "programmedSessionKey":"psk-skip-1",
        "proposedDate":"2026-07-01",
        "proposedDisposition":"skipped",
        "protocolId":"protocol-skip-1",
        "sessionOrder":1,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      }],
      "assignmentId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "collidingDates":[],
      "cursorAfter":{
        "dayKey":"day_2",
        "sessionOrder":1,
        "sessionSlotId":"22222222-2222-4222-8222-222222222222",
        "weekNumber":1
      },
      "cursorBefore":{
        "dayKey":"day_1",
        "sessionOrder":1,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      },
      "operation":{
        "type":"skip",
        "sessionSlotId":"11111111-1111-4111-8111-111111111111"
      },
      "packageContentHash":"hash-conformance-skip",
      "policyVersion":"programme.scheduling.policy.v1",
      "programmeVersionId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "scheduleRevision":0,
      "timezone":"Pacific/Auckland"
    }'::jsonb
  );
  PERFORM sprint12_record(
    'O', 'fingerprint_skip_vector',
    '60ca198c39d2625ac882b4a7d6667e2a305be1b0abfa5bff2c759e4a96a4f162',
    v_fp, NULL,
    v_fp = '60ca198c39d2625ac882b4a7d6667e2a305be1b0abfa5bff2c759e4a96a4f162',
    NULL
  );

  -- Undo without operation_id is malformed and must not mutate (Undo owned by Gate P).
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', 'x',
      'idempotency_key', 'gate-o-undo'
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'O', 'undo_requires_operation_id', 'malformed_request',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'malformed_request',
    v_res::text
  );
  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'O', 'undo_no_revision', '0', v_rev::text, NULL, v_rev = 0, NULL
  );

  -- Build authoritative Push fingerprint from live projection.
  SELECT scheduled_date INTO v_date_before
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT COALESCE(
        jsonb_agg(row_obj ORDER BY row_obj->>'sessionSlotId'),
        '[]'::jsonb
      )
      FROM (
        SELECT jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(o.scheduled_date + 2, 'YYYY-MM-DD'),
          'proposedDisposition', o.disposition,
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        ) AS row_obj
        FROM programme_schedule_occurrences o
        WHERE o.assignment_id = v_enrol_a
          AND o.disposition = 'scheduled'
          AND o.session_slot_id IN (v_slot_a, v_slot_b)
      ) q
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', '[]'::jsonb,
    'operation', jsonb_build_object(
      'type', 'push',
      'fromSessionSlotId', v_slot_a::text,
      'dayDelta', 2
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 0,
    'timezone', v_tz
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
               WHEN o.disposition = 'scheduled'
                 AND o.session_slot_id IN (v_slot_a, v_slot_b)
               THEN o.scheduled_date + 2
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

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'push',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 0,
      'preview_fingerprint', v_fp,
      'idempotency_key', v_idem,
      'session_slot_id', v_slot_a,
      'day_delta', 2
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'O', 'push_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT scheduled_date INTO v_date_after
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'O', 'push_date_shifted', to_char(v_date_before + 2, 'YYYY-MM-DD'),
    to_char(v_date_after, 'YYYY-MM-DD'), NULL,
    v_date_after = v_date_before + 2, NULL
  );

  SELECT current_week_number = v_cursor_week
         AND current_day_key IS NOT DISTINCT FROM v_cursor_day
         AND current_slot_order = v_cursor_order
    INTO v_has_exec
  FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'O', 'push_cursor_untouched', 'true', v_has_exec::text, NULL,
    v_has_exec IS TRUE, NULL
  );

  SELECT week_number, day_key, session_order
    INTO v_next_week, v_next_day, v_next_order
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a
    AND session_slot_id = v_slot_b;

  v_fp_payload := jsonb_build_object(
    'affected', jsonb_build_array(
      jsonb_build_object(
        'dayKey', (SELECT day_key FROM programme_schedule_occurrences
                   WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a),
        'originalDate', to_char((SELECT scheduled_date FROM programme_schedule_occurrences
                                 WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a), 'YYYY-MM-DD'),
        'originalDisposition', 'scheduled',
        'programmedSessionKey', (SELECT programmed_session_key FROM programme_schedule_occurrences
                                 WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a),
        'proposedDate', to_char((SELECT scheduled_date FROM programme_schedule_occurrences
                                 WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a), 'YYYY-MM-DD'),
        'proposedDisposition', 'skipped',
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
    'cursorBefore', jsonb_build_object(
      'dayKey', v_cursor_day,
      'sessionOrder', v_cursor_order,
      'sessionSlotId', v_slot_a::text,
      'weekNumber', v_cursor_week
    ),
    'cursorAfter', jsonb_build_object(
      'dayKey', v_next_day,
      'sessionOrder', v_next_order,
      'sessionSlotId', v_slot_b::text,
      'weekNumber', v_next_week
    ),
    'operation', jsonb_build_object(
      'type', 'skip',
      'sessionSlotId', v_slot_a::text
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 1,
    'timezone', v_tz
  );
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'skip',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 1,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-o-skip-1',
      'session_slot_id', v_slot_a
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'O', 'skip_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT current_week_number, current_day_key, current_slot_order
    INTO v_cursor_week, v_cursor_day, v_cursor_order
  FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'O', 'skip_cursor_advanced', v_next_week::text || '/' || v_next_day || '/' || v_next_order::text,
    v_cursor_week::text || '/' || v_cursor_day || '/' || v_cursor_order::text, NULL,
    v_cursor_week = v_next_week
      AND v_cursor_day IS NOT DISTINCT FROM v_next_day
      AND v_cursor_order = v_next_order,
    NULL
  );

  SELECT disposition INTO v_disposition
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'O', 'skip_disposition', 'skipped',
    v_disposition, NULL,
    v_disposition = 'skipped',
    NULL
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_slot_outcomes
  WHERE assignment_id = v_enrol_a
    AND session_slot_id = v_slot_a
    AND outcome_status = 'skipped';
  PERFORM sprint12_record(
    'O', 'skip_outcome_written', '1', v_count::text, NULL, v_count = 1, NULL
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_slot_outcomes o
  JOIN training_session_records r ON r.record_id = o.completion_record_id
  WHERE o.assignment_id = v_enrol_a
    AND o.session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'O', 'skip_no_completion_rows', '0', v_count::text, NULL, v_count = 0, NULL
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_slot_outcomes
  WHERE assignment_id = v_enrol_a
    AND session_slot_id = v_slot_a
    AND training_session_id IS NOT NULL;
  PERFORM sprint12_record(
    'O', 'skip_no_training_session_id', '0', v_count::text, NULL, v_count = 0, NULL
  );

  -- Cross-athlete apply denied.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'skip',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 2,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-o-cross',
      'session_slot_id', v_slot_b
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'O', 'cross_athlete_denied', 'assignment_not_found',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'assignment_not_found',
    v_res::text
  );

  -- Direct cursor update denied without RPC GUC.
  PERFORM set_config('cohort.allow_materialisation_write', '', true);
  PERFORM set_config('cohort.allow_schedule_write', '', true);
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    UPDATE programme_assignments
    SET current_week_number = current_week_number + 1
    WHERE id = v_enrol_a;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM set_config('role', 'postgres', true);
    IF v_count > 0 THEN
      PERFORM sprint12_record(
        'O', 'direct_cursor_update_denied', 'denied', 'allowed', NULL, FALSE,
        'update succeeded'
      );
    ELSE
      PERFORM sprint12_record(
        'O', 'direct_cursor_update_denied', 'denied', 'denied', NULL, TRUE,
        '0 rows'
      );
    END IF;
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'O', 'direct_cursor_update_denied', 'denied', 'denied', NULL, TRUE, NULL
      );
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'O', 'direct_cursor_update_denied', 'denied', SQLERRM, NULL, TRUE, NULL
      );
  END;
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results
WHERE gate = 'O'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
