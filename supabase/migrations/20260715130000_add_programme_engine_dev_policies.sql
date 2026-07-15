-- Programme Engine development RLS policies (single-user Flutter / anon key)
-- Related: 07 Documentation/42_Programme_Engine_Schema.md, 43_Programme_Engine_Service_Contracts.md
--
-- Auth state at implementation time:
--   - Flutter uses SUPABASE_ANON_KEY only (no Supabase Auth session)
--   - Development athlete context is hardcoded as athlete_id = 'lee'
--   - Service-role key is NOT used in Flutter and must never be
--
-- Strategy:
--   1. Helper functions centralise temporary dev identities
--   2. Cohort Global published catalogue is readable (read-only)
--   3. Cohort Global draft templates are readable/writable for Coach Studio dev
--   4. Coach-private and organisation content remain denied (no policies)
--   5. Assignments and slot outcomes are scoped to dev athlete ids
--
-- BEFORE EXTERNAL BETA (required replacements):
--   - Drop all policies prefixed with dev_programme_
--   - Drop helper functions cohort_programme_dev_*
--   - Add auth.uid() ownership policies for coach/org content
--   - Remove anon write access entirely
--   - Add assignment policies scoped to authenticated athlete or coach relationship

-- ---------------------------------------------------------------------------
-- Development identity helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_programme_dev_athlete_ids()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT ARRAY['lee']::TEXT[];
$$;

COMMENT ON FUNCTION cohort_programme_dev_athlete_ids() IS
  'TEMPORARY development allowlist for Programme Engine RLS. Replace with auth.uid() athlete mapping before beta.';

CREATE OR REPLACE FUNCTION cohort_programme_dev_coach_id()
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 'dev-coach'::TEXT;
$$;

COMMENT ON FUNCTION cohort_programme_dev_coach_id() IS
  'TEMPORARY development coach identity for draft authoring. Replace with auth.uid() before beta.';

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_readable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    WHERE v.id = p_version_id
      AND (
        (
          v.lifecycle_status = 'published'
          AND v.library_scope = 'cohort_global'
          AND v.approved_for_global = TRUE
        )
        OR (
          v.lifecycle_status = 'draft'
          AND v.library_scope = 'cohort_global'
          AND v.owner_type = 'global'
        )
      )
  );
$$;

COMMENT ON FUNCTION cohort_programme_version_is_dev_readable(UUID) IS
  'TEMPORARY readability gate: published global catalogue OR unpublished global draft fixture.';

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_draft_global(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    WHERE v.id = p_version_id
      AND v.lifecycle_status = 'draft'
      AND v.library_scope = 'cohort_global'
      AND v.owner_type = 'global'
      AND (
        v.created_by = cohort_programme_dev_coach_id()
        OR v.created_by IS NULL
      )
  );
$$;

COMMENT ON FUNCTION cohort_programme_version_is_dev_draft_global(UUID) IS
  'TEMPORARY write gate for Coach Studio draft authoring against global templates.';

-- ---------------------------------------------------------------------------
-- programme_lineages
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_lineages_select
  ON programme_lineages
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_versions v
      WHERE v.lineage_id = programme_lineages.id
        AND cohort_programme_version_is_dev_readable(v.id)
    )
  );

COMMENT ON POLICY dev_programme_lineages_select ON programme_lineages IS
  'DEV: read lineages that have a readable Cohort Global version. Replace before beta.';

CREATE POLICY dev_programme_lineages_insert
  ON programme_lineages
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    created_by = cohort_programme_dev_coach_id()
    OR created_by IS NULL
  );

COMMENT ON POLICY dev_programme_lineages_insert ON programme_lineages IS
  'DEV: allow anon draft lineage creation for Coach Studio development only.';

CREATE POLICY dev_programme_lineages_update
  ON programme_lineages
  FOR UPDATE
  TO anon, authenticated
  USING (
    created_by = cohort_programme_dev_coach_id()
    OR created_by IS NULL
  )
  WITH CHECK (
    created_by = cohort_programme_dev_coach_id()
    OR created_by IS NULL
  );

-- ---------------------------------------------------------------------------
-- programme_versions — catalogue reads + draft authoring writes
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_versions_select_catalogue
  ON programme_versions
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_readable(id));

COMMENT ON POLICY dev_programme_versions_select_catalogue ON programme_versions IS
  'DEV: Cohort Global published catalogue reads + unpublished global draft reads. Coach-private and organisation rows remain denied.';

