-- Programme Engine V1 — additive canonical schema
-- Related: 07 Documentation/42_Programme_Engine_Schema.md
--
-- Legacy tables retained for compatibility (not dropped or renamed):
--   programmes, programme_weeks, programme_sessions
-- Legacy data is NOT migrated in this file.
--
-- Deletion policy summary:
--   programme_lineages        → RESTRICT while versions exist (no silent athlete history loss)
--   programme_versions        → RESTRICT while assignments reference the version
--   version structure rows    → CASCADE when parent draft version is deleted
--   programme_assignments     → RESTRICT on pinned programme_version_id
--   programme_slot_outcomes   → CASCADE when assignment is deleted
--   session_slot template FK  → RESTRICT on outcomes (published slot references preserved)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- updated_at trigger (reusable across Programme Engine mutable tables)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION cohort_set_updated_at() IS
  'Sets updated_at to NOW() on row update. Used by Programme Engine mutable tables.';

-- ---------------------------------------------------------------------------
-- 4.1 programme_lineages — stable human-readable identity (code ≠ PK)
-- ---------------------------------------------------------------------------

CREATE TABLE programme_lineages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT NOT NULL,
  created_by  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_lineages_code_unique UNIQUE (code)
);

CREATE INDEX idx_programme_lineages_code
  ON programme_lineages (code);

COMMENT ON TABLE programme_lineages IS
  'Stable programme identity across versions. code is human-readable (e.g. PROG-HYROX-12); id is the UUID PK. RLS enabled; policies pending auth/ownership implementation. Legacy programmes table retained separately.';
COMMENT ON COLUMN programme_lineages.code IS
  'Human-readable lineage code. Maps from legacy programmes.programme_id. Not the primary key.';
COMMENT ON COLUMN programme_lineages.created_by IS
  'Coach or admin user id that created the lineage.';

-- ---------------------------------------------------------------------------
-- 4.2 programme_versions — versioned template (draft mutable / published immutable)
-- ---------------------------------------------------------------------------

CREATE TABLE programme_versions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lineage_id              UUID NOT NULL
                            REFERENCES programme_lineages (id) ON DELETE RESTRICT,
  version_number          INT NOT NULL,
  lifecycle_status        TEXT NOT NULL,
  library_scope           TEXT NOT NULL,
  owner_type              TEXT NOT NULL,
  owner_id                TEXT,
  organisation_id         TEXT,
  created_by              TEXT,
  name                    TEXT NOT NULL,
  description             TEXT,
  duration_weeks          INT,
  target_athlete          TEXT,
  difficulty              TEXT,
  primary_goal            TEXT,
  equipment_requirements  TEXT,
  sessions_per_week       INT,
  approved_for_global     BOOLEAN NOT NULL DEFAULT FALSE,
  approved_for_adaptation BOOLEAN NOT NULL DEFAULT FALSE,
  published_at            TIMESTAMPTZ,
  archived_at             TIMESTAMPTZ,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_versions_lineage_version_unique
    UNIQUE (lineage_id, version_number),
  CONSTRAINT programme_versions_lifecycle_status_check
    CHECK (lifecycle_status IN ('draft', 'published', 'archived')),
  CONSTRAINT programme_versions_library_scope_check
    CHECK (library_scope IN ('cohort_global', 'coach_private', 'organisation')),
  CONSTRAINT programme_versions_owner_type_check
    CHECK (owner_type IN ('global', 'coach', 'organisation')),
  CONSTRAINT programme_versions_version_number_positive
    CHECK (version_number > 0)
);

CREATE INDEX idx_programme_versions_lineage
  ON programme_versions (lineage_id, version_number);

CREATE INDEX idx_programme_versions_catalogue
  ON programme_versions (lifecycle_status, library_scope);

CREATE INDEX idx_programme_versions_owner_scope
  ON programme_versions (owner_type, owner_id, library_scope);

CREATE INDEX idx_programme_versions_organisation
  ON programme_versions (organisation_id)
  WHERE organisation_id IS NOT NULL;

CREATE INDEX idx_programme_versions_published
  ON programme_versions (lifecycle_status)
  WHERE lifecycle_status = 'published';

COMMENT ON TABLE programme_versions IS
  'Versioned programme template. Published rows are immutable at service level; edits create a new version. Canonical Programme Engine versions. Legacy tables programmes / programme_weeks / programme_sessions remain for compatibility until data cutover.';
COMMENT ON COLUMN programme_versions.organisation_id IS
  'Organisation scope identifier when owner_type = organisation or library_scope = organisation.';
COMMENT ON COLUMN programme_versions.created_by IS
  'Coach user id that authored this version.';
COMMENT ON COLUMN programme_versions.published_at IS
  'Timestamp when lifecycle_status became published.';

