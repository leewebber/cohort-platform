-- M9.2: Session Revision usage relationship query support
-- Additive index only — no graph table or schema redesign.

CREATE INDEX IF NOT EXISTS idx_training_session_records_source_protocol_terminal
  ON training_session_records (source_protocol_id)
  WHERE status <> 'in_progress'
    AND source_protocol_id IS NOT NULL;

COMMENT ON INDEX idx_training_session_records_source_protocol_terminal IS
  'Supports M9.2 historical usage queries by exact source_protocol_id.';
