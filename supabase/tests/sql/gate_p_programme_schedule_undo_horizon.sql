-- Sprint 1.7F Gate P — Scheduling horizon bound, one-level Undo, inverse
-- snapshot completeness, undo invalidation, fingerprint parity, RLS.
-- Requires helpers.sql. Uses auth.users + profiles + request.jwt.claim.sub.
--
-- Conformance fingerprints published for Dart parity (canonical JSON, sha256):
--   undo (move inverse)  d5d7aeaf1a41d957f77ed9b29dca70446f240e18f29f445adcf56e799cab9bb5
--   undo (skip inverse)  befab0de8d00747f873bc135e570c11a43731059f2ff38c893c2286be5c5a5c7
--   move + horizon       6dafec7ad0b1091acf9ea41743fe23292a11dfdec8f344e70855386fbb993f5f
-- Sprint 1.7D/1.7E vectors 39d41887 / 4b2dfec5 / 60ca198c remain unchanged
-- because a NULL scheduling_horizon_end contributes no fingerprint key.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-P-R1';
  v_protocol_b TEXT := 'PROT-GATE-P-R2';
  -- Distinct from Gates M/N/O lineages to avoid lineage/revision uniqueness clashes.
  v_lineage UUID := 'f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1';
  v_lineage_b UUID := 'f2f2f2f2-f2f2-4f2f-8f2f-f2f2f2f2f2f2';
  v_hash TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_version UUID;
  -- Distinct fixture athletes from Gate N/O.
  v_athlete_a UUID := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  v_athlete_b UUID := 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  v_enrol_a UUID;
  v_count INT;
  v_rev INT;
  v_started DATE;
  v_slot_a UUID;
  v_slot_b UUID;
  v_fp TEXT;
  v_fp_payload JSONB;
  v_tz TEXT := 'Pacific/Auckland';
  v_cursor_week INT;
  v_cursor_day TEXT;
  v_cursor_order INT;
  v_next_week INT;
  v_next_day TEXT;
  v_next_order INT;
  v_horizon DATE;
  v_date_pre DATE;
  v_date_push DATE;
  v_date_move DATE;
  v_date_slot_b DATE;
  v_push_op UUID;
  v_move_op UUID;
  v_undo_op UUID;
  v_skip_op UUID;
  v_move2_op UUID;
  v_legacy_op UUID;
  v_snapshot JSONB;
  v_collisions JSONB;
  v_flag BOOLEAN;
  v_disposition TEXT;
