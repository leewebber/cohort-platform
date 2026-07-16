-- Allow Coach Studio dev-coach programme authoring (lineage → version → template tree)
-- Related:
--   20260715130000_add_programme_engine_dev_policies.sql
--   20260715140000_fix_programme_dev_rls_recursion.sql
--
-- =============================================================================
-- EXISTING POLICY GAP (why New Programme failed with 42501 on programme_lineages)
-- =============================================================================
--
-- 1. programme_lineages INSERT
--    Migration 130000 defined dev_programme_lineages_insert, but migration 140000
--    only recreated SELECT. If INSERT was never applied on the target project, anon
--    has no permissive INSERT policy → 42501 on insertLineage.
--
-- 2. programme_versions INSERT / SELECT / UPDATE
--    Only cohort_global + owner_type = global drafts are writable/readable in dev.
--    Coach Studio creates coach_private + owner_type = coach + owner_id = dev-coach.
--    No policy covered that path → version + tree writes would fail after lineage.
--
-- 3. Template child tables (phases/weeks/days/slots)
--    Write policies call cohort_programme_version_is_dev_draft_global(), which
--    excludes coach-owned drafts.
--
-- 4. programme_lineages SELECT
--    cohort_programme_lineage_has_dev_readable_version() requires an existing
--    readable version — a brand-new lineage has none until version insert succeeds.
--
-- FIX (additive, temporary, owner-scoped):
--   - SECURITY DEFINER helpers for dev-coach-owned draft/read/delete gates
--   - Parallel dev_programme_*_coach policies (do not weaken global/org boundaries)
--   - Preserve existing Cohort Global catalogue + assignment policies unchanged
--
-- BEFORE EXTERNAL BETA:
--   Drop all dev_programme_*_coach policies and cohort_programme_*_coach_* helpers.
--   Replace with auth.uid() ownership. Remove anon write access entirely.

-- ---------------------------------------------------------------------------
-- SECURITY DEFINER helpers — dev-coach ownership only, no dynamic SQL
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_programme_lineage_is_dev_coach_owned(p_lineage_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_lineages l
    WHERE l.id = p_lineage_id
      AND (
        l.created_by = cohort_programme_dev_coach_id()
        OR l.created_by IS NULL
      )
  );
$$;

COMMENT ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) IS
  'TEMPORARY: lineage owned by dev-coach for Coach Studio authoring. Replace with auth.uid() before beta.';

CREATE OR REPLACE FUNCTION cohort_programme_lineage_is_dev_coach_deletable(p_lineage_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_lineages l
    WHERE l.id = p_lineage_id
      AND (
        l.created_by = cohort_programme_dev_coach_id()
        OR l.created_by IS NULL
      )
      AND NOT EXISTS (
        SELECT 1
        FROM programme_versions v
        WHERE v.lineage_id = l.id
          AND v.lifecycle_status = 'published'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM programme_versions v
        JOIN programme_assignments a ON a.programme_version_id = v.id
        WHERE v.lineage_id = l.id
      )
  );
$$;

COMMENT ON FUNCTION cohort_programme_lineage_is_dev_coach_deletable(UUID) IS
  'TEMPORARY: dev-coach lineage delete gate — no published versions or assignments.';

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_coach_readable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    WHERE v.id = p_version_id
      AND v.owner_type = 'coach'
      AND v.owner_id = cohort_programme_dev_coach_id()
      AND v.library_scope = 'coach_private'
      AND v.organisation_id IS NULL
      AND v.lifecycle_status IN ('draft', 'published', 'archived')
  );
$$;

COMMENT ON FUNCTION cohort_programme_version_is_dev_coach_readable(UUID) IS
  'TEMPORARY: read gate for dev-coach coach_private catalogue rows. Bypasses RLS recursion.';

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_coach_draft_writable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    JOIN programme_lineages l ON l.id = v.lineage_id
    WHERE v.id = p_version_id
      AND v.lifecycle_status = 'draft'
      AND v.owner_type = 'coach'
      AND v.owner_id = cohort_programme_dev_coach_id()
      AND v.library_scope = 'coach_private'
      AND v.approved_for_global = FALSE
      AND v.organisation_id IS NULL
      AND (
        l.created_by = cohort_programme_dev_coach_id()
        OR l.created_by IS NULL
      )
  );
$$;

