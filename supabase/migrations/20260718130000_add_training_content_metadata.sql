-- Embedded Session Authoring M1 — training content metadata on performance_protocols
-- Related: 07 Documentation/47_Embedded_Session_Authoring.md
--
-- Assumes pre-existing table:
--   performance_protocols (protocol_id TEXT PRIMARY KEY, published BOOLEAN, …)
--   protocol_steps (protocol_id → performance_protocols.protocol_id)
--
-- Does NOT create a second training-content stack. Adds classification columns only.
-- RLS on performance_protocols is unchanged in M1 (future owner-scoped policies documented).

-- ---------------------------------------------------------------------------
-- Additive columns
-- ---------------------------------------------------------------------------

ALTER TABLE performance_protocols
  ADD COLUMN IF NOT EXISTS content_kind TEXT NOT NULL DEFAULT 'cohort_protocol',
  ADD COLUMN IF NOT EXISTS authoring_scope TEXT NOT NULL DEFAULT 'cohort_global',
  ADD COLUMN IF NOT EXISTS endorsement_status TEXT NOT NULL DEFAULT 'cohort_endorsed',
  ADD COLUMN IF NOT EXISTS owner_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS organisation_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS programme_version_id UUID NULL,
  ADD COLUMN IF NOT EXISTS source_content_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS source_content_kind TEXT NULL,
  ADD COLUMN IF NOT EXISTS source_version_id TEXT NULL;

COMMENT ON COLUMN performance_protocols.content_kind IS
  'Training content classification: cohort_protocol | session | session_template. Programme-only workouts use session + programme_only scope (not a separate kind).';
COMMENT ON COLUMN performance_protocols.authoring_scope IS
  'Visibility/ownership scope: cohort_global | coach_private | organisation | programme_only.';
COMMENT ON COLUMN performance_protocols.endorsement_status IS
  'Endorsement/review state: cohort_endorsed | organisation_approved | coach_authored | unreviewed.';
COMMENT ON COLUMN performance_protocols.owner_id IS
  'Coach owner for coach_private sessions/templates. TEXT to match programme_versions.owner_id and dev-coach identity during development.';
COMMENT ON COLUMN performance_protocols.organisation_id IS
  'Organisation scope identifier when authoring_scope = organisation.';
COMMENT ON COLUMN performance_protocols.programme_version_id IS
  'Populated when authoring_scope = programme_only; FK to programme_versions.id.';
COMMENT ON COLUMN performance_protocols.source_content_id IS
  'Provenance: source protocol/session/template id when copied or customised.';
COMMENT ON COLUMN performance_protocols.source_content_kind IS
  'Provenance: kind of source content (cohort_protocol | session | session_template).';
COMMENT ON COLUMN performance_protocols.source_version_id IS
  'Provenance: optional version identifier for source content.';

-- owner_id / organisation_id use TEXT (not UUID) to align with programme_versions
-- and temporary dev identities (cohort_programme_dev_coach_id() returns TEXT).

-- ---------------------------------------------------------------------------
-- Foreign keys (types verified: programme_versions.id is UUID)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'performance_protocols_programme_version_id_fkey'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_programme_version_id_fkey
        FOREIGN KEY (programme_version_id)
        REFERENCES programme_versions (id)
        ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Check constraints (named, consistent with programme_versions style)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_content_kind_check'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_content_kind_check
        CHECK (content_kind IN ('cohort_protocol', 'session', 'session_template'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_authoring_scope_check'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_authoring_scope_check
        CHECK (authoring_scope IN (
          'cohort_global',
          'coach_private',
          'organisation',
          'programme_only'
        ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_endorsement_status_check'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_endorsement_status_check
        CHECK (endorsement_status IN (
          'cohort_endorsed',
          'organisation_approved',
          'coach_authored',
          'unreviewed'
        ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'performance_protocols_source_content_kind_check'
  ) THEN
    ALTER TABLE performance_protocols
      ADD CONSTRAINT performance_protocols_source_content_kind_check
        CHECK (
          source_content_kind IS NULL
          OR source_content_kind IN (
            'cohort_protocol',
            'session',
            'session_template'
          )
        );
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Query indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_performance_protocols_cohort_catalogue
  ON performance_protocols (content_kind, authoring_scope, published)
  WHERE content_kind = 'cohort_protocol'
    AND authoring_scope = 'cohort_global';

CREATE INDEX IF NOT EXISTS idx_performance_protocols_coach_sessions
  ON performance_protocols (owner_id, content_kind, authoring_scope)
  WHERE content_kind = 'session'
    AND authoring_scope = 'coach_private';

CREATE INDEX IF NOT EXISTS idx_performance_protocols_programme_sessions
  ON performance_protocols (programme_version_id, content_kind, authoring_scope)
  WHERE content_kind = 'session'
    AND authoring_scope = 'programme_only';

CREATE INDEX IF NOT EXISTS idx_performance_protocols_session_templates
  ON performance_protocols (content_kind, authoring_scope, owner_id)
  WHERE content_kind = 'session_template';

-- ---------------------------------------------------------------------------
-- Backfill legacy official content
-- ---------------------------------------------------------------------------
-- All pre-existing rows are imported official Cohort training content.
-- Defaults on ADD COLUMN already set cohort_protocol / cohort_global / cohort_endorsed.
-- Explicit UPDATE ensures rows created before defaults apply are normalized.
-- Preserves: protocol_id, published, name, all other metadata, protocol_steps links.

DO $$
DECLARE
  legacy_count INT;
BEGIN
  UPDATE performance_protocols
  SET
    content_kind = 'cohort_protocol',
    authoring_scope = 'cohort_global',
    endorsement_status = 'cohort_endorsed'
  WHERE content_kind IS DISTINCT FROM 'cohort_protocol'
     OR authoring_scope IS DISTINCT FROM 'cohort_global'
     OR endorsement_status IS DISTINCT FROM 'cohort_endorsed';

  SELECT COUNT(*) INTO legacy_count
  FROM performance_protocols
  WHERE content_kind = 'cohort_protocol'
    AND authoring_scope = 'cohort_global'
    AND endorsement_status = 'cohort_endorsed';

  RAISE NOTICE '[TrainingContentMigration] legacy cohort protocol count=%', legacy_count;
END $$;
