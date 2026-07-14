-- Persist circuit / WOD performance for athlete session resume and history.
-- Additive only. Strength and interval logging are unchanged.

CREATE TABLE training_session_circuits (
  id                          BIGSERIAL PRIMARY KEY,
  training_session_id         BIGINT NOT NULL
                                REFERENCES training_sessions(id) ON DELETE CASCADE,
  protocol_id                 TEXT NOT NULL,
  circuit_format              TEXT NOT NULL,
  score_type                  TEXT NOT NULL,
  elapsed_duration_seconds    INTEGER,
  completed_rounds            INTEGER,
  additional_reps             INTEGER,
  total_reps                  INTEGER,
  completed_intervals         INTEGER,
  completed_movements         INTEGER,
  prescribed_load             TEXT,
  actual_load                 TEXT,
  rpe                         SMALLINT,
  completed                   BOOLEAN NOT NULL DEFAULT FALSE,
  time_capped                 BOOLEAN NOT NULL DEFAULT FALSE,
  skipped                     BOOLEAN NOT NULL DEFAULT FALSE,
  data_source                 TEXT NOT NULL DEFAULT 'manual',
  athlete_note                TEXT,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT training_session_circuits_unique_session
    UNIQUE (training_session_id),
  CONSTRAINT training_session_circuits_rpe_range
    CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10)),
  CONSTRAINT training_session_circuits_elapsed_duration_positive
    CHECK (elapsed_duration_seconds IS NULL OR elapsed_duration_seconds > 0),
  CONSTRAINT training_session_circuits_completed_rounds_positive
    CHECK (completed_rounds IS NULL OR completed_rounds >= 0),
  CONSTRAINT training_session_circuits_additional_reps_positive
    CHECK (additional_reps IS NULL OR additional_reps >= 0),
  CONSTRAINT training_session_circuits_total_reps_positive
    CHECK (total_reps IS NULL OR total_reps > 0),
  CONSTRAINT training_session_circuits_completed_intervals_positive
    CHECK (completed_intervals IS NULL OR completed_intervals >= 0),
  CONSTRAINT training_session_circuits_completed_movements_positive
    CHECK (completed_movements IS NULL OR completed_movements >= 0)
);

CREATE INDEX idx_training_session_circuits_session
  ON training_session_circuits (training_session_id);

CREATE INDEX idx_training_session_circuits_protocol
  ON training_session_circuits (protocol_id);

COMMENT ON TABLE training_session_circuits IS
  'Session-level circuit / WOD performance for athlete resume and history.';
