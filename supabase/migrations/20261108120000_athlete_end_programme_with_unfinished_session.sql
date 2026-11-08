BEGIN;

CREATE FUNCTION public.end_my_fixed_programme(
  p_expected_athlete_id uuid,
  p_assignment_id uuid,
  p_programme_version_id uuid,
  p_allow_unfinished boolean
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  athlete uuid := auth.uid();
  assignment public.programme_assignments%ROWTYPE;
  previous_guard text;
BEGIN
  IF athlete IS NULL OR p_expected_athlete_id IS DISTINCT FROM athlete
    OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object('status', 'access_denied');
  END IF;

  -- A preceding start can commit a session without changing the assignment
  -- row. The session check after acquiring the lock needs a fresh snapshot.
  IF current_setting('transaction_isolation') <> 'read committed' THEN
    RETURN jsonb_build_object('status', 'unavailable');
  END IF;

  -- Share the acquisition lock, then serialize with fixed session starts and
  -- completions on the assignment row. The locked row is the only write target.
  PERFORM pg_advisory_xact_lock(84202613, hashtext(athlete::text));
  SELECT * INTO assignment FROM public.programme_assignments
  WHERE id = p_assignment_id AND athlete_id = athlete FOR UPDATE;
  IF NOT FOUND OR assignment.programme_version_id IS DISTINCT FROM p_programme_version_id THEN
    RETURN jsonb_build_object('status', 'access_denied');
  END IF;
  IF assignment.ended_at IS NULL THEN
    IF assignment.status <> 'active' OR assignment.schedule_mode <> 'fixed_schedule'
      OR assignment.materialised_at IS NULL THEN
      RETURN jsonb_build_object('status', 'programme_not_active');
    END IF;
    -- The explicit confirmation ends the assignment only. The original
    -- session and actuals remain attached to that now-terminal assignment.
    IF p_allow_unfinished IS NOT TRUE AND (EXISTS (
      SELECT 1 FROM public.programme_slot_outcomes o
      LEFT JOIN public.training_sessions s ON s.id = o.training_session_id
      WHERE o.assignment_id = assignment.id
      AND (o.outcome_status = 'in_progress' OR s.status = 'in_progress')
    ) OR EXISTS (
      SELECT 1 FROM public.training_session_records r
      WHERE r.assignment_id = assignment.id AND r.athlete_id = athlete::text
      AND r.status = 'in_progress'
    )) THEN
      RETURN jsonb_build_object('status', 'programme_session_in_progress');
    END IF;

    previous_guard := current_setting('cohort.allow_materialisation_write', true);
    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    UPDATE public.programme_assignments
    SET status = 'paused', ended_at = transaction_timestamp()
    WHERE id = assignment.id
    RETURNING * INTO assignment;
    PERFORM set_config('cohort.allow_materialisation_write', coalesce(previous_guard, ''), true);
  END IF;

  RETURN jsonb_build_object('status', 'ok', 'athlete_id', assignment.athlete_id,
    'assignment_id', assignment.id, 'programme_version_id', assignment.programme_version_id);
END $$;

REVOKE ALL ON FUNCTION public.end_my_fixed_programme(uuid,uuid,uuid,boolean)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.end_my_fixed_programme(uuid,uuid,uuid,boolean) TO authenticated;

-- Keep the installed three-argument client contract, including its refusal
-- to end while a session is in progress.
CREATE OR REPLACE FUNCTION public.end_my_fixed_programme(
  p_expected_athlete_id uuid,
  p_assignment_id uuid,
  p_programme_version_id uuid
) RETURNS jsonb
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT public.end_my_fixed_programme(
    p_expected_athlete_id, p_assignment_id, p_programme_version_id, false
  );
$$;

COMMIT;
