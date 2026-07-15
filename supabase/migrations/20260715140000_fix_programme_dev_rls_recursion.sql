-- Fix Programme Engine development RLS infinite recursion (PostgreSQL 54001)
-- Related: 20260715130000_add_programme_engine_dev_policies.sql
--
-- RECURSIVE POLICY CHAIN (why 54001 occurred):
--
--   1. dev_programme_versions_select_catalogue ON programme_versions
--        USING (cohort_programme_version_is_dev_readable(id))
--
--   2. cohort_programme_version_is_dev_readable(UUID) [SECURITY INVOKER]
--        SELECT EXISTS (... FROM programme_versions v WHERE v.id = p_version_id ...)
--
--   3. Step 2 re-enters RLS on programme_versions → step 1 → step 2 → ∞
--
-- The same cycle affected dev_programme_versions_update_draft_global via
-- cohort_programme_version_is_dev_draft_global(). Child-table and lineage
-- policies that called these helpers inherited the failure whenever they
-- reached programme_versions through RLS-protected queries.
--
-- FIX STRATEGY:
--   A. programme_versions policies use direct row predicates (no helper calls).
--   B. Parent-visibility helpers are recreated as narrow SECURITY DEFINER
--      functions with SET search_path = public, pg_temp so child/lineage
--      policies can check version ancestry without re-entering RLS loops.
--   C. Identity helpers (athlete/coach allowlists) remain SECURITY INVOKER.
--
-- BEFORE SUPABASE AUTH (required replacements):
--   Drop dev_programme_* policies and cohort_programme_* helpers; replace with
--   auth.uid() ownership policies. SECURITY DEFINER helpers here are temporary
--   and must not survive production — they bypass RLS by design.

-- ---------------------------------------------------------------------------
-- Drop affected policies only (assignments, slot outcomes, lineage writes unchanged)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS dev_programme_lineages_select ON programme_lineages;

DROP POLICY IF EXISTS dev_programme_versions_select_catalogue ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_update_draft_global ON programme_versions;

DROP POLICY IF EXISTS dev_programme_version_phases_select ON programme_version_phases;
DROP POLICY IF EXISTS dev_programme_version_phases_write ON programme_version_phases;

DROP POLICY IF EXISTS dev_programme_version_weeks_select ON programme_version_weeks;
DROP POLICY IF EXISTS dev_programme_version_weeks_write ON programme_version_weeks;

DROP POLICY IF EXISTS dev_programme_version_days_select ON programme_version_days;
DROP POLICY IF EXISTS dev_programme_version_days_write ON programme_version_days;

DROP POLICY IF EXISTS dev_programme_version_session_slots_select ON programme_version_session_slots;
DROP POLICY IF EXISTS dev_programme_version_session_slots_write ON programme_version_session_slots;

-- ---------------------------------------------------------------------------
-- Drop recursive helpers (recreated below as SECURITY DEFINER)
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS cohort_programme_version_is_dev_readable(UUID);
DROP FUNCTION IF EXISTS cohort_programme_version_is_dev_draft_global(UUID);

-- ---------------------------------------------------------------------------
-- Narrow SECURITY DEFINER helpers — parent visibility only, no dynamic SQL
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_readable(p_version_id UUID)
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
  'TEMPORARY SECURITY DEFINER parent check. Bypasses RLS to avoid policy recursion when child tables validate version readability. Replace with auth-scoped policies before beta.';

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_draft_global(p_version_id UUID)
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
      AND v.library_scope = 'cohort_global'
      AND v.owner_type = 'global'
      AND (
        v.created_by = cohort_programme_dev_coach_id()
        OR v.created_by IS NULL
      )
  );
$$;

COMMENT ON FUNCTION cohort_programme_version_is_dev_draft_global(UUID) IS
  'TEMPORARY SECURITY DEFINER draft write gate. Bypasses RLS to avoid recursion from child-table write policies. Replace before beta.';

CREATE OR REPLACE FUNCTION cohort_programme_lineage_has_dev_readable_version(p_lineage_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    WHERE v.lineage_id = p_lineage_id
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

COMMENT ON FUNCTION cohort_programme_lineage_has_dev_readable_version(UUID) IS
  'TEMPORARY SECURITY DEFINER lineage read gate. Avoids programme_lineages → programme_versions RLS recursion.';

CREATE OR REPLACE FUNCTION cohort_programme_week_is_dev_readable(p_week_id UUID)
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
      AND cohort_programme_version_is_dev_readable(w.version_id)
  );
$$;

COMMENT ON FUNCTION cohort_programme_week_is_dev_readable(UUID) IS
  'TEMPORARY SECURITY DEFINER week → version readability bridge for day policies.';

CREATE OR REPLACE FUNCTION cohort_programme_week_is_dev_draft_global(p_week_id UUID)
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
      AND cohort_programme_version_is_dev_draft_global(w.version_id)
  );
$$;

COMMENT ON FUNCTION cohort_programme_week_is_dev_draft_global(UUID) IS
  'TEMPORARY SECURITY DEFINER week → version draft write bridge for day policies.';

CREATE OR REPLACE FUNCTION cohort_programme_day_is_dev_readable(p_day_id UUID)
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
      AND cohort_programme_version_is_dev_readable(w.version_id)
  );
$$;

COMMENT ON FUNCTION cohort_programme_day_is_dev_readable(UUID) IS
  'TEMPORARY SECURITY DEFINER day → version readability bridge for slot policies.';

CREATE OR REPLACE FUNCTION cohort_programme_day_is_dev_draft_global(p_day_id UUID)
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
      AND cohort_programme_version_is_dev_draft_global(w.version_id)
  );
