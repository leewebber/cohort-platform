-- Final database guarantee: at most one catalogue-eligible Cohort Global
-- programme version per immutable programme lineage.
--
-- Apply only after any pre-existing duplicate-eligible lineage has been
-- reconciled through replace_approved_cohort_global_programme_version().

CREATE UNIQUE INDEX idx_programme_versions_one_catalogue_eligible_per_lineage
  ON public.programme_versions (lineage_id)
  WHERE lifecycle_status = 'published'
    AND library_scope = 'cohort_global'
    AND owner_type = 'global'
    AND approved_for_global = TRUE
    AND archived_at IS NULL;

COMMENT ON INDEX public.idx_programme_versions_one_catalogue_eligible_per_lineage IS
  'Guarantees at most one published, unarchived, globally approved Cohort Global catalogue version per programme lineage.';