BEGIN
  DELETE FROM programme_assignments
  WHERE athlete_id IN (v_athlete_a, v_athlete_b);

  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate P Slot A');
  PERFORM sprint12_ensure_published_session(v_protocol_b, v_lineage_b, 1, 'Gate P Slot B');

  v_hash := sprint12_hash('gate-p-schedule');
  v_payload := sprint12_build_package('PROG-GATE-P-ELIG', 1, v_hash, v_protocol, v_lineage);
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
    SELECT gen_random_uuid(), d.id, 1, v_protocol_b, 'Gate P Slot B'
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
  PERFORM public.publish_cohort_global_programme_version(v_version, 'gate-p');
  PERFORM public.approve_cohort_global_programme_version(v_version, 'gate-p');
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
     'gate-p-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
     'gate-p-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate P Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate P Athlete B', TRUE, FALSE)
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
    'P', 'materialise_a', 'materialised_or_already',
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
    'P', 'ensure_ready', 'ok',
    COALESCE(v_res->>'status', ''), NULL,
    (v_res->>'status') IN ('initialised', 'already_exists'),
    v_res::text
  );

  -- -------------------------------------------------------------------------
  -- Horizon column presence and explicit unbounded default
  -- -------------------------------------------------------------------------
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'programme_schedule_projections'
    AND column_name = 'scheduling_horizon_end';
  PERFORM sprint12_record(
    'P', 'horizon_column_exists', '1', v_count::text, NULL, v_count = 1, NULL
  );

  SELECT scheduling_horizon_end INTO v_horizon
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'horizon_null_after_ensure', 'null',
    COALESCE(v_horizon::text, 'null'), NULL,
    v_horizon IS NULL, NULL
  );

  v_res := public.cohort_programme_schedule_projection_json(v_enrol_a);
  PERFORM sprint12_record(
    'P', 'projection_json_exposes_horizon', 'true',
    (v_res ? 'scheduling_horizon_end')::text, NULL,
    (v_res ? 'scheduling_horizon_end')
      AND jsonb_typeof(v_res->'scheduling_horizon_end') = 'null',
    NULL
  );

  -- -------------------------------------------------------------------------
  -- Conformance vectors (Dart parity)
  -- -------------------------------------------------------------------------
  v_fp := public.cohort_scheduling_apply_fingerprint(
    '{
      "affected":[{
        "dayKey":"day_1",
        "originalDate":"2026-07-05",
        "originalDisposition":"scheduled",
        "programmedSessionKey":"psk-undo-move-1",
        "proposedDate":"2026-07-01",
        "proposedDisposition":"scheduled",
        "protocolId":"protocol-undo-move-1",
        "sessionOrder":1,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      }],
      "assignmentId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "collidingDates":[],
      "operation":{
        "type":"undo",
        "operationId":"33333333-3333-4333-8333-333333333333"
      },
      "packageContentHash":"hash-conformance-undo-move",
      "policyVersion":"programme.scheduling.policy.v1",
      "programmeVersionId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "scheduleRevision":1,
      "timezone":"Pacific/Auckland"
    }'::jsonb
  );
  PERFORM sprint12_record(
    'P', 'fingerprint_undo_move_vector',
    'd5d7aeaf1a41d957f77ed9b29dca70446f240e18f29f445adcf56e799cab9bb5',
    v_fp, NULL,
    v_fp = 'd5d7aeaf1a41d957f77ed9b29dca70446f240e18f29f445adcf56e799cab9bb5',
    NULL
  );

  v_fp := public.cohort_scheduling_apply_fingerprint(
    '{
      "affected":[{
        "dayKey":"day_1",
        "originalDate":"2026-07-01",
        "originalDisposition":"skipped",
        "programmedSessionKey":"psk-undo-skip-1",
        "proposedDate":"2026-07-01",
        "proposedDisposition":"scheduled",
        "protocolId":"protocol-undo-skip-1",
        "sessionOrder":1,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      }],
      "assignmentId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "collidingDates":[],
      "cursorAfter":{
        "dayKey":"day_1",
        "sessionOrder":1,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      },
      "cursorBefore":{
        "dayKey":"day_2",
        "sessionOrder":1,
        "sessionSlotId":"22222222-2222-4222-8222-222222222222",
        "weekNumber":1
      },
      "operation":{
        "type":"undo",
        "operationId":"33333333-3333-4333-8333-333333333333"
      },
      "packageContentHash":"hash-conformance-undo-skip",
      "policyVersion":"programme.scheduling.policy.v1",
      "programmeVersionId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "scheduleRevision":2,
      "timezone":"Pacific/Auckland"
    }'::jsonb
  );
  PERFORM sprint12_record(
    'P', 'fingerprint_undo_skip_vector',
    'befab0de8d00747f873bc135e570c11a43731059f2ff38c893c2286be5c5a5c7',
    v_fp, NULL,
    v_fp = 'befab0de8d00747f873bc135e570c11a43731059f2ff38c893c2286be5c5a5c7',
    NULL
  );

  v_fp := public.cohort_scheduling_apply_fingerprint(
    '{
      "affected":[{
        "dayKey":"day_1",
        "originalDate":"2026-07-01",
        "originalDisposition":"scheduled",
        "programmedSessionKey":"psk-horizon-1",
        "proposedDate":"2026-07-31",
        "proposedDisposition":"scheduled",
        "protocolId":"protocol-horizon-1",
        "sessionOrder":1,
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "weekNumber":1
      }],
      "assignmentId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "collidingDates":[],
      "operation":{
        "type":"move",
        "sessionSlotId":"11111111-1111-4111-8111-111111111111",
        "targetDate":"2026-07-31"
      },
      "packageContentHash":"hash-conformance-horizon-move",
      "policyVersion":"programme.scheduling.policy.v1",
      "programmeVersionId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      "scheduleRevision":0,
      "schedulingHorizonEnd":"2026-07-31",
      "timezone":"Pacific/Auckland"
    }'::jsonb
  );
  PERFORM sprint12_record(
    'P', 'fingerprint_move_horizon_vector',
    '6dafec7ad0b1091acf9ea41743fe23292a11dfdec8f344e70855386fbb993f5f',
    v_fp, NULL,
    v_fp = '6dafec7ad0b1091acf9ea41743fe23292a11dfdec8f344e70855386fbb993f5f',
    NULL
  );

  -- -------------------------------------------------------------------------
  -- Push under a NULL horizon still applies (1.7E behaviour preserved)
  -- -------------------------------------------------------------------------
  SELECT scheduled_date INTO v_date_pre
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
  INTO v_collisions
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id IN (v_slot_a, v_slot_b)
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
  v_fp_payload := jsonb_set(v_fp_payload, '{collidingDates}', v_collisions);
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
      'idempotency_key', 'gate-p-push-1',
      'session_slot_id', v_slot_a,
      'day_delta', 2
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'push_null_horizon_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT scheduled_date INTO v_date_push
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'P', 'push_date_shifted', to_char(v_date_pre + 2, 'YYYY-MM-DD'),
    to_char(v_date_push, 'YYYY-MM-DD'), NULL,
    v_date_push = v_date_pre + 2, NULL
  );

  SELECT id INTO v_push_op
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a AND operation_type = 'push'
  ORDER BY operated_at DESC LIMIT 1;

  -- -------------------------------------------------------------------------
  -- Move at revision 1 invalidates the previously undoable Push
  -- -------------------------------------------------------------------------
  v_date_move := v_date_push + 10;

  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_collisions
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id = v_slot_a THEN v_date_move
               ELSE o.scheduled_date
             END AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND o.disposition = 'scheduled'
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(v_date_move, 'YYYY-MM-DD'),
          'proposedDisposition', o.disposition,
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        )
      )
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a AND o.session_slot_id = v_slot_a
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', v_collisions,
    'operation', jsonb_build_object(
      'sessionSlotId', v_slot_a::text,
      'targetDate', to_char(v_date_move, 'YYYY-MM-DD'),
      'type', 'move'
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
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 1,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-p-move-1',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_date_move, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'move_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT undo_invalidated_at IS NOT NULL INTO v_flag
  FROM programme_schedule_operations WHERE id = v_push_op;
  PERFORM sprint12_record(
    'P', 'previous_undoable_invalidated', 'true',
    COALESCE(v_flag::text, 'null'), NULL,
    v_flag IS TRUE, NULL
  );

  SELECT id INTO v_move_op
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a AND operation_type = 'move'
  ORDER BY operated_at DESC LIMIT 1;

  -- Superseded operation is no longer undoable.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 2,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-invalidated',
      'operation_id', v_push_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_invalidated_rejected', 'undo_unavailable',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'undo_unavailable',
    v_res::text
  );

  -- -------------------------------------------------------------------------
  -- Undo of the Move restores the prior date and advances the revision
  -- -------------------------------------------------------------------------
  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_collisions
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id = v_slot_a THEN v_date_push
               ELSE o.scheduled_date
             END AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND o.disposition = 'scheduled'
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(v_date_push, 'YYYY-MM-DD'),
          'proposedDisposition', 'scheduled',
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        )
      )
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a AND o.session_slot_id = v_slot_a
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', v_collisions,
    'operation', jsonb_build_object(
      'type', 'undo',
      'operationId', v_move_op::text
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 2,
    'timezone', v_tz
  );
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 2,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-p-undo-move-1',
      'operation_id', v_move_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_move_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT scheduled_date INTO v_date_pre
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'P', 'undo_move_restored_date', to_char(v_date_push, 'YYYY-MM-DD'),
    to_char(v_date_pre, 'YYYY-MM-DD'), NULL,
    v_date_pre = v_date_push, NULL
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'undo_move_projection_revision', '3', v_rev::text, NULL, v_rev = 3, NULL
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'undo_move_assignment_revision', '3', v_rev::text, NULL, v_rev = 3, NULL
  );

  SELECT undo_consumed_at IS NOT NULL INTO v_flag
  FROM programme_schedule_operations WHERE id = v_move_op;
  PERFORM sprint12_record(
    'P', 'undo_move_original_consumed', 'true',
    COALESCE(v_flag::text, 'null'), NULL,
    v_flag IS TRUE, NULL
  );

  SELECT id INTO v_undo_op
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a AND operation_type = 'undo'
  ORDER BY operated_at DESC LIMIT 1;
  PERFORM sprint12_record(
    'P', 'undo_row_appended', 'true',
    (v_undo_op IS NOT NULL)::text, NULL,
    v_undo_op IS NOT NULL, NULL
  );

  SELECT undo_expires_at IS NULL INTO v_flag
  FROM programme_schedule_operations WHERE id = v_undo_op;
  PERFORM sprint12_record(
    'P', 'undo_row_not_undoable', 'true',
    COALESCE(v_flag::text, 'null'), NULL,
    v_flag IS TRUE, NULL
  );

  -- Undo of an Undo is not offered.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 3,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-of-undo',
      'operation_id', v_undo_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_of_undo_rejected', 'undo_unavailable',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'undo_unavailable',
    v_res::text
  );

  -- -------------------------------------------------------------------------
  -- Skip records a complete inverse snapshot; Undo restores it
  -- -------------------------------------------------------------------------
  SELECT current_week_number, current_day_key, current_slot_order
    INTO v_cursor_week, v_cursor_day, v_cursor_order
  FROM programme_assignments WHERE id = v_enrol_a;

  SELECT week_number, day_key, session_order
    INTO v_next_week, v_next_day, v_next_order
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_b;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'proposedDisposition', 'skipped',
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        )
      )
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a AND o.session_slot_id = v_slot_a
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
    'scheduleRevision', 3,
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
      'expected_schedule_revision', 3,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-p-skip-1',
      'session_slot_id', v_slot_a
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'skip_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT id, prior_snapshot INTO v_skip_op, v_snapshot
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a AND operation_type = 'skip'
  ORDER BY operated_at DESC LIMIT 1;

  PERFORM sprint12_record(
    'P', 'skip_snapshot_complete', 'true',
    (
      COALESCE(v_snapshot, '{}'::jsonb) ? 'operation_type'
      AND v_snapshot ? 'session_slot_id'
      AND v_snapshot ? 'disposition_before'
      AND v_snapshot ? 'outcome_existed_before'
      AND v_snapshot ? 'outcome_status_before'
      AND v_snapshot ? 'cursor_before'
      AND v_snapshot ? 'assignment_status_before'
      AND v_snapshot ? 'assignment_completed_at_before'
      AND (v_snapshot->'cursor_before') ? 'week_number'
      AND (v_snapshot->'cursor_before') ? 'day_key'
      AND (v_snapshot->'cursor_before') ? 'session_order'
    )::text,
    NULL,
    COALESCE(v_snapshot, '{}'::jsonb) ? 'operation_type'
      AND v_snapshot ? 'session_slot_id'
      AND v_snapshot ? 'disposition_before'
      AND v_snapshot ? 'outcome_existed_before'
      AND v_snapshot ? 'outcome_status_before'
      AND v_snapshot ? 'cursor_before'
      AND v_snapshot ? 'assignment_status_before'
      AND v_snapshot ? 'assignment_completed_at_before'
      AND (v_snapshot->'cursor_before') ? 'week_number'
      AND (v_snapshot->'cursor_before') ? 'day_key'
      AND (v_snapshot->'cursor_before') ? 'session_order',
    v_snapshot::text
  );

  SELECT affected_after ? 'outcome_status_after'
         AND affected_after ? 'assignment_status_after'
         AND affected_after ? 'assignment_completed_at_after'
         AND affected_after ? 'disposition_after'
         AND affected_after ? 'cursor_after'
    INTO v_flag
  FROM programme_schedule_operations WHERE id = v_skip_op;
  PERFORM sprint12_record(
    'P', 'skip_after_state_recorded', 'true',
    COALESCE(v_flag::text, 'null'), NULL,
    v_flag IS TRUE, NULL
  );

  -- Undo the Skip: disposition, outcome, cursor and assignment status restore.
  SELECT scheduled_date INTO v_date_pre
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;

  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_collisions
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT o.scheduled_date AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND (o.disposition = 'scheduled' OR o.session_slot_id = v_slot_a)
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'proposedDisposition', 'scheduled',
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        )
      )
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a AND o.session_slot_id = v_slot_a
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', v_collisions,
    'cursorAfter', jsonb_build_object(
      'dayKey', v_cursor_day,
      'sessionOrder', v_cursor_order,
      'sessionSlotId', v_slot_a::text,
      'weekNumber', v_cursor_week
    ),
    'cursorBefore', jsonb_build_object(
      'dayKey', v_next_day,
      'sessionOrder', v_next_order,
      'sessionSlotId', v_slot_b::text,
      'weekNumber', v_next_week
    ),
    'operation', jsonb_build_object(
      'type', 'undo',
      'operationId', v_skip_op::text
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 4,
    'timezone', v_tz
  );
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 4,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-p-undo-skip-1',
      'operation_id', v_skip_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_skip_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT disposition INTO v_disposition
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'P', 'undo_skip_disposition_restored', 'scheduled',
    v_disposition, NULL,
    v_disposition = 'scheduled', NULL
  );

  -- The outcome row must return to exactly what the snapshot recorded:
  -- deleted when none existed, otherwise restored to its prior status.
  SELECT COUNT(*) INTO v_count
  FROM programme_slot_outcomes
  WHERE assignment_id = v_enrol_a
    AND session_slot_id = v_slot_a
    AND (
      NOT COALESCE((v_snapshot->>'outcome_existed_before')::boolean, FALSE)
      OR outcome_status IS NOT DISTINCT FROM (v_snapshot->>'outcome_status_before')
    );
  PERFORM sprint12_record(
    'P', 'undo_skip_outcome_restored',
    CASE
      WHEN COALESCE((v_snapshot->>'outcome_existed_before')::boolean, FALSE)
      THEN '1' ELSE '0'
    END,
    v_count::text, NULL,
    v_count = CASE
                WHEN COALESCE((v_snapshot->>'outcome_existed_before')::boolean, FALSE)
                THEN 1 ELSE 0
              END,
    'outcome_existed_before=' || COALESCE(v_snapshot->>'outcome_existed_before', 'null')
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_slot_outcomes
  WHERE assignment_id = v_enrol_a
    AND session_slot_id = v_slot_a
    AND outcome_status = 'skipped';
  PERFORM sprint12_record(
    'P', 'undo_skip_outcome_not_skipped', '0', v_count::text, NULL,
    v_count = 0, NULL
  );

  SELECT current_week_number, current_day_key, current_slot_order
    INTO v_next_week, v_next_day, v_next_order
  FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'undo_skip_cursor_restored',
    v_cursor_week::text || '/' || v_cursor_day || '/' || v_cursor_order::text,
    v_next_week::text || '/' || v_next_day || '/' || v_next_order::text, NULL,
    v_next_week = v_cursor_week
      AND v_next_day IS NOT DISTINCT FROM v_cursor_day
      AND v_next_order = v_cursor_order,
    NULL
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'undo_skip_projection_revision', '5', v_rev::text, NULL, v_rev = 5, NULL
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'undo_skip_assignment_revision', '5', v_rev::text, NULL, v_rev = 5, NULL
  );

  SELECT undo_consumed_at IS NOT NULL INTO v_flag
  FROM programme_schedule_operations WHERE id = v_skip_op;
  PERFORM sprint12_record(
    'P', 'undo_skip_original_consumed', 'true',
    COALESCE(v_flag::text, 'null'), NULL,
    v_flag IS TRUE, NULL
  );

  -- Replaying the consumed target is refused.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 5,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-skip-again',
      'operation_id', v_skip_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_already_consumed_rejected', 'undo_already_consumed',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'undo_already_consumed',
    v_res::text
  );

  -- Unknown operation id.
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 5,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-missing',
      'operation_id', '00000000-0000-4000-8000-000000000009'
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_operation_not_found', 'operation_not_found',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'operation_not_found',
    v_res::text
  );

  -- -------------------------------------------------------------------------
  -- Expired undo window is refused
  -- -------------------------------------------------------------------------
  SELECT scheduled_date INTO v_date_slot_b
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_b;

  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_collisions
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id = v_slot_b THEN v_date_slot_b + 20
               ELSE o.scheduled_date
             END AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND o.disposition = 'scheduled'
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(v_date_slot_b + 20, 'YYYY-MM-DD'),
          'proposedDisposition', o.disposition,
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        )
      )
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a AND o.session_slot_id = v_slot_b
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', v_collisions,
    'operation', jsonb_build_object(
      'sessionSlotId', v_slot_b::text,
      'targetDate', to_char(v_date_slot_b + 20, 'YYYY-MM-DD'),
      'type', 'move'
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 5,
    'timezone', v_tz
  );
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 5,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-p-move-2',
      'session_slot_id', v_slot_b,
      'target_date', to_char(v_date_slot_b + 20, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'move_2_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT id INTO v_move2_op
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a
    AND operation_type = 'move'
    AND undo_consumed_at IS NULL
    AND undo_invalidated_at IS NULL
  ORDER BY operated_at DESC LIMIT 1;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_operations
  SET undo_expires_at = NOW() - INTERVAL '1 hour'
  WHERE id = v_move2_op;
  PERFORM set_config('cohort.allow_schedule_write', '', true);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-expired',
      'operation_id', v_move2_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_expired_rejected', 'undo_expired',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'undo_expired',
    v_res::text
  );

  SELECT scheduled_date INTO v_date_pre
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_b;
  PERFORM sprint12_record(
    'P', 'undo_expired_no_mutation', to_char(v_date_slot_b + 20, 'YYYY-MM-DD'),
    to_char(v_date_pre, 'YYYY-MM-DD'), NULL,
    v_date_pre = v_date_slot_b + 20, NULL
  );

  -- -------------------------------------------------------------------------
  -- Legacy-shaped (1.7E) Skip snapshot cannot be inverted
  -- -------------------------------------------------------------------------
  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  INSERT INTO programme_schedule_operations (
    assignment_id, athlete_id, operation_type, idempotency_key,
    preview_fingerprint, base_revision, result_revision, policy_version,
    affected_before, affected_after, prior_snapshot, operated_at, undo_expires_at
  ) VALUES (
    v_enrol_a, v_athlete_a, 'skip', 'gate-p-legacy-skip-op',
    'legacy-shaped', 5, 6, 'programme.scheduling.policy.v1',
    '[]'::jsonb,
    jsonb_build_object('cleared_programmed_session_keys', '[]'::jsonb),
    jsonb_build_object(
      'operation_type', 'skip',
      'session_slot_id', v_slot_a,
      'disposition_before', 'scheduled',
      'cursor_before', jsonb_build_object(
        'week_number', v_cursor_week,
        'day_key', v_cursor_day,
        'session_order', v_cursor_order
      )
    ),
    NOW(), NOW() + INTERVAL '72 hours'
  )
  RETURNING id INTO v_legacy_op;
  PERFORM set_config('cohort.allow_schedule_write', '', true);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-legacy',
      'operation_id', v_legacy_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'incomplete_inverse_snapshot_rejected', 'incomplete_inverse_snapshot',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'incomplete_inverse_snapshot',
    v_res::text
  );

  -- -------------------------------------------------------------------------
  -- Cross-athlete undo denied
  -- -------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-cross',
      'operation_id', v_legacy_op
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'undo_cross_athlete_denied', 'assignment_not_found',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'assignment_not_found',
    v_res::text
  );

  -- -------------------------------------------------------------------------
  -- Client-nominated inverse state is refused
  -- -------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-client-snapshot',
      'operation_id', v_legacy_op,
      'prior_snapshot', jsonb_build_object('scheduled_date', '2026-01-01')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'client_prior_snapshot_rejected', 'client_nominated_projection_forbidden',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'client_nominated_projection_forbidden',
    v_res::text
  );

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'undo',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-undo-client-cursor',
      'operation_id', v_legacy_op,
      'cursor_before', jsonb_build_object('week_number', 1)
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'client_cursor_before_rejected', 'client_nominated_projection_forbidden',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'client_nominated_projection_forbidden',
    v_res::text
  );

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-move-client-horizon',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_date_slot_b, 'YYYY-MM-DD'),
      'scheduling_horizon_end', '2099-01-01'
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'client_horizon_rejected', 'client_nominated_projection_forbidden',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'client_nominated_projection_forbidden',
    v_res::text
  );

  -- -------------------------------------------------------------------------
  -- Direct table writes remain blocked
  -- -------------------------------------------------------------------------
  PERFORM set_config('cohort.allow_schedule_write', '', true);
  PERFORM set_config('cohort.allow_materialisation_write', '', true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    UPDATE programme_schedule_operations
    SET undo_consumed_at = NULL, undo_invalidated_at = NULL
    WHERE assignment_id = v_enrol_a;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM set_config('role', 'postgres', true);
    IF v_count > 0 THEN
      PERFORM sprint12_record(
        'P', 'direct_operation_update_denied', 'denied', 'allowed', NULL, FALSE,
        'update succeeded'
      );
    ELSE
      PERFORM sprint12_record(
        'P', 'direct_operation_update_denied', 'denied', 'denied', NULL, TRUE,
        '0 rows'
      );
    END IF;
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'P', 'direct_operation_update_denied', 'denied', 'denied', NULL, TRUE, NULL
      );
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'P', 'direct_operation_update_denied', 'denied', SQLERRM, NULL, TRUE, NULL
      );
  END;

  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    UPDATE programme_schedule_projections
    SET scheduling_horizon_end = '2099-01-01'
    WHERE assignment_id = v_enrol_a;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM set_config('role', 'postgres', true);
    IF v_count > 0 THEN
      PERFORM sprint12_record(
        'P', 'direct_horizon_update_denied', 'denied', 'allowed', NULL, FALSE,
        'update succeeded'
      );
    ELSE
      PERFORM sprint12_record(
        'P', 'direct_horizon_update_denied', 'denied', 'denied', NULL, TRUE,
        '0 rows'
      );
    END IF;
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'P', 'direct_horizon_update_denied', 'denied', 'denied', NULL, TRUE, NULL
      );
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record(
        'P', 'direct_horizon_update_denied', 'denied', SQLERRM, NULL, TRUE, NULL
      );
  END;

  SELECT scheduling_horizon_end INTO v_horizon
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'horizon_unchanged_by_direct_write', 'null',
    COALESCE(v_horizon::text, 'null'), NULL,
    v_horizon IS NULL, NULL
  );

  -- -------------------------------------------------------------------------
  -- Horizon enforcement (inclusive bound)
  -- -------------------------------------------------------------------------
  SELECT scheduled_date INTO v_date_pre
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;

  v_horizon := v_date_pre + 5;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  UPDATE programme_schedule_projections
  SET scheduling_horizon_end = v_horizon
  WHERE assignment_id = v_enrol_a;
  PERFORM set_config('cohort.allow_schedule_write', '', true);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-move-beyond-horizon',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_horizon + 1, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'move_beyond_horizon_rejected', 'horizon_exceeded',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'horizon_exceeded',
    v_res::text
  );

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'push',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', 'unused-precheck',
      'idempotency_key', 'gate-p-push-beyond-horizon',
      'session_slot_id', v_slot_a,
      'day_delta', 60
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'push_beyond_horizon_rejected', 'horizon_exceeded',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'horizon_exceeded',
    v_res::text
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'P', 'horizon_rejection_no_revision_change', '6', v_rev::text, NULL,
    v_rev = 6, NULL
  );

  -- A date equal to the horizon is valid, and binds into the fingerprint.
  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_collisions
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id = v_slot_a THEN v_horizon
               ELSE o.scheduled_date
             END AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND o.disposition = 'scheduled'
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(v_horizon, 'YYYY-MM-DD'),
          'proposedDisposition', o.disposition,
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        )
      )
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a AND o.session_slot_id = v_slot_a
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', v_collisions,
    'operation', jsonb_build_object(
      'sessionSlotId', v_slot_a::text,
      'targetDate', to_char(v_horizon, 'YYYY-MM-DD'),
      'type', 'move'
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 6,
    'schedulingHorizonEnd', to_char(v_horizon, 'YYYY-MM-DD'),
    'timezone', v_tz
  );
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 6,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-p-move-on-horizon',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_horizon, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'move_on_horizon_applied', 'applied',
    v_res->>'status', NULL,
    v_res->>'status' = 'applied',
    v_res::text
  );

  SELECT scheduled_date INTO v_date_pre
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a AND session_slot_id = v_slot_a;
  PERFORM sprint12_record(
    'P', 'move_on_horizon_date', to_char(v_horizon, 'YYYY-MM-DD'),
    to_char(v_date_pre, 'YYYY-MM-DD'), NULL,
    v_date_pre = v_horizon, NULL
  );

  -- Same move, fingerprinted without the horizon key: the only difference is
  -- the omitted schedulingHorizonEnd, so the apply must refuse it.
  SELECT COALESCE(
    jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
    '[]'::jsonb
  )
  INTO v_collisions
  FROM (
    SELECT d AS collision_date
    FROM (
      SELECT CASE
               WHEN o.session_slot_id = v_slot_a THEN v_horizon - 1
               ELSE o.scheduled_date
             END AS d
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a
        AND o.disposition = 'scheduled'
    ) s
    GROUP BY d
    HAVING COUNT(*) > 1
  ) c;

  v_fp_payload := jsonb_build_object(
    'affected', (
      SELECT jsonb_build_array(
        jsonb_build_object(
          'dayKey', o.day_key,
          'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
          'originalDisposition', o.disposition,
          'programmedSessionKey', o.programmed_session_key,
          'proposedDate', to_char(v_horizon - 1, 'YYYY-MM-DD'),
          'proposedDisposition', o.disposition,
          'protocolId', o.protocol_id,
          'sessionOrder', o.session_order,
          'sessionSlotId', o.session_slot_id::text,
          'weekNumber', o.week_number
        )
      )
      FROM programme_schedule_occurrences o
      WHERE o.assignment_id = v_enrol_a AND o.session_slot_id = v_slot_a
    ),
    'assignmentId', v_enrol_a::text,
    'collidingDates', v_collisions,
    'operation', jsonb_build_object(
      'sessionSlotId', v_slot_a::text,
      'targetDate', to_char(v_horizon - 1, 'YYYY-MM-DD'),
      'type', 'move'
    ),
    'packageContentHash', v_hash,
    'policyVersion', 'programme.scheduling.policy.v1',
    'programmeVersionId', v_version::text,
    'scheduleRevision', 7,
    'timezone', v_tz
  );
  v_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.apply_programme_schedule_operation(
    jsonb_build_object(
      'operation_type', 'move',
      'assignment_id', v_enrol_a,
      'programme_version_id', v_version,
      'package_content_hash', v_hash,
      'expected_schedule_revision', 7,
      'preview_fingerprint', v_fp,
      'idempotency_key', 'gate-p-move-horizon-unbound-fp',
      'session_slot_id', v_slot_a,
      'target_date', to_char(v_horizon - 1, 'YYYY-MM-DD')
    )
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'P', 'horizon_bound_into_fingerprint', 'stale_preview_fingerprint',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'stale_preview_fingerprint',
    v_res::text
  );
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results
WHERE gate = 'P'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
