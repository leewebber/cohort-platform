-- Assigned athletes may read the pinned programme graph for versions they
-- are assigned to. Does not edit earlier migrations. Does not mutate
-- assignments, cursors, occurrences, or catalogue defaults.
--
-- Coach day SELECT still requires lineage.created_by. Private publication
-- sets created_by to the operational importer, so owner-athletes could
-- load weeks and not days. Assigned-graph read is the execution authority.

CREATE OR REPLACE FUNCTION public.cohort_can_read_assigned_programme_version(
  p_version_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL
    AND p_version_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.programme_assignments a
      WHERE a.programme_version_id = p_version_id
        AND a.athlete_id = auth.uid()
    );
$$;

REVOKE ALL ON FUNCTION public.cohort_can_read_assigned_programme_version(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_can_read_assigned_programme_version(UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cohort_can_read_assigned_programme_version(UUID) IS
  'TRUE when the caller has any assignment pinned to the version. Guessed ids return FALSE. Does not authorise writes.';

CREATE POLICY programme_versions_select_assigned
  ON public.programme_versions
  FOR SELECT
  TO authenticated
  USING (public.cohort_can_read_assigned_programme_version(id));

COMMENT ON POLICY programme_versions_select_assigned ON public.programme_versions IS
  'Assigned athlete read of a pinned programme version. Not catalogue eligibility.';

CREATE POLICY programme_version_phases_select_assigned
  ON public.programme_version_phases
  FOR SELECT
  TO authenticated
  USING (public.cohort_can_read_assigned_programme_version(version_id));

CREATE POLICY programme_version_weeks_select_assigned
  ON public.programme_version_weeks
  FOR SELECT
  TO authenticated
  USING (public.cohort_can_read_assigned_programme_version(version_id));

CREATE POLICY programme_version_days_select_assigned
  ON public.programme_version_days
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_version_weeks w
      WHERE w.id = week_id
        AND public.cohort_can_read_assigned_programme_version(w.version_id)
    )
  );

CREATE POLICY programme_version_session_slots_select_assigned
  ON public.programme_version_session_slots
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_version_days d
      JOIN public.programme_version_weeks w ON w.id = d.week_id
      WHERE d.id = day_id
        AND public.cohort_can_read_assigned_programme_version(w.version_id)
    )
  );

COMMENT ON POLICY programme_version_days_select_assigned ON public.programme_version_days IS
  'Assigned athlete read of authored days for a pinned version. Cursor namespace remains day_key.';

COMMENT ON POLICY programme_version_session_slots_select_assigned
  ON public.programme_version_session_slots IS
  'Assigned athlete read of authored slots for a pinned version.';
