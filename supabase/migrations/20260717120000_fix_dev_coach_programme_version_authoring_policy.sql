-- Fix programme_versions INSERT/UPDATE failure (42501) for Coach Studio New Programme
-- Related:
--   20260715130000_add_programme_engine_dev_policies.sql
--   20260715140000_fix_programme_dev_rls_recursion.sql
--   20260716150000_allow_dev_coach_programme_authoring.sql
--   20260717110000_fix_dev_coach_lineage_insert_policy.sql
--
-- ROOT CAUSE (confirmed against Dart saveDraftVersion path + schema):
--
--   ProgrammeVersionSupabaseStore.saveDraftVersion() for New Programme:
--     operation = INSERT (version.id is empty)
--     PostgREST .insert().select().single() → INSERT ... RETURNING
--
--   Payload from ProgrammeVersion.toInsertMap() (createDraftProgramme):
--     lineage_id: <new lineage uuid>
--     version_number: 1
--     lifecycle_status: 'draft'
--     library_scope: 'coach_private'
--     owner_type: 'coach'
--     owner_id: 'dev-coach'
--     name: <programme name>
--     approved_for_global: false
--     approved_for_adaptation: false
--     (created_by omitted → NULL; organisation_id omitted → NULL)
--
--   INSERT WITH CHECK on dev_programme_versions_insert_coach_draft matches the payload
--   EXCEPT created_by is NULL (not sent by ProgrammeBuilderCompiler.toVersionRow).
--
--   Failure is INSERT ... RETURNING SELECT:
--     - dev_programme_versions_select_catalogue (140000) only covers cohort_global rows
--       → FALSE for coach_private draft
--     - dev_programme_versions_select_coach (16150000) used indirect
--       cohort_programme_version_is_dev_coach_readable(id) SECURITY DEFINER subquery
--       instead of direct row predicates on owner_type / owner_id / library_scope
--       → same INSERT ... RETURNING gap fixed on programme_lineages (17110000)
--
--   When no SELECT policy passes, PostgreSQL rejects saveDraftVersion with 42501 even
--   though INSERT WITH CHECK would succeed.
--
-- FIX (additive, temporary until Supabase Auth):
--   Drop/recreate only dev-coach programme_versions authoring policies.
--   Use direct row predicates for SELECT and draft UPDATE (supports RETURNING).
--   Use SECURITY DEFINER lineage helper for lineage_id ownership (no RLS recursion).
--   Preserve dev_programme_versions_select_catalogue and global draft policies.

-- ---------------------------------------------------------------------------
-- Ensure lineage ownership helper exists (from 16150000; unchanged semantics)
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
      AND l.created_by = cohort_programme_dev_coach_id()
  );
$$;

COMMENT ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) IS
  'TEMPORARY: lineage authored by dev-coach. SECURITY DEFINER avoids lineage RLS during version INSERT checks. Replace before Supabase Auth beta.';

ALTER FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) OWNER TO postgres;

REVOKE ALL ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- Drop incorrect dev-coach programme_versions authoring policies only
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS dev_programme_versions_select_coach ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_insert_coach_draft ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_update_coach_draft ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_delete_coach_draft ON programme_versions;

-- dev_programme_versions_select_catalogue, insert_draft_global, update_draft_global intentionally preserved

-- ---------------------------------------------------------------------------
-- Shared predicate: dev-coach coach_private version row (direct, no helper)
-- ---------------------------------------------------------------------------

-- SELECT — supports INSERT/UPDATE ... RETURNING for coach-owned catalogue rows
CREATE POLICY dev_programme_versions_select_coach
  ON programme_versions
  FOR SELECT
  TO anon, authenticated
  USING (
    owner_type = 'coach'
    AND owner_id = cohort_programme_dev_coach_id()
    AND library_scope = 'coach_private'
    AND organisation_id IS NULL
    AND lifecycle_status IN ('draft', 'published', 'archived')
  );

COMMENT ON POLICY dev_programme_versions_select_coach ON programme_versions IS
  'TEMPORARY DEV: read dev-coach coach_private versions via direct row predicates (supports INSERT ... RETURNING). Remove before Supabase Auth beta.';

-- INSERT — New Programme first draft (v1)
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
    AND approved_for_adaptation = FALSE
    AND organisation_id IS NULL
    AND (
      created_by = cohort_programme_dev_coach_id()
      OR created_by IS NULL
    )
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  );

COMMENT ON POLICY dev_programme_versions_insert_coach_draft ON programme_versions IS
  'TEMPORARY DEV: insert coach_private draft v1 under dev-coach lineage. created_by may be NULL (current Flutter payload). Remove before Supabase Auth beta.';

