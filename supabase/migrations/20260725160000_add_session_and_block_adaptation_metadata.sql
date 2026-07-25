-- Milestone 2A Task 3 — Session and block adaptation metadata (additive)
-- Related: 07 Documentation/79_Adaptation_Ontology_V1.md
--
-- Session definitions live on performance_protocols (protocol_id = session revision id).
-- Modular blocks live on session_blocks (session_id → performance_protocols.protocol_id).
--
-- No backfill: legacy rows keep NULL adaptation fields; Dart derives block defaults at read time.
-- Does NOT map primary_capability → SessionIntent. Does NOT persist block type defaults.
-- RLS unchanged. No athlete-facing behaviour change.

-- ---------------------------------------------------------------------------
-- performance_protocols — session-level adaptation metadata
-- ---------------------------------------------------------------------------

ALTER TABLE performance_protocols
  ADD COLUMN IF NOT EXISTS primary_session_intent TEXT NULL,
  ADD COLUMN IF NOT EXISTS secondary_session_intents JSONB NULL,
  ADD COLUMN IF NOT EXISTS minimum_viable_duration_min INTEGER NULL;

COMMENT ON COLUMN performance_protocols.primary_session_intent IS
  'M2A canonical SessionIntent dbValue when explicitly authored (e.g. lower_body_strength). NULL = unset; app ignores unknown values.';
COMMENT ON COLUMN performance_protocols.secondary_session_intents IS
  'M2A JSON array of SessionIntent dbValue strings when explicitly authored. NULL = unset; omit empty arrays at write time in app.';
COMMENT ON COLUMN performance_protocols.minimum_viable_duration_min IS
  'M2A minimum viable session duration in minutes when explicitly authored. NULL = unset.';

-- ---------------------------------------------------------------------------
-- session_blocks — block-level adaptation metadata
-- ---------------------------------------------------------------------------

ALTER TABLE session_blocks
  ADD COLUMN IF NOT EXISTS block_priority TEXT NULL,
  ADD COLUMN IF NOT EXISTS adaptation_policy JSONB NULL;

COMMENT ON COLUMN session_blocks.block_priority IS
  'M2A canonical BlockPriority dbValue when explicitly authored (essential|primary|secondary|optional|disposable). NULL = use block-type default in app only.';
COMMENT ON COLUMN session_blocks.adaptation_policy IS
  'M2A BlockAdaptationPolicy JSON (BlockAdaptationPolicy.toJson shape) when explicitly authored. NULL = use block-type default in app only.';

-- ---------------------------------------------------------------------------
-- Check constraints (named, idempotent — no PostgreSQL enum types)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_minimum_viable_duration_min_positive'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_minimum_viable_duration_min_positive
        CHECK (
          minimum_viable_duration_min IS NULL
          OR minimum_viable_duration_min > 0
        );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_secondary_session_intents_array'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_secondary_session_intents_array
        CHECK (
          secondary_session_intents IS NULL
          OR jsonb_typeof(secondary_session_intents) = 'array'
        );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'session_blocks_block_priority_check'
  ) THEN
    ALTER TABLE session_blocks
      ADD CONSTRAINT session_blocks_block_priority_check
        CHECK (
          block_priority IS NULL
          OR block_priority IN (
            'essential',
            'primary',
            'secondary',
            'optional',
            'disposable'
          )
        );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'session_blocks_adaptation_policy_object'
  ) THEN
    ALTER TABLE session_blocks
      ADD CONSTRAINT session_blocks_adaptation_policy_object
        CHECK (
          adaptation_policy IS NULL
          OR jsonb_typeof(adaptation_policy) = 'object'
        );
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Rollback (manual — run in reverse order if reverting this migration)
-- ---------------------------------------------------------------------------
--
-- ALTER TABLE session_blocks
--   DROP CONSTRAINT IF EXISTS session_blocks_adaptation_policy_object;
-- ALTER TABLE session_blocks
--   DROP CONSTRAINT IF EXISTS session_blocks_block_priority_check;
-- ALTER TABLE session_blocks
--   DROP COLUMN IF EXISTS adaptation_policy;
-- ALTER TABLE session_blocks
--   DROP COLUMN IF EXISTS block_priority;
--
-- ALTER TABLE performance_protocols
--   DROP CONSTRAINT IF EXISTS performance_protocols_secondary_session_intents_array;
-- ALTER TABLE performance_protocols
--   DROP CONSTRAINT IF EXISTS performance_protocols_minimum_viable_duration_min_positive;
-- ALTER TABLE performance_protocols
--   DROP COLUMN IF EXISTS minimum_viable_duration_min;
-- ALTER TABLE performance_protocols
--   DROP COLUMN IF EXISTS secondary_session_intents;
-- ALTER TABLE performance_protocols
--   DROP COLUMN IF EXISTS primary_session_intent;
