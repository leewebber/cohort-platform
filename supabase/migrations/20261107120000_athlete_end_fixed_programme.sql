BEGIN;

-- Retain the inactive status understood by installed clients. The timestamp
-- distinguishes a terminal athlete end from a resumable pause.
ALTER TABLE public.programme_assignments
  ADD COLUMN ended_at timestamptz,
  ADD CONSTRAINT programme_assignments_ended_inactive_check
    CHECK (ended_at IS NULL OR status = 'paused');

CREATE FUNCTION public.cohort_protect_programme_end()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.ended_at IS NULL THEN RETURN NEW; END IF;
  ELSIF NEW.ended_at IS NOT DISTINCT FROM OLD.ended_at THEN
    RETURN NEW;
  ELSIF OLD.ended_at IS NULL AND NEW.ended_at IS NOT NULL
    AND OLD.status = 'active' AND NEW.status = 'paused'
    AND current_user IN ('postgres', 'supabase_admin')
    AND current_setting('cohort.allow_materialisation_write', true) = 'on' THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Programme end is RPC-only and terminal' USING ERRCODE = '42501';
END $$;

CREATE TRIGGER programme_assignments_protect_end
  BEFORE INSERT OR UPDATE OF ended_at ON public.programme_assignments
  FOR EACH ROW EXECUTE FUNCTION public.cohort_protect_programme_end();

REVOKE ALL ON FUNCTION public.cohort_protect_programme_end()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.end_my_fixed_programme(
  p_expected_athlete_id uuid,
  p_assignment_id uuid,
  p_programme_version_id uuid
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
    IF EXISTS (
      SELECT 1 FROM public.programme_slot_outcomes o
      LEFT JOIN public.training_sessions s ON s.id = o.training_session_id
      WHERE o.assignment_id = assignment.id
      AND (o.outcome_status = 'in_progress' OR s.status = 'in_progress')
    ) OR EXISTS (
      SELECT 1 FROM public.training_session_records r
      WHERE r.assignment_id = assignment.id AND r.athlete_id = athlete::text
      AND r.status = 'in_progress'
    ) THEN
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

REVOKE ALL ON FUNCTION public.end_my_fixed_programme(uuid,uuid,uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.end_my_fixed_programme(uuid,uuid,uuid) TO authenticated;

COMMIT;