-- UPDATE — draft authoring only; published rows remain immutable (no matching USING)
CREATE POLICY dev_programme_versions_update_coach_draft
  ON programme_versions
  FOR UPDATE
  TO anon, authenticated
  USING (
    lifecycle_status = 'draft'
    AND owner_type = 'coach'
    AND owner_id = cohort_programme_dev_coach_id()
    AND library_scope = 'coach_private'
    AND approved_for_global = FALSE
    AND organisation_id IS NULL
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  )
  WITH CHECK (
    lifecycle_status = 'draft'
    AND owner_type = 'coach'
    AND owner_id = cohort_programme_dev_coach_id()
    AND library_scope = 'coach_private'
    AND approved_for_global = FALSE
    AND approved_for_adaptation = FALSE
    AND organisation_id IS NULL
    AND (
      created_by = cohort_programme_dev_coach_id()
      OR created_by IS NULL
    )
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  );

COMMENT ON POLICY dev_programme_versions_update_coach_draft ON programme_versions IS
  'TEMPORARY DEV: update dev-coach drafts only; lifecycle must remain draft. Remove before Supabase Auth beta.';

-- DELETE — unassigned dev-coach drafts only (helper retains assignment safety)
CREATE POLICY dev_programme_versions_delete_coach_draft
  ON programme_versions
  FOR DELETE
  TO anon, authenticated
  USING (cohort_programme_version_is_dev_coach_draft_deletable(id));

COMMENT ON POLICY dev_programme_versions_delete_coach_draft ON programme_versions IS
  'TEMPORARY DEV: delete unassigned dev-coach drafts only. Remove before Supabase Auth beta.';

-- ---------------------------------------------------------------------------
-- Validation queries (run manually after migration apply)
-- ---------------------------------------------------------------------------
--
-- 1) Insert dev-coach lineage
-- BEGIN;
-- SET LOCAL ROLE anon;
-- INSERT INTO programme_lineages (code, created_by)
-- VALUES ('RLS-VERSION-TEST-LINEAGE', 'dev-coach')
-- RETURNING id;
-- -- capture lineage id as :lineage_id
--
-- 2) Insert dev-coach draft version beneath it (expect success)
-- INSERT INTO programme_versions (
--   lineage_id, version_number, lifecycle_status, library_scope,
--   owner_type, owner_id, name, approved_for_global, approved_for_adaptation
-- ) VALUES (
--   :lineage_id, 1, 'draft', 'coach_private',
--   'coach', 'dev-coach', 'RLS Version Test', FALSE, FALSE
-- ) RETURNING id, name;
-- -- capture version id as :version_id
--
-- 3) Update that draft (expect success)
-- UPDATE programme_versions
-- SET name = 'RLS Version Test Updated'
-- WHERE id = :version_id
-- RETURNING id, name;
--
-- 4) Reject owner_id = 'other-coach' (expect 42501)
-- INSERT INTO programme_versions (
--   lineage_id, version_number, lifecycle_status, library_scope,
--   owner_type, owner_id, name, approved_for_global, approved_for_adaptation
-- ) VALUES (
--   :lineage_id, 2, 'draft', 'coach_private',
--   'coach', 'other-coach', 'Denied Coach', FALSE, FALSE
-- );
--
-- 5) Reject owner_type not approved (expect 42501)
-- INSERT INTO programme_versions (
--   lineage_id, version_number, lifecycle_status, library_scope,
--   owner_type, owner_id, name, approved_for_global, approved_for_adaptation
-- ) VALUES (
--   :lineage_id, 3, 'draft', 'coach_private',
--   'global', 'dev-coach', 'Denied Owner Type', FALSE, FALSE
-- );
--
-- 6) Reject lifecycle_status = 'published' through draft authoring path (expect 42501)
-- INSERT INTO programme_versions (
--   lineage_id, version_number, lifecycle_status, library_scope,
--   owner_type, owner_id, name, approved_for_global, approved_for_adaptation
-- ) VALUES (
--   :lineage_id, 4, 'published', 'coach_private',
--   'coach', 'dev-coach', 'Denied Published Insert', FALSE, FALSE
-- );
--
-- 7) Reject organisation-owned version (expect 42501)
-- INSERT INTO programme_versions (
--   lineage_id, version_number, lifecycle_status, library_scope,
--   owner_type, owner_id, organisation_id, name,
--   approved_for_global, approved_for_adaptation
-- ) VALUES (
--   :lineage_id, 5, 'draft', 'organisation',
--   'organisation', 'org-1', 'org-1', 'Denied Organisation', FALSE, FALSE
-- );
--
-- 8) Confirm published global reads still work (expect >= 0)
-- SELECT COUNT(*) FROM programme_versions
-- WHERE lifecycle_status = 'published'
--   AND library_scope = 'cohort_global'
--   AND approved_for_global = TRUE;
--
-- ROLLBACK;
