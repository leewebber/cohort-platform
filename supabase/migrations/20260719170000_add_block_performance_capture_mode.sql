-- M8.1: explicit performance capture mode on session blocks

ALTER TABLE session_blocks
  ADD COLUMN IF NOT EXISTS performance_capture_mode TEXT NOT NULL DEFAULT 'auto';

ALTER TABLE session_blocks
  DROP CONSTRAINT IF EXISTS session_blocks_performance_capture_mode_check;

ALTER TABLE session_blocks
  ADD CONSTRAINT session_blocks_performance_capture_mode_check CHECK (
    performance_capture_mode IN (
      'auto',
      'completion',
      'strength',
      'endurance',
      'amrap',
      'for_time',
      'interval',
      'rounds',
      'custom_metric'
    )
  );

COMMENT ON COLUMN session_blocks.performance_capture_mode IS
  'M8.1 explicit athlete performance capture mode. auto uses block type and workout format defaults.';
