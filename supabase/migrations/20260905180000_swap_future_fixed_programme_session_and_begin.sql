-- Authenticated one-for-one future-session date swap plus begin/resume.
-- Dates exchange atomically inside the same transaction as session create.
-- Compatibility cursor is refreshed to the next uncompleted occurrence by
-- scheduled date, not authored ordinal order.

ALTER TABLE public.programme_schedule_operations
  DROP CONSTRAINT IF EXISTS programme_schedule_operations_type_check;

ALTER TABLE public.programme_schedule_operations
  ADD CONSTRAINT programme_schedule_operations_type_check
  CHECK (operation_type IN (
    'baseline_initialisation',
    'move',
    'swap',
    'push',
    'skip',
    'undo',
    'future_train_today_swap'
  ));

CREATE OR REPLACE FUNCTION public.cohort_fixed_assignment_refresh_compatibility_cursor(
  p_assignment_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_next public.programme_schedule_occurrences%ROWTYPE;
BEGIN
  SELECT *
  INTO v_next
  FROM public.programme_schedule_occurrences
  WHERE assignment_id = p_assignment_id
    AND disposition = 'scheduled'
  ORDER BY scheduled_date, week_number, day_key, session_order
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  UPDATE public.programme_assignments
  SET current_week_number = v_next.week_number,
      current_day_key = v_next.day_key,
      current_slot_order = v_next.session_order,
      updated_at = NOW()
  WHERE id = p_assignment_id;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_fixed_assignment_refresh_compatibility_cursor(
  UUID
) FROM PUBLIC, anon, authenticated;

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
  'Atomically swap today’s unstarted fixed occurrence with a future scheduled occurrence, then create or resume the selected session.';

CREATE OR REPLACE FUNCTION public.complete_fixed_programme_occurrence_and_advance(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_occurrence_id UUID;
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_assignment public.programme_assignments%ROWTYPE;
  v_outcome public.programme_slot_outcomes%ROWTYPE;
  v_result JSONB;
  v_old_week INT;
  v_old_day TEXT;
  v_old_slot INT;
  v_old_status TEXT;
  v_old_completed_at TIMESTAMPTZ;
  v_old_order BIGINT;
  v_occ_order BIGINT;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required'
    );
  END IF;
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object'
     OR NULLIF(payload->>'occurrence_id', '') IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_occurrence_id'
    );
  END IF;
  BEGIN
    v_occurrence_id := (payload->>'occurrence_id')::UUID;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_occurrence_id'
    );
  END;

  PERFORM pg_advisory_xact_lock(84202409, hashtext(v_occurrence_id::TEXT));
  SELECT * INTO v_occ
  FROM public.programme_schedule_occurrences
  WHERE id = v_occurrence_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_missing'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_occ.assignment_id
  FOR UPDATE;
  IF NOT FOUND OR v_assignment.athlete_id IS DISTINCT FROM v_athlete THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'cross_athlete_occurrence'
    );
  END IF;
  IF v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule'
     OR v_assignment.materialised_at IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'fixed_assignment_ineligible'
    );
  END IF;

  IF payload->>'assignment_id' IS DISTINCT FROM v_occ.assignment_id::TEXT
     OR payload->>'session_slot_id' IS DISTINCT FROM v_occ.session_slot_id::TEXT
     OR payload->>'programme_version_id' IS DISTINCT FROM v_occ.programme_version_id::TEXT
     OR payload->>'materialised_package_content_hash' IS DISTINCT FROM v_occ.package_content_hash
     OR payload->>'programmed_session_key' IS DISTINCT FROM v_occ.programmed_session_key
     OR payload->>'logical_completion_key' IS DISTINCT FROM v_occ.programmed_session_key
     OR payload->>'protocol_id' IS DISTINCT FROM v_occ.protocol_id
     OR (payload->>'expected_week')::INT IS DISTINCT FROM v_occ.week_number
     OR payload->>'expected_day_key' IS DISTINCT FROM v_occ.day_key
     OR (payload->>'expected_slot_order')::INT IS DISTINCT FROM v_occ.session_order
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_lineage_mismatch'
    );
  END IF;

  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_occ.assignment_id
    AND session_slot_id = v_occ.session_slot_id
  FOR UPDATE;
  IF NOT FOUND
     OR v_outcome.training_session_id::TEXT IS DISTINCT FROM payload->>'training_session_id'
     OR v_outcome.programme_version_id IS DISTINCT FROM v_occ.programme_version_id
     OR v_outcome.materialised_package_content_hash IS DISTINCT FROM v_occ.package_content_hash
     OR v_outcome.programmed_session_key IS DISTINCT FROM v_occ.programmed_session_key
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_session_integrity_failure'
    );
  END IF;

  v_old_week := v_assignment.current_week_number;
  v_old_day := v_assignment.current_day_key;
  v_old_slot := v_assignment.current_slot_order;
  v_old_status := v_assignment.status;
  v_old_completed_at := v_assignment.completed_at;

  WITH ordered AS (
    SELECT
      w.week_number,
      d.day_key,
      s.session_order,
      ROW_NUMBER() OVER (
        ORDER BY w.week_number, d.day_order, s.session_order
      ) AS ordinal
    FROM public.programme_version_weeks w
    JOIN public.programme_version_days d ON d.week_id = w.id
    JOIN public.programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = v_assignment.programme_version_id
      AND COALESCE(d.day_type, '') <> 'rest'
      AND NULLIF(TRIM(COALESCE(s.protocol_id, '')), '') IS NOT NULL
  )
  SELECT
    MAX(ordinal) FILTER (
      WHERE week_number = v_old_week
        AND day_key = v_old_day
        AND session_order = v_old_slot
    ),
    MAX(ordinal) FILTER (
      WHERE week_number = v_occ.week_number
        AND day_key = v_occ.day_key
        AND session_order = v_occ.session_order
    )
  INTO v_old_order, v_occ_order
  FROM ordered;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  UPDATE public.programme_assignments
  SET current_week_number = v_occ.week_number,
      current_day_key = v_occ.day_key,
      current_slot_order = v_occ.session_order,
      updated_at = NOW()
  WHERE id = v_assignment.id;

  v_result := public.complete_programme_session_and_advance(
    payload - 'occurrence_id'
  );

  IF v_result->>'status' IN ('committed', 'already_committed') THEN
    PERFORM set_config('cohort.allow_schedule_write', 'on', true);
    UPDATE public.programme_schedule_occurrences
    SET disposition = 'completed',
        updated_at = NOW()
    WHERE id = v_occ.id;

    IF v_old_order IS NOT NULL
       AND v_occ_order IS NOT NULL
       AND v_old_order > v_occ_order
    THEN
      PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
      UPDATE public.programme_assignments
      SET current_week_number = v_old_week,
          current_day_key = v_old_day,
          current_slot_order = v_old_slot,
          status = v_old_status,
          completed_at = v_old_completed_at,
          updated_at = NOW()
      WHERE id = v_assignment.id;
    END IF;

    PERFORM public.cohort_fixed_assignment_refresh_compatibility_cursor(
      v_assignment.id
    );

    RETURN v_result || jsonb_build_object(
      'occurrence_id', v_occ.id,
      'original_scheduled_date', v_occ.original_scheduled_date
    );
  END IF;

  PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  UPDATE public.programme_assignments
  SET current_week_number = v_old_week,
      current_day_key = v_old_day,
      current_slot_order = v_old_slot,
      status = v_old_status,
      completed_at = v_old_completed_at,
      updated_at = NOW()
  WHERE id = v_assignment.id;
  RETURN v_result;
EXCEPTION
  WHEN invalid_text_representation OR numeric_value_out_of_range THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_lineage_mismatch'
    );
END;
$$;