-- ---------------------------------------------------------------------------
-- 4.3 programme_version_phases — optional macro blocks (flat weeks are V1 default)
-- ---------------------------------------------------------------------------

CREATE TABLE programme_version_phases (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id   UUID NOT NULL
                 REFERENCES programme_versions (id) ON DELETE CASCADE,
  phase_order  INT NOT NULL,
  title        TEXT NOT NULL,
  intent       TEXT,
  coach_note   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_phases_version_order_unique
    UNIQUE (version_id, phase_order),
  CONSTRAINT programme_version_phases_intent_check
    CHECK (intent IS NULL OR intent IN (
      'build', 'maintain', 'deload', 'test', 'recover', 'technique'
    )),
  CONSTRAINT programme_version_phases_phase_order_positive
    CHECK (phase_order > 0)
);

CREATE INDEX idx_programme_version_phases_version
  ON programme_version_phases (version_id, phase_order);

-- ---------------------------------------------------------------------------
-- 4.4 programme_version_weeks
-- ---------------------------------------------------------------------------

CREATE TABLE programme_version_weeks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id   UUID NOT NULL
                 REFERENCES programme_versions (id) ON DELETE CASCADE,
  phase_id     UUID
                 REFERENCES programme_version_phases (id) ON DELETE SET NULL,
  week_number  INT NOT NULL,
  title        TEXT,
  intent       TEXT,
  coach_note   TEXT,
  athlete_note TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_weeks_version_week_unique
    UNIQUE (version_id, week_number),
  CONSTRAINT programme_version_weeks_intent_check
    CHECK (intent IS NULL OR intent IN (
      'build', 'maintain', 'deload', 'test', 'recover', 'technique'
    )),
  CONSTRAINT programme_version_weeks_week_number_positive
    CHECK (week_number > 0)
);

CREATE INDEX idx_programme_version_weeks_version
  ON programme_version_weeks (version_id, week_number);

CREATE INDEX idx_programme_version_weeks_phase
  ON programme_version_weeks (phase_id)
  WHERE phase_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4.5 programme_version_days — ordinal day keys only (day_1, day_2, …)
-- ---------------------------------------------------------------------------

CREATE TABLE programme_version_days (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_id     UUID NOT NULL
                REFERENCES programme_version_weeks (id) ON DELETE CASCADE,
  day_key     TEXT NOT NULL,
  day_order   INT NOT NULL,
  title       TEXT,
  day_type    TEXT NOT NULL,
  intent      TEXT,
  coach_note  TEXT,
  athlete_note TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_days_week_day_key_unique
    UNIQUE (week_id, day_key),
  CONSTRAINT programme_version_days_week_day_order_unique
    UNIQUE (week_id, day_order),
  CONSTRAINT programme_version_days_day_type_check
    CHECK (day_type IN ('training', 'rest', 'optional')),
  CONSTRAINT programme_version_days_intent_check
    CHECK (intent IS NULL OR intent IN (
      'build', 'maintain', 'deload', 'test', 'recover', 'technique'
    )),
  CONSTRAINT programme_version_days_day_key_ordinal_check
    CHECK (day_key ~ '^day_[1-9][0-9]*$'),
  CONSTRAINT programme_version_days_day_order_positive
    CHECK (day_order > 0)
);

CREATE INDEX idx_programme_version_days_week
  ON programme_version_days (week_id, day_order);

-- ---------------------------------------------------------------------------
-- 4.6 programme_version_session_slots
-- ---------------------------------------------------------------------------

CREATE TABLE programme_version_session_slots (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  day_id                 UUID NOT NULL
                           REFERENCES programme_version_days (id) ON DELETE CASCADE,
  session_order          INT NOT NULL,
  protocol_id            TEXT NOT NULL,
  display_title          TEXT,
  time_of_day            TEXT NOT NULL DEFAULT 'any',
  is_optional            BOOLEAN NOT NULL DEFAULT FALSE,
  completion_expectation TEXT NOT NULL DEFAULT 'required',
  coach_note             TEXT,
  athlete_note           TEXT,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_version_session_slots_day_order_unique
    UNIQUE (day_id, session_order),
  CONSTRAINT programme_version_session_slots_time_of_day_check
    CHECK (time_of_day IN ('morning', 'afternoon', 'evening', 'any')),
  CONSTRAINT programme_version_session_slots_completion_expectation_check
    CHECK (completion_expectation IN ('required', 'optional', 'recommended')),
  CONSTRAINT programme_version_session_slots_session_order_positive
    CHECK (session_order > 0)
);

CREATE INDEX idx_programme_version_session_slots_day
  ON programme_version_session_slots (day_id, session_order);

CREATE INDEX idx_programme_version_session_slots_protocol
  ON programme_version_session_slots (protocol_id);

