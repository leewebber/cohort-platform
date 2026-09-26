-- Gate BB — authored calendar dates + private exact-version enrolment.
TRUNCATE sprint12_gate_results;

DROP TABLE IF EXISTS sprint12_gate_bb_fixture;
CREATE TABLE sprint12_gate_bb_fixture (
  fixture_key TEXT PRIMARY KEY,
  athlete_id UUID NOT NULL,
  programme_version_id UUID NOT NULL
);

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-BB-R1';
  v_lineage UUID := 'b1b1b1b1-b1b1-41b1-81b1-b1b1b1b1b1b1';
  v_hash_cat TEXT := sprint12_hash('gate-bb-cat');
  v_hash_priv TEXT := sprint12_hash('gate-bb-priv');
  v_hash_draft TEXT := sprint12_hash('gate-bb-draft');
  v_payload JSONB;
  v_res JSONB;
  v_cat UUID;
  v_priv UUID;
  v_draft UUID;
  v_athlete UUID := 'b2b2b2b2-b2b2-42b2-82b2-b2b2b2b2b2b2';
  v_coach UUID := 'b3b3b3b3-b3b3-43b3-83b3-b3b3b3b3b3b3';
  v_other UUID := 'b4b4b4b4-b4b4-44b4-84b4-b4b4b4b4b4b4';
  v_conc UUID := 'b5b5b5b5-b5b5-45b5-85b5-b5b5b5b5b5b5';
  v_old UUID;
  v_new UUID;
  v_count INT;
  v_error TEXT;
  v_date TEXT;
  v_date2 TEXT;
