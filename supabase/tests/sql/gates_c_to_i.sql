-- Live PostgreSQL behavioural gates C–I (custom assertions; not pgTAP).
-- Requires helpers.sql already loaded. ON_ERROR_STOP expected by caller.
TRUNCATE sprint12_gate_results;

DO $$
DECLARE
  v_protocol TEXT := 'PROT-GATE-SQUAT-R1';
  v_lineage UUID := '22222222-2222-2222-2222-222222222222';
  v_hash TEXT;
  v_payload JSONB;
  v_payload2 JSONB;
  v_res JSONB;
  v_vid UUID;
  v_counts JSONB;
  v_status TEXT;
  v_ok BOOLEAN;
  v_before INT;
  v_after INT;
  v_week_id UUID;
  v_day_id UUID;
  v_slot_id UUID;
  v_alt_week UUID;
  v_alt_day UUID;
  v_foreign_week UUID;
  v_foreign_day UUID;
  v_coach_lineage UUID;
  v_coach_version UUID;
  v_draft UUID;
  v_approved UUID;
  v_pub_unapproved UUID;
  lineage TEXT;
  domains TEXT[];
  d TEXT;
  cases JSONB;
  c JSONB;
  mut TEXT;
  phases JSONB;
  weeks JSONB;
  child_tables TEXT[];
  child TEXT;
  trg TEXT;
  v_counts_pre JSONB;
  v_pre_ok BOOLEAN;
  v_phase_id UUID;
  v_text TEXT;
