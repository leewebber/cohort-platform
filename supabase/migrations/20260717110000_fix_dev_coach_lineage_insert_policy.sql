-- Fix programme_lineages INSERT failure (42501) for Coach Studio New Programme
-- Related:
--   20260715130000_add_programme_engine_dev_policies.sql
--   20260715140000_fix_programme_dev_rls_recursion.sql
--   20260716150000_allow_dev_coach_programme_authoring.sql
--
-- ROOT CAUSE (confirmed against Dart insert path + schema):
--
--   ProgrammeVersionSupabaseStore.insertLineage() sends:
--     { code: <lineageCode>, created_by: 'dev-coach' }
--   (programme_lineages has no owner_type / owner_id / organisation_id columns)
--
--   PostgREST .insert().select().single() issues INSERT ... RETURNING, which
--   requires BOTH:
--     1) INSERT WITH CHECK — satisfied by dev_programme_lineages_insert(_coach)
--     2) SELECT USING on the returned row — must pass at least one permissive policy
--
--   For a brand-new coach-owned lineage (no versions yet):
--     - dev_programme_lineages_select requires cohort_programme_lineage_has_dev_readable_version(id)
--       → FALSE (no Cohort Global / readable child version exists yet)
--     - dev_programme_lineages_select_coach used cohort_programme_lineage_is_dev_coach_owned(id),
--       an indirect SECURITY DEFINER subquery on programme_lineages instead of the direct
--       created_by column on the new row — fragile for INSERT ... RETURNING and inconsistent
--       with the direct-predicate pattern used on programme_versions (140000).
--
--   When no SELECT policy passes, PostgreSQL rejects the statement with 42501 on insertLineage
--   even though the INSERT WITH CHECK predicate matches the payload.
--
-- FIX (additive, temporary until Supabase Auth):
--   Drop/recreate only programme_lineages dev-coach authoring policies.
--   Use direct row predicates on created_by (actual ownership column on this table).
--   Preserve dev_programme_lineages_select (Cohort Global catalogue lineage reads).
--   Preserve denial for other coach identities and organisation content (no policies added).

-- ---------------------------------------------------------------------------
-- Drop incorrect / duplicate programme_lineages authoring policies only
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS dev_programme_lineages_insert ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_insert_coach ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_select_coach ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_update ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_update_coach ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_delete_coach ON programme_lineages;

-- dev_programme_lineages_select (140000) intentionally preserved — global catalogue reads

-- ---------------------------------------------------------------------------
-- Recreate programme_lineages dev-coach authoring (direct row predicates)
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_lineages_insert_coach
  ON programme_lineages
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (created_by = cohort_programme_dev_coach_id());

COMMENT ON POLICY dev_programme_lineages_insert_coach ON programme_lineages IS
  'TEMPORARY DEV: anon/authenticated insert for Coach Studio lineage creation (dev-coach only). Remove before Supabase Auth beta.';

CREATE POLICY dev_programme_lineages_select_coach
  ON programme_lineages
  FOR SELECT
  TO anon, authenticated
  USING (created_by = cohort_programme_dev_coach_id());

COMMENT ON POLICY dev_programme_lineages_select_coach ON programme_lineages IS
  'TEMPORARY DEV: read dev-coach-owned lineages via direct created_by predicate (supports INSERT ... RETURNING). Remove before Supabase Auth beta.';

CREATE POLICY dev_programme_lineages_update_coach
  ON programme_lineages
  FOR UPDATE
  TO anon, authenticated
  USING (created_by = cohort_programme_dev_coach_id())
  WITH CHECK (created_by = cohort_programme_dev_coach_id());

COMMENT ON POLICY dev_programme_lineages_update_coach ON programme_lineages IS
  'TEMPORARY DEV: update dev-coach-owned lineages only. Remove before Supabase Auth beta.';

CREATE POLICY dev_programme_lineages_delete_coach
  ON programme_lineages
  FOR DELETE
  TO anon, authenticated
  USING (cohort_programme_lineage_is_dev_coach_deletable(id));

COMMENT ON POLICY dev_programme_lineages_delete_coach ON programme_lineages IS
  'TEMPORARY DEV: delete dev-coach lineages only when no published versions or assignments. Remove before Supabase Auth beta.';

-- ---------------------------------------------------------------------------
-- Validation queries (run manually after migration apply)
-- ---------------------------------------------------------------------------
--
-- Positive: anon can insert dev-coach lineage (expect success, rolled back)
-- BEGIN;
-- SET LOCAL ROLE anon;
-- INSERT INTO programme_lineages (code, created_by)
-- VALUES ('RLS-DEV-TEST-TEMP', 'dev-coach');
-- ROLLBACK;
--
-- Negative: anon cannot insert other-coach lineage (expect 42501)
-- BEGIN;
-- SET LOCAL ROLE anon;
-- INSERT INTO programme_lineages (code, created_by)
-- VALUES ('RLS-DEV-TEST-DENY', 'other-coach');
-- ROLLBACK;
--
-- Confirm global catalogue select policy still present:
-- SELECT policyname, cmd FROM pg_policies
-- WHERE tablename = 'programme_lineages'
-- ORDER BY policyname;
