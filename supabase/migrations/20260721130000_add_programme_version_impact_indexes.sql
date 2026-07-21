-- M10.1 Programme Version impact analysis indexes (additive, non-destructive).

CREATE INDEX IF NOT EXISTS idx_training_session_records_assignment_terminal
  ON training_session_records (assignment_id)
  WHERE assignment_id IS NOT NULL
    AND status <> 'in_progress';

COMMENT ON INDEX idx_training_session_records_assignment_terminal IS
  'M10.1: terminal training records attributable via assignment_id → programme_version_id.';

CREATE INDEX IF NOT EXISTS idx_training_session_records_programme_session_terminal
  ON training_session_records (programme_session_id)
  WHERE programme_session_id IS NOT NULL
    AND status <> 'in_progress';

COMMENT ON INDEX idx_training_session_records_programme_session_terminal IS
  'M10.1: terminal training records attributable via programme_version_session_slots.id.';

CREATE INDEX IF NOT EXISTS idx_programme_assignments_version_active
  ON programme_assignments (programme_version_id, status)
  WHERE status = 'active';

COMMENT ON INDEX idx_programme_assignments_version_active IS
  'M10.1: active assignment impact for exact Programme Version queries.';

CREATE INDEX IF NOT EXISTS idx_programme_version_weeks_version
  ON programme_version_weeks (version_id, week_number);

COMMENT ON INDEX idx_programme_version_weeks_version IS
  'M10.1: session slot traversal for Programme Version impact analysis.';
