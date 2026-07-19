-- M8: Athlete performance capture and training history
-- Additive migration — separate performance domain from authored training content.

CREATE TABLE IF NOT EXISTS training_session_records (
  record_id UUID PRIMARY KEY,
  athlete_id TEXT NOT NULL,
  training_session_id BIGINT REFERENCES training_sessions(id) ON DELETE SET NULL,
  source_protocol_id TEXT,
  programme_id TEXT,
  assignment_id UUID,
  programme_session_id UUID,
  status TEXT NOT NULL,
  session_snapshot JSONB NOT NULL,
  active_block_id TEXT,
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  overall_rpe INTEGER,
  athlete_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT training_session_records_status_check CHECK (
    status IN ('in_progress', 'completed', 'partially_completed', 'abandoned')
  ),
  CONSTRAINT training_session_records_overall_rpe_range CHECK (
    overall_rpe IS NULL OR (overall_rpe >= 1 AND overall_rpe <= 10)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS training_session_records_active_assignment_idx
  ON training_session_records (athlete_id, training_session_id)
  WHERE training_session_id IS NOT NULL
    AND status = 'in_progress';

CREATE INDEX IF NOT EXISTS training_session_records_athlete_completed_idx
  ON training_session_records (athlete_id, completed_at DESC)
  WHERE status <> 'in_progress';

CREATE TABLE IF NOT EXISTS training_block_results (
  block_result_id UUID PRIMARY KEY,
  session_record_id UUID NOT NULL
    REFERENCES training_session_records(record_id) ON DELETE CASCADE,
  source_block_id TEXT,
  block_snapshot JSONB NOT NULL,
  status TEXT NOT NULL,
  result_type TEXT NOT NULL,
  result_data JSONB,
  athlete_note TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  position INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT training_block_results_status_check CHECK (
    status IN ('not_started', 'in_progress', 'completed', 'skipped')
  )
);

CREATE INDEX IF NOT EXISTS training_block_results_session_idx
  ON training_block_results (session_record_id, position);

CREATE TABLE IF NOT EXISTS training_exercise_results (
  exercise_result_id UUID PRIMARY KEY,
  block_result_id UUID NOT NULL
    REFERENCES training_block_results(block_result_id) ON DELETE CASCADE,
  source_exercise_id TEXT,
  exercise_snapshot JSONB NOT NULL,
  athlete_note TEXT,
  position INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS training_exercise_results_block_idx
  ON training_exercise_results (block_result_id, position);

CREATE TABLE IF NOT EXISTS training_set_results (
  set_result_id UUID PRIMARY KEY,
  exercise_result_id UUID NOT NULL
    REFERENCES training_exercise_results(exercise_result_id) ON DELETE CASCADE,
  set_number INTEGER NOT NULL,
  reps NUMERIC,
  load NUMERIC,
  load_unit TEXT,
  distance NUMERIC,
  distance_unit TEXT,
  duration_seconds INTEGER,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  rpe NUMERIC,
  note TEXT,
  position INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT training_set_results_rpe_range CHECK (
    rpe IS NULL OR (rpe >= 1 AND rpe <= 10)
  )
);

CREATE INDEX IF NOT EXISTS training_set_results_exercise_idx
  ON training_set_results (exercise_result_id, position);

COMMENT ON TABLE training_session_records IS
  'M8 immutable athlete performance records with prescription snapshots.';

-- ---------------------------------------------------------------------------
-- Transactional completion RPC (idempotent on terminal record per assignment)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION complete_training_session_record(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_record_id UUID := (payload->>'record_id')::UUID;
  v_athlete_id TEXT := payload->>'athlete_id';
  v_training_session_id BIGINT := NULLIF(payload->>'training_session_id', '')::BIGINT;
  v_existing_status TEXT;
BEGIN
  IF v_training_session_id IS NOT NULL THEN
    SELECT status
    INTO v_existing_status
    FROM training_session_records
    WHERE athlete_id = v_athlete_id
      AND training_session_id = v_training_session_id
      AND status <> 'in_progress'
    ORDER BY completed_at DESC NULLS LAST
    LIMIT 1;

    IF v_existing_status IS NOT NULL THEN
      RETURN (
        SELECT to_jsonb(r.*)
        FROM training_session_records r
        WHERE athlete_id = v_athlete_id
          AND training_session_id = v_training_session_id
          AND status <> 'in_progress'
        ORDER BY completed_at DESC NULLS LAST
        LIMIT 1
      );
    END IF;
  END IF;

  INSERT INTO training_session_records (
    record_id,
    athlete_id,
    training_session_id,
    source_protocol_id,
    programme_id,
    assignment_id,
    programme_session_id,
    status,
    session_snapshot,
    active_block_id,
    started_at,
    completed_at,
    duration_seconds,
    overall_rpe,
    athlete_note,
    updated_at
  )
  VALUES (
    v_record_id,
    v_athlete_id,
    v_training_session_id,
    payload->>'source_protocol_id',
    payload->>'programme_id',
    NULLIF(payload->>'assignment_id', '')::UUID,
    NULLIF(payload->>'programme_session_id', '')::UUID,
    payload->>'status',
    payload->'session_snapshot',
    payload->>'active_block_id',
    (payload->>'started_at')::TIMESTAMPTZ,
    NULLIF(payload->>'completed_at', '')::TIMESTAMPTZ,
    NULLIF(payload->>'duration_seconds', '')::INTEGER,
    NULLIF(payload->>'overall_rpe', '')::INTEGER,
    payload->>'athlete_note',
    now()
  )
  ON CONFLICT (record_id) DO UPDATE SET
    status = EXCLUDED.status,
    active_block_id = EXCLUDED.active_block_id,
    completed_at = EXCLUDED.completed_at,
    duration_seconds = EXCLUDED.duration_seconds,
    overall_rpe = EXCLUDED.overall_rpe,
    athlete_note = EXCLUDED.athlete_note,
    updated_at = now();

  RETURN (
    SELECT to_jsonb(r.*)
    FROM training_session_records r
    WHERE r.record_id = v_record_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Development RLS (dev athlete allowlist)
-- ---------------------------------------------------------------------------

ALTER TABLE training_session_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_block_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_exercise_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_set_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY dev_performance_records_select
  ON training_session_records
  FOR SELECT
  USING (athlete_id = ANY (cohort_programme_dev_athlete_ids()));

CREATE POLICY dev_performance_records_insert
  ON training_session_records
  FOR INSERT
  WITH CHECK (athlete_id = ANY (cohort_programme_dev_athlete_ids()));

CREATE POLICY dev_performance_records_update
  ON training_session_records
  FOR UPDATE
  USING (
    athlete_id = ANY (cohort_programme_dev_athlete_ids())
    AND status = 'in_progress'
  )
  WITH CHECK (athlete_id = ANY (cohort_programme_dev_athlete_ids()));

CREATE POLICY dev_performance_block_results_all
  ON training_block_results
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM training_session_records r
      WHERE r.record_id = training_block_results.session_record_id
        AND r.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM training_session_records r
      WHERE r.record_id = training_block_results.session_record_id
        AND r.athlete_id = ANY (cohort_programme_dev_athlete_ids())
        AND r.status = 'in_progress'
    )
  );

CREATE POLICY dev_performance_exercise_results_all
  ON training_exercise_results
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM training_block_results b
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE b.block_result_id = training_exercise_results.block_result_id
        AND r.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM training_block_results b
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE b.block_result_id = training_exercise_results.block_result_id
        AND r.athlete_id = ANY (cohort_programme_dev_athlete_ids())
        AND r.status = 'in_progress'
    )
  );

CREATE POLICY dev_performance_set_results_all
  ON training_set_results
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM training_exercise_results e
      JOIN training_block_results b ON b.block_result_id = e.block_result_id
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE e.exercise_result_id = training_set_results.exercise_result_id
        AND r.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM training_exercise_results e
      JOIN training_block_results b ON b.block_result_id = e.block_result_id
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE e.exercise_result_id = training_set_results.exercise_result_id
        AND r.athlete_id = ANY (cohort_programme_dev_athlete_ids())
        AND r.status = 'in_progress'
    )
  );

COMMENT ON FUNCTION complete_training_session_record(JSONB) IS
  'M8 idempotent terminal completion upsert for training_session_records.';
