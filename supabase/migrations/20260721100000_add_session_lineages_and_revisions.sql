-- M9.1: Session Lineages and immutable Session Revisions
-- Related: 07 Documentation/55_M9_1_Session_Lineages_and_Revisions.md
--
-- protocol_id remains the Session Revision primary identifier.
-- Additive only — preserves all existing protocol_id references.

CREATE TABLE IF NOT EXISTS session_lineages (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name  TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE session_lineages IS
  'M9.1 stable Session identity across immutable revisions (performance_protocols rows).';

ALTER TABLE performance_protocols
  ADD COLUMN IF NOT EXISTS session_lineage_id UUID NULL
    REFERENCES session_lineages (id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS revision_number INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS lifecycle_status TEXT NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_lifecycle_status_check'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_lifecycle_status_check
        CHECK (lifecycle_status IN ('draft', 'published', 'archived'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_lineage_revision_unique'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_lineage_revision_unique
        UNIQUE (session_lineage_id, revision_number);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_revision_number_positive'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_revision_number_positive
        CHECK (revision_number > 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_performance_protocols_session_lineage
  ON performance_protocols (session_lineage_id, revision_number);

CREATE INDEX IF NOT EXISTS idx_performance_protocols_lifecycle_status
  ON performance_protocols (lifecycle_status);

COMMENT ON COLUMN performance_protocols.session_lineage_id IS
  'M9.1 lineage grouping for immutable session revisions.';
COMMENT ON COLUMN performance_protocols.revision_number IS
  'M9.1 monotonic revision number within session_lineage_id.';
COMMENT ON COLUMN performance_protocols.lifecycle_status IS
  'M9.1 draft | published | archived. Published revisions are immutable.';
COMMENT ON COLUMN performance_protocols.published_at IS
  'Timestamp when lifecycle_status became published.';
COMMENT ON COLUMN performance_protocols.archived_at IS
  'Timestamp when lifecycle_status became archived.';

-- Backfill: each existing protocol becomes revision 1 of its own lineage.
DO $$
DECLARE
  protocol_row RECORD;
  new_lineage_id UUID;
BEGIN
  FOR protocol_row IN
    SELECT protocol_id, name, published
    FROM performance_protocols
    WHERE session_lineage_id IS NULL
  LOOP
    new_lineage_id := gen_random_uuid();

    INSERT INTO session_lineages (id, display_name)
    VALUES (new_lineage_id, COALESCE(NULLIF(trim(protocol_row.name), ''), protocol_row.protocol_id));

    UPDATE performance_protocols
    SET
      session_lineage_id = new_lineage_id,
      revision_number = 1,
      lifecycle_status = CASE
        WHEN lower(trim(coalesce(protocol_row.published, ''))) = 'true' 'published'
        ELSE 'draft'
      END,
      published_at = CASE
        WHEN lower(trim(coalesce(protocol_row.published, ''))) = 'true' THEN now()
        ELSE NULL
      END
    WHERE protocol_id = protocol_row.protocol_id;
  END LOOP;
END $$;
