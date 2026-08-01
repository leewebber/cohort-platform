-- Sprint 1.3 Gate J — athlete catalogue enrolment RPC / isolation.
-- Requires helpers.sql. Uses auth.users + profiles + request.jwt.claim.sub.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-ENROL-R1';
  -- Distinct from helpers/Gate G fixed lineage UUIDs to avoid unique collisions.
  v_lineage UUID := 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1';
  v_hash TEXT;
  v_payload JSONB;
  v_res JSONB;
  v_eligible UUID;
  v_draft UUID;
  v_unapproved UUID;
  v_private UUID;
  v_private_lineage UUID;
  v_athlete_a UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_athlete_b UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_enrol_a UUID;
  v_enrol_b UUID;
  v_count INT;
  v_hash_before TEXT;
  v_hash_after TEXT;
BEGIN
  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Enrol Gate Session');

  -- Eligible approved published cohort_global package via import → publish → approve
  v_hash := sprint12_hash('gate-j-eligible');
  v_payload := sprint12_build_package('PROG-GATE-J-ELIG', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_eligible := (v_res->>'programme_version_id')::uuid;
  PERFORM set_config('role', 'service_role', true);
  PERFORM public.publish_cohort_global_programme_version(v_eligible, 'gate-j');
  PERFORM public.approve_cohort_global_programme_version(v_eligible, 'gate-j');
  PERFORM set_config('role', 'postgres', true);

  SELECT package_content_hash INTO v_hash_before
  FROM programme_versions WHERE id = v_eligible;

  -- Draft (imported, not published)
  v_hash := sprint12_hash('gate-j-draft');
  v_payload := sprint12_build_package('PROG-GATE-J-DRAFT', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_draft := (v_res->>'programme_version_id')::uuid;

  -- Published unapproved
  v_hash := sprint12_hash('gate-j-unapproved');
  v_payload := sprint12_build_package('PROG-GATE-J-UNAPP', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  v_unapproved := (v_res->>'programme_version_id')::uuid;
  PERFORM public.publish_cohort_global_programme_version(v_unapproved, 'gate-j');
  PERFORM set_config('role', 'postgres', true);

  -- Wrong scope (coach_private): draft structure then publish transition
  v_private_lineage := gen_random_uuid();
  v_private := gen_random_uuid();
  INSERT INTO programme_lineages (id, code, created_by)
  VALUES (v_private_lineage, 'PROG-GATE-J-PRIV', 'gate-j');
  INSERT INTO programme_versions (
    id, lineage_id, version_number, lifecycle_status, library_scope, owner_type, owner_id,
    created_by, name, approved_for_global, approved_for_adaptation
  ) VALUES (
    v_private, v_private_lineage, 1, 'draft', 'coach_private', 'coach', 'gate-coach',
    'gate-j', 'Private Draft', FALSE, FALSE
  );
  INSERT INTO programme_version_weeks (id, version_id, week_number, title)
  VALUES (gen_random_uuid(), v_private, 1, 'W1');
  INSERT INTO programme_version_days (id, week_id, day_key, day_order, day_type)
  SELECT gen_random_uuid(), w.id, 'day_1', 1, 'rest'
  FROM programme_version_weeks w WHERE w.version_id = v_private LIMIT 1;
  UPDATE programme_versions
  SET lifecycle_status = 'published', published_at = NOW()
  WHERE id = v_private;

  -- Auth users + athlete profiles
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_super_admin,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_athlete_a, 'authenticated', 'authenticated',
     'gate-j-a@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', v_athlete_b, 'authenticated', 'authenticated',
     'gate-j-b@example.invalid', crypt('x', gen_salt('bf')), NOW(), NOW(), NOW(),
     '{"provider":"email","providers":["email"]}', '{}', FALSE, '', '', '', '')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES
    (v_athlete_a, 'Gate Athlete A', TRUE, FALSE),
    (v_athlete_b, 'Gate Athlete B', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete, is_coach = EXCLUDED.is_coach;

  -- Anon execute denied
  BEGIN
    PERFORM set_config('role', 'anon', true);
    v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'UTC', FALSE);
    PERFORM sprint12_record('J','anon_execute','permission_denied', coalesce(v_res->>'status','executed'), NULL, FALSE, 'anon executed');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('J','anon_execute','permission_denied','permission_denied', TRUE, TRUE, 'EXECUTE denied');
  WHEN OTHERS THEN
    PERFORM sprint12_record('J','anon_execute','permission_denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Athlete A enrols eligible
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'J','enrol_eligible','enrolled', v_res->>'status',
    NULL, (v_res->>'status') = 'enrolled' AND (v_res->>'programme_version_id') = v_eligible::text,
    v_res::text
  );
  v_enrol_a := (v_res->>'enrolment_id')::uuid;

  -- Exact version + non_commercial_test source
  SELECT count(*) INTO v_count
  FROM programme_assignments
  WHERE id = v_enrol_a
    AND athlete_id = v_athlete_a
    AND programme_version_id = v_eligible
    AND enrolment_source = 'non_commercial_test'
    AND status = 'active';
  PERFORM sprint12_record('J','exact_version_persisted','1', v_count::text, NULL, v_count = 1, NULL);

  -- Idempotent repeat
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'J','idempotent_repeat','already_enrolled', v_res->>'status',
    NULL, (v_res->>'status') = 'already_enrolled' AND (v_res->>'enrolment_id') = v_enrol_a::text,
    v_res::text
  );
  SELECT count(*) INTO v_count FROM programme_assignments WHERE athlete_id = v_athlete_a AND status = 'active';
  PERFORM sprint12_record('J','idempotent_one_active','1', v_count::text, NULL, v_count = 1, NULL);

  -- Draft denied
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_draft, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'J','deny_draft','version_not_catalogue_eligible', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'version_not_catalogue_eligible', v_res::text
  );

  -- Unapproved denied
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_unapproved, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'J','deny_unapproved','version_not_catalogue_eligible', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'version_not_catalogue_eligible', v_res::text
  );

  -- Wrong scope denied
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_private, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record(
    'J','deny_wrong_scope','version_not_catalogue_eligible', coalesce(v_res->>'code', v_res->>'status'),
    NULL, (v_res->>'code') = 'version_not_catalogue_eligible', v_res::text
  );

  -- Athlete B independent enrolment
  PERFORM set_config('request.jwt.claim.sub', v_athlete_b::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_res := public.enrol_athlete_in_catalogue_programme_version(v_eligible, 'UTC', FALSE);
  PERFORM set_config('role', 'postgres', true);
  v_enrol_b := (v_res->>'enrolment_id')::uuid;
  PERFORM sprint12_record(
    'J','athlete_b_enrol','enrolled', v_res->>'status',
    NULL, (v_res->>'status') = 'enrolled' AND v_enrol_b IS DISTINCT FROM v_enrol_a, v_res::text
  );

  -- Athlete A cannot read B via RLS
  PERFORM set_config('request.jwt.claim.sub', v_athlete_a::text, true);
  PERFORM set_config('role', 'authenticated', true);
  SELECT count(*) INTO v_count FROM programme_assignments WHERE id = v_enrol_b;
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record('J','isolation_a_cannot_read_b','0', v_count::text, NULL, v_count = 0, NULL);

  -- No payment/subscription tables touched (none exist); package hash unchanged
  SELECT package_content_hash INTO v_hash_after FROM programme_versions WHERE id = v_eligible;
  PERFORM sprint12_record(
    'J','package_immutable', v_hash_before, coalesce(v_hash_after,''),
    NULL, v_hash_before IS NOT DISTINCT FROM v_hash_after, NULL
  );

  -- Import/publish still service_role only
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM public.publish_cohort_global_programme_version(v_draft, 'gate-j');
    PERFORM sprint12_record('J','publish_still_denied','permission_denied','executed', NULL, FALSE, 'authenticated published');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('J','publish_still_denied','permission_denied','permission_denied', TRUE, TRUE, NULL);
  WHEN OTHERS THEN
    PERFORM sprint12_record('J','publish_still_denied','permission_denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  -- No subscription/purchase tables created by this sprint
  PERFORM sprint12_record(
    'J','no_commerce_tables','absent',
    CASE WHEN to_regclass('public.subscriptions') IS NULL
              AND to_regclass('public.purchases') IS NULL
              AND to_regclass('public.payment_transactions') IS NULL
         THEN 'absent' ELSE 'present' END,
    NULL,
    to_regclass('public.subscriptions') IS NULL
      AND to_regclass('public.purchases') IS NULL
      AND to_regclass('public.payment_transactions') IS NULL,
    NULL
  );
END;
$$;

SELECT gate, assertion, expected, actual, passed, notes
FROM sprint12_gate_results
WHERE gate = 'J'
ORDER BY assertion;

SELECT sprint12_fail_if_any_failed();
