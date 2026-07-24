-- Founder Programme Importer V1 — stable idempotency key on programme lineages.

ALTER TABLE programme_lineages
  ADD COLUMN IF NOT EXISTS import_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS programme_lineages_import_key_unique
  ON programme_lineages (import_key)
  WHERE import_key IS NOT NULL;

COMMENT ON COLUMN programme_lineages.import_key IS
  'Stable founder YAML import identifier (schema programme.import_key). Nullable for legacy lineages.';