COMMENT ON FUNCTION cohort_programme_version_is_dev_coach_draft_writable(UUID) IS
  'TEMPORARY: write gate for dev-coach draft versions and child template rows.';

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    WHERE v.id = p_version_id
      AND v.lifecycle_status = 'draft'
      AND v.owner_type = 'coach'
      AND v.owner_id = cohort_programme_dev_coach_id()
      AND v.library_scope = 'coach_private'
      AND v.organisation_id IS NULL
      AND v.published_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM programme_assignments a
        WHERE a.programme_version_id = v.id
      )
  );
$$;

COMMENT ON FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(UUID) IS
  'TEMPORARY: delete gate for unassigned dev-coach drafts only.';

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
    WHERE w.id = p_week_id
      AND cohort_programme_version_is_dev_coach_readable(w.version_id)
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
    WHERE w.id = p_week_id
      AND cohort_programme_version_is_dev_coach_draft_writable(w.version_id)
  );
$$;

CREATE OR REPLACE FUNCTION cohort_programme_day_is_dev_coach_readable(p_day_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_version_days d
    JOIN programme_version_weeks w ON w.id = d.week_id
    WHERE d.id = p_day_id
      AND cohort_programme_version_is_dev_coach_readable(w.version_id)
  );
$$;

CREATE OR REPLACE FUNCTION cohort_programme_day_is_dev_coach_draft_writable(p_day_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_version_days d
    JOIN programme_version_weeks w ON w.id = d.week_id
    WHERE d.id = p_day_id
      AND cohort_programme_version_is_dev_coach_draft_writable(w.version_id)
  );
$$;

-- Trusted owner + least-privilege execute grants
ALTER FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_lineage_is_dev_coach_deletable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_version_is_dev_coach_readable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_version_is_dev_coach_draft_writable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_week_is_dev_coach_readable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_week_is_dev_coach_draft_writable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_day_is_dev_coach_readable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_day_is_dev_coach_draft_writable(UUID) OWNER TO postgres;

REVOKE ALL ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_lineage_is_dev_coach_deletable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_coach_readable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_coach_draft_writable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_week_is_dev_coach_readable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_week_is_dev_coach_draft_writable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_day_is_dev_coach_readable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_day_is_dev_coach_draft_writable(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_lineage_is_dev_coach_deletable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_coach_readable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_coach_draft_writable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_week_is_dev_coach_readable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_week_is_dev_coach_draft_writable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_day_is_dev_coach_readable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_day_is_dev_coach_draft_writable(UUID) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- programme_lineages — dev-coach authoring (additive)
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_lineages_insert_coach
  ON programme_lineages
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    created_by = cohort_programme_dev_coach_id()
    OR created_by IS NULL
  );

COMMENT ON POLICY dev_programme_lineages_insert_coach ON programme_lineages IS
  'TEMPORARY DEV: anon insert for Coach Studio lineage creation (dev-coach only). Remove before beta.';

CREATE POLICY dev_programme_lineages_select_coach
  ON programme_lineages
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_lineage_is_dev_coach_owned(id));

COMMENT ON POLICY dev_programme_lineages_select_coach ON programme_lineages IS
  'TEMPORARY DEV: read dev-coach-owned lineages (including before first version exists).';

CREATE POLICY dev_programme_lineages_update_coach
  ON programme_lineages
  FOR UPDATE
  TO anon, authenticated
  USING (cohort_programme_lineage_is_dev_coach_owned(id))
  WITH CHECK (
    created_by = cohort_programme_dev_coach_id()
    OR created_by IS NULL
  );

CREATE POLICY dev_programme_lineages_delete_coach
  ON programme_lineages
  FOR DELETE
  TO anon, authenticated
  USING (cohort_programme_lineage_is_dev_coach_deletable(id));

-- ---------------------------------------------------------------------------
-- programme_versions — dev-coach coach_private drafts (additive)
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_versions_select_coach
  ON programme_versions
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_readable(id));

COMMENT ON POLICY dev_programme_versions_select_coach ON programme_versions IS
  'TEMPORARY DEV: coach_private rows owned by dev-coach (draft + published catalogue).';

CREATE POLICY dev_programme_versions_insert_coach_draft
  ON programme_versions
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    lifecycle_status = 'draft'
    AND owner_type = 'coach'
    AND owner_id = cohort_programme_dev_coach_id()
    AND library_scope = 'coach_private'
    AND approved_for_global = FALSE
    AND organisation_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM programme_lineages l
      WHERE l.id = lineage_id
        AND (
          l.created_by = cohort_programme_dev_coach_id()
          OR l.created_by IS NULL
        )
    )
  );

COMMENT ON POLICY dev_programme_versions_insert_coach_draft ON programme_versions IS
  'TEMPORARY DEV: New Programme creates coach_private draft v1 under dev-coach lineage.';

