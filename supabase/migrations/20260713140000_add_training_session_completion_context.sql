-- Add completion context to training_sessions for strength session records.
-- Additive only: existing rows receive ended_early = false and null context fields.

ALTER TABLE training_sessions
  ADD COLUMN IF NOT EXISTS session_note TEXT,
  ADD COLUMN IF NOT EXISTS ended_early BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS completion_reason TEXT,
  ADD COLUMN IF NOT EXISTS completed_exercise_count INTEGER,
  ADD COLUMN IF NOT EXISTS total_exercise_count INTEGER;

COMMENT ON COLUMN training_sessions.session_note IS
  'Optional athlete session reflection saved at completion.';
COMMENT ON COLUMN training_sessions.ended_early IS
  'True when the athlete ended the session before all exercises were completed.';
COMMENT ON COLUMN training_sessions.completion_reason IS
  'Optional athlete-selected reason for ending a session early.';
COMMENT ON COLUMN training_sessions.completed_exercise_count IS
  'Exercises fully completed when the session was closed.';
COMMENT ON COLUMN training_sessions.total_exercise_count IS
  'Total programmed exercises in the session at completion time.';