CREATE POLICY dev_programme_versions_insert_draft_global
  ON programme_versions
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    lifecycle_status = 'draft'
    AND library_scope = 'cohort_global'
    AND owner_type = 'global'
    AND (
      created_by = cohort_programme_dev_coach_id()
      OR created_by IS NULL
    )
  );

COMMENT ON POLICY dev_programme_versions_insert_draft_global ON programme_versions IS
  'DEV: authoring writes for unpublished Cohort Global drafts only. No public write to published versions.';

CREATE POLICY dev_programme_versions_update_draft_global
  ON programme_versions
  FOR UPDATE
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_draft_global(id))
  WITH CHECK (cohort_programme_version_is_dev_draft_global(id));

-- ---------------------------------------------------------------------------
-- Template structure — read via readable version; write via draft global version
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_version_phases_select
  ON programme_version_phases
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_readable(version_id));

CREATE POLICY dev_programme_version_phases_write
  ON programme_version_phases
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_draft_global(version_id))
  WITH CHECK (cohort_programme_version_is_dev_draft_global(version_id));

CREATE POLICY dev_programme_version_weeks_select
  ON programme_version_weeks
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_readable(version_id));

CREATE POLICY dev_programme_version_weeks_write
  ON programme_version_weeks
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_draft_global(version_id))
  WITH CHECK (cohort_programme_version_is_dev_draft_global(version_id));

CREATE POLICY dev_programme_version_days_select
  ON programme_version_days
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_weeks w
      WHERE w.id = programme_version_days.week_id
        AND cohort_programme_version_is_dev_readable(w.version_id)
    )
  );

CREATE POLICY dev_programme_version_days_write
  ON programme_version_days
  FOR ALL
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_weeks w
      WHERE w.id = programme_version_days.week_id
        AND cohort_programme_version_is_dev_draft_global(w.version_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_version_weeks w
      WHERE w.id = programme_version_days.week_id
        AND cohort_programme_version_is_dev_draft_global(w.version_id)
    )
  );

CREATE POLICY dev_programme_version_session_slots_select
  ON programme_version_session_slots
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_version_is_dev_readable(w.version_id)
    )
  );

CREATE POLICY dev_programme_version_session_slots_write
  ON programme_version_session_slots
  FOR ALL
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_version_is_dev_draft_global(w.version_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_version_is_dev_draft_global(w.version_id)
    )
  );

-- ---------------------------------------------------------------------------
-- programme_assignments — dev athlete scoped
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_assignments_select
  ON programme_assignments
  FOR SELECT
  TO anon, authenticated
  USING (athlete_id = ANY (cohort_programme_dev_athlete_ids()));

COMMENT ON POLICY dev_programme_assignments_select ON programme_assignments IS
  'DEV: assignment reads limited to development athlete allowlist (lee). Replace with authenticated athlete ownership before beta.';

CREATE POLICY dev_programme_assignments_insert
  ON programme_assignments
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (athlete_id = ANY (cohort_programme_dev_athlete_ids()));

CREATE POLICY dev_programme_assignments_update
  ON programme_assignments
  FOR UPDATE
  TO anon, authenticated
  USING (athlete_id = ANY (cohort_programme_dev_athlete_ids()))
  WITH CHECK (athlete_id = ANY (cohort_programme_dev_athlete_ids()));

-- ---------------------------------------------------------------------------
-- programme_slot_outcomes — via parent assignment scope
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_slot_outcomes_select
  ON programme_slot_outcomes
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  );

CREATE POLICY dev_programme_slot_outcomes_insert
  ON programme_slot_outcomes
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  );

CREATE POLICY dev_programme_slot_outcomes_update
  ON programme_slot_outcomes
  FOR UPDATE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  );

COMMENT ON POLICY dev_programme_slot_outcomes_select ON programme_slot_outcomes IS
  'DEV: slot outcome reads/writes follow assignment athlete scope. Outcome status remains separate from training_sessions.status.';

-- ---------------------------------------------------------------------------
-- Validation queries (comments)
-- ---------------------------------------------------------------------------
--
-- SELECT policyname, tablename, cmd, roles
-- FROM pg_policies
-- WHERE policyname LIKE 'dev_programme_%'
-- ORDER BY tablename, policyname;
--
-- SELECT proname
-- FROM pg_proc
-- WHERE proname LIKE 'cohort_programme_%'
-- ORDER BY proname;