CREATE POLICY dev_programme_versions_update_coach_draft
  ON programme_versions
  FOR UPDATE
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_draft_writable(id))
  WITH CHECK (cohort_programme_version_is_dev_coach_draft_writable(id));

CREATE POLICY dev_programme_versions_delete_coach_draft
  ON programme_versions
  FOR DELETE
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_draft_deletable(id));

-- ---------------------------------------------------------------------------
-- Template structure — dev-coach draft tree (additive, parallel to global policies)
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_version_phases_select_coach
  ON programme_version_phases
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_readable(version_id));

CREATE POLICY dev_programme_version_phases_write_coach
  ON programme_version_phases
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_draft_writable(version_id))
  WITH CHECK (cohort_programme_version_is_dev_coach_draft_writable(version_id));

CREATE POLICY dev_programme_version_weeks_select_coach
  ON programme_version_weeks
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_readable(version_id));

CREATE POLICY dev_programme_version_weeks_write_coach
  ON programme_version_weeks
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_draft_writable(version_id))
  WITH CHECK (cohort_programme_version_is_dev_coach_draft_writable(version_id));

CREATE POLICY dev_programme_version_days_select_coach
  ON programme_version_days
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_week_is_dev_coach_readable(week_id));

CREATE POLICY dev_programme_version_days_write_coach
  ON programme_version_days
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_week_is_dev_coach_draft_writable(week_id))
  WITH CHECK (cohort_programme_week_is_dev_coach_draft_writable(week_id));

CREATE POLICY dev_programme_version_session_slots_select_coach
  ON programme_version_session_slots
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_day_is_dev_coach_readable(day_id));

CREATE POLICY dev_programme_version_session_slots_write_coach
  ON programme_version_session_slots
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_day_is_dev_coach_draft_writable(day_id))
  WITH CHECK (cohort_programme_day_is_dev_coach_draft_writable(day_id));

-- ---------------------------------------------------------------------------
-- Validation queries (run manually after migration apply)
-- ---------------------------------------------------------------------------
--
-- A) anon can insert a dev-coach lineage (expect success)
-- SET ROLE anon;
-- INSERT INTO programme_lineages (code, created_by)
-- VALUES ('COHORT-RLS-TEST-LINEAGE', 'dev-coach')
-- RETURNING id, code, created_by;
-- ROLLBACK;
-- RESET ROLE;
--
-- B) anon can insert a dev-coach draft version under that lineage (expect success)
-- -- (use lineage id from A)
-- SET ROLE anon;
-- INSERT INTO programme_versions (
--   lineage_id, version_number, lifecycle_status, library_scope,
--   owner_type, owner_id, name, approved_for_global
-- ) VALUES (
--   '<lineage-uuid>', 1, 'draft', 'coach_private',
--   'coach', 'dev-coach', 'RLS Test Programme', FALSE
-- ) RETURNING id, name;
-- ROLLBACK;
-- RESET ROLE;
--
-- C) anon can insert week/day/slot beneath owned draft (expect success)
-- -- (use version id from B; week/day/slot inserts)
--
-- D) anon cannot insert owner_id = 'other-coach' (expect 42501)
-- SET ROLE anon;
-- INSERT INTO programme_versions (
--   lineage_id, version_number, lifecycle_status, library_scope,
--   owner_type, owner_id, name, approved_for_global
-- ) VALUES (
--   '<lineage-uuid>', 2, 'draft', 'coach_private',
--   'coach', 'other-coach', 'Denied Programme', FALSE
-- );
-- RESET ROLE;
--
-- E) anon cannot UPDATE a published version in place (expect 0 rows or 42501)
-- SET ROLE anon;
-- UPDATE programme_versions
-- SET name = 'Mutated'
-- WHERE lifecycle_status = 'published'
--   AND owner_type = 'coach'
--   AND owner_id = 'dev-coach';
-- RESET ROLE;
--
-- F) anon cannot access organisation-owned content (expect 0 rows)
-- SET ROLE anon;
-- SELECT COUNT(*) FROM programme_versions WHERE library_scope = 'organisation';
-- RESET ROLE;
--
-- G) existing Cohort Global reads still work (expect >= 0 seeded rows)
-- SET ROLE anon;
-- SELECT COUNT(*) FROM programme_versions
-- WHERE lifecycle_status = 'published'
--   AND library_scope = 'cohort_global'
--   AND approved_for_global = TRUE;
-- RESET ROLE;
--
-- H) List new coach policies
-- SELECT policyname, tablename, cmd
-- FROM pg_policies
-- WHERE policyname LIKE '%_coach%'
-- ORDER BY tablename, policyname;
