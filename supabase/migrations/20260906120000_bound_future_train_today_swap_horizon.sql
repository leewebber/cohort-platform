-- Constrain Train today swaps to the next seven athlete-local calendar days.
-- Horizon uses assignment-timezone calendar dates, not elapsed UTC hours.

CREATE OR REPLACE FUNCTION public.swap_future_fixed_programme_session_and_begin(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_assignment_id UUID;
  v_today_id UUID;
  v_selected_id UUID;
  v_expected_today DATE;
  v_expected_selected DATE;
  v_expected_rev INT;
  v_assignment public.programme_assignments%ROWTYPE;
  v_projection public.programme_schedule_projections%ROWTYPE;
  v_today_occ public.programme_schedule_occurrences%ROWTYPE;
  v_selected public.programme_schedule_occurrences%ROWTYPE;
  v_today DATE;
  v_active_count INT;
  v_in_progress INT;
  v_already_swapped BOOLEAN := FALSE;
  v_result_rev INT;
  v_idem TEXT;
  v_start JSONB;
  v_today_found BOOLEAN := FALSE;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'not_authenticated'
    );
  END IF;

  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  BEGIN
    v_assignment_id := NULLIF(trim(payload->>'assignment_id'), '')::UUID;
    v_today_id := NULLIF(trim(payload->>'today_occurrence_id'), '')::UUID;
    v_selected_id := NULLIF(trim(payload->>'selected_occurrence_id'), '')::UUID;
    v_expected_today := NULLIF(trim(payload->>'expected_today_date'), '')::DATE;
    v_expected_selected := NULLIF(trim(payload->>'expected_selected_date'), '')::DATE;
    v_expected_rev := NULLIF(trim(payload->>'expected_schedule_revision'), '')::INT;
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END;

  IF v_assignment_id IS NULL
     OR v_today_id IS NULL
     OR v_selected_id IS NULL
     OR v_expected_today IS NULL
     OR v_expected_selected IS NULL
     OR v_today_id = v_selected_id
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete
    AND status = 'active';
  IF v_active_count IS DISTINCT FROM 1 THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'multiple_active_assignments'
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84202509, hashtext(v_assignment_id::TEXT));

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_assignment.athlete_id IS DISTINCT FROM v_athlete
     OR v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule'
     OR v_assignment.materialised_at IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_authorised'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_timezone_names WHERE name = v_assignment.timezone
  ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_unavailable'
    );
  END IF;

  v_today := (NOW() AT TIME ZONE v_assignment.timezone)::DATE;

  SELECT * INTO v_projection
  FROM public.programme_schedule_projections
  WHERE assignment_id = v_assignment_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_projection.athlete_id IS DISTINCT FROM v_athlete
     OR v_projection.started_at IS DISTINCT FROM v_assignment.started_at
     OR v_projection.timezone IS DISTINCT FROM v_assignment.timezone
     OR v_projection.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
     OR v_projection.programme_version_id
          IS DISTINCT FROM v_assignment.programme_version_id
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'projection_provenance_conflict'
    );
  END IF;

  IF v_expected_rev IS NOT NULL
     AND (
       v_projection.schedule_revision IS DISTINCT FROM v_expected_rev
       OR v_assignment.schedule_revision IS DISTINCT FROM v_expected_rev
     )
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision'
    );
  END IF;

  SELECT * INTO v_today_occ
  FROM public.programme_schedule_occurrences
  WHERE id = v_today_id
  FOR UPDATE;
  v_today_found := FOUND;
  SELECT * INTO v_selected
  FROM public.programme_schedule_occurrences
  WHERE id = v_selected_id
  FOR UPDATE;

  IF NOT v_today_found
     OR NOT FOUND
     OR v_today_occ.assignment_id IS DISTINCT FROM v_assignment_id
     OR v_selected.assignment_id IS DISTINCT FROM v_assignment_id
  THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'occurrence_not_found'
    );
  END IF;

  IF v_today_occ.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_selected.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_today_occ.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
     OR v_selected.package_content_hash
          IS DISTINCT FROM v_assignment.materialised_package_content_hash
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_lineage_mismatch'
    );
  END IF;

  v_already_swapped :=
    v_selected.scheduled_date = v_expected_today
    AND v_today_occ.scheduled_date = v_expected_selected
    AND v_expected_today = v_today
    AND v_expected_selected > v_today;

  IF NOT v_already_swapped THEN
    IF v_today_occ.scheduled_date IS DISTINCT FROM v_expected_today
       OR v_selected.scheduled_date IS DISTINCT FROM v_expected_selected
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'stale_occurrence_dates'
      );
    END IF;
    IF v_expected_today IS DISTINCT FROM v_today THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'today_date_mismatch'
      );
    END IF;
    IF v_expected_selected <= v_today THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'selected_not_future'
      );
    END IF;
    -- Athlete-local calendar dates, not elapsed UTC hours.
    IF (v_expected_selected - v_today) > 7 THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'selected_outside_train_today_horizon'
      );
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND disposition = 'missed'
  ) OR EXISTS (
    SELECT 1
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND disposition = 'scheduled'
      AND scheduled_date < v_today
  ) THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'overdue_occurrence'
    );
  END IF;

  IF v_today_occ.disposition IS DISTINCT FROM 'scheduled'
     OR v_selected.disposition IS DISTINCT FROM 'scheduled'
  THEN
    RETURN jsonb_build_object(
      'status',
      'ineligible',
      'code',
      CASE
        WHEN v_today_occ.disposition = 'completed'
          OR v_selected.disposition = 'completed'
          THEN 'occurrence_completed'
        WHEN v_today_occ.disposition = 'skipped'
          OR v_selected.disposition = 'skipped'
          THEN 'occurrence_skipped'
        ELSE 'occurrence_ineligible'
      END
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.programme_slot_outcomes o
    WHERE o.assignment_id = v_assignment_id
      AND o.session_slot_id IN (
        v_today_occ.session_slot_id,
        v_selected.session_slot_id
      )
      AND o.outcome_status IN (
        'completed',
        'completed_partial',
        'skipped',
        'in_progress'
      )
  ) THEN
    IF NOT (
      v_already_swapped
      AND EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes o
        WHERE o.assignment_id = v_assignment_id
          AND o.session_slot_id = v_selected.session_slot_id
          AND o.outcome_status = 'in_progress'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes o
        WHERE o.assignment_id = v_assignment_id
          AND o.session_slot_id = v_today_occ.session_slot_id
          AND o.outcome_status IN (
            'completed',
            'completed_partial',
            'skipped',
            'in_progress'
          )
      )
    ) THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_has_session_state'
      );
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_in_progress
  FROM public.training_sessions ts
  JOIN public.programme_slot_outcomes o ON o.training_session_id = ts.id
  JOIN public.programme_assignments a ON a.id = o.assignment_id
  WHERE a.athlete_id = v_athlete
    AND ts.status = 'in_progress';
  IF v_in_progress > 0 AND NOT v_already_swapped THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'in_progress_session_exists'
    );
  END IF;
  IF v_in_progress > 1 THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'in_progress_session_exists'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
    GROUP BY scheduled_date
    HAVING COUNT(*) > 1
  ) THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'duplicate_scheduled_dates'
    );
  END IF;

  BEGIN
  IF NOT v_already_swapped THEN
    PERFORM set_config('cohort.allow_schedule_write', 'on', true);
    v_result_rev := v_projection.schedule_revision + 1;

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_expected_selected,
        updated_at = NOW()
    WHERE id = v_today_occ.id
      AND disposition = 'scheduled'
      AND scheduled_date = v_expected_today;
    IF NOT FOUND THEN
      v_start := jsonb_build_object('status', 'conflict', 'code', 'swap_race');
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_expected_today,
        updated_at = NOW()
    WHERE id = v_selected.id
      AND disposition = 'scheduled'
      AND scheduled_date = v_expected_selected;
    IF NOT FOUND THEN
      v_start := jsonb_build_object('status', 'conflict', 'code', 'swap_race');
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    UPDATE public.programme_schedule_projections
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND schedule_revision = v_projection.schedule_revision;
    IF NOT FOUND THEN
      v_start := jsonb_build_object(
        'status', 'conflict',
        'code', 'stale_schedule_revision'
      );
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    UPDATE public.programme_assignments
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE id = v_assignment_id
      AND schedule_revision = v_projection.schedule_revision;
    IF NOT FOUND THEN
      v_start := jsonb_build_object(
        'status', 'conflict',
        'code', 'stale_schedule_revision'
      );
      RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
    END IF;

    v_idem :=
      'future_train_today:'
      || v_today_id::TEXT
      || ':'
      || v_selected_id::TEXT
      || ':'
      || to_char(v_expected_today, 'YYYY-MM-DD')
      || ':'
      || to_char(v_expected_selected, 'YYYY-MM-DD');

    INSERT INTO public.programme_schedule_operations (
      assignment_id,
      athlete_id,
      operation_type,
      idempotency_key,
      base_revision,
      result_revision,
      policy_version,
      affected_before,
      affected_after,
      prior_snapshot
    ) VALUES (
      v_assignment_id,
      v_athlete,
      'future_train_today_swap',
      v_idem,
      v_projection.schedule_revision,
      v_result_rev,
      'programme.scheduling.policy.v1',
      jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_today_occ.id,
          'scheduledDate', to_char(v_expected_today, 'YYYY-MM-DD')
        ),
        jsonb_build_object(
          'occurrenceId', v_selected.id,
          'scheduledDate', to_char(v_expected_selected, 'YYYY-MM-DD')
        )
      ),
      jsonb_build_array(
        jsonb_build_object(
          'occurrenceId', v_today_occ.id,
          'scheduledDate', to_char(v_expected_selected, 'YYYY-MM-DD')
        ),
        jsonb_build_object(
          'occurrenceId', v_selected.id,
          'scheduledDate', to_char(v_expected_today, 'YYYY-MM-DD')
        )
      ),
      jsonb_build_object(
        'operation_type', 'future_train_today_swap',
        'today_occurrence_id', v_today_id,
        'selected_occurrence_id', v_selected_id
      )
    )
    ON CONFLICT (assignment_id, idempotency_key) DO NOTHING;
  END IF;

  SELECT * INTO v_selected
  FROM public.programme_schedule_occurrences
  WHERE id = v_selected_id;
  IF v_selected.scheduled_date IS DISTINCT FROM v_today THEN
    v_start := jsonb_build_object(
      'status', 'conflict',
      'code', 'selected_not_on_today'
    );
    RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
  END IF;

  v_start := public.cohort_create_or_resume_fixed_occurrence_at(
    v_selected_id,
    NOW()
  );
  IF v_start->>'status' NOT IN ('created', 'resumed') THEN
    RAISE EXCEPTION 'SWAP_BEGIN_FAILED';
  END IF;

  PERFORM public.cohort_fixed_assignment_refresh_compatibility_cursor(
    v_assignment_id
  );

  SELECT * INTO v_today_occ
  FROM public.programme_schedule_occurrences
  WHERE id = v_today_id;
  SELECT * INTO v_selected
  FROM public.programme_schedule_occurrences
  WHERE id = v_selected_id;

  RETURN jsonb_build_object(
    'status', v_start->>'status',
    'code', CASE
      WHEN v_already_swapped THEN 'already_applied'
      ELSE 'swapped_and_begun'
    END,
    'assignment_id', v_assignment_id,
    'today_occurrence_id', v_today_id,
    'selected_occurrence_id', v_selected_id,
    'today_scheduled_date', to_char(v_selected.scheduled_date, 'YYYY-MM-DD'),
    'displaced_scheduled_date', to_char(v_today_occ.scheduled_date, 'YYYY-MM-DD'),
    'training_session', v_start->'training_session',
    'programmed_session_key', v_selected.programmed_session_key,
    'schedule_revision', (
      SELECT schedule_revision
      FROM public.programme_schedule_projections
      WHERE assignment_id = v_assignment_id
    )
  );
  EXCEPTION
    WHEN raise_exception THEN
      IF SQLERRM = 'SWAP_BEGIN_FAILED' THEN
        RETURN COALESCE(v_start, jsonb_build_object()) || jsonb_build_object(
          'swap_status',
          CASE WHEN v_already_swapped THEN 'already_applied' ELSE 'rolled_back' END
        );
      END IF;
      RAISE;
  END;
END;
$$;

REVOKE ALL ON FUNCTION public.swap_future_fixed_programme_session_and_begin(
  JSONB
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.swap_future_fixed_programme_session_and_begin(
  JSONB
) TO authenticated;

COMMENT ON FUNCTION public.swap_future_fixed_programme_session_and_begin(JSONB) IS
  'Atomically swap today’s unstarted fixed occurrence with a future scheduled occurrence 1–7 athlete-local calendar days ahead, then create or resume the selected session.';
