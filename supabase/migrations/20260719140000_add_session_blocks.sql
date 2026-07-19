-- M6/M7: Modular Session Blocks (additive)

CREATE TABLE IF NOT EXISTS session_blocks (
  block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id TEXT NOT NULL REFERENCES performance_protocols(protocol_id) ON DELETE CASCADE,
  block_type TEXT NOT NULL DEFAULT 'custom',
  title TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  workout_format TEXT NOT NULL DEFAULT 'none',
  timer_config JSONB,
  coach_notes TEXT,
  position INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS session_blocks_session_position_idx
  ON session_blocks (session_id, position);

CREATE TABLE IF NOT EXISTS session_block_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id UUID NOT NULL REFERENCES session_blocks(block_id) ON DELETE CASCADE,
  exercise_id TEXT NOT NULL,
  position INT NOT NULL,
  display_label_override TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS session_block_exercises_block_position_idx
  ON session_block_exercises (block_id, position);

INSERT INTO session_blocks (
  session_id, block_type, title, content, workout_format, position
)
SELECT
  ps.protocol_id,
  'custom',
  'Session',
  string_agg(
    trim(concat_ws(E'\n',
      CASE WHEN coalesce(ps.title, '') <> '' THEN ps.title END,
      CASE WHEN coalesce(ps.notes, '') <> '' THEN ps.notes END
    )),
    E'\n\n' ORDER BY ps.step_order
  ),
  'none',
  1
FROM protocol_steps ps
WHERE NOT EXISTS (
  SELECT 1 FROM session_blocks sb WHERE sb.session_id = ps.protocol_id
)
GROUP BY ps.protocol_id;
