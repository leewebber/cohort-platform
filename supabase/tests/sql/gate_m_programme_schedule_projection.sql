-- Sprint 1.7C Gate M — durable schedule projection init / RLS / no apply path.
-- Requires helpers.sql. Uses auth.users + profiles + request.jwt.claim.sub.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-M-R1';
  v_protocol_b TEXT := 'PROT-GATE-M-R2';
  v_lineage UUID := 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  v_hash TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_version UUID;
  v_athlete_a UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_athlete_b UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_enrol_a UUID;
  v_count INT;
  v_rev INT;
  v_date DATE;
  v_started DATE;
  v_slot_a UUID;
  v_has_exec BOOLEAN;
BEGIN
  DELETE FROM programme_assignments
  WHERE athlete_id IN (v_athlete_a, v_athlete_b);

  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate M Slot A');
  PERFORM sprint12_ensure_published_session(v_protocol_b, v_lineage, 2, 'Gate M Slot B');

  v_hash := sprint12_hash('gate-m-schedule');
  v_payload := sprint12_build_package('PROG-GATE-M-ELIG', 1, v_hash, v_protocol, v_lineage);
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
    SELECT gen_random_uuid(), d.id, 1, v_protocol_b, 'Gate M Slot B'
    FROM programme_version_weeks w
    JOIN programme_version_days d ON d.week_id = w.id
    WHERE w.version_id = v_version
      AND d.day_key = 'day_2'
      AND NOT EXISTS (
        SELECT 1 FROM programme_version_session_slots s WHERE s.day_id = d.id
      )
    LIMIT 1;
  END IF;

  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_version, 'gate-m');
  PERFORM public.approve_cohort_global_programme_version(v_version, 'gate-m');
  PERFORM set_config('role', 'postgres', true);

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
     'gate-m-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
     'gate-m-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate M Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate M Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(
    v_version, 'Pacific/Auckland', FALSE
  );
  v_enrol_a := (v_res->>'enrolment_id')::uuid;
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, 'Pacific/Auckland');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'M', 'materialise_a', 'materialised_or_already',
    v_res->>'status', NULL,
    (v_res->>'status') IN ('materialised', 'already_materialised'),
    v_res::text
  );

  SELECT started_at INTO v_started
  FROM programme_assignments WHERE id = v_enrol_a;

  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    INSERT INTO programme_schedule_projections (
      assignment_id, athlete_id, programme_version_id, package_content_hash,
      timezone, started_at, schedule_revision
    ) VALUES (
      v_enrol_a, v_athlete_a, v_version, v_hash,
      'Pacific/Auckland', v_started, 0
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('M', 'direct_insert_denied', 'denied', 'allowed', NULL, FALSE, 'insert succeeded');
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('M', 'direct_insert_denied', 'denied', 'denied', NULL, TRUE, NULL);
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('M', 'direct_insert_denied', 'denied', SQLERRM, NULL, TRUE, NULL);
  END;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.ensure_programme_schedule_projection(v_enrol_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'M', 'ensure_initialised', 'initialised', v_res->>'status', NULL,
    v_res->>'status' = 'initialised', v_res::text
  );
  PERFORM sprint12_record(
    'M', 'baseline_revision', '0', v_res->>'schedule_revision', NULL,
    v_res->>'schedule_revision' = '0', NULL
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'M', 'occurrence_count_positive', '>0', v_count::text, NULL, v_count > 0, NULL
  );

  SELECT MIN(scheduled_date) INTO v_date
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a;
  SELECT started_at INTO v_started FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'M', 'first_date_is_started_at', v_started::text, v_date::text, NULL,
    v_date = v_started, NULL
  );

  PERFORM set_config('role', 'authenticated', true);
  v_res := public.ensure_programme_schedule_projection(v_enrol_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'M', 'ensure_idempotent', 'already_exists', v_res->>'status', NULL,
    v_res->>'status' = 'already_exists', v_res::text
  );

  SELECT schedule_revision INTO v_rev
  FROM programme_schedule_projections WHERE assignment_id = v_enrol_a;
  PERFORM sprint12_record(
    'M', 'revision_unchanged', '0', v_rev::text, NULL, v_rev = 0, NULL
  );

  SELECT session_slot_id INTO v_slot_a
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_enrol_a
  ORDER BY week_number, day_key, session_order
  LIMIT 1;

  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    UPDATE programme_schedule_occurrences
    SET scheduled_date = scheduled_date + 1
    WHERE assignment_id = v_enrol_a
      AND session_slot_id = v_slot_a;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM set_config('role', 'postgres', true);
    IF v_count > 0 THEN
      PERFORM sprint12_record('M', 'direct_date_update_denied', 'denied', 'allowed', NULL, FALSE, 'update succeeded');
    ELSE
      PERFORM sprint12_record('M', 'direct_date_update_denied', 'denied', 'denied', NULL, TRUE, '0 rows');
    END IF;
  EXCEPTION
    WHEN insufficient_privilege OR SQLSTATE '42501' THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('M', 'direct_date_update_denied', 'denied', 'denied', NULL, TRUE, NULL);
    WHEN OTHERS THEN
      PERFORM set_config('role', 'postgres', true);
      PERFORM sprint12_record('M', 'direct_date_update_denied', 'denied', SQLERRM, NULL, TRUE, NULL);
  END;

  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.ensure_programme_schedule_projection(v_enrol_a);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'M', 'cross_athlete_ensure', 'assignment_not_found',
    COALESCE(v_res->>'code', v_res->>'status'), NULL,
    (v_res->>'code') = 'assignment_not_found', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_projections
  WHERE assignment_id = v_enrol_a;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'M', 'cross_athlete_select_hidden', '0', v_count::text, NULL, v_count = 0, NULL
  );

  v_has_exec := has_function_privilege(
    'authenticated',
    'public.apply_programme_schedule_operation(jsonb)',
    'execute'
  );
  PERFORM sprint12_record(
    'M', 'apply_not_granted_authenticated', 'false', v_has_exec::text, NULL,
    v_has_exec IS NOT TRUE, NULL
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a
    AND operation_type = 'baseline_initialisation';
  PERFORM sprint12_record(
    'M', 'baseline_audit_row', '1', v_count::text, NULL, v_count = 1, NULL
  );

  SELECT COUNT(*) INTO v_count
  FROM programme_schedule_operations
  WHERE assignment_id = v_enrol_a
    AND operation_type IN ('move', 'swap', 'push', 'skip', 'undo');
  PERFORM sprint12_record(
    'M', 'no_athlete_op_rows', '0', v_count::text, NULL, v_count = 0, NULL
  );

  SELECT current_week_number INTO v_count
  FROM programme_assignments WHERE id = v_enrol_a;
  PERFORM sprint12_record(
    'M', 'cursor_week_untouched', '1', v_count::text, NULL, v_count = 1, NULL
  );
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results
WHERE gate = 'M'
ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