-- ---------------------------------------------------------------------------
-- 4.7 programme_assignments — athlete cursor source of truth
-- ---------------------------------------------------------------------------

CREATE TABLE programme_assignments (
  id                                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id                          TEXT NOT NULL,
  programme_version_id                UUID NOT NULL
                                        REFERENCES programme_versions (id) ON DELETE RESTRICT,
  lineage_code                        TEXT NOT NULL,
  status                              TEXT NOT NULL,
  started_at                          DATE NOT NULL,
  timezone                            TEXT,
  current_week_number                 INT NOT NULL DEFAULT 1,
  current_day_key                     TEXT NOT NULL DEFAULT 'day_1',
  current_slot_order                  INT NOT NULL DEFAULT 1,
  paused_at                           TIMESTAMPTZ,
  completed_at                        TIMESTAMPTZ,
  superseded_by_assignment_id         UUID
                                        REFERENCES programme_assignments (id) ON DELETE SET NULL,
  last_progressed_training_session_id BIGINT
                                        REFERENCES training_sessions (id) ON DELETE SET NULL,
  created_at                          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_assignments_status_check
    CHECK (status IN ('active', 'paused', 'completed', 'reassigned')),
  CONSTRAINT programme_assignments_current_week_positive
    CHECK (current_week_number > 0),
  CONSTRAINT programme_assignments_current_slot_order_positive
    CHECK (current_slot_order > 0),
  CONSTRAINT programme_assignments_current_day_key_ordinal_check
    CHECK (current_day_key ~ '^day_[1-9][0-9]*$')
);

-- One active assignment per athlete (V1)
CREATE UNIQUE INDEX programme_assignments_one_active_per_athlete
  ON programme_assignments (athlete_id)
  WHERE status = 'active';

CREATE INDEX idx_programme_assignments_athlete_status
  ON programme_assignments (athlete_id, status);

CREATE INDEX idx_programme_assignments_version
  ON programme_assignments (programme_version_id);

CREATE INDEX idx_programme_assignments_lineage_code
  ON programme_assignments (lineage_code);

CREATE INDEX idx_programme_assignments_cursor
  ON programme_assignments (
    athlete_id,
    current_week_number,
    current_day_key,
    current_slot_order
  );

COMMENT ON TABLE programme_assignments IS
  'Athlete enrolment on a pinned published programme version. Source of truth for programme cursor.';
COMMENT ON COLUMN programme_assignments.lineage_code IS
  'Denormalised snapshot of programme_lineages.code for training_sessions.programme_id compatibility.';
COMMENT ON COLUMN programme_assignments.programme_version_id IS
  'ON DELETE RESTRICT — assignments protect historical programme version references.';

-- ---------------------------------------------------------------------------
-- 4.8 programme_slot_outcomes — separate from training_sessions.status
-- ---------------------------------------------------------------------------

CREATE TABLE programme_slot_outcomes (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id            UUID NOT NULL
                             REFERENCES programme_assignments (id) ON DELETE CASCADE,
  session_slot_id          UUID NOT NULL
                             REFERENCES programme_version_session_slots (id) ON DELETE RESTRICT,
  week_number              INT NOT NULL,
  day_key                  TEXT NOT NULL,
  session_order            INT NOT NULL,
  outcome_status           TEXT NOT NULL,
  training_session_id      BIGINT
                             REFERENCES training_sessions (id) ON DELETE SET NULL,
  replacement_protocol_id  TEXT,
  resolution_note          TEXT,
  resolved_at              TIMESTAMPTZ,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_slot_outcomes_assignment_slot_unique
    UNIQUE (assignment_id, session_slot_id),
  CONSTRAINT programme_slot_outcomes_outcome_status_check
    CHECK (outcome_status IN (
      'scheduled',
      'in_progress',
      'completed',
      'completed_partial',
      'skipped',
      'rescheduled',
      'replaced'
    )),
  CONSTRAINT programme_slot_outcomes_day_key_ordinal_check
    CHECK (day_key ~ '^day_[1-9][0-9]*$'),
  CONSTRAINT programme_slot_outcomes_week_number_positive
    CHECK (week_number > 0),
  CONSTRAINT programme_slot_outcomes_session_order_positive
    CHECK (session_order > 0)
);

CREATE INDEX idx_programme_slot_outcomes_assignment_status
  ON programme_slot_outcomes (assignment_id, outcome_status);

CREATE INDEX idx_programme_slot_outcomes_assignment_position
  ON programme_slot_outcomes (assignment_id, week_number, day_key, session_order);

CREATE INDEX idx_programme_slot_outcomes_training_session
  ON programme_slot_outcomes (training_session_id)
  WHERE training_session_id IS NOT NULL;

COMMENT ON TABLE programme_slot_outcomes IS
  'Per-assignment slot resolution. outcome_status is separate from training_sessions.status.';
