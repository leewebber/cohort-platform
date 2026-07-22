-- Fix authenticated coach programme_version_days authoring (42501 on INSERT)
-- Related:
--   20260716150000_allow_dev_coach_programme_authoring.sql
--   20260722130000_production_identity_rls_lockdown.sql
--   20260722150000_fix_authenticated_programme_authoring_insert_returning.sql
--
-- ROOT CAUSE:
--   ProgrammeVersionSupabaseStore.saveTemplateTree() inserts days with
--   .insert().select().single() → INSERT ... RETURNING.
--
--   Production lockdown recreated programme_version_days coach policies using:
--     cohort_programme_day_is_dev_coach_readable(id)
--     cohort_programme_day_is_dev_coach_draft_writable(id)
--
--   Those helpers look up ownership by the day row primary key. On INSERT the
--   day row is not yet visible to the helper subquery, so WITH CHECK and
--   RETURNING SELECT both fail with 42501 even though week_id points at an
--   owned coach draft week that already exists.
--
--   Dev-coach policies (16150000) correctly keyed ownership off week_id:
--     cohort_programme_week_is_dev_coach_draft_writable(week_id)
--
-- OWNERSHIP CHAIN:
--   auth.uid()
--     → programme_lineages.created_by
--     → programme_versions.owner_id (draft coach_private)
--     → programme_version_weeks.version_id
--     → programme_version_days.week_id
--
-- FIX:
--   Recreate programme_version_days coach policies keyed on week_id.
--   Harden week helper functions with direct auth.uid() ownership chain.
--   Align session_slots coach write policy to week ownership for new slots.

-- ---------------------------------------------------------------------------
-- Week ownership helpers — direct auth.uid() chain (supports day INSERT)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_programme_week_is_dev_coach_readable(p_week_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_version_weeks w
    JOIN programme_versions v ON v.id = w.version_id
    JOIN programme_lineages l ON l.id = v.lineage_id
    WHERE w.id = p_week_id
      AND auth.uid() IS NOT NULL
      AND cohort_auth_is_coach()
      AND v.owner_type = 'coach'
      AND v.owner_id = auth.uid()::TEXT
      AND v.library_scope = 'coach_private'
      AND v.organisation_id IS NULL
      AND v.lifecycle_status IN ('draft', 'published', 'archived')
      AND l.created_by = auth.uid()::TEXT
  );
$$;

CREATE OR REPLACE FUNCTION cohort_programme_week_is_dev_coach_draft_writable(p_week_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_version_weeks w
    JOIN programme_versions v ON v.id = w.version_id
    JOIN programme_lineages l ON l.id = v.lineage_id
    WHERE w.id = p_week_id
      AND auth.uid() IS NOT NULL
      AND cohort_auth_is_coach()
      AND v.lifecycle_status = 'draft'
      AND v.owner_type = 'coach'
      AND v.owner_id = auth.uid()::TEXT
      AND v.library_scope = 'coach_private'
      AND v.approved_for_global = FALSE
      AND v.organisation_id IS NULL
      AND l.created_by = auth.uid()::TEXT
  );
$$;

COMMENT ON FUNCTION cohort_programme_week_is_dev_coach_readable(UUID) IS
  'Coach can read template days under owned weeks via lineage → version → week chain.';

COMMENT ON FUNCTION cohort_programme_week_is_dev_coach_draft_writable(UUID) IS
  'Coach can write template days under owned draft weeks (supports day INSERT ... RETURNING).';

-- ---------------------------------------------------------------------------
-- programme_version_days — key policies on week_id, not day id
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS programme_version_days_select_coach ON programme_version_days;
DROP POLICY IF EXISTS programme_version_days_write_coach ON programme_version_days;

CREATE POLICY programme_version_days_select_coach
  ON programme_version_days
  FOR SELECT
  TO authenticated
  USING (cohort_programme_week_is_dev_coach_readable(week_id));

COMMENT ON POLICY programme_version_days_select_coach ON programme_version_days IS
  'Coach reads days under owned weeks via week_id (supports INSERT ... RETURNING).';

CREATE POLICY programme_version_days_write_coach
  ON programme_version_days
  FOR ALL
  TO authenticated
  USING (cohort_programme_week_is_dev_coach_draft_writable(week_id))
  WITH CHECK (cohort_programme_week_is_dev_coach_draft_writable(week_id));

COMMENT ON POLICY programme_version_days_write_coach ON programme_version_days IS
  'Coach writes days under owned draft weeks via week_id ownership chain.';

-- ---------------------------------------------------------------------------
-- programme_version_session_slots — week ownership for new slot INSERT
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS programme_version_session_slots_write_coach ON programme_version_session_slots;

CREATE POLICY programme_version_session_slots_write_coach
  ON programme_version_session_slots
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_week_is_dev_coach_draft_writable(d.week_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_week_is_dev_coach_draft_writable(d.week_id)
    )
  );

COMMENT ON POLICY programme_version_session_slots_write_coach ON programme_version_session_slots IS
  'Coach writes slots under days owned via week → version → lineage chain.';

-- ---------------------------------------------------------------------------
-- Manual verification (hosted)
-- ---------------------------------------------------------------------------
-- 1. Coach creates programme → lineage, version, weeks, days, slots all insert
-- 2. programme_version_days INSERT ... RETURNING succeeds for owned week_id
-- 3. Different coach denied SELECT/INSERT on those days
-- 4. Global catalogue days remain readable only via catalogue policy
