-- Sprint 1.4A Gate K — athlete plan materialisation RPC / isolation.
-- Requires helpers.sql. Uses auth.users + profiles + request.jwt.claim.sub.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-MAT-R1';
  v_lineage UUID := 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1';
  v_hash TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_eligible UUID;
  v_empty UUID;
  v_empty_lineage UUID;
  v_athlete_a UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_athlete_b UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_enrol_a UUID;
  v_enrol_b UUID;
  v_count INT;
  v_hash_before TEXT;
  v_hash_after TEXT;
  v_started_before DATE;
  v_started_after DATE;
  v_mat_at TIMESTAMPTZ;
  v_week INT;
  v_day TEXT;
  v_slot INT;
BEGIN
  -- Isolate from prior gates (Gate J leaves enrolments for the shared athlete ids).
  DELETE FROM programme_assignments
  WHERE athlete_id IN (v_athlete_a, v_athlete_b);

  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Materialise Gate Session');

  v_hash := sprint12_hash('gate-k-eligible');
  v_payload := sprint12_build_package('PROG-GATE-K-ELIG', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_eligible := (v_res->>'programme_version_id')::uuid;
  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_eligible, 'gate-k');
  PERFORM public.approve_cohort_global_programme_version(v_eligible, 'gate-k');
  PERFORM set_config('role', 'postgres', true);

  SELECT package_content_hash INTO v_hash_before
  FROM programme_versions WHERE id = v_eligible;

  -- Empty programme (rest-only day, no executable slots) — structure while draft.
  v_empty_lineage := gen_random_uuid();
  v_empty := gen_random_uuid();
  INSERT INTO programme_lineages (id, code, created_by)
  VALUES (v_empty_lineage, 'PROG-GATE-K-EMPTY', 'gate-k');
  INSERT INTO programme_versions (
    id, lineage_id, version_number, lifecycle_status, library_scope, owner_type, owner_id,
    created_by, name, approved_for_global, approved_for_adaptation,
    package_schema_version, package_content_hash
  ) VALUES (
    v_empty, v_empty_lineage, 1, 'draft', 'cohort_global', 'global', NULL,
    'gate-k', 'Empty Package', FALSE, FALSE,
    '1', repeat('ab', 32)
  );
  INSERT INTO programme_version_weeks (id, version_id, week_number, title)
  VALUES (gen_random_uuid(), v_empty, 1, 'W1');
  INSERT INTO programme_version_days (id, week_id, day_key, day_order, day_type)
  SELECT gen_random_uuid(), w.id, 'day_1', 1, 'rest'
  FROM programme_version_weeks w WHERE w.version_id = v_empty LIMIT 1;
  -- Publish/approve via controlled status transitions (rest-only package may be
  -- rejected by the publish RPC's executable-session checks).
  UPDATE programme_versions
  SET lifecycle_status = 'published',
      published_at = NOW()
  WHERE id = v_empty;
  UPDATE programme_versions
  SET approved_for_global = TRUE
  WHERE id = v_empty;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
     'gate-k-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
     'gate-k-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate Mat Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate Mat Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  -- Schema: materialisation columns exist; S1.3 enrolment remains non-materialised
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  v_enrol_a := (v_res->>'enrolment_id')::uuid;
  PERFORM sprint12_record(
    'K','enrol_non_materialised','enrolled', v_res->>'status',
    NULL, (v_res->>'status') = 'enrolled', v_res::text
  );

  SELECT count(*) INTO v_count
  FROM programme_assignments
  WHERE id = v_enrol_a AND materialised_at IS NULL AND status = 'active';
  PERFORM sprint12_record('K','s13_enrolment_not_materialised','1', v_count::text, NULL, v_count = 1, NULL);

  SELECT started_at INTO v_started_before FROM programme_assignments WHERE id = v_enrol_a;
  -- Prove enrolment-time started_at is overwritten at materialisation.
  UPDATE programme_assignments
  SET started_at = (CURRENT_DATE - 7)
  WHERE id = v_enrol_a;
  SELECT started_at INTO v_started_before FROM programme_assignments WHERE id = v_enrol_a;

  -- Anon execute denied
  BEGIN
    PERFORM set_config('role', 'anon', true);
    v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, 'UTC');
    PERFORM sprint12_record('K','anon_execute','permission_denied', coalesce(v_res->>'status','executed'), NULL, FALSE, 'anon executed');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('K','anon_execute','permission_denied','permission_denied', TRUE, TRUE, 'EXECUTE denied');
  WHEN OTHERS THEN
    PERFORM sprint12_record('K','anon_execute','permission_denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Direct materialisation-field UPDATE denied for authenticated
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
    PERFORM set_config('role', 'authenticated', true);
    UPDATE programme_assignments
    SET materialised_at = NOW(),
        materialisation_source = 'athlete_start_programme',
        materialised_package_content_hash = v_hash_before
    WHERE id = v_enrol_a;
    PERFORM sprint12_record('K','direct_materialise_update','denied','updated', NULL, FALSE, 'update succeeded');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('K','direct_materialise_update','denied','denied', TRUE, TRUE, SQLERRM);
  WHEN OTHERS THEN
    PERFORM sprint12_record('K','direct_materialise_update','denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Authenticated set_config of the RPC GUC must not bypass the write guard.
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    UPDATE programme_assignments
    SET materialised_at = NOW(),
        materialisation_source = 'athlete_start_programme',
        materialised_package_content_hash = v_hash_before
    WHERE id = v_enrol_a;
    PERFORM sprint12_record(
      'K','guc_bypass_blocked','denied','updated', NULL, FALSE,
      'authenticated GUC bypass succeeded'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('K','guc_bypass_blocked','denied','denied', TRUE, TRUE, SQLERRM);
  WHEN OTHERS THEN
    PERFORM sprint12_record(
      'K','guc_bypass_blocked','denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM
    );
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Direct INSERT still denied for plain athlete (no INSERT grant / RLS)
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
    PERFORM set_config('role', 'authenticated', true);
    INSERT INTO programme_assignments (
      athlete_id, programme_version_id, lineage_code, status, started_at,
      current_week_number, current_day_key, current_slot_order
    ) VALUES (
      v_athlete_a, v_eligible, 'PROG-GATE-K-ELIG', 'active', CURRENT_DATE, 1, 'day_1', 1
    );
    PERFORM sprint12_record('K','direct_insert','denied','inserted', NULL, FALSE, 'insert succeeded');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('K','direct_insert','denied','denied', TRUE, TRUE, NULL);
  WHEN OTHERS THEN
    PERFORM sprint12_record('K','direct_insert','denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Successful materialisation
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, 'UTC');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'K','materialise_success','materialised', v_res->>'status',
    NULL,
    (v_res->>'status') = 'materialised'
      AND (v_res->>'programme_version_id') = v_eligible::text
      AND (v_res->>'materialised_package_content_hash') = v_hash_before
      AND (v_res->>'materialisation_source') = 'athlete_start_programme',
    v_res::text
  );

  SELECT started_at, materialised_at, current_week_number, current_day_key, current_slot_order
    INTO v_started_after, v_mat_at, v_week, v_day, v_slot
  FROM programme_assignments WHERE id = v_enrol_a;

  PERFORM sprint12_record(
    'K','start_anchor_reset','today_utc', v_started_after::text,
    NULL,
    v_started_after = (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date
      AND v_started_after IS DISTINCT FROM v_started_before,
    format('before=%s after=%s', v_started_before, v_started_after)
  );

  PERFORM sprint12_record(
    'K','exact_version_bound', v_eligible::text,
    (SELECT programme_version_id::text FROM programme_assignments WHERE id = v_enrol_a),
    NULL,
    (SELECT programme_version_id FROM programme_assignments WHERE id = v_enrol_a) = v_eligible,
    NULL
  );

  PERFORM sprint12_record(
    'K','hash_from_version', v_hash_before,
    (SELECT materialised_package_content_hash FROM programme_assignments WHERE id = v_enrol_a),
    NULL,
    (SELECT materialised_package_content_hash FROM programme_assignments WHERE id = v_enrol_a) = v_hash_before,
    NULL
  );

  PERFORM sprint12_record(
    'K','cursor_initialised','week_day_slot',
    format('%s/%s/%s', v_week, v_day, v_slot),
    NULL,
    v_week IS NOT NULL AND v_day IS NOT NULL AND v_slot IS NOT NULL AND v_mat_at IS NOT NULL,
    NULL
  );

  -- Idempotent retry
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, 'UTC');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'K','idempotent_retry','already_materialised', v_res->>'status',
    NULL,
    (v_res->>'status') = 'already_materialised'
      AND (v_res->>'enrolment_id') = v_enrol_a::text,
    v_res::text
  );
  SELECT count(*) INTO v_count
  FROM programme_assignments
  WHERE athlete_id = v_athlete_a AND status = 'active' AND materialised_at IS NOT NULL;
  PERFORM sprint12_record('K','one_active_materialised','1', v_count::text, NULL, v_count = 1, NULL);

  -- Unique index present
  PERFORM sprint12_record(
    'K','unique_active_materialised_index','present',
    CASE WHEN EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'programme_assignments_one_active_materialised_per_athlete'
    ) THEN 'present' ELSE 'absent' END,
    NULL,
    EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'programme_assignments_one_active_materialised_per_athlete'
    ),
    NULL
  );

  -- Cross-athlete: B cannot materialise A's assignment
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, 'UTC');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'K','b_cannot_materialise_a','assignment_not_found', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'assignment_not_found', v_res::text
  );

  -- B enrols + materialises independently
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'UTC', FALSE);
  v_enrol_b := (v_res->>'enrolment_id')::uuid;
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_b, 'UTC');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'K','athlete_b_materialise','materialised', v_res->>'status',
    NULL, (v_res->>'status') = 'materialised', v_res::text
  );

  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE id = v_enrol_b;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('K','isolation_a_cannot_read_b','0', v_count::text, NULL, v_count = 0, NULL);

  -- Inactive enrolment denial: pause A then attempt (use second synthetic enrolment path)
  -- Reassign A away then try materialise old id — already materialised returns already_materialised.
  -- Create inactive non-materialised denial via paused row for B's second attempt:
  -- Use empty package assignment inserted as service/postgres then athlete materialise.
  INSERT INTO programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    current_week_number, current_day_key, current_slot_order, enrolment_source, timezone
  ) VALUES (
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',
    v_athlete_a,
    v_empty,
    'PROG-GATE-K-EMPTY',
    'paused',
    CURRENT_DATE,
    1, 'day_1', 1,
    'non_commercial_test',
    'UTC'
  );
  -- Athlete A already has active materialised row; paused empty is fine.
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.materialise_athlete_plan_from_enrolment(
    'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'::uuid, 'UTC'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'K','inactive_enrolment_denied','inactive_enrolment', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'inactive_enrolment', v_res::text
  );

  -- Empty / unresolvable: need active non-materialised enrolment on empty version.
  -- Reassign A's active materialised to allow a new active enrolment.
  UPDATE programme_assignments
  SET status = 'reassigned', updated_at = NOW()
  WHERE id = v_enrol_a;
  INSERT INTO programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    current_week_number, current_day_key, current_slot_order, enrolment_source, timezone
  ) VALUES (
    'ffffffff-ffff-4fff-8fff-ffffffffffff',
    v_athlete_a,
    v_empty,
    'PROG-GATE-K-EMPTY',
    'active',
    CURRENT_DATE,
    1, 'day_1', 1,
    'non_commercial_test',
    'UTC'
  );
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.materialise_athlete_plan_from_enrolment(
    'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid, 'UTC'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'K','empty_programme_denied','empty_programme_structure', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'empty_programme_structure', v_res::text
  );

  -- Timezone unavailable on an otherwise materialisable enrolment
  UPDATE programme_assignments
  SET status = 'reassigned', updated_at = NOW()
  WHERE id = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, NULL, FALSE);
  PERFORM set_config('role', 'postgres', true);
  v_enrol_a := (v_res->>'enrolment_id')::uuid;
  UPDATE programme_assignments SET timezone = NULL WHERE id = v_enrol_a;
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.materialise_athlete_plan_from_enrolment(v_enrol_a, NULL);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'K','timezone_unavailable','timezone_unavailable', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'timezone_unavailable', v_res::text
  );

  -- Package immutability preserved
  SELECT package_content_hash INTO v_hash_after FROM programme_versions WHERE id = v_eligible;
  PERFORM sprint12_record(
    'K','package_immutable', v_hash_before, coalesce(v_hash_after,''),
    NULL, v_hash_before IS NOT DISTINCT FROM v_hash_after, NULL
  );

  -- No commerce / prepared-session tables
  PERFORM sprint12_record(
    'K','no_commerce_or_prepared_tables','absent',
    CASE WHEN to_regclass('public.subscriptions') IS NULL
              AND to_regclass('public.purchases') IS NULL
              AND to_regclass('public.prepared_sessions') IS NULL
              AND to_regclass('public.athlete_plans') IS NULL
         THEN 'absent' ELSE 'present' END,
    NULL,
    to_regclass('public.subscriptions') IS NULL
      AND to_regclass('public.purchases') IS NULL
      AND to_regclass('public.prepared_sessions') IS NULL
      AND to_regclass('public.athlete_plans') IS NULL,
    NULL
  );

  -- No training sessions created by materialisation
  SELECT count(*) INTO v_count FROM training_sessions;
  PERFORM sprint12_record('K','no_training_sessions','0', v_count::text, NULL, v_count = 0, NULL);
END;
$$;

SELECT gate, case_id, expected, actual, pass, detail
FROM sprint12_gate_results
WHERE gate = 'K'
ORDER BY case_id;

SELECT sprint12_fail_if_any_failed();