COMMENT ON COLUMN programme_slot_outcomes.outcome_status IS
  'Slot outcome vocabulary: scheduled, in_progress, completed, completed_partial, skipped, rescheduled, replaced.';
COMMENT ON COLUMN programme_slot_outcomes.replacement_protocol_id IS
  'Effective protocol when outcome_status = replaced (Decision Engine substitution).';
COMMENT ON COLUMN programme_slot_outcomes.session_slot_id IS
  'ON DELETE RESTRICT — protects template references for athlete outcome history.';

-- ---------------------------------------------------------------------------
-- updated_at triggers on mutable tables
-- ---------------------------------------------------------------------------

CREATE TRIGGER programme_lineages_set_updated_at
  BEFORE UPDATE ON programme_lineages
  FOR EACH ROW
  EXECUTE FUNCTION cohort_set_updated_at();

CREATE TRIGGER programme_versions_set_updated_at
  BEFORE UPDATE ON programme_versions
  FOR EACH ROW
  EXECUTE FUNCTION cohort_set_updated_at();

CREATE TRIGGER programme_assignments_set_updated_at
  BEFORE UPDATE ON programme_assignments
  FOR EACH ROW
  EXECUTE FUNCTION cohort_set_updated_at();

CREATE TRIGGER programme_slot_outcomes_set_updated_at
  BEFORE UPDATE ON programme_slot_outcomes
  FOR EACH ROW
  EXECUTE FUNCTION cohort_set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS preparation — enabled without production policies yet
-- Service-role migrations and backend services bypass RLS.
-- Policies will follow auth/ownership implementation milestone.
-- ---------------------------------------------------------------------------

ALTER TABLE programme_lineages ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_version_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_version_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_version_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_version_session_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE programme_slot_outcomes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- VALIDATION QUERIES (run manually after migration apply)
-- ===========================================================================
--
-- 1) Tables created
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND table_name IN (
--     'programme_lineages',
--     'programme_versions',
--     'programme_version_phases',
--     'programme_version_weeks',
--     'programme_version_days',
--     'programme_version_session_slots',
--     'programme_assignments',
--     'programme_slot_outcomes'
--   )
-- ORDER BY table_name;
--
-- 2) Key constraints present
-- SELECT conname, conrelid::regclass AS table_name
-- FROM pg_constraint
-- WHERE conname IN (
--   'programme_lineages_code_unique',
--   'programme_versions_lineage_version_unique',
--   'programme_version_weeks_version_week_unique',
--   'programme_version_days_week_day_key_unique',
--   'programme_version_session_slots_day_order_unique',
--   'programme_assignments_status_check',
--   'programme_slot_outcomes_assignment_slot_unique',
--   'programme_slot_outcomes_outcome_status_check'
-- )
-- ORDER BY table_name, conname;
--
-- 3) Indexes present
-- SELECT indexname, tablename
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND tablename LIKE 'programme_%'
-- ORDER BY tablename, indexname;
--
-- 4) Partial unique index — one active assignment per athlete
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE indexname = 'programme_assignments_one_active_per_athlete';
--
-- 5) RLS enabled
-- SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
-- FROM pg_class c
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public'
--   AND c.relname IN (
--     'programme_lineages',
--     'programme_versions',
--     'programme_version_phases',
--     'programme_version_weeks',
--     'programme_version_days',
--     'programme_version_session_slots',
--     'programme_assignments',
--     'programme_slot_outcomes'
--   )
-- ORDER BY c.relname;
--
-- 6) updated_at triggers attached
-- SELECT tgname, tgrelid::regclass AS table_name
-- FROM pg_trigger
-- WHERE tgname IN (
--   'programme_lineages_set_updated_at',
--   'programme_versions_set_updated_at',
--   'programme_assignments_set_updated_at',
--   'programme_slot_outcomes_set_updated_at'
-- )
-- ORDER BY table_name;
--
-- 7) Foreign key ON DELETE behaviour
-- SELECT
--   con.conname AS constraint_name,
--   src.relname AS source_table,
--   tgt.relname AS target_table,
--   CASE con.confdeltype
--     WHEN 'a' THEN 'NO ACTION'
--     WHEN 'r' THEN 'RESTRICT'
--     WHEN 'c' THEN 'CASCADE'
--     WHEN 'n' THEN 'SET NULL'
--     WHEN 'd' THEN 'SET DEFAULT'
--   END AS on_delete
-- FROM pg_constraint con
-- JOIN pg_class src ON src.oid = con.conrelid
-- JOIN pg_class tgt ON tgt.oid = con.confrelid
-- WHERE src.relname LIKE 'programme_%'
--   AND con.contype = 'f'
-- ORDER BY source_table, constraint_name;
