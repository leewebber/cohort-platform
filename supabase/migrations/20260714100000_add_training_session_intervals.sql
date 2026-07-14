-- Persist interval phase performance for structured interval sessions.
-- Additive only. Strength set logging is unchanged.

CREATE TABLE training_session_intervals (
  id                          BIGSERIAL PRIMARY KEY,
  training_session_id         BIGINT NOT NULL
                                REFERENCES training_sessions(id) ON DELETE CASCADE,
  protocol_step_id            BIGINT
                                REFERENCES protocol_steps(id) ON DELETE SET NULL,
  block_index                 INTEGER NOT NULL CHECK (block_index >= 0),
  rep_number                  INTEGER NOT NULL CHECK (rep_number > 0),
  phase_type                  TEXT NOT NULL,
  modality                    TEXT NOT NULL,
  target_distance_meters      NUMERIC(10, 2),
  target_duration_seconds     INTEGER,
  target_pace_seconds_per_km  NUMERIC(10, 2),
  target_intensity            TEXT,
  recovery_duration_seconds   INTEGER,
  actual_distance_meters      NUMERIC(10, 2),
  actual_duration_seconds     INTEGER,
  actual_pace_seconds_per_km  NUMERIC(10, 2),
  average_heart_rate          INTEGER,
  max_heart_rate              INTEGER,
  rpe                         SMALLINT,
  completed                   BOOLEAN NOT NULL DEFAULT FALSE,
  skipped                     BOOLEAN NOT NULL DEFAULT FALSE,
  data_source                 TEXT NOT NULL DEFAULT 'manual',
  athlete_note                TEXT,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT training_session_intervals_unique_phase
    UNIQUE (training_session_id, block_index, rep_number, phase_type),
  CONSTRAINT training_session_intervals_rpe_range
    CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10)),
  CONSTRAINT training_session_intervals_target_distance_positive
    CHECK (target_distance_meters IS NULL OR target_distance_meters > 0),
  CONSTRAINT training_session_intervals_target_duration_positive
    CHECK (target_duration_seconds IS NULL OR target_duration_seconds > 0),
  CONSTRAINT training_session_intervals_target_pace_positive
    CHECK (target_pace_seconds_per_km IS NULL OR target_pace_seconds_per_km > 0),
  CONSTRAINT training_session_intervals_recovery_duration_positive
    CHECK (recovery_duration_seconds IS NULL OR recovery_duration_seconds > 0),
  CONSTRAINT training_session_intervals_actual_distance_positive
    CHECK (actual_distance_meters IS NULL OR actual_distance_meters > 0),
  CONSTRAINT training_session_intervals_actual_duration_positive
    CHECK (actual_duration_seconds IS NULL OR actual_duration_seconds > 0),
  CONSTRAINT training_session_intervals_actual_pace_positive
    CHECK (actual_pace_seconds_per_km IS NULL OR actual_pace_seconds_per_km > 0),
  CONSTRAINT training_session_intervals_average_hr_positive
    CHECK (average_heart_rate IS NULL OR average_heart_rate > 0),
  CONSTRAINT training_session_intervals_max_hr_positive
    CHECK (max_heart_rate IS NULL OR max_heart_rate > 0)
);

CREATE INDEX idx_training_session_intervals_session
  ON training_session_intervals (training_session_id);

CREATE INDEX idx_training_session_intervals_protocol_step
  ON training_session_intervals (protocol_step_id);

COMMENT ON TABLE training_session_intervals IS
  'Per-phase interval execution records for athlete session resume and history.';
