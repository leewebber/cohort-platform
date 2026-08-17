-- Gate R — atomic catalogue replacement, rollback, authority and history.
-- Requires helpers.sql. Runs only against the disposable local database.

TRUNCATE sprint12_gate_results;

DROP TABLE IF EXISTS sprint12_gate_r_fixture;
CREATE TABLE sprint12_gate_r_fixture (
  fixture_key TEXT PRIMARY KEY,
  retiring_version_id UUID NOT NULL,
  replacement_a_id UUID NOT NULL,
  replacement_b_id UUID NOT NULL
);

CREATE OR REPLACE FUNCTION sprint12_gate_r_reject_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.id = TG_ARGV[0]::UUID AND NEW.approved_for_global = TRUE THEN
    RAISE EXCEPTION 'Gate R injected replacement failure'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_gate_r_reject_retirement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.id = TG_ARGV[0]::UUID
     AND NEW.lifecycle_status = 'archived'
     AND OLD.lifecycle_status = 'published'
  THEN
    RAISE EXCEPTION 'Gate R injected retirement failure'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-R-R1';
  v_session_lineage UUID := '88888888-8888-4888-8888-888888888888';
  v_lineage_code TEXT := 'PROG-GATE-R-ATOMIC';
  v_other_code TEXT := 'PROG-GATE-R-OTHER';
  v_res JSONB;
  v_v1 UUID;
  v_v2 UUID;
  v_v3 UUID;
  v_v4 UUID;
  v_other UUID;
  v_athlete UUID := 'a8000000-0000-4000-8000-000000000008';
  v_assignment UUID := gen_random_uuid();
  v_slot UUID;
  v_v1_hash TEXT;
  v_v1_counts JSONB;
  v_history_ok BOOLEAN;
  v_state_ok BOOLEAN;
  v_eligible_count INT;