$$;

COMMENT ON FUNCTION cohort_programme_day_is_dev_draft_global(UUID) IS
  'TEMPORARY SECURITY DEFINER day → version draft write bridge for slot policies.';

-- Trusted owner + least-privilege execute grants
ALTER FUNCTION cohort_programme_version_is_dev_readable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_version_is_dev_draft_global(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_lineage_has_dev_readable_version(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_week_is_dev_readable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_week_is_dev_draft_global(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_day_is_dev_readable(UUID) OWNER TO postgres;
ALTER FUNCTION cohort_programme_day_is_dev_draft_global(UUID) OWNER TO postgres;

REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_readable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_draft_global(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_lineage_has_dev_readable_version(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_week_is_dev_readable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_week_is_dev_draft_global(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_day_is_dev_readable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_day_is_dev_draft_global(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_readable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_draft_global(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_lineage_has_dev_readable_version(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_week_is_dev_readable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_week_is_dev_draft_global(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_day_is_dev_readable(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_day_is_dev_draft_global(UUID) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- programme_lineages — select via SECURITY DEFINER lineage helper
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_lineages_select
  ON programme_lineages
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_lineage_has_dev_readable_version(id));

COMMENT ON POLICY dev_programme_lineages_select ON programme_lineages IS
  'DEV: read lineages with readable Cohort Global versions. Uses SECURITY DEFINER helper to avoid recursion.';

-- ---------------------------------------------------------------------------
-- programme_versions — direct row predicates (breaks recursion at source)
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_versions_select_catalogue
  ON programme_versions
  FOR SELECT
  TO anon, authenticated
  USING (
    (
      lifecycle_status = 'published'
      AND library_scope = 'cohort_global'
      AND approved_for_global = TRUE
    )
    OR (
      lifecycle_status = 'draft'
      AND library_scope = 'cohort_global'
      AND owner_type = 'global'
    )
  );

COMMENT ON POLICY dev_programme_versions_select_catalogue ON programme_versions IS
  'DEV: direct row predicate — published global catalogue OR unpublished global draft. No helper calls (prevents 54001 recursion).';

CREATE POLICY dev_programme_versions_update_draft_global
  ON programme_versions
  FOR UPDATE
  TO anon, authenticated
  USING (
    lifecycle_status = 'draft'
    AND library_scope = 'cohort_global'
    AND owner_type = 'global'
    AND (
      created_by = cohort_programme_dev_coach_id()
      OR created_by IS NULL
    )
  )
  WITH CHECK (
    lifecycle_status = 'draft'
    AND library_scope = 'cohort_global'
    AND owner_type = 'global'
    AND (
      created_by = cohort_programme_dev_coach_id()
      OR created_by IS NULL
    )
  );

COMMENT ON POLICY dev_programme_versions_update_draft_global ON programme_versions IS
  'DEV: direct row predicate for draft global authoring updates. No helper calls (prevents 54001 recursion).';

-- ---------------------------------------------------------------------------
-- Template structure — SECURITY DEFINER parent checks
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
  USING (cohort_programme_week_is_dev_readable(week_id));

CREATE POLICY dev_programme_version_days_write
  ON programme_version_days
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_week_is_dev_draft_global(week_id))
  WITH CHECK (cohort_programme_week_is_dev_draft_global(week_id));

CREATE POLICY dev_programme_version_session_slots_select
  ON programme_version_session_slots
  FOR SELECT
  TO anon, authenticated
  USING (cohort_programme_day_is_dev_readable(day_id));

CREATE POLICY dev_programme_version_session_slots_write
  ON programme_version_session_slots
  FOR ALL
  TO anon, authenticated
  USING (cohort_programme_day_is_dev_draft_global(day_id))
  WITH CHECK (cohort_programme_day_is_dev_draft_global(day_id));

-- ---------------------------------------------------------------------------
-- Validation queries (run manually after migration apply)
-- ---------------------------------------------------------------------------
--
-- 1) List dev policies
-- SELECT policyname, tablename, cmd, roles, qual, with_check
-- FROM pg_policies
-- WHERE policyname LIKE 'dev_programme_%'
-- ORDER BY tablename, policyname;
--
-- 2) Helper function security settings
-- SELECT
--   p.proname,
--   p.prosecdef AS security_definer,
--   p.provolatile AS volatility,
--   pg_get_userbyid(p.proowner) AS owner,
--   pg_get_function_identity_arguments(p.oid) AS args
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public'
--   AND p.proname LIKE 'cohort_programme_%'
-- ORDER BY p.proname;
--
-- 3) Anon-readable seeded programme (COHORT-FOUNDATION-TEST v1 draft)
-- SET ROLE anon;
-- SELECT v.id, v.name, v.lifecycle_status, v.library_scope
-- FROM programme_versions v
-- JOIN programme_lineages l ON l.id = v.lineage_id
-- WHERE l.code = 'COHORT-FOUNDATION-TEST';
-- RESET ROLE;
--
-- 4) Coach-private rows remain inaccessible (expect 0 rows as anon)
-- SET ROLE anon;
-- SELECT COUNT(*) AS coach_private_visible
-- FROM programme_versions
-- WHERE owner_type = 'coach_private';
-- RESET ROLE;
--
-- 5) Confirm no programme_versions policy references helper functions
-- SELECT policyname, qual
-- FROM pg_policies
-- WHERE tablename = 'programme_versions'
--   AND policyname LIKE 'dev_programme_%'
--   AND (
--     qual LIKE '%cohort_programme_version_is_dev_readable%'
--     OR qual LIKE '%cohort_programme_version_is_dev_draft_global%'
--   );
