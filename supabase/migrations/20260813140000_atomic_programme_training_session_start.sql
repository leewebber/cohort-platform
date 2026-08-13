-- Atomic programme occurrence -> training session create-or-resume authority.
--
-- The existing (assignment_id, session_slot_id) uniqueness is the canonical
-- authored occurrence identity. This migration makes each non-null
-- training_session_id belong to at most one outcome and exposes one
-- authenticated transaction that validates programme authority, creates the
-- M8 training session, and links the occurrence.

-- Fail explicitly if historical data cannot satisfy the new one-session /
-- one-occurrence invariant. Never delete, merge, or rewrite athlete data.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.programme_slot_outcomes
    WHERE training_session_id IS NOT NULL
    GROUP BY training_session_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Cannot enforce programme outcome training-session uniqueness: existing duplicate links require explicit repair'
      USING ERRCODE = '23505';
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS programme_slot_outcomes_training_session_uidx
  ON public.programme_slot_outcomes (training_session_id)
  WHERE training_session_id IS NOT NULL;

COMMENT ON INDEX public.programme_slot_outcomes_training_session_uidx IS
  'One training session may be linked to at most one canonical programme slot occurrence.';

CREATE OR REPLACE FUNCTION public.create_or_resume_programme_training_session(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_assignment public.programme_assignments%ROWTYPE;
  v_version public.programme_versions%ROWTYPE;
  v_outcome public.programme_slot_outcomes%ROWTYPE;
  v_session public.training_sessions%ROWTYPE;

  v_assignment_raw TEXT;
  v_slot_raw TEXT;
  v_version_raw TEXT;
  v_assignment_id UUID;
  v_session_slot_id UUID;
  v_programme_version_id UUID;
  v_package_hash TEXT;
  v_programmed_key TEXT;
  v_planned_protocol_id TEXT;
  v_effective_protocol_id TEXT;
  v_expected_week INT;
  v_expected_day TEXT;
  v_expected_slot INT;
  v_expected_key TEXT;
  v_authored_week INT;
  v_authored_day TEXT;
  v_authored_slot INT;
  v_authored_protocol TEXT;
  v_outcome_found BOOLEAN := FALSE;
  v_uuid_pattern CONSTANT TEXT :=
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required'
    );
  END IF;

  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_role_required'
    );
  END IF;

  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  -- Athlete identity and any server-derived session id are never client
  -- authority.
  IF payload ? 'athlete_id'
     OR payload ? 'training_session_id'
     OR payload ? 'outcome_id'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'client_nominated_authority_forbidden'
    );
  END IF;

  v_assignment_raw := payload->>'assignment_id';
  v_slot_raw := payload->>'session_slot_id';
  v_version_raw := payload->>'programme_version_id';
  v_package_hash := payload->>'materialised_package_content_hash';
  v_programmed_key := payload->>'programmed_session_key';
  v_planned_protocol_id := payload->>'planned_protocol_id';
  v_effective_protocol_id := payload->>'effective_protocol_id';
  v_expected_day := payload->>'expected_day_key';

  IF v_assignment_raw IS NULL
     OR v_slot_raw IS NULL
     OR v_version_raw IS NULL
     OR v_package_hash IS NULL
     OR v_programmed_key IS NULL
     OR v_planned_protocol_id IS NULL
     OR v_effective_protocol_id IS NULL
     OR v_expected_day IS NULL
     OR payload->>'expected_week' IS NULL
     OR payload->>'expected_slot_order' IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_args'
    );
  END IF;

  IF v_assignment_raw !~ v_uuid_pattern
     OR v_slot_raw !~ v_uuid_pattern
     OR v_version_raw !~ v_uuid_pattern
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_identity'
    );
  END IF;

  IF v_package_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_package_hash'
    );
  END IF;

  IF v_programmed_key IS DISTINCT FROM btrim(v_programmed_key)
     OR v_programmed_key = ''
     OR v_planned_protocol_id IS DISTINCT FROM btrim(v_planned_protocol_id)
     OR v_planned_protocol_id = ''
     OR v_effective_protocol_id IS DISTINCT FROM btrim(v_effective_protocol_id)
     OR v_effective_protocol_id = ''
     OR v_expected_day !~ '^day_[1-9][0-9]*$'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_args'
    );
  END IF;

  BEGIN
    v_expected_week := (payload->>'expected_week')::INT;
    v_expected_slot := (payload->>'expected_slot_order')::INT;
  EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_args'
    );
  END;

  IF v_expected_week <= 0 OR v_expected_slot <= 0 THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_args'
    );
  END IF;

  v_assignment_id := v_assignment_raw::UUID;
  v_session_slot_id := v_slot_raw::UUID;
  v_programme_version_id := v_version_raw::UUID;

  -- Serialize all starts for one authored occurrence. Hash collisions only
  -- serialize unrelated requests; they cannot merge identities.
  PERFORM pg_advisory_xact_lock(
    84201813,
    hashtext(v_assignment_id::TEXT || ':' || v_session_slot_id::TEXT)
  );

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'assignment_missing'
    );
  END IF;

  IF v_assignment.athlete_id IS DISTINCT FROM v_athlete_id THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'cross_athlete_assignment'
    );
  END IF;

  IF v_assignment.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'assignment_inactive'
    );
  END IF;

  IF v_assignment.materialised_at IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'assignment_not_materialised'
    );
  END IF;

  IF v_assignment.programme_version_id IS DISTINCT FROM v_programme_version_id THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'exact_version_missing'
    );
  END IF;

  IF v_assignment.materialised_package_content_hash IS DISTINCT FROM v_package_hash THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'package_hash_mismatch'
    );
  END IF;

  IF v_assignment.current_week_number IS DISTINCT FROM v_expected_week
     OR v_assignment.current_day_key IS DISTINCT FROM v_expected_day
     OR v_assignment.current_slot_order IS DISTINCT FROM v_expected_slot
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_cursor'
    );
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_programme_version_id;

  IF NOT FOUND
     OR v_version.lifecycle_status IS DISTINCT FROM 'published'
     OR v_version.archived_at IS NOT NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'exact_version_missing'
    );
  END IF;

  IF v_version.package_content_hash IS DISTINCT FROM v_package_hash THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'package_hash_mismatch'
    );
  END IF;

  SELECT w.week_number, d.day_key, s.session_order, s.protocol_id
    INTO v_authored_week, v_authored_day, v_authored_slot, v_authored_protocol
  FROM public.programme_version_session_slots s
  JOIN public.programme_version_days d ON d.id = s.day_id
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  WHERE s.id = v_session_slot_id
    AND w.version_id = v_programme_version_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'authored_slot_mismatch'
    );
  END IF;

  IF v_authored_week IS DISTINCT FROM v_expected_week
     OR v_authored_day IS DISTINCT FROM v_expected_day
     OR v_authored_slot IS DISTINCT FROM v_expected_slot
     OR v_authored_protocol IS DISTINCT FROM v_planned_protocol_id
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'authored_slot_mismatch'
    );
  END IF;

  v_expected_key := format(
    'prog:%s@%s:w%s:%s:s%s:%s',
    v_assignment_id,
    v_programme_version_id,
    v_expected_week,
    v_expected_day,
    v_expected_slot,
    v_planned_protocol_id
  );

  IF v_programmed_key IS DISTINCT FROM v_expected_key THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'programme_key_mismatch'
    );
  END IF;

  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_assignment_id
    AND session_slot_id = v_session_slot_id
  FOR UPDATE;
  v_outcome_found := FOUND;

  IF v_outcome_found
     AND v_outcome.outcome_status NOT IN ('scheduled', 'in_progress')
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'completed_occurrence'
    );
  END IF;

  IF v_outcome_found THEN
    IF v_outcome.week_number IS DISTINCT FROM v_expected_week
       OR v_outcome.day_key IS DISTINCT FROM v_expected_day
       OR v_outcome.session_order IS DISTINCT FROM v_expected_slot
       OR (
         v_outcome.programme_version_id IS NOT NULL
         AND v_outcome.programme_version_id IS DISTINCT FROM v_programme_version_id
       )
       OR (
         v_outcome.materialised_package_content_hash IS NOT NULL
         AND v_outcome.materialised_package_content_hash IS DISTINCT FROM v_package_hash
       )
       OR (
         v_outcome.programmed_session_key IS NOT NULL
         AND v_outcome.programmed_session_key IS DISTINCT FROM v_programmed_key
       )
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'occurrence_identity_conflict'
      );
    END IF;
  END IF;

  IF v_outcome_found AND v_outcome.training_session_id IS NOT NULL THEN
    SELECT * INTO v_session
    FROM public.training_sessions
    WHERE id = v_outcome.training_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'missing_training_session'
      );
    END IF;

    IF v_session.athlete_id IS DISTINCT FROM v_athlete_id::TEXT
       OR v_session.status IS DISTINCT FROM 'in_progress'
       OR v_session.protocol_id IS DISTINCT FROM v_effective_protocol_id
       OR v_session.programme_id NOT IN (
         v_assignment.lineage_code,
         v_programme_version_id::TEXT
       )
       OR v_session.week_number IS DISTINCT FROM v_expected_week
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'training_session_mismatch'
      );
    END IF;

    -- Older valid links may not yet carry the completion-provenance columns.
    -- Fill only null provenance after every authoritative identity check.
    UPDATE public.programme_slot_outcomes
    SET outcome_status = 'in_progress',
        programme_version_id = COALESCE(
          programme_version_id,
          v_programme_version_id
        ),
        materialised_package_content_hash = COALESCE(
          materialised_package_content_hash,
          v_package_hash
        ),
        programmed_session_key = COALESCE(
          programmed_session_key,
          v_programmed_key
        )
    WHERE id = v_outcome.id
    RETURNING * INTO v_outcome;

    RETURN jsonb_build_object(
      'status', 'resumed',
      'code', 'existing_session',
      'training_session',
        to_jsonb(v_session) || jsonb_build_object('day', v_expected_day),
      'outcome_id', v_outcome.id,
      'programmed_session_key', v_programmed_key
    );
  END IF;

  INSERT INTO public.training_sessions (
    athlete_id,
    protocol_id,
    programme_id,
    week_number,
    status,
    started_at,
    created_at,
    updated_at
  ) VALUES (
    v_athlete_id::TEXT,
    v_effective_protocol_id,
    v_assignment.lineage_code,
    v_expected_week,
    'in_progress',
    NOW(),
    NOW(),
    NOW()
  )
  RETURNING * INTO v_session;

  IF v_outcome_found THEN
    UPDATE public.programme_slot_outcomes
    SET outcome_status = 'in_progress',
        training_session_id = v_session.id,
        programme_version_id = v_programme_version_id,
        materialised_package_content_hash = v_package_hash,
        programmed_session_key = v_programmed_key,
        resolved_at = NULL
    WHERE id = v_outcome.id
    RETURNING * INTO v_outcome;
  ELSE
    INSERT INTO public.programme_slot_outcomes (
      assignment_id,
      session_slot_id,
      week_number,
      day_key,
      session_order,
      outcome_status,
      training_session_id,
      programme_version_id,
      materialised_package_content_hash,
      programmed_session_key
    ) VALUES (
      v_assignment_id,
      v_session_slot_id,
      v_expected_week,
      v_expected_day,
      v_expected_slot,
      'in_progress',
      v_session.id,
      v_programme_version_id,
      v_package_hash,
      v_programmed_key
    )
    RETURNING * INTO v_outcome;
  END IF;

  RETURN jsonb_build_object(
    'status', 'created',
    'code', 'session_created',
    'training_session',
      to_jsonb(v_session) || jsonb_build_object('day', v_expected_day),
    'outcome_id', v_outcome.id,
    'programmed_session_key', v_programmed_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_or_resume_programme_training_session(JSONB)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_or_resume_programme_training_session(JSONB)
  FROM anon;
GRANT EXECUTE ON FUNCTION public.create_or_resume_programme_training_session(JSONB)
  TO authenticated;

COMMENT ON FUNCTION public.create_or_resume_programme_training_session(JSONB) IS
  'Atomically creates or resumes one authenticated athlete training session for one exact materialised programme slot occurrence.';
