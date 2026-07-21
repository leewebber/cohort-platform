-- M9.4: Exercise usage relationship query support
-- Additive indexes only — no graph table or schema redesign.

CREATE INDEX IF NOT EXISTS idx_session_block_exercises_exercise_id
  ON session_block_exercises (exercise_id);

CREATE INDEX IF NOT EXISTS idx_training_exercise_results_source_exercise_terminal
  ON training_exercise_results (source_exercise_id)
  WHERE source_exercise_id IS NOT NULL;

COMMENT ON INDEX idx_session_block_exercises_exercise_id IS
  'Supports M9.4 authored Exercise usage queries through session block links.';

COMMENT ON INDEX idx_training_exercise_results_source_exercise_terminal IS
  'Supports M9.4 historical Exercise usage queries by exact source_exercise_id.';
