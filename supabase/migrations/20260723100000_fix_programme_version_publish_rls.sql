-- Fix programme version publish blocked by draft-only UPDATE WITH CHECK (Critical Issue 018).
--
-- Root cause: programme_versions_update_coach_draft required lifecycle_status = 'draft'
-- in WITH CHECK, so draft → published transitions failed (HTTP 403 on UPDATE ... RETURNING).
--
-- Preserves:
--   - draft-only USING (published rows not editable in place)
--   - coach ownership + lineage ownership chain
--   - no blanket authenticated UPDATE
--
-- Applies after 20260722150000_fix_authenticated_programme_authoring_insert_returning.sql

-- ---------------------------------------------------------------------------
-- programme_versions — allow owned draft → published (+ published → archived)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS programme_versions_update_coach_draft ON programme_versions;

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
    AND (
      lifecycle_status = 'draft'
      OR (
        lifecycle_status = 'published'
        AND published_at IS NOT NULL
      )
    )
  );

COMMENT ON POLICY programme_versions_update_coach_draft ON programme_versions IS
  'Authenticated coach updates own draft versions or publishes them (draft USING, draft|published WITH CHECK).';

CREATE POLICY programme_versions_archive_coach
  ON programme_versions
  FOR UPDATE
  TO authenticated
  USING (
    cohort_auth_is_coach()
    AND lifecycle_status = 'published'
    AND owner_type = 'coach'
    AND owner_id = auth.uid()::TEXT
    AND library_scope = 'coach_private'
    AND organisation_id IS NULL
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  )
  WITH CHECK (
    cohort_auth_is_coach()
    AND lifecycle_status = 'archived'
    AND archived_at IS NOT NULL
    AND owner_type = 'coach'
    AND owner_id = auth.uid()::TEXT
    AND library_scope = 'coach_private'
    AND organisation_id IS NULL
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  );

COMMENT ON POLICY programme_versions_archive_coach ON programme_versions IS
  'Authenticated coach archives own published coach_private versions (published → archived only).';

-- ---------------------------------------------------------------------------
-- Manual verification (hosted)
-- ---------------------------------------------------------------------------
-- 1. Authenticated coach UPDATE owned draft SET lifecycle_status = published,
--    published_at = now() → success with RETURNING row visible to select_coach
-- 2. Same coach UPDATE published row content in place → denied (no draft USING)
-- 3. Athlete role UPDATE draft → denied
-- 4. Coach UPDATE another coach draft → denied
