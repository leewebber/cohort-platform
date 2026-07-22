-- Sprint 10: Structured strength exercise prescriptions on session block links.
-- Additive — legacy links without prescription remain valid reference-only rows.

ALTER TABLE session_block_exercises
  ADD COLUMN IF NOT EXISTS prescription JSONB;

COMMENT ON COLUMN session_block_exercises.prescription IS
  'Structured strength prescription (sets, reps, load, rest, tempo, coach cue). Null for legacy reference-only links.';
