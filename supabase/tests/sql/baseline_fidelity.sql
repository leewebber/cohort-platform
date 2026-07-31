-- Baseline-fidelity assertions for the authoritative local test fixture.
-- Separate from Sprint 1.2 behavioural gates C–I (does not use sprint12_gate_results).
-- Intended to run after disposable db reset (baseline + production migrations applied).
-- Fail-closed: any failure raises (ON_ERROR_STOP).

DROP TABLE IF EXISTS sprint12_baseline_fidelity_results CASCADE;
CREATE TABLE sprint12_baseline_fidelity_results (
  case_id TEXT PRIMARY KEY,
  expected TEXT NOT NULL,
  actual TEXT,
  pass BOOLEAN NOT NULL,
  detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION sprint12_baseline_record(
  p_case TEXT,
  p_expected TEXT,
  p_actual TEXT,
  p_pass BOOLEAN,
  p_detail TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO sprint12_baseline_fidelity_results(case_id, expected, actual, pass, detail)
  VALUES (p_case, p_expected, p_actual, p_pass, p_detail)
  ON CONFLICT (case_id) DO UPDATE
    SET expected = EXCLUDED.expected,
        actual = EXCLUDED.actual,
        pass = EXCLUDED.pass,
        detail = EXCLUDED.detail,
        created_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION sprint12_baseline_fail_if_any_failed() RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  n INT;
  sample TEXT;
BEGIN
  SELECT count(*) INTO n FROM sprint12_baseline_fidelity_results WHERE pass IS NOT TRUE;
  IF n > 0 THEN
    SELECT case_id || ' expected=' || expected || ' actual=' || coalesce(actual, '<null>')
      INTO sample
    FROM sprint12_baseline_fidelity_results
    WHERE pass IS NOT TRUE
    ORDER BY case_id
    LIMIT 1;
    RAISE EXCEPTION 'SPRINT12_BASELINE_FIDELITY_FAILURES=% first=%', n, sample
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

DO $$
DECLARE
  v_count INT;
  v_bool BOOLEAN;
  v_udt TEXT;
  v_null TEXT;
  t TEXT;
  tables TEXT[] := ARRAY[
    'training_sessions',
    'performance_protocols',
    'protocol_steps',
    'athlete_state',
    'exercises_v2'
  ];
BEGIN
  -- -------------------------------------------------------------------------
  -- Existence + column counts (hosted dump shapes)
  -- -------------------------------------------------------------------------
  FOREACH t IN ARRAY tables LOOP
    SELECT count(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = t;
    PERFORM sprint12_baseline_record(
      'exists_' || t, '1', v_count::text, v_count = 1, 'public.' || t
    );
  END LOOP;

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='training_sessions';
  PERFORM sprint12_baseline_record('cols_training_sessions', '20', v_count::text, v_count = 20, NULL);

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='performance_protocols';
  PERFORM sprint12_baseline_record('cols_performance_protocols', '61', v_count::text, v_count = 61, NULL);

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='protocol_steps';
  PERFORM sprint12_baseline_record('cols_protocol_steps', '10', v_count::text, v_count = 10, NULL);

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='athlete_state';
  PERFORM sprint12_baseline_record('cols_athlete_state', '9', v_count::text, v_count = 9, NULL);

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='exercises_v2';
  PERFORM sprint12_baseline_record('cols_exercises_v2', '39', v_count::text, v_count = 39, NULL);

  -- -------------------------------------------------------------------------
  -- Critical types / nullability (hosted)
  -- -------------------------------------------------------------------------
  SELECT udt_name, is_nullable INTO v_udt, v_null
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='athlete_state' AND column_name='current_day';
  PERFORM sprint12_baseline_record(
    'athlete_state_current_day_type', 'text', v_udt, v_udt = 'text', 'null=' || v_null
  );

  SELECT udt_name, is_nullable INTO v_udt, v_null
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='performance_protocols' AND column_name='published';
  PERFORM sprint12_baseline_record(
    'performance_protocols_published_type', 'text', v_udt, v_udt = 'text', 'null=' || v_null
  );

  SELECT udt_name, is_nullable INTO v_udt, v_null
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='protocol_steps' AND column_name='metadata';
  PERFORM sprint12_baseline_record(
    'protocol_steps_metadata_type', 'jsonb', v_udt, v_udt = 'jsonb', 'null=' || v_null
  );
  PERFORM sprint12_baseline_record(
    'protocol_steps_metadata_nullable', 'YES', v_null, v_null = 'YES', NULL
  );

  SELECT udt_name INTO v_udt
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='athlete_state' AND column_name='current_week';
  PERFORM sprint12_baseline_record(
    'athlete_state_current_week_type', 'int2', v_udt, v_udt = 'int2', NULL
  );

  SELECT udt_name INTO v_udt
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='training_sessions' AND column_name='ended_early';
  PERFORM sprint12_baseline_record(
    'training_sessions_ended_early_type', 'bool', v_udt, v_udt = 'bool', NULL
  );

  -- -------------------------------------------------------------------------
  -- Absence of previously invented fixture shapes
  -- -------------------------------------------------------------------------
  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='performance_protocols'
    AND column_name IN ('created_at', 'updated_at');
  PERFORM sprint12_baseline_record(
    'performance_protocols_no_invented_timestamps', '0', v_count::text, v_count = 0, NULL
  );

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='protocol_steps'
    AND column_name IN ('created_at', 'updated_at');
  PERFORM sprint12_baseline_record(
    'protocol_steps_no_invented_timestamps', '0', v_count::text, v_count = 0, NULL
  );

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='athlete_state'
    AND column_name = 'created_at';
  PERFORM sprint12_baseline_record(
    'athlete_state_no_invented_created_at', '0', v_count::text, v_count = 0, NULL
  );

  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema='public' AND table_name='exercises_v2'
    AND column_name IN ('created_at', 'updated_at');
  PERFORM sprint12_baseline_record(
    'exercises_v2_no_invented_timestamps', '0', v_count::text, v_count = 0, NULL
  );

  -- No invented protocol_steps → performance_protocols FK
  SELECT count(*) INTO v_count
  FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname = 'public'
    AND rel.relname = 'protocol_steps'
    AND c.contype = 'f'
    AND pg_get_constraintdef(c.oid) ILIKE '%performance_protocols%';
  PERFORM sprint12_baseline_record(
    'protocol_steps_no_invented_protocol_fk', '0', v_count::text, v_count = 0, NULL
  );

  -- -------------------------------------------------------------------------
  -- Primary / unique / foreign-key / check constraints (hosted, post-migration)
  -- -------------------------------------------------------------------------
  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='training_sessions'
    AND c.contype='p' AND c.conname='training_sessions_pkey';
  PERFORM sprint12_baseline_record('pk_training_sessions', '1', v_count::text, v_count = 1, NULL);

  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='performance_protocols'
    AND c.contype='p' AND c.conname='Performance Protocols_pkey';
  PERFORM sprint12_baseline_record('pk_performance_protocols', '1', v_count::text, v_count = 1, NULL);

  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='protocol_steps'
    AND c.contype='p' AND c.conname='protocol_steps_pkey';
  PERFORM sprint12_baseline_record('pk_protocol_steps', '1', v_count::text, v_count = 1, NULL);

  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='athlete_state'
    AND c.contype='p' AND c.conname='athlete_state_pkey';
  PERFORM sprint12_baseline_record('pk_athlete_state', '1', v_count::text, v_count = 1, NULL);

  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='exercises_v2'
    AND c.contype='p' AND c.conname='exercises_v2_pkey';
  PERFORM sprint12_baseline_record('pk_exercises_v2', '1', v_count::text, v_count = 1, NULL);

  -- Unique present after production migration 20260715150000
  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='athlete_state'
    AND c.conname='athlete_state_athlete_id_unique';
  PERFORM sprint12_baseline_record('uq_athlete_state_athlete_id', '1', v_count::text, v_count = 1, NULL);

  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='performance_protocols'
    AND c.conname='performance_protocols_lineage_revision_unique';
  PERFORM sprint12_baseline_record('uq_pp_lineage_revision', '1', v_count::text, v_count = 1, NULL);

  -- Hosted FKs on performance_protocols (programme_version FK via migration accommodation)
  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='performance_protocols'
    AND c.conname='performance_protocols_session_lineage_id_fkey';
  PERFORM sprint12_baseline_record('fk_pp_session_lineage', '1', v_count::text, v_count = 1, NULL);

  SELECT count(*) INTO v_count FROM pg_constraint c
  JOIN pg_class rel ON rel.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname='public' AND rel.relname='performance_protocols'
    AND c.conname='performance_protocols_programme_version_id_fkey';
  PERFORM sprint12_baseline_record('fk_pp_programme_version', '1', v_count::text, v_count = 1, NULL);

  -- Representative hosted checks
  FOREACH t IN ARRAY ARRAY[
    'performance_protocols_content_kind_check',
    'performance_protocols_authoring_scope_check',
    'performance_protocols_lifecycle_status_check',
    'performance_protocols_revision_number_positive'
  ] LOOP
    SELECT count(*) INTO v_count FROM pg_constraint WHERE conname = t;
    PERFORM sprint12_baseline_record('check_' || t, '1', v_count::text, v_count = 1, NULL);
  END LOOP;

  -- -------------------------------------------------------------------------
  -- Relevant indexes
  -- -------------------------------------------------------------------------
  FOREACH t IN ARRAY ARRAY[
    'idx_performance_protocols_session_lineage',
    'idx_performance_protocols_lifecycle_status',
    'idx_performance_protocols_cohort_catalogue',
    'idx_performance_protocols_coach_sessions',
    'idx_performance_protocols_programme_sessions',
    'idx_performance_protocols_session_templates'
  ] LOOP
    SELECT count(*) INTO v_count
    FROM pg_indexes
    WHERE schemaname='public' AND indexname = t;
    PERFORM sprint12_baseline_record('idx_' || t, '1', v_count::text, v_count = 1, NULL);
  END LOOP;

  -- -------------------------------------------------------------------------
  -- RLS disabled + zero policies on all five
  -- -------------------------------------------------------------------------
  FOREACH t IN ARRAY tables LOOP
    SELECT c.relrowsecurity INTO v_bool
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname='public' AND c.relname = t AND c.relkind='r';
    PERFORM sprint12_baseline_record(
      'rls_disabled_' || t, 'false', v_bool::text, v_bool IS FALSE, NULL
    );

    SELECT count(*) INTO v_count
    FROM pg_policies
    WHERE schemaname='public' AND tablename = t;
    PERFORM sprint12_baseline_record(
      'policies_zero_' || t, '0', v_count::text, v_count = 0, NULL
    );
  END LOOP;

  -- Note: production migrations intentionally seed catalogue/template rows into
  -- performance_protocols, protocol_steps, and exercises_v2. Absence of
  -- application-data seeding by the baseline fixture is asserted by the
  -- orchestrator (fixture file must contain no INSERT/COPY statements).

  PERFORM sprint12_baseline_fail_if_any_failed();
END $$;

SELECT 'BASELINE_FIDELITY_OK' AS status,
       count(*) AS assertion_count,
       count(*) FILTER (WHERE pass) AS passed
FROM sprint12_baseline_fidelity_results;
