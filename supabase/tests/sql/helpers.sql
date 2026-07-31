-- Helper/setup for Sprint 1.2 disposable live PostgreSQL gates.
-- Custom assertion table (not pgTAP).

DROP TABLE IF EXISTS sprint12_gate_results CASCADE;
CREATE TABLE sprint12_gate_results (
  gate TEXT NOT NULL,
  case_id TEXT NOT NULL,
  expected TEXT NOT NULL,
  actual TEXT,
  persisted_ok BOOLEAN,
  pass BOOLEAN NOT NULL,
  detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION sprint12_record(
  p_gate TEXT,
  p_case TEXT,
  p_expected TEXT,
  p_actual TEXT,
  p_persisted_ok BOOLEAN,
  p_pass BOOLEAN,
  p_detail TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO sprint12_gate_results(gate, case_id, expected, actual, persisted_ok, pass, detail)
  VALUES (p_gate, p_case, p_expected, p_actual, p_persisted_ok, p_pass, p_detail);
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_assert_eq(
  p_gate TEXT, p_case TEXT, p_expected TEXT, p_actual TEXT, p_detail TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM sprint12_record(
    p_gate, p_case, p_expected, p_actual, NULL,
    (p_expected IS NOT DISTINCT FROM p_actual), p_detail
  );
END;
$$;

-- Fail closed: any pass=false raises (non-zero psql with ON_ERROR_STOP).
CREATE OR REPLACE FUNCTION sprint12_fail_if_any_failed() RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  n INT;
  sample TEXT;
BEGIN
  SELECT count(*) INTO n FROM sprint12_gate_results WHERE pass IS NOT TRUE;
  IF n > 0 THEN
    SELECT gate || '/' || case_id || ' expected=' || expected || ' actual=' || coalesce(actual, '<null>')
      INTO sample
    FROM sprint12_gate_results
    WHERE pass IS NOT TRUE
    ORDER BY gate, case_id
    LIMIT 1;
    RAISE EXCEPTION 'SPRINT12_GATE_FAILURES=% first=%', n, sample
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_ensure_published_session(
  p_protocol_id TEXT,
  p_lineage_id UUID,
  p_revision INT DEFAULT 1,
  p_name TEXT DEFAULT 'Gate Session'
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO session_lineages (id, display_name)
  VALUES (p_lineage_id, p_name)
  ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

  INSERT INTO performance_protocols (
    protocol_id, name, published, content_kind, authoring_scope, endorsement_status,
    session_lineage_id, revision_number, lifecycle_status, published_at, owner_id
  ) VALUES (
    p_protocol_id, p_name, 'true', 'session', 'cohort_global', 'cohort_endorsed',
    p_lineage_id, p_revision, 'published', NOW(), NULL
  )
  ON CONFLICT (protocol_id) DO UPDATE SET
    name = EXCLUDED.name,
    published = 'true',
    content_kind = 'session',
    authoring_scope = 'cohort_global',
    endorsement_status = 'cohort_endorsed',
    session_lineage_id = EXCLUDED.session_lineage_id,
    revision_number = EXCLUDED.revision_number,
    lifecycle_status = 'published',
    published_at = NOW(),
    owner_id = NULL;
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_build_package(
  p_lineage_code TEXT,
  p_version INT,
  p_hash TEXT,
  p_protocol_id TEXT,
  p_session_lineage_id UUID,
  p_revision INT DEFAULT 1,
  p_imported_by TEXT DEFAULT 'gate-runner',
  p_phase_key TEXT DEFAULT 'PH1',
  p_slot_key TEXT DEFAULT 'W1D1S1'
) RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
  v_lineage TEXT := p_session_lineage_id::TEXT;
BEGIN
  RETURN jsonb_build_object(
    'package_schema_version', 1,
    'package_content_hash', lower(p_hash),
    'imported_by', p_imported_by,
    'programme', jsonb_build_object(
      'lineage_code', p_lineage_code,
      'version_number', p_version,
      'name', 'Gate Package ' || p_lineage_code,
      'description', 'Disposable local validation package',
      'coaching_intent', 'Validate authored package import contract',
      'duration_weeks', 1,
      'sessions_per_week', 1,
      'primary_goal', 'strength'
    ),
    'sessions', jsonb_build_array(
      jsonb_build_object(
        'session_key', 'SES-A',
        'protocol_id', p_protocol_id,
        'session_lineage_id', v_lineage,
        'revision_number', p_revision,
        'title', 'Session A'
      )
    ),
    'phases', jsonb_build_array(
      jsonb_build_object(
        'phase_key', p_phase_key,
        'phase_order', 1,
        'title', 'Foundation',
        'intent', 'build',
        'coach_note', 'Phase note'
      )
    ),
    'weeks', jsonb_build_array(
      jsonb_build_object(
        'week_number', 1,
        'phase_key', p_phase_key,
        'title', 'Week 1',
        'intent', 'build',
        'coach_note', 'Week note',
        'days', jsonb_build_array(
          jsonb_build_object(
            'day_key', 'day_1',
            'day_order', 1,
            'day_type', 'training',
            'title', 'Day 1',
            'intent', 'build',
            'coach_note', 'Day note',
            'slots', jsonb_build_array(
              jsonb_build_object(
                'slot_key', p_slot_key,
                'session_order', 1,
                'session_key', 'SES-A',
                'time_of_day', 'any',
                'is_optional', false,
                'completion_expectation', 'required',
                'display_title', 'Slot A',
                'coach_note', 'Slot note',
                'progression', jsonb_build_object(
                  'prescription_summary', '3x5 @ RPE 7',
                  'volume_note', 'Quality sets',
                  'intensity_note', 'Submaximal',
                  'coach_note', 'Progression note'
                )
              )
            )
          )
        )
      )
    ),
    'adaptation_permissions', jsonb_build_array(
      jsonb_build_object(
        'id', 'ADP-1',
        'change_kind', 'reduce_volume',
        'target_ref', p_slot_key,
        'athlete_agreement_required', true,
        'scope_note', 'Volume only'
      )
    ),
    'protected_invariants', jsonb_build_array(
      jsonb_build_object(
        'id', 'INV-1',
        'kind', 'assessment_immutable',
        'target_ref', 'ASM-1',
        'description', 'Assessment immutable'
      )
    ),
    'assessments', jsonb_build_array(
      jsonb_build_object(
        'id', 'ASM-1',
        'slot_ref', p_slot_key,
        'evidence_requirement', 'recorded_load_and_reps',
        'comparison_identity_id', 'CMP-1',
        'label', 'Baseline'
      )
    ),
    'performance_evidence_requirements', jsonb_build_array(
      jsonb_build_object(
        'id', 'EVD-1',
        'comparison_identity_id', 'CMP-1',
        'metric', 'load_kg',
        'required', true
      )
    ),
    'comparison_identities', jsonb_build_array(
      jsonb_build_object(
        'id', 'CMP-1',
        'session_lineage_id', v_lineage,
        'label', 'Like-for-like'
      )
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_package_counts(p_version_id UUID)
RETURNS JSONB
LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'phases', (SELECT count(*) FROM programme_version_phases WHERE version_id = p_version_id),
    'weeks', (SELECT count(*) FROM programme_version_weeks WHERE version_id = p_version_id),
    'days', (
      SELECT count(*) FROM programme_version_days d
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE w.version_id = p_version_id
    ),
    'slots', (
      SELECT count(*) FROM programme_version_session_slots s
      JOIN programme_version_days d ON d.id = s.day_id
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE w.version_id = p_version_id
    ),
    'adaptations', (SELECT count(*) FROM programme_version_adaptation_permissions WHERE version_id = p_version_id),
    'invariants', (SELECT count(*) FROM programme_version_protected_invariants WHERE version_id = p_version_id),
    'assessments', (SELECT count(*) FROM programme_version_assessments WHERE version_id = p_version_id),
    'evidence', (SELECT count(*) FROM programme_version_evidence_requirements WHERE version_id = p_version_id),
    'comparisons', (SELECT count(*) FROM programme_version_comparison_identities WHERE version_id = p_version_id)
  );
$$;

CREATE OR REPLACE FUNCTION sprint12_lineage_residue(p_lineage_code TEXT)
RETURNS INT
LANGUAGE sql STABLE AS $$
  SELECT count(*)::INT FROM programme_lineages WHERE code = p_lineage_code;
$$;

CREATE OR REPLACE FUNCTION sprint12_version_row_count(p_lineage_code TEXT)
RETURNS INT
LANGUAGE sql STABLE AS $$
  SELECT count(*)::INT
  FROM programme_versions pv
  JOIN programme_lineages pl ON pl.id = pv.lineage_id
  WHERE pl.code = p_lineage_code;
$$;

-- True only for truthful partial-state conflict (never idempotency/success).
CREATE OR REPLACE FUNCTION sprint12_is_partial_conflict(p_res JSONB)
RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_res->>'status', '') = 'partial_state_conflict'
     AND coalesce(p_res->>'status', '') IS DISTINCT FROM 'idempotent_existing_draft'
     AND coalesce(p_res->>'status', '') IS DISTINCT FROM 'imported_draft';
$$;

-- Gate D substantive recorder: conflict + frozen counts + single lineage/version + custom predicate.
CREATE OR REPLACE FUNCTION sprint12_record_d_no_repair(
  p_case TEXT,
  p_res JSONB,
  p_vid UUID,
  p_lineage TEXT,
  p_counts_pre JSONB,
  p_predicate BOOLEAN,
  p_detail TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  v_counts_post JSONB;
  v_ok BOOLEAN;
BEGIN
  v_counts_post := sprint12_package_counts(p_vid);
  v_ok := sprint12_is_partial_conflict(p_res)
     AND v_counts_post IS NOT DISTINCT FROM p_counts_pre
     AND sprint12_version_row_count(p_lineage) = 1
     AND sprint12_lineage_residue(p_lineage) = 1
     AND EXISTS (SELECT 1 FROM programme_versions WHERE id = p_vid)
     AND coalesce(p_predicate, FALSE);
  PERFORM sprint12_record(
    'D', p_case, 'partial_state_conflict', p_res->>'status',
    v_ok, v_ok,
    trim(both FROM coalesce(p_detail, '') ||
      ' counts_frozen=' || (v_counts_post IS NOT DISTINCT FROM p_counts_pre)::text ||
      ' versions=' || sprint12_version_row_count(p_lineage)::text)
  );
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_hash(p_seed TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
  SELECT encode(digest(p_seed, 'sha256'), 'hex');
$$;

-- Install a temporary AFTER INSERT fail trigger; drop with sprint12_drop_fail_trigger.
CREATE OR REPLACE FUNCTION sprint12_install_fail_trigger(
  p_table REGCLASS,
  p_trigger_name TEXT,
  p_errcode TEXT DEFAULT 'check_violation'
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format(
    'CREATE OR REPLACE FUNCTION %I() RETURNS trigger LANGUAGE plpgsql AS $t$
     BEGIN
       RAISE EXCEPTION ''sprint12_forced_failure_on_%%'', TG_TABLE_NAME USING ERRCODE = %L;
     END;
     $t$',
    p_trigger_name || '_fn',
    p_errcode
  );
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', p_trigger_name, p_table);
  EXECUTE format(
    'CREATE TRIGGER %I AFTER INSERT ON %s FOR EACH ROW EXECUTE FUNCTION %I()',
    p_trigger_name, p_table, p_trigger_name || '_fn'
  );
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_drop_fail_trigger(
  p_table REGCLASS,
  p_trigger_name TEXT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', p_trigger_name, p_table);
  EXECUTE format('DROP FUNCTION IF EXISTS %I()', p_trigger_name || '_fn');
END;
$$;
