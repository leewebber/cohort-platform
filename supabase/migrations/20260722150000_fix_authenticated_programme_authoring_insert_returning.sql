-- Fix authenticated coach programme creation (42501 on programme_lineages INSERT)
-- Related:
--   20260717110000_fix_dev_coach_lineage_insert_policy.sql
--   20260717120000_fix_dev_coach_programme_version_authoring_policy.sql
--   20260722130000_production_identity_rls_lockdown.sql
--
-- ROOT CAUSE:
--   ProgrammeVersionSupabaseStore.insertLineage() uses PostgREST
--   .insert().select().single() → INSERT ... RETURNING.
--   INSERT WITH CHECK on programme_lineages_insert_coach passes when
--   created_by = auth.uid()::TEXT, but RETURNING also requires a permissive
--   SELECT policy on the new row.
--
--   For a brand-new coach-owned lineage (no child versions yet):
--     - programme_lineages_select_catalogue requires a readable global version → FALSE
--     - programme_lineages_select_coach used indirect
--       cohort_programme_lineage_is_dev_coach_owned(id) subquery
--       → fragile for INSERT ... RETURNING (same gap fixed for dev-coach in 17110000)
--
--   PostgreSQL rejects the statement with 42501 even though the INSERT payload
--   and WITH CHECK predicate are correct.
--
-- FIX:
--   Recreate coach SELECT/UPDATE lineage policies with direct created_by predicates
--   tied to auth.uid(). Recreate coach SELECT/UPDATE version policies with direct
--   row ownership predicates (supports version INSERT/UPDATE ... RETURNING).
--   INSERT WITH CHECK policies unchanged — still require coach role + ownership.

-- ---------------------------------------------------------------------------
-- programme_lineages — direct row predicates for RETURNING
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS programme_lineages_select_coach ON programme_lineages;
DROP POLICY IF EXISTS programme_lineages_update_coach ON programme_lineages;

CREATE POLICY programme_lineages_select_coach
  ON programme_lineages
  FOR SELECT
  TO authenticated
  USING (
    cohort_auth_is_coach()
    AND created_by = auth.uid()::TEXT
  );

COMMENT ON POLICY programme_lineages_select_coach ON programme_lineages IS
  'Authenticated coach reads own lineages via direct created_by predicate (supports INSERT ... RETURNING).';

CREATE POLICY programme_lineages_update_coach
  ON programme_lineages
  FOR UPDATE
  TO authenticated
  USING (
    cohort_auth_is_coach()
    AND created_by = auth.uid()::TEXT
  )
  WITH CHECK (
    cohort_auth_is_coach()
    AND created_by = auth.uid()::TEXT
  );

COMMENT ON POLICY programme_lineages_update_coach ON programme_lineages IS
  'Authenticated coach updates own lineages only; ownership cannot change.';

-- ---------------------------------------------------------------------------
-- programme_versions — direct row predicates for RETURNING
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS programme_versions_select_coach ON programme_versions;
DROP POLICY IF EXISTS programme_versions_update_coach_draft ON programme_versions;

CREATE POLICY programme_versions_select_coach
  ON programme_versions
  FOR SELECT
  TO authenticated
  USING (
    cohort_auth_is_coach()
    AND owner_type = 'coach'
    AND owner_id = auth.uid()::TEXT
    AND library_scope = 'coach_private'
    AND organisation_id IS NULL
    AND lifecycle_status IN ('draft', 'published', 'archived')
  );

COMMENT ON POLICY programme_versions_select_coach ON programme_versions IS
  'Authenticated coach reads own coach_private versions via direct row predicates (supports INSERT ... RETURNING).';

CREATE POLICY programme_versions_update_coach_draft
  ON programme_versions
  FOR UPDATE
  TO authenticated
  USING (
    cohort_auth_is_coach()
    AND lifecycle_status = 'draft'
    AND owner_type = 'coach'
    AND owner_id = auth.uid()::TEXT
    AND library_scope = 'coach_private'
    AND approved_for_global = FALSE
    AND organisation_id IS NULL
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  )
  WITH CHECK (
    cohort_auth_is_coach()
    AND lifecycle_status = 'draft'
    AND owner_type = 'coach'
    AND owner_id = auth.uid()::TEXT
    AND library_scope = 'coach_private'
    AND approved_for_global = FALSE
    AND approved_for_adaptation = FALSE
    AND organisation_id IS NULL
    AND (
      created_by = auth.uid()::TEXT
      OR created_by IS NULL
    )
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  );

COMMENT ON POLICY programme_versions_update_coach_draft ON programme_versions IS
  'Authenticated coach updates own draft versions under owned lineages.';

-- ---------------------------------------------------------------------------
-- Manual verification (hosted)
-- ---------------------------------------------------------------------------
-- 1. Authenticated coach INSERT programme_lineages (code, created_by) with
--    created_by = auth.uid()::TEXT → success with RETURNING row
-- 2. Same coach INSERT programme_versions draft v1 under owned lineage → success
-- 3. Different authenticated coach SELECT/UPDATE those rows → denied
-- 4. Catalogue-only lineage without coach ownership remains unreadable to coach SELECT policy
