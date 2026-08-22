-- Allow an authenticated athlete to resolve only the published protocol
-- content referenced by their active, materialised programme assignment.
-- The execution loader reads performance_protocols, modular blocks, linked
-- exercises and (only when blocks are absent) legacy protocol_steps directly.

CREATE OR REPLACE FUNCTION public.cohort_can_read_assigned_protocol(
  p_protocol_id TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.programme_assignments a
      JOIN public.programme_version_weeks w
        ON w.version_id = a.programme_version_id
      JOIN public.programme_version_days d
        ON d.week_id = w.id
      JOIN public.programme_version_session_slots s
        ON s.day_id = d.id
      JOIN public.performance_protocols p
        ON p.protocol_id = s.protocol_id
      WHERE s.protocol_id = TRIM(p_protocol_id)
        AND a.status = 'active'
        AND a.materialised_at IS NOT NULL
        AND p.lifecycle_status = 'published'
        AND p.published = 'true'
        AND (
          a.athlete_id = auth.uid()
          OR public.cohort_coach_has_active_athlete(a.athlete_id)
        )
    );
$$;

REVOKE ALL ON FUNCTION public.cohort_can_read_assigned_protocol(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_can_read_assigned_protocol(TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.cohort_can_read_assigned_exercise(
  p_exercise_id TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.session_block_exercises e
      JOIN public.session_blocks b ON b.block_id = e.block_id
      WHERE e.exercise_id = TRIM(p_exercise_id)
        AND public.cohort_can_read_assigned_protocol(b.session_id)
    );
$$;

REVOKE ALL ON FUNCTION public.cohort_can_read_assigned_exercise(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_can_read_assigned_exercise(TEXT) TO authenticated;

ALTER TABLE public.performance_protocols ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_block_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.protocol_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises_v2 ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON TABLE public.performance_protocols TO authenticated;
GRANT SELECT ON TABLE public.session_blocks TO authenticated;
GRANT SELECT ON TABLE public.session_block_exercises TO authenticated;
GRANT SELECT ON TABLE public.protocol_steps TO authenticated;
GRANT SELECT ON TABLE public.exercises_v2 TO authenticated;

CREATE POLICY authenticated_assigned_protocols_select
  ON public.performance_protocols
  FOR SELECT
  TO authenticated
  USING (
    lifecycle_status = 'published'
    AND published = 'true'
    AND public.cohort_can_read_assigned_protocol(protocol_id)
  );

CREATE POLICY authenticated_assigned_session_blocks_select
  ON public.session_blocks
  FOR SELECT
  TO authenticated
  USING (public.cohort_can_read_assigned_protocol(session_id));

CREATE POLICY authenticated_assigned_session_block_exercises_select
  ON public.session_block_exercises
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.session_blocks b
      WHERE b.block_id = session_block_exercises.block_id
        AND public.cohort_can_read_assigned_protocol(b.session_id)
    )
  );

CREATE POLICY authenticated_assigned_protocol_steps_select
  ON public.protocol_steps
  FOR SELECT
  TO authenticated
  USING (public.cohort_can_read_assigned_protocol(protocol_id));

CREATE POLICY authenticated_assigned_exercises_select
  ON public.exercises_v2
  FOR SELECT
  TO authenticated
  USING (
    published IS TRUE
    AND public.cohort_can_read_assigned_exercise(exercise_id)
  );