BEGIN
  PERFORM sprint12_ensure_published_session(
    v_protocol,
    v_session_lineage,
    1,
    'Gate R Session'
  );

  -- Create four exact immutable package versions in one lineage and one
  -- wrong-lineage version through the trusted import/publication boundaries.
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(
    sprint12_build_package(
      v_lineage_code, 1, sprint12_hash('gate-r-v1'),
      v_protocol, v_session_lineage
    )
  );
  v_v1 := NULLIF(v_res->>'programme_version_id', '')::UUID;
  v_res := public.publish_cohort_global_programme_version(v_v1, 'gate-r');
  v_res := public.approve_cohort_global_programme_version(v_v1, 'gate-r');

  v_res := public.import_authored_plan_package(
    sprint12_build_package(
      v_lineage_code, 2, sprint12_hash('gate-r-v2'),
      v_protocol, v_session_lineage
    )
  );
  v_v2 := NULLIF(v_res->>'programme_version_id', '')::UUID;
  v_res := public.publish_cohort_global_programme_version(v_v2, 'gate-r');

  v_res := public.import_authored_plan_package(
    sprint12_build_package(
      v_lineage_code, 3, sprint12_hash('gate-r-v3'),
      v_protocol, v_session_lineage
    )
  );
  v_v3 := NULLIF(v_res->>'programme_version_id', '')::UUID;

  v_res := public.import_authored_plan_package(
    sprint12_build_package(
      v_lineage_code, 4, sprint12_hash('gate-r-v4'),
      v_protocol, v_session_lineage
    )
  );
  v_v4 := NULLIF(v_res->>'programme_version_id', '')::UUID;

  v_res := public.import_authored_plan_package(
    sprint12_build_package(
      v_other_code, 1, sprint12_hash('gate-r-other'),
      v_protocol, v_session_lineage
    )
  );
  v_other := NULLIF(v_res->>'programme_version_id', '')::UUID;
  v_res := public.publish_cohort_global_programme_version(v_other, 'gate-r');
  PERFORM set_config('role', 'postgres', true);

  SELECT package_content_hash, sprint12_package_counts(id)
  INTO v_v1_hash, v_v1_counts
  FROM programme_versions
  WHERE id = v_v1;

  SELECT s.id INTO v_slot
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id = s.day_id
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_v1
  LIMIT 1;

  -- Assignment and slot audit protect exact historical v1 references.
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_athlete,
    'authenticated',
    'authenticated',
    'gate-r@example.invalid',
    crypt('x', gen_salt('bf')),
    NOW(), NOW(), NOW(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    FALSE, '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id, display_name, is_athlete, is_coach)
  VALUES (v_athlete, 'Gate R Athlete', TRUE, FALSE)
  ON CONFLICT (id) DO UPDATE
    SET is_athlete = EXCLUDED.is_athlete,
        is_coach = EXCLUDED.is_coach;

  INSERT INTO programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    timezone, current_week_number, current_day_key, current_slot_order
  ) VALUES (
    v_assignment, v_athlete,
    v_v1, v_lineage_code, 'active',
    CURRENT_DATE, 'UTC', 1, 'day_1', 1
  );
  INSERT INTO programme_slot_outcomes (
    assignment_id, session_slot_id, week_number, day_key, session_order,
    outcome_status
  ) VALUES (
    v_assignment, v_slot, 1, 'day_1', 1, 'in_progress'
  );

  -- Anonymous and ordinary athletes have no execution authority.
  BEGIN
    PERFORM set_config('role', 'anon', true);
    v_res := public.replace_approved_cohort_global_programme_version(
      v_v1, v_v2, 'gate-r'
    );
    PERFORM sprint12_record(
      'R', 'anon_denied', 'permission_denied',
      COALESCE(v_res->>'status', 'executed'), NULL, FALSE
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record(
      'R', 'anon_denied', 'permission_denied',
      'permission_denied', TRUE, TRUE
    );
  END;
  PERFORM set_config('role', 'postgres', true);

  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    v_res := public.replace_approved_cohort_global_programme_version(
      v_v1, v_v2, 'gate-r'
    );
    PERFORM sprint12_record(
      'R', 'authenticated_denied', 'permission_denied',
      COALESCE(v_res->>'status', 'executed'), NULL, FALSE
    );
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record(
      'R', 'authenticated_denied', 'permission_denied',
      'permission_denied', TRUE, TRUE
    );
  END;
  PERFORM set_config('role', 'postgres', true);

  -- Wrong lineage and draft replacement both fail without mutation.
  PERFORM set_config('role', 'service_role', true);
  v_res := public.replace_approved_cohort_global_programme_version(
    v_v1, v_other, 'gate-r'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'R', 'wrong_lineage', 'wrong_lineage', v_res->>'code'
  );

  PERFORM set_config('role', 'service_role', true);
  v_res := public.replace_approved_cohort_global_programme_version(
    v_v1, v_v3, 'gate-r'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'R', 'draft_replacement', 'invalid_replacement', v_res->>'code'
  );

  -- First replacement: v1 retires+unapproves and v2 becomes sole eligible.
  PERFORM set_config('role', 'service_role', true);
  v_res := public.replace_approved_cohort_global_programme_version(
    v_v1, v_v2, 'gate-r'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'R', 'replace_success', 'replaced', v_res->>'status'
  );

  SELECT
    (SELECT lifecycle_status = 'archived'
            AND approved_for_global = FALSE
            AND archived_at IS NOT NULL
     FROM programme_versions WHERE id = v_v1)
    AND
    (SELECT lifecycle_status = 'published'
            AND approved_for_global = TRUE
            AND archived_at IS NULL
     FROM programme_versions WHERE id = v_v2)
  INTO v_state_ok;
  PERFORM sprint12_record(
    'R', 'atomic_state', 'retired_and_replaced',
    CASE WHEN v_state_ok THEN 'retired_and_replaced' ELSE 'invalid' END,
    v_state_ok, v_state_ok
  );

  -- Historical package identity/content and assignment/session audit survive.
  SELECT
    pv.package_content_hash = v_v1_hash
    AND sprint12_package_counts(pv.id) = v_v1_counts
    AND EXISTS (
      SELECT 1 FROM programme_assignments a
      WHERE a.id = v_assignment AND a.programme_version_id = v_v1
    )
    AND EXISTS (
      SELECT 1 FROM programme_slot_outcomes o
      WHERE o.assignment_id = v_assignment AND o.session_slot_id = v_slot
    )
  INTO v_history_ok
  FROM programme_versions pv
  WHERE pv.id = v_v1;
  PERFORM sprint12_record(
    'R', 'historical_resolution', 'unchanged',
    CASE WHEN v_history_ok THEN 'unchanged' ELSE 'changed' END,
    v_history_ok, v_history_ok
  );

  -- Exact retry is idempotent.
  PERFORM set_config('role', 'service_role', true);
  v_res := public.replace_approved_cohort_global_programme_version(
    v_v1, v_v2, 'gate-r'
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'R', 'idempotent_retry', 'already_replaced', v_res->>'status'
  );

  -- Hosted reconciliation shape: two approved versions before uniqueness.
  -- Temporarily drop the pending unique index so the exact beta state can be
  -- reproduced, then reinstall it after reconciliation.
  DROP INDEX IF EXISTS public.idx_programme_versions_one_catalogue_eligible_per_lineage;

  DECLARE
    v_recon_code TEXT := 'PROG-GATE-R-RECON';
    v_recon_a UUID;
    v_recon_b UUID;
    v_recon_snapshot JSONB;
    v_recon_updated_at TIMESTAMPTZ;
    v_recon_hash TEXT;
    v_after_snapshot JSONB;
    v_after_updated_at TIMESTAMPTZ;
    v_after_hash TEXT;
  BEGIN
    PERFORM set_config('role', 'service_role', true);
    v_res := public.import_authored_plan_package(
      sprint12_build_package(
        v_recon_code, 1, sprint12_hash('gate-r-recon-a'),
        v_protocol, v_session_lineage
      )
    );
    v_recon_a := NULLIF(v_res->>'programme_version_id', '')::UUID;
    v_res := public.publish_cohort_global_programme_version(v_recon_a, 'gate-r');
    v_res := public.approve_cohort_global_programme_version(v_recon_a, 'gate-r');

    v_res := public.import_authored_plan_package(
      sprint12_build_package(
        v_recon_code, 2, sprint12_hash('gate-r-recon-b'),
        v_protocol, v_session_lineage
      )
    );
    v_recon_b := NULLIF(v_res->>'programme_version_id', '')::UUID;
    v_res := public.publish_cohort_global_programme_version(v_recon_b, 'gate-r');
    PERFORM set_config('role', 'postgres', true);

    -- Second eligible approval via the same whitelist path used historically
    -- before uniqueness; mirrors hosted beta's two-approved Spartan state.
    UPDATE public.programme_versions
    SET approved_for_global = TRUE,
        updated_at = NOW()
    WHERE id = v_recon_b;

    SELECT COUNT(*) INTO v_eligible_count
    FROM programme_versions
    WHERE lineage_id = (SELECT lineage_id FROM programme_versions WHERE id = v_recon_a)
      AND lifecycle_status = 'published'
      AND library_scope = 'cohort_global'
      AND owner_type = 'global'
      AND approved_for_global = TRUE
      AND archived_at IS NULL;
    PERFORM sprint12_record(
      'R', 'hosted_two_approved_shape', '2',
      v_eligible_count::TEXT, v_eligible_count = 2, v_eligible_count = 2
    );

    SELECT to_jsonb(pv.*), pv.updated_at, pv.package_content_hash
    INTO v_recon_snapshot, v_recon_updated_at, v_recon_hash
    FROM programme_versions pv
    WHERE pv.id = v_recon_b;

    -- Intermediate failure after retirement must restore both rows completely.
    EXECUTE format(
      'CREATE TRIGGER zz_sprint12_gate_r_reject_retirement '
      'AFTER UPDATE ON public.programme_versions '
      'FOR EACH ROW EXECUTE FUNCTION sprint12_gate_r_reject_retirement(%L)',
      v_recon_a::TEXT
    );
    PERFORM set_config('role', 'service_role', true);
    v_res := public.replace_approved_cohort_global_programme_version(
      v_recon_a, v_recon_b, 'gate-r'
    );
    PERFORM set_config('role', 'postgres', true);
    DROP TRIGGER zz_sprint12_gate_r_reject_retirement ON programme_versions;

    SELECT
      (SELECT lifecycle_status = 'published' AND approved_for_global = TRUE
       FROM programme_versions WHERE id = v_recon_a)
      AND
      (SELECT lifecycle_status = 'published' AND approved_for_global = TRUE
              AND updated_at = v_recon_updated_at
              AND package_content_hash = v_recon_hash
       FROM programme_versions WHERE id = v_recon_b)
    INTO v_state_ok;
    PERFORM sprint12_record(
      'R', 'already_approved_rollback', 'atomic_replacement_rolled_back',
      v_res->>'code', v_state_ok,
      v_res->>'code' = 'atomic_replacement_rolled_back' AND v_state_ok
    );

    PERFORM set_config('role', 'service_role', true);
    v_res := public.replace_approved_cohort_global_programme_version(
      v_recon_a, v_recon_b, 'gate-r'
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_assert_eq(
      'R', 'already_approved_replace', 'replaced', v_res->>'status'
    );
    PERFORM sprint12_assert_eq(
      'R', 'already_approved_satisfied', 'already_satisfied',
      v_res->>'replacement_approval'
    );

    SELECT to_jsonb(pv.*), pv.updated_at, pv.package_content_hash
    INTO v_after_snapshot, v_after_updated_at, v_after_hash
    FROM programme_versions pv
    WHERE pv.id = v_recon_b;

    PERFORM sprint12_record(
      'R', 'already_approved_no_update', 'unchanged',
      CASE
        WHEN v_after_snapshot = v_recon_snapshot
             AND v_after_updated_at = v_recon_updated_at
             AND v_after_hash = v_recon_hash
        THEN 'unchanged'
        ELSE 'mutated'
      END,
      v_after_snapshot = v_recon_snapshot
        AND v_after_updated_at = v_recon_updated_at
        AND v_after_hash = v_recon_hash,
      v_after_snapshot = v_recon_snapshot
        AND v_after_updated_at = v_recon_updated_at
        AND v_after_hash = v_recon_hash
    );

    SELECT
      (SELECT lifecycle_status = 'archived'
              AND approved_for_global = FALSE
              AND archived_at IS NOT NULL
       FROM programme_versions WHERE id = v_recon_a)
      AND
      (SELECT lifecycle_status = 'published'
              AND approved_for_global = TRUE
              AND archived_at IS NULL
       FROM programme_versions WHERE id = v_recon_b)
    INTO v_state_ok;
    PERFORM sprint12_record(
      'R', 'already_approved_atomic_state', 'retired_and_sole',
      CASE WHEN v_state_ok THEN 'retired_and_sole' ELSE 'invalid' END,
      v_state_ok, v_state_ok
    );

    SELECT COUNT(*) INTO v_eligible_count
    FROM programme_versions
    WHERE lineage_id = (SELECT lineage_id FROM programme_versions WHERE id = v_recon_b)
      AND lifecycle_status = 'published'
      AND library_scope = 'cohort_global'
      AND owner_type = 'global'
      AND approved_for_global = TRUE
      AND archived_at IS NULL;
    PERFORM sprint12_record(
      'R', 'already_approved_sole_eligible', '1',
      v_eligible_count::TEXT, v_eligible_count = 1, v_eligible_count = 1
    );

    PERFORM set_config('role', 'service_role', true);
    v_res := public.replace_approved_cohort_global_programme_version(
      v_recon_a, v_recon_b, 'gate-r'
    );
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_assert_eq(
      'R', 'already_approved_idempotent', 'already_replaced', v_res->>'status'
    );

    SELECT to_jsonb(pv.*), pv.updated_at
    INTO v_after_snapshot, v_after_updated_at
    FROM programme_versions pv
    WHERE pv.id = v_recon_b;
    PERFORM sprint12_record(
      'R', 'already_approved_idempotent_no_mutation', 'unchanged',
      CASE
        WHEN v_after_snapshot = v_recon_snapshot
             AND v_after_updated_at = v_recon_updated_at
        THEN 'unchanged'
        ELSE 'mutated'
      END,
      v_after_snapshot = v_recon_snapshot
        AND v_after_updated_at = v_recon_updated_at,
      v_after_snapshot = v_recon_snapshot
        AND v_after_updated_at = v_recon_updated_at
    );
  END;

  CREATE UNIQUE INDEX idx_programme_versions_one_catalogue_eligible_per_lineage
    ON public.programme_versions (lineage_id)
    WHERE lifecycle_status = 'published'
      AND library_scope = 'cohort_global'
      AND owner_type = 'global'
      AND approved_for_global = TRUE
      AND archived_at IS NULL;
  PERFORM sprint12_record(
    'R', 'uniqueness_installs_after_recon', 'installed', 'installed', TRUE, TRUE
  );

  -- Publish v3/v4. Direct approval cannot create a competing version.
  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_cohort_global_programme_version(v_v3, 'gate-r');
  v_res := public.publish_cohort_global_programme_version(v_v4, 'gate-r');
  v_res := public.approve_cohort_global_programme_version(v_v3, 'gate-r');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq(
    'R', 'second_direct_approval', 'conflicting_eligible_version',
    v_res->>'code'
  );

  -- Inject a failure after retirement but before replacement approval. The
  -- nested RPC subtransaction must restore both rows completely.
  EXECUTE format(
    'CREATE TRIGGER zz_sprint12_gate_r_reject_approval '
    'BEFORE UPDATE ON public.programme_versions '
    'FOR EACH ROW EXECUTE FUNCTION sprint12_gate_r_reject_approval(%L)',
    v_v3::TEXT
  );
  PERFORM set_config('role', 'service_role', true);
  v_res := public.replace_approved_cohort_global_programme_version(
    v_v2, v_v3, 'gate-r'
  );
  PERFORM set_config('role', 'postgres', true);
  DROP TRIGGER zz_sprint12_gate_r_reject_approval ON programme_versions;

  SELECT
    (SELECT lifecycle_status = 'published' AND approved_for_global = TRUE
     FROM programme_versions WHERE id = v_v2)
    AND
    (SELECT lifecycle_status = 'published' AND approved_for_global = FALSE
     FROM programme_versions WHERE id = v_v3)
  INTO v_state_ok;
  PERFORM sprint12_record(
    'R', 'rollback_all_fields', 'atomic_replacement_rolled_back',
    v_res->>'code', v_state_ok,
    v_res->>'code' = 'atomic_replacement_rolled_back' AND v_state_ok
  );

  SELECT COUNT(*) INTO v_eligible_count
  FROM programme_versions
  WHERE lineage_id = (SELECT lineage_id FROM programme_versions WHERE id = v_v2)
    AND lifecycle_status = 'published'
    AND library_scope = 'cohort_global'
    AND owner_type = 'global'
    AND approved_for_global = TRUE
    AND archived_at IS NULL;
  PERFORM sprint12_record(
    'R', 'sole_eligible_before_concurrency', '1',
    v_eligible_count::TEXT, v_eligible_count = 1, v_eligible_count = 1
  );

  INSERT INTO sprint12_gate_r_fixture (
    fixture_key, retiring_version_id, replacement_a_id, replacement_b_id
  ) VALUES ('concurrency', v_v2, v_v3, v_v4);
END;
$$;

DROP FUNCTION sprint12_gate_r_reject_approval();
DROP FUNCTION sprint12_gate_r_reject_retirement();

SELECT sprint12_fail_if_any_failed();

SELECT gate, case_id, expected, actual, persisted_ok, pass
FROM sprint12_gate_results
ORDER BY gate, case_id;