BEGIN
  PERFORM sprint12_assert_eq(
    'BB', 'w1d1_makassar', '2026-09-26',
    public.cohort_authored_occurrence_date(DATE '2026-09-26', 1, 1)::text
  );
  PERFORM sprint12_assert_eq(
    'BB', 'w1d2_shared', '2026-09-27',
    public.cohort_authored_occurrence_date(DATE '2026-09-26', 1, 2)::text
  );
  PERFORM sprint12_assert_eq(
    'BB', 'w1d3', '2026-09-28',
    public.cohort_authored_occurrence_date(DATE '2026-09-26', 1, 3)::text
  );
  PERFORM sprint12_assert_eq(
    'BB', 'w8d7', '2026-11-20',
    public.cohort_authored_occurrence_date(DATE '2026-09-26', 8, 7)::text
  );
  PERFORM sprint12_assert_eq(
    'BB', 'w8d8', '2026-11-21',
    public.cohort_authored_occurrence_date(DATE '2026-09-26', 8, 8)::text
  );
  PERFORM sprint12_assert_eq(
    'BB', 'w8d9', '2026-11-22',
    public.cohort_authored_occurrence_date(DATE '2026-09-26', 8, 9)::text
  );
  PERFORM sprint12_assert_eq(
    'BB', 'london_dst_civil_day', '2026-03-29',
    public.cohort_authored_occurrence_date(DATE '2026-03-28', 1, 2)::text
  );

  DELETE FROM programme_assignments WHERE athlete_id IN (v_athlete, v_other, v_conc);
  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate BB session');

  v_payload := sprint12_build_package('PROG-GATE-BB-CAT', 1, v_hash_cat, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  v_cat := (v_res->>'programme_version_id')::uuid;
  v_payload := sprint12_build_package('PROG-GATE-BB-PRIV', 1, v_hash_priv, v_protocol, v_lineage);
  v_res := public.import_authored_plan_package(v_payload);
  v_priv := (v_res->>'programme_version_id')::uuid;
  v_payload := sprint12_build_package('PROG-GATE-BB-DRAFT', 1, v_hash_draft, v_protocol, v_lineage);
  v_res := public.import_authored_plan_package(v_payload);
  v_draft := (v_res->>'programme_version_id')::uuid;
  PERFORM public.publish_cohort_global_programme_version(v_cat, 'gate-bb');
  PERFORM public.approve_cohort_global_programme_version(v_cat, 'gate-bb');
  PERFORM set_config('role', 'postgres', true);

  UPDATE programme_versions
  SET library_scope = 'coach_private',
      owner_type = 'coach',
      owner_id = v_athlete::text,
      approved_for_global = FALSE
  WHERE id = v_priv;

  INSERT INTO programme_version_session_slots (
    day_id, session_order, protocol_id, display_title, time_of_day
  )
  SELECT s.day_id, 2, s.protocol_id, 'PM slot', 'afternoon'
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_priv AND s.session_order = 1
  LIMIT 1;

  UPDATE programme_versions
  SET lifecycle_status = 'published',
      published_at = NOW(),
      updated_at = NOW()
  WHERE id = v_priv;

  UPDATE programme_versions
  SET library_scope = 'coach_private',
      owner_type = 'coach',
      owner_id = v_athlete::text,
      approved_for_global = FALSE
  WHERE id = v_draft;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete, 'authenticated', 'authenticated',
     'gate-bb@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_coach, 'authenticated', 'authenticated',
     'gate-bb-coach@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_other, 'authenticated', 'authenticated',
     'gate-bb-other@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_conc, 'authenticated', 'authenticated',
     'gate-bb-conc@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete, 'Gate BB Dual', TRUE, TRUE),
    (v_coach, 'Gate BB Coach', FALSE, TRUE),
    (v_other, 'Gate BB Other', TRUE, FALSE),
    (v_conc, 'Gate BB Conc', TRUE, TRUE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;
  INSERT INTO coach_athlete_relationships (coach_id, athlete_id, status)
  SELECT v_athlete, v_conc, 'active'
  WHERE NOT EXISTS (
    SELECT 1
    FROM coach_athlete_relationships
    WHERE athlete_id = v_conc AND status = 'active'
  );

  PERFORM sprint12_record(
    'BB', 'private_not_catalogue_eligible', 'false',
    public.cohort_programme_version_is_catalogue_eligible(v_priv)::text,
    NULL, NOT public.cohort_programme_version_is_catalogue_eligible(v_priv), NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_cat, 'Europe/London', FALSE);
  v_old := (v_res->>'enrolment_id')::uuid;
  PERFORM set_config('role', 'postgres', true);
  INSERT INTO training_session_records (
    record_id, athlete_id, assignment_id, programme_session_id, status, session_snapshot, started_at
  ) VALUES (gen_random_uuid(), v_athlete::text, v_old, NULL, 'completed', '{}'::jsonb, NOW());

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_priv, 'Asia/Makassar', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'replace_false_conflict', 'active_enrolment_exists', v_res->>'code',
    NULL, (v_res->>'status') = 'conflict' AND (v_res->>'code') = 'active_enrolment_exists',
    v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_priv, 'Asia/Makassar', TRUE);
  PERFORM set_config('role', 'postgres', true);
  v_new := (v_res->>'enrolment_id')::uuid;
  PERFORM sprint12_record(
    'BB', 'private_replace_enrolled', 'enrolled', v_res->>'status',
    NULL,
    (v_res->>'status') = 'enrolled'
      AND (v_res->>'replaced_enrolment_id') = v_old::text
      AND (v_res->>'enrolment_source') = 'dual_role_self'
      AND (v_res->>'schedule_mode') = 'fixed_schedule',
    v_res::text
  );

  SELECT count(*) INTO v_count FROM programme_assignments
  WHERE id = v_old AND status = 'reassigned' AND superseded_by_assignment_id = v_new
    AND programme_version_id = v_cat;
  PERFORM sprint12_record('BB', 'apollo_style_history_preserved', '1', v_count::text, NULL, v_count = 1, NULL);
  SELECT count(*) INTO v_count FROM training_session_records
  WHERE assignment_id = v_old AND athlete_id = v_athlete::text AND status = 'completed';
  PERFORM sprint12_record('BB', 'prior_evidence_retained', '1', v_count::text, NULL, v_count = 1, NULL);
  SELECT count(*) INTO v_count FROM programme_assignments
  WHERE athlete_id = v_athlete AND status = 'active' AND id = v_new
    AND programme_version_id = v_priv AND materialised_at IS NOT NULL
    AND schedule_mode = 'fixed_schedule';
  PERFORM sprint12_record('BB', 'new_sole_active_materialised', '1', v_count::text, NULL, v_count = 1, NULL);

  SELECT o.scheduled_date::text INTO v_date
  FROM programme_schedule_occurrences o
  WHERE o.assignment_id = v_new
  ORDER BY o.session_order
  LIMIT 1;
  SELECT count(*) INTO v_count FROM programme_schedule_occurrences WHERE assignment_id = v_new;
  PERFORM sprint12_record(
    'BB', 'projection_created', '2', v_count::text, NULL, v_count = 2 AND v_date IS NOT NULL, v_date
  );
  SELECT count(DISTINCT scheduled_date) INTO v_count
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_new;
  PERFORM sprint12_record(
    'BB', 'same_day_slots_share_date', '1', v_count::text, NULL, v_count = 1, NULL
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_priv, 'Asia/Makassar', TRUE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'retry_idempotent', 'already_enrolled', v_res->>'status',
    NULL, (v_res->>'status') = 'already_enrolled' AND (v_res->>'enrolment_id') = v_new::text,
    v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_cat, 'Asia/Makassar', TRUE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'catalogue_rejected_on_private_rpc', 'use_catalogue_enrolment', v_res->>'code',
    NULL, (v_res->>'code') = 'use_catalogue_enrolment', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_draft, 'Asia/Makassar', TRUE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'draft_rejected', 'version_not_private_eligible', v_res->>'code',
    NULL, (v_res->>'code') = 'version_not_private_eligible', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_coach::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_priv, 'Asia/Makassar', TRUE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'coach_only_denied', 'athlete_role_required', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'athlete_role_required', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_priv, 'Asia/Makassar', TRUE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'unrelated_athlete_denied', 'private_enrolment_not_authorised', v_res->>'code',
    NULL, (v_res->>'code') = 'private_enrolment_not_authorised', v_res::text
  );

  BEGIN
    PERFORM set_config('role', 'anon', true);
    PERFORM public.enrol_athlete_in_private_programme_version(v_priv, 'Asia/Makassar', TRUE);
    v_error := 'executed';
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLSTATE;
  END;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'anon_denied', '42501', v_error, NULL, v_error = '42501', NULL
  );

  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '{}', true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_private_programme_version(v_priv, 'Asia/Makassar', TRUE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'BB', 'missing_identity_denied', 'not_authenticated', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'not_authenticated', v_res::text
  );

  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_install_fail_trigger(
    'public.programme_assignments'::regclass, 'sprint12_bb_replace_fail', 'check_violation'
  );
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
    PERFORM set_config('role', 'authenticated', true);
    -- other still unauthorised; use athlete and a second private version for rollback.
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLSTATE;
  END;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_drop_fail_trigger(
    'public.programme_assignments'::regclass, 'sprint12_bb_replace_fail'
  );

  -- Injected insert failure after reassignment must restore the active private pin.
  v_payload := sprint12_build_package('PROG-GATE-BB-PRIV2', 1, sprint12_hash('gate-bb-priv2'), v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  v_draft := (v_res->>'programme_version_id')::uuid;
  PERFORM set_config('role', 'postgres', true);
  UPDATE programme_versions
  SET library_scope = 'coach_private',
      owner_type = 'coach',
      owner_id = v_athlete::text,
      approved_for_global = FALSE
  WHERE id = v_draft;
  UPDATE programme_versions
  SET lifecycle_status = 'published',
      published_at = NOW(),
      updated_at = NOW()
  WHERE id = v_draft;

  PERFORM sprint12_install_fail_trigger(
    'public.programme_assignments'::regclass, 'sprint12_bb_replace_fail', 'check_violation'
  );
  v_error := NULL;
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete::text, true);
    PERFORM set_config('role', 'authenticated', true);
    PERFORM public.enrol_athlete_in_private_programme_version(v_draft, 'Asia/Makassar', TRUE);
  EXCEPTION WHEN OTHERS THEN
    v_error := SQLSTATE;
  END;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_drop_fail_trigger(
    'public.programme_assignments'::regclass, 'sprint12_bb_replace_fail'
  );
  SELECT count(*) INTO v_count FROM programme_assignments WHERE id = v_new AND status = 'active';
  PERFORM sprint12_record(
    'BB', 'failure_rolls_back_reassignment', '23514', coalesce(v_error, 'no error'),
    NULL, v_error = '23514' AND v_count = 1, NULL
  );

  -- Same-day slots share a date when projection uses authored offsets.
  SELECT min(scheduled_date)::text, max(scheduled_date)::text
    INTO v_date, v_date2
  FROM programme_schedule_occurrences
  WHERE assignment_id = v_new;
  PERFORM sprint12_record(
    'BB', 'same_day_programme_one_date', v_date, v_date2, NULL, v_date IS NOT DISTINCT FROM v_date2, NULL
  );

  INSERT INTO sprint12_gate_bb_fixture (fixture_key, athlete_id, programme_version_id)
  VALUES ('concurrency', v_conc, v_priv)
  ON CONFLICT (fixture_key) DO UPDATE
    SET athlete_id = EXCLUDED.athlete_id,
        programme_version_id = EXCLUDED.programme_version_id;
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results WHERE gate = 'BB' ORDER BY case_id;
SELECT sprint12_fail_if_any_failed();
