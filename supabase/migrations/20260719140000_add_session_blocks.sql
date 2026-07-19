-- M6: Modular Session Blocks
-- Additive migration — preserves protocol_steps for legacy compatibility.

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
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT session_blocks_block_type_check CHECK (
    block_type IN (
      'warm_up', 'strength', 'skill', 'accessory',
      'conditioning', 'core', 'cool_down', 'custom'
    )
  ),
  CONSTRAINT session_blocks_workout_format_check CHECK (
    workout_format IN (
      'none', 'amrap', 'emom', 'for_time', 'intervals', 'tabata', 'rounds', 'other'
    )
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS session_blocks_session_position_idx
  ON session_blocks (session_id, position);

CREATE INDEX IF NOT EXISTS session_blocks_session_id_idx
  ON session_blocks (session_id);

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

CREATE INDEX IF NOT EXISTS session_block_exercises_block_id_idx
  ON session_block_exercises (block_id);

-- Idempotent backfill: one default block per session with legacy steps and no blocks yet.
INSERT INTO session_blocks (
  session_id,
  block_type,
  title,
  content,
  workout_format,
  coach_notes,
  position
)
SELECT
  ps.protocol_id,
  'custom',
  'Session',
  string_agg(
    trim(
      concat_ws(
        E'\n',
        CASE WHEN coalesce(ps.title, '') <> '' THEN ps.title END,
        CASE WHEN coalesce(ps.notes, '') <> '' THEN ps.notes END,
        CASE WHEN coalesce(ps.metadata->>'sets', '') <> ''
          THEN 'Sets: ' || (ps.metadata->>'sets') END,
        CASE WHEN coalesce(ps.metadata->>'reps', '') <> ''
          THEN 'Reps: ' || (ps.metadata->>'reps') END,
        CASE WHEN coalesce(ps.metadata->>'load', '') <> ''
          THEN 'Load: ' || (ps.metadata->>'load') END,
        CASE WHEN coalesce(ps.metadata->>'duration', '') <> ''
          THEN 'Duration: ' || (ps.metadata->>'duration') END,
        CASE WHEN coalesce(ps.metadata->>'rest', '') <> ''
          THEN 'Rest: ' || (ps.metadata->>'rest') END
      )
    ),
    E'\n\n'
    ORDER BY ps.step_order
  ),
  'none',
  NULL,
  1
FROM protocol_steps ps
WHERE NOT EXISTS (
  SELECT 1 FROM session_blocks sb WHERE sb.session_id = ps.protocol_id
)
GROUP BY ps.protocol_id;

-- Backfill exercise links from legacy steps (ordered, deduped per exercise within block).
INSERT INTO session_block_exercises (block_id, exercise_id, position, display_label_override)
SELECT
  sb.block_id,
  ranked.exercise_id,
  ranked.link_position,
  ranked.display_label_override
FROM session_blocks sb
JOIN LATERAL (
  SELECT
    ps.exercise_id,
    row_number() OVER (ORDER BY ps.step_order) AS link_position,
    NULLIF(trim(ps.title), '') AS display_label_override
  FROM protocol_steps ps
  WHERE ps.protocol_id = sb.session_id
    AND ps.exercise_id IS NOT NULL
    AND trim(ps.exercise_id) <> ''
) ranked ON true
WHERE sb.position = 1
  AND sb.title = 'Session'
  AND sb.block_type = 'custom'
  AND NOT EXISTS (
    SELECT 1 FROM session_block_exercises sbe WHERE sbe.block_id = sb.block_id
  );

COMMENT ON TABLE session_blocks IS
  'M6 modular Session blocks. Prefer over protocol_steps for authoring.';

COMMENT ON TABLE session_block_exercises IS
  'M6 exercise reference links for Session blocks — not prescriptions.';