BEGIN
  PERFORM sprint12_ensure_published_session(v_protocol, v_lineage, 1, 'Gate Squat A');

  -- Self-contained coach-private fixture (no Gate B hard-coded dependency).
  v_coach_lineage := gen_random_uuid();
  v_coach_version := gen_random_uuid();
  INSERT INTO programme_lineages (id, code, created_by)
  VALUES (v_coach_lineage, 'PROG-GATE-COACH-PRIVATE-' || substr(v_coach_lineage::text, 1, 8), 'gate-coach');
  INSERT INTO programme_versions (
    id, lineage_id, version_number, lifecycle_status, library_scope, owner_type, owner_id,
    created_by, name, description, approved_for_global, approved_for_adaptation
  ) VALUES (
    v_coach_version, v_coach_lineage, 1, 'draft', 'coach_private', 'coach', 'gate-coach',
    'gate-coach', 'Gate Coach Private Draft', 'Self-contained fixture', FALSE, FALSE
  );

  -- =========================================================================
  -- Gate C — Import / replay / role EXECUTE denial
  -- =========================================================================
  v_hash := sprint12_hash('gate-c-base');
  v_payload := sprint12_build_package('PROG-GATE-C-01', 1, v_hash, v_protocol, v_lineage);

  BEGIN
    PERFORM set_config('role', 'anon', true);
    v_res := public.import_authored_plan_package(v_payload);
    PERFORM sprint12_record('C','anon_execute','permission_denied', coalesce(v_res->>'status','executed'), NULL, FALSE, 'anon unexpectedly executed');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('C','anon_execute','permission_denied','permission_denied', TRUE, TRUE, 'EXECUTE denied');
  WHEN OTHERS THEN
    PERFORM sprint12_record('C','anon_execute','permission_denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    v_res := public.import_authored_plan_package(v_payload);
    PERFORM sprint12_record('C','authenticated_execute','permission_denied', coalesce(v_res->>'status','executed'), NULL, FALSE, 'authenticated unexpectedly executed');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM sprint12_record('C','authenticated_execute','permission_denied','permission_denied', TRUE, TRUE, 'EXECUTE denied');
  WHEN OTHERS THEN
    PERFORM sprint12_record('C','authenticated_execute','permission_denied', SQLSTATE, NULL, (SQLSTATE = '42501'), SQLERRM);
  END;
  PERFORM set_config('role', 'postgres', true);

  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_status := v_res->>'status';
  v_vid := NULLIF(v_res->>'programme_version_id','')::UUID;
  v_ok := (v_status = 'imported_draft' AND v_vid IS NOT NULL);
  IF v_ok THEN
    SELECT lifecycle_status = 'draft' AND library_scope = 'cohort_global' AND owner_type = 'global'
           AND owner_id IS NULL AND approved_for_global = FALSE
           AND package_content_hash = v_hash AND published_at IS NULL
    INTO v_ok FROM programme_versions WHERE id = v_vid;
    v_counts := sprint12_package_counts(v_vid);
    v_ok := v_ok
      AND (v_counts->>'phases')::INT = 1 AND (v_counts->>'weeks')::INT = 1
      AND (v_counts->>'days')::INT = 1 AND (v_counts->>'slots')::INT = 1
      AND (v_counts->>'adaptations')::INT = 1 AND (v_counts->>'invariants')::INT = 1
      AND (v_counts->>'assessments')::INT = 1 AND (v_counts->>'evidence')::INT = 1
      AND (v_counts->>'comparisons')::INT = 1;
  END IF;
  PERFORM sprint12_record('C','first_import_service_role','imported_draft', v_status, v_ok, v_ok AND v_status='imported_draft', v_counts::TEXT);

  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) = 1 INTO v_ok FROM programme_versions pv
  JOIN programme_lineages pl ON pl.id = pv.lineage_id
  WHERE pl.code = 'PROG-GATE-C-01' AND pv.version_number = 1;
  v_ok := v_ok AND v_res->>'status' = 'idempotent_existing_draft';
  PERFORM sprint12_record('C','exact_replay','idempotent_existing_draft', v_res->>'status', v_ok, v_ok, NULL);

  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(
    jsonb_set(v_payload, '{package_content_hash}', to_jsonb(sprint12_hash('different-hash')))
  );
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('C','different_hash_collision','version_collision', v_res->>'status', v_res->>'code');

  -- =========================================================================
  -- Gate D — Completeness (substantive malformed-state cases + one setup assert)
  -- Setup: setup_seed_complete_import
  -- Substantive: hollow + missing_* + extra_* + reparented_* + altered_* + ownership
  -- Every substantive case proves pre-persisted counterexample + post-conflict no-repair.
  -- =========================================================================
  v_hash := sprint12_hash('gate-d-complete');
  lineage := 'PROG-GATE-D-01';
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  PERFORM sprint12_record(
    'D','setup_seed_complete_import','imported_draft', v_res->>'status',
    v_res->>'status' = 'imported_draft', v_res->>'status' = 'imported_draft',
    'SETUP/helper only — not a malformed-state completeness case'
  );

  -- hollow_graph: delete all structure/children; prove remains hollow after conflict
  DELETE FROM programme_version_evidence_requirements WHERE version_id = v_vid;
  DELETE FROM programme_version_assessments WHERE version_id = v_vid;
  DELETE FROM programme_version_protected_invariants WHERE version_id = v_vid;
  DELETE FROM programme_version_adaptation_permissions WHERE version_id = v_vid;
  DELETE FROM programme_version_comparison_identities WHERE version_id = v_vid;
  DELETE FROM programme_version_session_slots s USING programme_version_days d, programme_version_weeks w
    WHERE s.day_id=d.id AND d.week_id=w.id AND w.version_id=v_vid;
  DELETE FROM programme_version_days d USING programme_version_weeks w WHERE d.week_id=w.id AND w.version_id=v_vid;
  DELETE FROM programme_version_weeks WHERE version_id=v_vid;
  DELETE FROM programme_version_phases WHERE version_id=v_vid;
  v_counts_pre := sprint12_package_counts(v_vid);
  v_pre_ok := (v_counts_pre->>'phases')::INT = 0 AND (v_counts_pre->>'weeks')::INT = 0
          AND (v_counts_pre->>'days')::INT = 0 AND (v_counts_pre->>'slots')::INT = 0
          AND (v_counts_pre->>'adaptations')::INT = 0 AND (v_counts_pre->>'invariants')::INT = 0
          AND (v_counts_pre->>'assessments')::INT = 0 AND (v_counts_pre->>'evidence')::INT = 0
          AND (v_counts_pre->>'comparisons')::INT = 0;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'hollow_graph', v_res, v_vid, lineage, v_counts_pre, v_pre_ok,
    'pre_hollow_ok=' || v_pre_ok::text || '; no domain rows recreated'
  );

  domains := ARRAY['phase','week','day','slot','adaptation','invariant','assessment','evidence','comparison'];
  FOREACH d IN ARRAY domains LOOP
    lineage := 'PROG-GATE-D-MISS-' || d;
    v_hash := sprint12_hash('gate-d-miss-' || d);
    v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
    PERFORM set_config('role', 'service_role', true);
    v_res := public.import_authored_plan_package(v_payload);
    PERFORM set_config('role', 'postgres', true);
    v_vid := (v_res->>'programme_version_id')::UUID;
    IF d = 'phase' THEN
      DELETE FROM programme_version_phases WHERE version_id = v_vid;
      UPDATE programme_version_weeks SET phase_id = NULL WHERE version_id = v_vid;
    ELSIF d = 'week' THEN
      DELETE FROM programme_version_session_slots s USING programme_version_days dd, programme_version_weeks w
        WHERE s.day_id=dd.id AND dd.week_id=w.id AND w.version_id=v_vid;
      DELETE FROM programme_version_days dd USING programme_version_weeks w WHERE dd.week_id=w.id AND w.version_id=v_vid;
      DELETE FROM programme_version_weeks WHERE version_id=v_vid;
    ELSIF d = 'day' THEN
      DELETE FROM programme_version_session_slots s USING programme_version_days dd, programme_version_weeks w
        WHERE s.day_id=dd.id AND dd.week_id=w.id AND w.version_id=v_vid;
      DELETE FROM programme_version_days dd USING programme_version_weeks w WHERE dd.week_id=w.id AND w.version_id=v_vid;
    ELSIF d = 'slot' THEN
      DELETE FROM programme_version_session_slots s USING programme_version_days dd, programme_version_weeks w
        WHERE s.day_id=dd.id AND dd.week_id=w.id AND w.version_id=v_vid;
    ELSIF d = 'adaptation' THEN
      DELETE FROM programme_version_adaptation_permissions WHERE version_id=v_vid;
    ELSIF d = 'invariant' THEN
      DELETE FROM programme_version_protected_invariants WHERE version_id=v_vid;
    ELSIF d = 'assessment' THEN
      DELETE FROM programme_version_assessments WHERE version_id=v_vid;
    ELSIF d = 'evidence' THEN
      DELETE FROM programme_version_evidence_requirements WHERE version_id=v_vid;
    ELSIF d = 'comparison' THEN
      DELETE FROM programme_version_evidence_requirements WHERE version_id=v_vid;
      DELETE FROM programme_version_assessments WHERE version_id=v_vid;
      DELETE FROM programme_version_comparison_identities WHERE version_id=v_vid;
    END IF;
    v_counts_pre := sprint12_package_counts(v_vid);
    IF d = 'phase' THEN
      v_pre_ok := (v_counts_pre->>'phases')::INT = 0;
    ELSIF d = 'week' THEN
      v_pre_ok := (v_counts_pre->>'weeks')::INT = 0 AND (v_counts_pre->>'days')::INT = 0 AND (v_counts_pre->>'slots')::INT = 0;
    ELSIF d = 'day' THEN
      v_pre_ok := (v_counts_pre->>'days')::INT = 0 AND (v_counts_pre->>'slots')::INT = 0;
    ELSIF d = 'slot' THEN
      v_pre_ok := (v_counts_pre->>'slots')::INT = 0;
    ELSIF d = 'adaptation' THEN
      v_pre_ok := (v_counts_pre->>'adaptations')::INT = 0;
    ELSIF d = 'invariant' THEN
      v_pre_ok := (v_counts_pre->>'invariants')::INT = 0;
    ELSIF d = 'assessment' THEN
      v_pre_ok := (v_counts_pre->>'assessments')::INT = 0;
    ELSIF d = 'evidence' THEN
      v_pre_ok := (v_counts_pre->>'evidence')::INT = 0;
    ELSE
      v_pre_ok := (v_counts_pre->>'comparisons')::INT = 0
             AND (v_counts_pre->>'assessments')::INT = 0
             AND (v_counts_pre->>'evidence')::INT = 0;
    END IF;
    PERFORM set_config('role', 'service_role', true);
    v_res := public.import_authored_plan_package(v_payload);
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record_d_no_repair(
      'missing_'||d, v_res, v_vid, lineage, v_counts_pre, v_pre_ok,
      'pre_missing_'||d||'='||v_pre_ok::text||'; deleted domain not recreated; extras not removed'
    );
  END LOOP;

  -- extra_adaptation
  lineage := 'PROG-GATE-D-EXADP';
  v_hash := sprint12_hash('gate-d-extra-adp');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  INSERT INTO programme_version_adaptation_permissions(version_id, permission_key, change_kind, target_ref, athlete_agreement_required)
  VALUES (v_vid, 'ADP-EXTRA', 'reduce_volume', 'programme', TRUE);
  v_counts_pre := sprint12_package_counts(v_vid);
  v_pre_ok := (v_counts_pre->>'adaptations')::INT = 2
         AND EXISTS (SELECT 1 FROM programme_version_adaptation_permissions WHERE version_id=v_vid AND permission_key='ADP-EXTRA');
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'extra_adaptation', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_adaptation_permissions WHERE version_id=v_vid AND permission_key='ADP-EXTRA'),
    'extra adaptation row retained'
  );

  -- extra_phase
  lineage := 'PROG-GATE-D-EXPHASE';
  v_hash := sprint12_hash('gate-d-exphase');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  INSERT INTO programme_version_phases(version_id, phase_order, title) VALUES (v_vid, 2, 'Extra')
  RETURNING id INTO v_phase_id;
  v_counts_pre := sprint12_package_counts(v_vid);
  v_pre_ok := (v_counts_pre->>'phases')::INT = 2 AND EXISTS (SELECT 1 FROM programme_version_phases WHERE id=v_phase_id);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'extra_phase', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_phases WHERE id=v_phase_id AND title='Extra'),
    'extra phase row retained'
  );

  -- extra_week
  lineage := 'PROG-GATE-D-EXWEEK';
  v_hash := sprint12_hash('gate-d-exweek');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  INSERT INTO programme_version_weeks(version_id, week_number, title) VALUES (v_vid, 2, 'Extra Week')
  RETURNING id INTO v_alt_week;
  v_counts_pre := sprint12_package_counts(v_vid);
  v_pre_ok := (v_counts_pre->>'weeks')::INT = 2 AND EXISTS (SELECT 1 FROM programme_version_weeks WHERE id=v_alt_week);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'extra_week', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_weeks WHERE id=v_alt_week AND week_number=2),
    'extra week identity retained'
  );

  -- extra_day
  lineage := 'PROG-GATE-D-EXDAY';
  v_hash := sprint12_hash('gate-d-exday');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  SELECT id INTO v_week_id FROM programme_version_weeks WHERE version_id = v_vid AND week_number = 1;
  INSERT INTO programme_version_days(week_id, day_key, day_order, day_type)
  VALUES (v_week_id, 'day_2', 2, 'rest') RETURNING id INTO v_alt_day;
  v_counts_pre := sprint12_package_counts(v_vid);
  v_pre_ok := (v_counts_pre->>'days')::INT = 2 AND EXISTS (SELECT 1 FROM programme_version_days WHERE id=v_alt_day);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'extra_day', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_days WHERE id=v_alt_day AND day_key='day_2'),
    'extra day identity retained'
  );

  -- extra_slot
  lineage := 'PROG-GATE-D-EXSLOT';
  v_hash := sprint12_hash('gate-d-exslot');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  SELECT d.id INTO v_day_id
  FROM programme_version_days d
  JOIN programme_version_weeks w ON w.id = d.week_id
  WHERE w.version_id = v_vid LIMIT 1;
  INSERT INTO programme_version_session_slots(day_id, session_order, protocol_id, package_slot_key, authored_progression)
  VALUES (v_day_id, 2, v_protocol, 'W1D1S-EXTRA', '{"prescription_summary":"x"}'::jsonb)
  RETURNING id INTO v_slot_id;
  v_counts_pre := sprint12_package_counts(v_vid);
  v_pre_ok := (v_counts_pre->>'slots')::INT = 2 AND EXISTS (SELECT 1 FROM programme_version_session_slots WHERE id=v_slot_id);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'extra_slot', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_session_slots WHERE id=v_slot_id AND package_slot_key='W1D1S-EXTRA'),
    'extra slot identity retained'
  );

  -- reparented_day
  lineage := 'PROG-GATE-D-RDAY';
  v_hash := sprint12_hash('gate-d-reparent-day');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  INSERT INTO programme_version_weeks(version_id, week_number, title)
  VALUES (v_vid, 2, 'Alt Week') RETURNING id INTO v_foreign_week;
  SELECT d.id INTO v_day_id
  FROM programme_version_days d JOIN programme_version_weeks w ON w.id=d.week_id
  WHERE w.version_id=v_vid AND w.week_number=1 AND d.day_key='day_1';
  UPDATE programme_version_days SET week_id = v_foreign_week WHERE id = v_day_id;
  SELECT week_id = v_foreign_week INTO v_pre_ok FROM programme_version_days WHERE id = v_day_id;
  v_counts_pre := sprint12_package_counts(v_vid);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'reparented_day', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_days WHERE id=v_day_id AND week_id=v_foreign_week)
         AND EXISTS (SELECT 1 FROM programme_version_weeks WHERE id=v_foreign_week),
    'day remains on foreign week; foreign week not deleted'
  );

  -- reparented_slot
  lineage := 'PROG-GATE-D-RSLOT';
  v_hash := sprint12_hash('gate-d-reparent-slot');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  SELECT w.id INTO v_week_id FROM programme_version_weeks w WHERE w.version_id=v_vid AND w.week_number=1;
  INSERT INTO programme_version_days(week_id, day_key, day_order, day_type)
  VALUES (v_week_id, 'day_2', 2, 'rest') RETURNING id INTO v_foreign_day;
  SELECT s.id INTO v_slot_id
  FROM programme_version_session_slots s
  JOIN programme_version_days d ON d.id=s.day_id
  JOIN programme_version_weeks w ON w.id=d.week_id
  WHERE w.version_id=v_vid AND s.package_slot_key='W1D1S1';
  UPDATE programme_version_session_slots SET day_id = v_foreign_day WHERE id = v_slot_id;
  SELECT day_id = v_foreign_day INTO v_pre_ok FROM programme_version_session_slots WHERE id = v_slot_id;
  v_counts_pre := sprint12_package_counts(v_vid);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'reparented_slot', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_session_slots WHERE id=v_slot_id AND day_id=v_foreign_day)
         AND EXISTS (SELECT 1 FROM programme_version_days WHERE id=v_foreign_day),
    'slot remains on foreign day; foreign day not deleted'
  );

  -- equal_count_diff_identity
  lineage := 'PROG-GATE-D-DIFFKEY';
  v_hash := sprint12_hash('gate-d-diffkey');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  UPDATE programme_version_adaptation_permissions SET permission_key='ADP-OTHER' WHERE version_id=v_vid AND permission_key='ADP-1';
  v_counts_pre := sprint12_package_counts(v_vid);
  v_pre_ok := EXISTS (SELECT 1 FROM programme_version_adaptation_permissions WHERE version_id=v_vid AND permission_key='ADP-OTHER')
          AND NOT EXISTS (SELECT 1 FROM programme_version_adaptation_permissions WHERE version_id=v_vid AND permission_key='ADP-1')
          AND (v_counts_pre->>'adaptations')::INT = 1;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'equal_count_diff_identity', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok
      AND EXISTS (SELECT 1 FROM programme_version_adaptation_permissions WHERE version_id=v_vid AND permission_key='ADP-OTHER')
      AND NOT EXISTS (SELECT 1 FROM programme_version_adaptation_permissions WHERE version_id=v_vid AND permission_key='ADP-1'),
    'altered key not restored; ADP-1 not recreated'
  );

  -- altered_progression
  lineage := 'PROG-GATE-D-ALTER';
  v_hash := sprint12_hash('gate-d-alter');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  UPDATE programme_version_session_slots s
  SET authored_progression = jsonb_set(authored_progression, '{prescription_summary}', '"CHANGED"')
  FROM programme_version_days d, programme_version_weeks w
  WHERE s.day_id=d.id AND d.week_id=w.id AND w.version_id=v_vid
  RETURNING s.id INTO v_slot_id;
  v_counts_pre := sprint12_package_counts(v_vid);
  SELECT authored_progression->>'prescription_summary' = 'CHANGED' INTO v_pre_ok
  FROM programme_version_session_slots WHERE id = v_slot_id;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'altered_progression', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (
      SELECT 1 FROM programme_version_session_slots
      WHERE id=v_slot_id AND authored_progression->>'prescription_summary'='CHANGED'
    ),
    'tampered progression not restored'
  );

  -- altered_protocol
  lineage := 'PROG-GATE-D-PROTO';
  v_hash := sprint12_hash('gate-d-proto');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  UPDATE programme_version_session_slots s SET protocol_id='TMP-001'
  FROM programme_version_days d, programme_version_weeks w
  WHERE s.day_id=d.id AND d.week_id=w.id AND w.version_id=v_vid
  RETURNING s.id INTO v_slot_id;
  v_counts_pre := sprint12_package_counts(v_vid);
  SELECT protocol_id = 'TMP-001' INTO v_pre_ok FROM programme_version_session_slots WHERE id = v_slot_id;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'altered_protocol', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_session_slots WHERE id=v_slot_id AND protocol_id='TMP-001'),
    'tampered protocol_id not restored'
  );

  -- altered_nullable_description
  lineage := 'PROG-GATE-D-NULL';
  v_hash := sprint12_hash('gate-d-null');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  UPDATE programme_versions SET description='tampered' WHERE id=v_vid;
  v_counts_pre := sprint12_package_counts(v_vid);
  SELECT description = 'tampered' INTO v_pre_ok FROM programme_versions WHERE id = v_vid;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'altered_nullable_description', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_versions WHERE id=v_vid AND description='tampered'),
    'tampered description not restored'
  );

  -- reparented_week_cross_version
  lineage := 'PROG-GATE-D-RWEEK';
  v_hash := sprint12_hash('gate-d-reparent-week');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  INSERT INTO programme_lineages(code, created_by) VALUES ('PROG-GATE-D-FOREIGN', 'gate');
  INSERT INTO programme_versions(lineage_id, version_number, lifecycle_status, library_scope, owner_type, created_by, name, approved_for_global)
  SELECT id, 1, 'draft', 'coach_private', 'coach', 'gate', 'Foreign', FALSE FROM programme_lineages WHERE code='PROG-GATE-D-FOREIGN';
  INSERT INTO programme_version_phases(version_id, phase_order, title)
  SELECT pv.id, 9, 'Foreign Phase' FROM programme_versions pv
  JOIN programme_lineages pl ON pl.id=pv.lineage_id WHERE pl.code='PROG-GATE-D-FOREIGN'
  RETURNING id INTO v_phase_id;
  UPDATE programme_version_weeks w SET phase_id = v_phase_id WHERE w.version_id = v_vid
  RETURNING w.id INTO v_week_id;
  v_counts_pre := sprint12_package_counts(v_vid);
  SELECT phase_id = v_phase_id INTO v_pre_ok FROM programme_version_weeks WHERE id = v_week_id;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'reparented_week_cross_version', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_weeks WHERE id=v_week_id AND phase_id=v_phase_id)
         AND EXISTS (SELECT 1 FROM programme_version_phases WHERE id=v_phase_id),
    'week remains attached to foreign phase; foreign phase not deleted'
  );

  -- wrong_ownership
  lineage := 'PROG-GATE-D-OWNER';
  v_hash := sprint12_hash('gate-d-owner');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  UPDATE programme_versions SET owner_type='coach', owner_id='someone', library_scope='coach_private' WHERE id=v_vid;
  v_counts_pre := sprint12_package_counts(v_vid);
  SELECT owner_type='coach' AND owner_id='someone' AND library_scope='coach_private' INTO v_pre_ok
  FROM programme_versions WHERE id=v_vid;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'wrong_ownership', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (
      SELECT 1 FROM programme_versions
      WHERE id=v_vid AND owner_type='coach' AND owner_id='someone' AND library_scope='coach_private'
    ),
    'ownership/scope not repaired to global'
  );

  -- altered_child_ref
  lineage := 'PROG-GATE-D-CHILDREF';
  v_hash := sprint12_hash('gate-d-childref');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  UPDATE programme_version_assessments SET slot_ref='OTHER' WHERE version_id=v_vid
  RETURNING id INTO v_slot_id; -- reuse uuid var for assessment id
  v_counts_pre := sprint12_package_counts(v_vid);
  SELECT slot_ref = 'OTHER' INTO v_pre_ok FROM programme_version_assessments WHERE id = v_slot_id;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'altered_child_ref', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (SELECT 1 FROM programme_version_assessments WHERE id=v_slot_id AND slot_ref='OTHER'),
    'assessment slot_ref not restored'
  );

  -- altered_comparison_lineage
  lineage := 'PROG-GATE-D-CMPLIN';
  v_hash := sprint12_hash('gate-d-cmplinea');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  UPDATE programme_version_comparison_identities
  SET session_lineage_id='00000000-0000-0000-0000-000000000099' WHERE version_id=v_vid
  RETURNING id INTO v_alt_week; -- reuse uuid var for comparison id
  v_counts_pre := sprint12_package_counts(v_vid);
  SELECT session_lineage_id = '00000000-0000-0000-0000-000000000099' INTO v_pre_ok
  FROM programme_version_comparison_identities WHERE id = v_alt_week;
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_record_d_no_repair(
    'altered_comparison_lineage', v_res, v_vid, lineage, v_counts_pre,
    v_pre_ok AND EXISTS (
      SELECT 1 FROM programme_version_comparison_identities
      WHERE id=v_alt_week AND session_lineage_id='00000000-0000-0000-0000-000000000099'
    ),
    'comparison session_lineage_id not restored'
  );

  -- =========================================================================
  -- Gate E — Duplicate identities (+ sequential G3 relocated here)
  -- =========================================================================
  cases := jsonb_build_array(
    jsonb_build_object('id','dup_phase_key','mut','phase_key'),
    jsonb_build_object('id','dup_phase_order','mut','phase_order'),
    jsonb_build_object('id','dup_week_number','mut','week_number'),
    jsonb_build_object('id','dup_day_key','mut','day_key'),
    jsonb_build_object('id','dup_day_order','mut','day_order'),
    jsonb_build_object('id','dup_slot_key','mut','slot_key'),
    jsonb_build_object('id','dup_session_order','mut','session_order'),
    jsonb_build_object('id','dup_adaptation','mut','adaptation'),
    jsonb_build_object('id','dup_invariant','mut','invariant'),
    jsonb_build_object('id','dup_assessment','mut','assessment'),
    jsonb_build_object('id','dup_evidence','mut','evidence'),
    jsonb_build_object('id','dup_comparison','mut','comparison')
  );
  FOR c IN SELECT * FROM jsonb_array_elements(cases) LOOP
    mut := c->>'mut';
    lineage := 'PROG-GATE-E-' || upper(mut);
    v_hash := sprint12_hash('gate-e-' || mut);
    v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
    v_payload2 := v_payload;
    IF mut = 'phase_key' THEN
      phases := v_payload2->'phases';
      phases := phases || jsonb_build_array(jsonb_set(phases->0, '{phase_order}', '2'));
      v_payload2 := jsonb_set(v_payload2, '{phases}', phases);
    ELSIF mut = 'phase_order' THEN
      phases := v_payload2->'phases';
      phases := phases || jsonb_build_array(jsonb_build_object('phase_key','PH2','phase_order',1,'title','X'));
      v_payload2 := jsonb_set(v_payload2, '{phases}', phases);
    ELSIF mut = 'week_number' THEN
      weeks := v_payload2->'weeks';
      weeks := weeks || jsonb_build_array(jsonb_set(weeks->0, '{days}', '[]'::jsonb));
      v_payload2 := jsonb_set(v_payload2, '{weeks}', weeks);
    ELSIF mut = 'day_key' THEN
      weeks := v_payload2->'weeks';
      weeks := jsonb_set(weeks, '{0,days}', (weeks->0->'days') || jsonb_build_array(
        jsonb_build_object('day_key','day_1','day_order',2,'day_type','rest','slots','[]'::jsonb)));
      v_payload2 := jsonb_set(v_payload2, '{weeks}', weeks);
    ELSIF mut = 'day_order' THEN
      weeks := v_payload2->'weeks';
      weeks := jsonb_set(weeks, '{0,days}', (weeks->0->'days') || jsonb_build_array(
        jsonb_build_object('day_key','day_2','day_order',1,'day_type','rest','slots','[]'::jsonb)));
      v_payload2 := jsonb_set(v_payload2, '{weeks}', weeks);
    ELSIF mut = 'slot_key' THEN
      weeks := v_payload2->'weeks';
      weeks := jsonb_set(weeks, '{0,days,0,slots}', (weeks->0->'days'->0->'slots') || jsonb_build_array(
        jsonb_build_object('slot_key','W1D1S1','session_order',2,'session_key','SES-A',
          'progression', jsonb_build_object('prescription_summary','x'))));
      v_payload2 := jsonb_set(v_payload2, '{weeks}', weeks);
    ELSIF mut = 'session_order' THEN
      weeks := v_payload2->'weeks';
      weeks := jsonb_set(weeks, '{0,days,0,slots}', (weeks->0->'days'->0->'slots') || jsonb_build_array(
        jsonb_build_object('slot_key','W1D1S2','session_order',1,'session_key','SES-A',
          'progression', jsonb_build_object('prescription_summary','x'))));
      v_payload2 := jsonb_set(v_payload2, '{weeks}', weeks);
    ELSIF mut = 'adaptation' THEN
      v_payload2 := jsonb_set(v_payload2, '{adaptation_permissions}',
        (v_payload2->'adaptation_permissions') || jsonb_build_array(v_payload2->'adaptation_permissions'->0));
    ELSIF mut = 'invariant' THEN
      v_payload2 := jsonb_set(v_payload2, '{protected_invariants}',
        (v_payload2->'protected_invariants') || jsonb_build_array(v_payload2->'protected_invariants'->0));
    ELSIF mut = 'assessment' THEN
      v_payload2 := jsonb_set(v_payload2, '{assessments}',
        (v_payload2->'assessments') || jsonb_build_array(v_payload2->'assessments'->0));
    ELSIF mut = 'evidence' THEN
      v_payload2 := jsonb_set(v_payload2, '{performance_evidence_requirements}',
        (v_payload2->'performance_evidence_requirements') || jsonb_build_array(v_payload2->'performance_evidence_requirements'->0));
    ELSIF mut = 'comparison' THEN
      v_payload2 := jsonb_set(v_payload2, '{comparison_identities}',
        (v_payload2->'comparison_identities') || jsonb_build_array(v_payload2->'comparison_identities'->0));
    END IF;

    v_before := sprint12_lineage_residue(lineage);
    PERFORM set_config('role', 'service_role', true);
    v_res := public.import_authored_plan_package(v_payload2);
    PERFORM set_config('role', 'postgres', true);
    v_after := sprint12_lineage_residue(lineage);
    v_ok := (v_res->>'status'='validation_failure' AND v_res->>'code'='duplicate_package_identity'
             AND v_res->>'code' IS DISTINCT FROM 'lineage_or_version_race' AND v_after = v_before);
    PERFORM sprint12_record('E', c->>'id', 'duplicate_package_identity',
      coalesce(v_res->>'code', v_res->>'status'), v_after=v_before, v_ok, v_res::TEXT);
  END LOOP;

  -- Sequential duplicate-slot validation formerly mislabeled as concurrency G3.
  lineage := 'PROG-GATE-E-SEQ-SLOT';
  v_hash := sprint12_hash('gate-e-seq-slot');
  v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
  v_payload2 := jsonb_set(
    v_payload, '{weeks,0,days,0,slots}',
    (v_payload->'weeks'->0->'days'->0->'slots') || jsonb_build_array(
      jsonb_build_object('slot_key','W1D1S1','session_order',2,'session_key','SES-A',
        'progression', jsonb_build_object('prescription_summary','x')))
  );
  v_before := sprint12_lineage_residue(lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload2);
  PERFORM set_config('role', 'postgres', true);
  v_ok := v_res->>'code'='duplicate_package_identity' AND sprint12_lineage_residue(lineage)=v_before;
  PERFORM sprint12_record('E','sequential_duplicate_slot_key','duplicate_package_identity',
    v_res->>'code', v_ok, v_ok, 'relocated from former Gate G3; not concurrency');

  -- =========================================================================
  -- Gate F — Rollback at write depths
  -- =========================================================================
  -- phase / slot / assessment + NEW adaptation / invariant / evidence / comparison
  child_tables := ARRAY[
    'programme_version_phases',
    'programme_version_session_slots',
    'programme_version_adaptation_permissions',
    'programme_version_protected_invariants',
    'programme_version_assessments',
    'programme_version_evidence_requirements',
    'programme_version_comparison_identities'
  ];
  FOREACH child IN ARRAY child_tables LOOP
    trg := 'sprint12_trg_fail_' || replace(child, 'programme_version_', '');
    lineage := 'PROG-GATE-F-' || upper(replace(child, 'programme_version_', ''));
    v_hash := sprint12_hash('gate-f-' || child);
    v_payload := sprint12_build_package(lineage, 1, v_hash, v_protocol, v_lineage);
    PERFORM sprint12_install_fail_trigger(child::regclass, trg, 'check_violation');
    v_before := sprint12_lineage_residue(lineage);
    PERFORM set_config('role', 'service_role', true);
    v_res := public.import_authored_plan_package(v_payload);
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_drop_fail_trigger(child::regclass, trg);
    v_after := sprint12_lineage_residue(lineage);
    v_ok := v_after = v_before
      AND NOT EXISTS (
        SELECT 1 FROM programme_versions pv
        JOIN programme_lineages pl ON pl.id=pv.lineage_id WHERE pl.code=lineage
      )
      AND v_res->>'status' IS DISTINCT FROM 'idempotent_existing_draft'
      AND coalesce(v_res->>'code','') IS DISTINCT FROM 'lineage_or_version_race';
    PERFORM sprint12_record(
      'F', 'rollback_' || replace(child, 'programme_version_', ''),
      'no_residue',
      CASE WHEN v_ok THEN 'no_residue' ELSE coalesce(v_res->>'status','residue') END,
      v_ok, v_ok, v_res::TEXT
    );
  END LOOP;

  lineage := 'PROG-GATE-F-REF';
  v_hash := sprint12_hash('gate-f-ref');
  v_payload := sprint12_build_package(lineage, 1, v_hash, 'PROT-DOES-NOT-EXIST', v_lineage);
  v_before := sprint12_lineage_residue(lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_ok := v_res->>'status'='session_resolution_failure' AND sprint12_lineage_residue(lineage)=v_before;
  PERFORM sprint12_record('F','session_missing_no_residue','session_resolution_failure', v_res->>'status', v_ok, v_ok, v_res->>'code');

  -- =========================================================================
  -- Gate H — Lifecycle
  -- =========================================================================
  v_hash := sprint12_hash('gate-h-life');
  v_payload := sprint12_build_package('PROG-GATE-H-01', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_vid := (v_res->>'programme_version_id')::UUID;
  PERFORM sprint12_assert_eq('H','import_is_draft','draft',
    (SELECT lifecycle_status FROM programme_versions WHERE id=v_vid), NULL);

  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload || jsonb_build_object('lifecycle_status','published'));
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('H','import_spoof_lifecycle','authorization_failure', v_res->>'status', v_res->>'code');

  PERFORM set_config('role', 'service_role', true);
  v_res := public.publish_cohort_global_programme_version(v_vid, 'publisher');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('H','publish','published', v_res->>'status', NULL);
  SELECT approved_for_global = FALSE AND lifecycle_status='published' INTO v_ok FROM programme_versions WHERE id=v_vid;
  PERFORM sprint12_record('H','publish_not_approved','true', v_ok::TEXT, v_ok, v_ok, 'approved_for_global must remain false');

  PERFORM set_config('role', 'service_role', true);
  v_res := public.approve_cohort_global_programme_version(v_vid, 'approver');
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('H','approve','catalogue_approved', v_res->>'status', NULL);

  BEGIN
    UPDATE programme_versions SET package_content_hash = sprint12_hash('tamper') WHERE id=v_vid;
    PERFORM sprint12_record('H','published_hash_immutable','blocked','allowed', FALSE, FALSE, NULL);
  EXCEPTION WHEN OTHERS THEN
    PERFORM sprint12_record('H','published_hash_immutable','blocked','blocked', TRUE, TRUE, SQLERRM);
  END;

  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  PERFORM sprint12_assert_eq('H','reimport_published','published_version_conflict', v_res->>'status', v_res->>'code');

  SELECT count(*) INTO v_after FROM programme_versions
  WHERE id = v_coach_version AND library_scope='coach_private' AND owner_type='coach';
  PERFORM sprint12_record('H','coach_private_intact','1', v_after::TEXT, v_after=1, v_after=1, 'self-contained fixture');

  -- =========================================================================
  -- Gate I-A — Migration-installed privileges (no temporary grants)
  -- =========================================================================
  -- actual = has_*_privilege; expected false means EXECUTE/SELECT must be absent.
  SELECT has_function_privilege('anon', 'public.import_authored_plan_package(jsonb)', 'EXECUTE') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_anon_execute_import','false', v_ok::TEXT, 'migration-installed EXECUTE');
  SELECT has_function_privilege('authenticated', 'public.import_authored_plan_package(jsonb)', 'EXECUTE') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_auth_execute_import','false', v_ok::TEXT, 'migration-installed EXECUTE');
  SELECT has_function_privilege('service_role', 'public.import_authored_plan_package(jsonb)', 'EXECUTE') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_service_execute_import','true', v_ok::TEXT, 'migration-installed EXECUTE');

  SELECT has_function_privilege('anon', 'public.cohort_authored_plan_package_graph_matches(uuid,jsonb)', 'EXECUTE') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_anon_execute_helper','false', v_ok::TEXT, 'migration-installed EXECUTE');
  SELECT has_function_privilege('authenticated', 'public.cohort_authored_plan_package_graph_matches(uuid,jsonb)', 'EXECUTE') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_auth_execute_helper','false', v_ok::TEXT, 'migration-installed EXECUTE');

  -- Catalogue table SELECT currently absent — deployment/integration gate (assert absence).
  SELECT has_table_privilege('authenticated', 'programme_versions', 'SELECT') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_auth_select_programme_versions_absent','false', v_ok::TEXT,
    'DEPLOYMENT_GATE: migration-installed SELECT absent for authenticated');
  SELECT has_table_privilege('anon', 'programme_versions', 'SELECT') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_anon_select_programme_versions_absent','false', v_ok::TEXT,
    'DEPLOYMENT_GATE: migration-installed SELECT absent for anon');
  SELECT has_table_privilege('service_role', 'programme_versions', 'SELECT') INTO v_ok;
  PERFORM sprint12_assert_eq('I','priv_service_select_programme_versions_absent','false', v_ok::TEXT,
    'DEPLOYMENT_GATE: migration-installed SELECT absent for service_role under local auto_expose=false');

  SELECT count(*) INTO v_after FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='import_authored_plan_package';
  PERFORM sprint12_record('I','import_overload_count','1', v_after::TEXT, v_after=1, v_after=1, NULL);
  SELECT (proconfig::text LIKE '%search_path=public, pg_temp%') INTO v_ok
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='import_authored_plan_package';
  PERFORM sprint12_record('I','import_search_path','true', v_ok::TEXT, v_ok, v_ok, NULL);

  -- =========================================================================
  -- Gate I-B — RLS semantics with disposable test-only grants (then revoke)
  -- =========================================================================
  -- Fresh draft for RLS probes
  v_hash := sprint12_hash('gate-i-rls-draft');
  v_payload := sprint12_build_package('PROG-GATE-I-RLS', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  PERFORM set_config('role', 'postgres', true);
  v_draft := (v_res->>'programme_version_id')::UUID;

  SELECT id INTO v_approved FROM programme_versions
  WHERE approved_for_global AND lifecycle_status='published' AND library_scope='cohort_global'
  ORDER BY created_at DESC LIMIT 1;

  -- Create published-unapproved via import+publish without approve
  v_hash := sprint12_hash('gate-i-pub-unapp');
  v_payload := sprint12_build_package('PROG-GATE-I-PUB', 1, v_hash, v_protocol, v_lineage);
  PERFORM set_config('role', 'service_role', true);
  v_res := public.import_authored_plan_package(v_payload);
  v_pub_unapproved := (v_res->>'programme_version_id')::UUID;
  PERFORM public.publish_cohort_global_programme_version(v_pub_unapproved, 'publisher');
  PERFORM set_config('role', 'postgres', true);

  -- Temporary test-only grants (disposable DB only; revoked below).
  EXECUTE 'GRANT SELECT ON TABLE public.programme_versions TO anon, authenticated, service_role';

  -- With grants, privilege errors must not occur; RLS must filter.
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    SELECT count(*) INTO v_after FROM programme_versions WHERE id = v_draft;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_draft_hidden','0', v_after::TEXT, v_after=0, v_after=0,
      'RLS after temporary GRANT SELECT (not privilege denial)');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_draft_hidden','0','privilege_error', FALSE, FALSE,
      '42501 is NOT RLS proof');
  END;

  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    SELECT count(*) INTO v_after FROM programme_versions WHERE id = v_pub_unapproved;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_published_unapproved_hidden','0', v_after::TEXT, v_after=0, v_after=0,
      'RLS after temporary GRANT SELECT');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_published_unapproved_hidden','0','privilege_error', FALSE, FALSE, '42501 != RLS');
  END;

  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    SELECT count(*) INTO v_after FROM programme_versions WHERE id = v_approved;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_approved_visible','1', v_after::TEXT, v_after=1, v_after=1,
      'RLS after temporary GRANT SELECT');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_approved_visible','1','privilege_error', FALSE, FALSE, '42501 != RLS');
  END;

  BEGIN
    PERFORM set_config('role', 'anon', true);
    SELECT count(*) INTO v_after FROM programme_versions WHERE id = v_approved;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_anon_approved_hidden','0', v_after::TEXT, v_after=0, v_after=0,
      'anon outside authenticated catalogue policy; after temporary GRANT');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_anon_approved_hidden','0','privilege_error', FALSE, FALSE, '42501 != RLS');
  END;

  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    SELECT count(*) INTO v_after FROM programme_versions WHERE id = v_coach_version;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_coach_private_hidden','0', v_after::TEXT, v_after=0, v_after=0,
      'coach_private not visible without ownership claims');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_coach_private_hidden','0','privilege_error', FALSE, FALSE, '42501 != RLS');
  END;

  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    UPDATE programme_versions SET name='hacked' WHERE id = v_draft;
    GET DIAGNOSTICS v_after = ROW_COUNT;
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_update_global_draft','0', v_after::TEXT, v_after=0, v_after=0,
      'direct write denied/filtered under RLS');
  EXCEPTION WHEN insufficient_privilege OR OTHERS THEN
    PERFORM set_config('role', 'postgres', true);
    PERFORM sprint12_record('I','rls_auth_update_global_draft','denied', SQLSTATE, TRUE, TRUE,
      'write denied (may be missing UPDATE privilege and/or RLS); not SELECT visibility proof');
  END;

  EXECUTE 'REVOKE SELECT ON TABLE public.programme_versions FROM anon, authenticated, service_role';

END $$;

\echo '=== SPRINT12 GATE RESULTS ==='
SELECT gate, case_id, expected, actual, persisted_ok, pass, left(coalesce(detail,''), 140) AS detail
FROM sprint12_gate_results
ORDER BY gate, case_id;

\echo '=== SUMMARY ==='
SELECT gate,
       count(*) AS total,
       count(*) FILTER (WHERE pass) AS passed,
       count(*) FILTER (WHERE NOT pass) AS failed
FROM sprint12_gate_results
GROUP BY gate
ORDER BY gate;

-- Fail closed: any failure => non-zero psql exit under ON_ERROR_STOP.
SELECT sprint12_fail_if_any_failed();
\echo 'ALL_PASSED'
