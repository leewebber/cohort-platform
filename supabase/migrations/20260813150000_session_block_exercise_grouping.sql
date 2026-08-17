-- Optional within-block exercise grouping for structured authored sessions.
-- Legacy links remain ungrouped and retain identical read/write behaviour.

ALTER TABLE public.session_block_exercises
  ADD COLUMN IF NOT EXISTS execution_group_key TEXT,
  ADD COLUMN IF NOT EXISTS execution_group_label TEXT,
  ADD COLUMN IF NOT EXISTS execution_group_rounds INT;

ALTER TABLE public.session_block_exercises
  DROP CONSTRAINT IF EXISTS session_block_exercises_execution_group_check;

ALTER TABLE public.session_block_exercises
  ADD CONSTRAINT session_block_exercises_execution_group_check CHECK (
    (
      execution_group_key IS NULL
      AND execution_group_label IS NULL
      AND execution_group_rounds IS NULL
    )
    OR (
      nullif(btrim(execution_group_key), '') IS NOT NULL
      AND nullif(btrim(execution_group_label), '') IS NOT NULL
      AND execution_group_rounds > 0
    )
  );

COMMENT ON COLUMN public.session_block_exercises.execution_group_key IS
  'Optional stable within-block group identity. Null preserves legacy flat exercise order.';
COMMENT ON COLUMN public.session_block_exercises.execution_group_label IS
  'Optional athlete-facing group label; present only with execution_group_key.';
COMMENT ON COLUMN public.session_block_exercises.execution_group_rounds IS
  'Optional authored round count for the within-block group; present only with execution_group_key.';
