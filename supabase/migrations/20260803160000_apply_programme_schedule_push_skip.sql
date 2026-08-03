-- Sprint 1.7E: Extend exact-preview apply RPC with Push and Skip.
-- Move/Swap behaviour unchanged from 1.7D. Undo remains unsupported (1.7F).

CREATE OR REPLACE FUNCTION public.apply_programme_schedule_operation(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_op TEXT;
  v_assignment_id UUID;
  v_expected_rev INT;
  v_version_id UUID;
  v_hash TEXT;
  v_policy TEXT;
  v_fingerprint TEXT;
  v_idem TEXT;
  v_slot_id UUID;
  v_slot_a UUID;
  v_slot_b UUID;
  v_target DATE;
  v_day_delta INT;
  v_anchor_order INT;
  v_assignment public.programme_assignments%ROWTYPE;
  v_projection public.programme_schedule_projections%ROWTYPE;
  v_prior public.programme_schedule_operations%ROWTYPE;
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_occ_a public.programme_schedule_occurrences%ROWTYPE;
  v_occ_b public.programme_schedule_occurrences%ROWTYPE;
  v_next_occ public.programme_schedule_occurrences%ROWTYPE;
  v_affected JSONB := '[]'::jsonb;
  v_collisions JSONB := '[]'::jsonb;
  v_fp_payload JSONB;
  v_server_fp TEXT;
  v_operation JSONB;
  v_date_a DATE;
  v_date_b DATE;
  v_projection_json JSONB;
  v_keys TEXT[] := ARRAY[]::TEXT[];
  v_undo_expires TIMESTAMPTZ;
  v_result_rev INT;
  v_prior_snapshot JSONB;
  v_cursor_before JSONB;
  v_cursor_after JSONB;
  v_has_next BOOLEAN := FALSE;
  v_rows INT;
  v_result JSONB;
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'not_authenticated'
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

  -- Reject client-supplied proposed projections / occurrence rows / cursor / impacts.
  IF payload ? 'projection'
     OR payload ? 'proposed_projection'
     OR payload ? 'occurrences'
     OR payload ? 'affected'
     OR payload ? 'impacts'
     OR payload ? 'colliding_dates'
     OR payload ? 'cursor_after'
     OR payload ? 'resulting_disposition'
     OR payload ? 'before'
     OR payload ? 'after'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'client_nominated_projection_forbidden'
    );
  END IF;

  v_op := lower(nullif(trim(COALESCE(payload->>'operation_type', '')), ''));
  v_assignment_id := NULLIF(trim(COALESCE(payload->>'assignment_id', '')), '')::uuid;
  v_expected_rev := NULLIF(payload->>'expected_schedule_revision', '')::INT;
  v_version_id := NULLIF(trim(COALESCE(payload->>'programme_version_id', '')), '')::uuid;
  v_hash := nullif(trim(COALESCE(payload->>'package_content_hash', '')), '');
  v_policy := COALESCE(
    nullif(trim(COALESCE(payload->>'policy_version', '')), ''),
    'programme.scheduling.policy.v1'
  );
  v_fingerprint := nullif(trim(COALESCE(payload->>'preview_fingerprint', '')), '');
  v_idem := nullif(trim(COALESCE(payload->>'idempotency_key', '')), '');

  IF v_op IS NULL OR v_assignment_id IS NULL OR v_expected_rev IS NULL
     OR v_version_id IS NULL OR v_hash IS NULL OR v_fingerprint IS NULL
     OR v_idem IS NULL
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'malformed_request'
    );
  END IF;

  IF v_op = 'undo' THEN
    RETURN jsonb_build_object(
      'status', 'unsupported',
      'code', 'unsupported_operation',
      'operation_type', v_op
    );
  END IF;

  IF v_op NOT IN ('move', 'swap', 'push', 'skip') THEN
    RETURN jsonb_build_object(
      'status', 'unsupported',
      'code', 'unsupported_operation',
      'operation_type', v_op
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84201704, hashtext(v_assignment_id::text));

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_assignment_id
    AND athlete_id = v_athlete_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_found'
    );
  END IF;

  IF v_assignment.status = 'paused' THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'assignment_paused'
    );
  END IF;

  IF v_assignment.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'assignment_ineligible',
      'assignment_status', v_assignment.status
    );
  END IF;

  IF v_assignment.materialised_at IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'ineligible',
      'code', 'assignment_not_materialised'
    );
  END IF;

  IF v_assignment.programme_version_id IS DISTINCT FROM v_version_id
     OR v_assignment.materialised_package_content_hash IS DISTINCT FROM v_hash
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'provenance_mismatch'
    );
  END IF;

  SELECT * INTO v_projection
  FROM public.programme_schedule_projections
  WHERE assignment_id = v_assignment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'projection_absent'
    );
  END IF;

  -- Idempotency check before revision CAS.
  SELECT * INTO v_prior
  FROM public.programme_schedule_operations
  WHERE assignment_id = v_assignment_id
    AND idempotency_key = v_idem
  FOR UPDATE;

  IF FOUND THEN
    IF v_prior.operation_type = v_op
       AND v_prior.preview_fingerprint IS NOT DISTINCT FROM v_fingerprint
    THEN
      v_projection_json := public.cohort_programme_schedule_projection_json(v_assignment_id);
      v_result := jsonb_build_object(
        'status', 'already_applied',
        'code', 'idempotent_replay',
        'assignment_id', v_assignment_id,
        'schedule_revision', v_projection.schedule_revision,
        'operation_id', v_prior.id,
        'cleared_programmed_session_keys', COALESCE(v_prior.affected_after->'cleared_programmed_session_keys', '[]'::jsonb),
        'projection', v_projection_json
      );
      IF v_prior.operation_type = 'skip' THEN
        v_result := v_result || jsonb_build_object(
          'cursor_after', v_prior.affected_after->'cursor_after'
        );
      END IF;
      RETURN v_result;
    END IF;
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'idempotency_key_conflict'
    );
  END IF;

  IF v_projection.schedule_revision IS DISTINCT FROM v_expected_rev
     OR v_assignment.schedule_revision IS DISTINCT FROM v_expected_rev
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision',
      'expected_schedule_revision', v_expected_rev,
      'current_schedule_revision', v_projection.schedule_revision
    );
  END IF;

  IF v_op = 'move' THEN
    v_slot_id := NULLIF(trim(COALESCE(payload->>'session_slot_id', '')), '')::uuid;
    v_target := NULLIF(trim(COALESCE(payload->>'target_date', '')), '')::date;
    IF v_slot_id IS NULL OR v_target IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;

    SELECT * INTO v_occ
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF v_occ.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ.disposition IS DISTINCT FROM 'scheduled' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    IF v_target < v_assignment.started_at THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'before_assignment_start');
    END IF;

    IF v_occ.scheduled_date = v_target THEN
      RETURN jsonb_build_object(
        'status', 'no_change',
        'code', 'no_change',
        'assignment_id', v_assignment_id,
        'schedule_revision', v_projection.schedule_revision
      );
    END IF;

    v_operation := jsonb_build_object(
      'sessionSlotId', v_slot_id::text,
      'targetDate', to_char(v_target, 'YYYY-MM-DD'),
      'type', 'move'
    );

    v_affected := jsonb_build_array(
      jsonb_build_object(
        'dayKey', v_occ.day_key,
        'originalDate', to_char(v_occ.scheduled_date, 'YYYY-MM-DD'),
        'originalDisposition', v_occ.disposition,
        'programmedSessionKey', v_occ.programmed_session_key,
        'proposedDate', to_char(v_target, 'YYYY-MM-DD'),
        'proposedDisposition', v_occ.disposition,
        'protocolId', v_occ.protocol_id,
        'sessionOrder', v_occ.session_order,
        'sessionSlotId', v_occ.session_slot_id::text,
        'weekNumber', v_occ.week_number
      )
    );

    -- Collisions after proposed move (uncompleted only).
    SELECT COALESCE(
      jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
      '[]'::jsonb
    )
    INTO v_collisions
    FROM (
      SELECT d AS collision_date
      FROM (
        SELECT CASE
                 WHEN o.session_slot_id = v_slot_id THEN v_target
                 ELSE o.scheduled_date
               END AS d
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
      ) s
      GROUP BY d
      HAVING COUNT(*) > 1
    ) c;

    v_keys := array_append(v_keys, v_occ.programmed_session_key);

  ELSIF v_op = 'swap' THEN
    v_slot_a := NULLIF(trim(COALESCE(payload->>'session_slot_id_a', '')), '')::uuid;
    v_slot_b := NULLIF(trim(COALESCE(payload->>'session_slot_id_b', '')), '')::uuid;
    IF v_slot_a IS NULL OR v_slot_b IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;
    IF v_slot_a = v_slot_b THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'swap_requires_distinct_occurrences'
      );
    END IF;

    SELECT * INTO v_occ_a
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_a
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_not_found');
    END IF;

    SELECT * INTO v_occ_b
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_b
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_not_found');
    END IF;

    IF v_occ_a.disposition = 'completed' OR v_occ_b.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ_a.disposition = 'skipped' OR v_occ_b.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ_a.disposition IS DISTINCT FROM 'scheduled'
       OR v_occ_b.disposition IS DISTINCT FROM 'scheduled'
    THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    IF v_occ_a.package_content_hash IS DISTINCT FROM v_hash
       OR v_occ_b.package_content_hash IS DISTINCT FROM v_hash
       OR v_occ_a.programme_version_id IS DISTINCT FROM v_version_id
       OR v_occ_b.programme_version_id IS DISTINCT FROM v_version_id
    THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'cross_assignment_or_version_swap');
    END IF;

    IF v_occ_a.scheduled_date = v_occ_b.scheduled_date THEN
      RETURN jsonb_build_object(
        'status', 'no_change',
        'code', 'no_change',
        'assignment_id', v_assignment_id,
        'schedule_revision', v_projection.schedule_revision
      );
    END IF;

    v_date_a := v_occ_a.scheduled_date;
    v_date_b := v_occ_b.scheduled_date;

    v_operation := jsonb_build_object(
      'sessionSlotIdA', v_slot_a::text,
      'sessionSlotIdB', v_slot_b::text,
      'type', 'swap'
    );

    v_affected := (
      SELECT jsonb_agg(row_obj ORDER BY row_obj->>'sessionSlotId')
      FROM (
        SELECT jsonb_build_object(
          'dayKey', v_occ_a.day_key,
          'originalDate', to_char(v_date_a, 'YYYY-MM-DD'),
          'originalDisposition', v_occ_a.disposition,
          'programmedSessionKey', v_occ_a.programmed_session_key,
          'proposedDate', to_char(v_date_b, 'YYYY-MM-DD'),
          'proposedDisposition', v_occ_a.disposition,
          'protocolId', v_occ_a.protocol_id,
          'sessionOrder', v_occ_a.session_order,
          'sessionSlotId', v_occ_a.session_slot_id::text,
          'weekNumber', v_occ_a.week_number
        ) AS row_obj
        UNION ALL
        SELECT jsonb_build_object(
          'dayKey', v_occ_b.day_key,
          'originalDate', to_char(v_date_b, 'YYYY-MM-DD'),
          'originalDisposition', v_occ_b.disposition,
          'programmedSessionKey', v_occ_b.programmed_session_key,
          'proposedDate', to_char(v_date_a, 'YYYY-MM-DD'),
          'proposedDisposition', v_occ_b.disposition,
          'protocolId', v_occ_b.protocol_id,
          'sessionOrder', v_occ_b.session_order,
          'sessionSlotId', v_occ_b.session_slot_id::text,
          'weekNumber', v_occ_b.week_number
        )
      ) q
    );

    SELECT COALESCE(
      jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
      '[]'::jsonb
    )
    INTO v_collisions
    FROM (
      SELECT d AS collision_date
      FROM (
        SELECT CASE
                 WHEN o.session_slot_id = v_slot_a THEN v_date_b
                 WHEN o.session_slot_id = v_slot_b THEN v_date_a
                 ELSE o.scheduled_date
               END AS d
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
      ) s
      GROUP BY d
      HAVING COUNT(*) > 1
    ) c;

    v_keys := ARRAY[v_occ_a.programmed_session_key, v_occ_b.programmed_session_key];

  ELSIF v_op = 'push' THEN
    v_slot_id := NULLIF(trim(COALESCE(payload->>'session_slot_id', '')), '')::uuid;
    v_day_delta := NULLIF(payload->>'day_delta', '')::INT;
    IF v_slot_id IS NULL OR v_day_delta IS NULL OR v_day_delta <= 0 THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;

    PERFORM 1
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
    FOR UPDATE;

    SELECT * INTO v_occ
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF v_occ.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ.disposition IS DISTINCT FROM 'scheduled' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    v_anchor_order :=
      (v_occ.week_number * 1000000)
      + (COALESCE((regexp_match(v_occ.day_key, '^day_(\d+)$'))[1]::int, v_occ.week_number * 100) * 1000)
      + v_occ.session_order;

    SELECT COALESCE(
      jsonb_agg(row_obj ORDER BY row_obj->>'sessionSlotId'),
      '[]'::jsonb
    )
    INTO v_affected
    FROM (
      SELECT jsonb_build_object(
        'dayKey', o.day_key,
        'originalDate', to_char(o.scheduled_date, 'YYYY-MM-DD'),
        'originalDisposition', o.disposition,
        'programmedSessionKey', o.programmed_session_key,
        'proposedDate', to_char(o.scheduled_date + v_day_delta, 'YYYY-MM-DD'),
        'proposedDisposition', o.disposition,
        'protocolId', o.protocol_id,
        'sessionOrder', o.session_order,
        'sessionSlotId', o.session_slot_id::text,
        'weekNumber', o.week_number
      ) AS row_obj
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.disposition = 'scheduled'
        AND (
          (o.week_number * 1000000)
          + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
          + o.session_order
        ) >= v_anchor_order
    ) q;

    IF v_affected = '[]'::jsonb THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.disposition = 'scheduled'
        AND (
          (o.week_number * 1000000)
          + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
          + o.session_order
        ) >= v_anchor_order
        AND (o.scheduled_date + v_day_delta) < v_assignment.started_at
    ) THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'before_assignment_start');
    END IF;

    v_operation := jsonb_build_object(
      'type', 'push',
      'fromSessionSlotId', v_slot_id::text,
      'dayDelta', v_day_delta
    );

    SELECT COALESCE(
      jsonb_agg(to_char(collision_date, 'YYYY-MM-DD') ORDER BY collision_date),
      '[]'::jsonb
    )
    INTO v_collisions
    FROM (
      SELECT d AS collision_date
      FROM (
        SELECT CASE
                 WHEN (
                   (o.week_number * 1000000)
                   + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
                   + o.session_order
                 ) >= v_anchor_order
                   AND o.disposition = 'scheduled'
                 THEN o.scheduled_date + v_day_delta
                 ELSE o.scheduled_date
               END AS d
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
      ) s
      GROUP BY d
      HAVING COUNT(*) > 1
    ) c;

    SELECT COALESCE(array_agg(o.programmed_session_key ORDER BY o.session_slot_id::text), ARRAY[]::TEXT[])
    INTO v_keys
    FROM public.programme_schedule_occurrences o
    WHERE o.assignment_id = v_assignment_id
      AND o.disposition = 'scheduled'
      AND (
        (o.week_number * 1000000)
        + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
        + o.session_order
      ) >= v_anchor_order;

  ELSIF v_op = 'skip' THEN
    v_slot_id := NULLIF(trim(COALESCE(payload->>'session_slot_id', '')), '')::uuid;
    IF v_slot_id IS NULL THEN
      RETURN jsonb_build_object(
        'status', 'validation_failure',
        'code', 'malformed_request'
      );
    END IF;

    SELECT * INTO v_occ
    FROM public.programme_schedule_occurrences
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_found'
      );
    END IF;

    IF v_occ.week_number IS DISTINCT FROM v_assignment.current_week_number
       OR v_occ.day_key IS DISTINCT FROM v_assignment.current_day_key
       OR v_occ.session_order IS DISTINCT FROM v_assignment.current_slot_order
    THEN
      RETURN jsonb_build_object(
        'status', 'ineligible',
        'code', 'occurrence_not_current'
      );
    END IF;

    IF v_occ.disposition = 'completed' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_completed');
    END IF;
    IF v_occ.disposition = 'skipped' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_already_skipped');
    END IF;
    IF v_occ.disposition IS DISTINCT FROM 'scheduled' THEN
      RETURN jsonb_build_object('status', 'ineligible', 'code', 'occurrence_ineligible');
    END IF;

    v_anchor_order :=
      (v_occ.week_number * 1000000)
      + (COALESCE((regexp_match(v_occ.day_key, '^day_(\d+)$'))[1]::int, v_occ.week_number * 100) * 1000)
      + v_occ.session_order;

    v_cursor_before := jsonb_build_object(
      'dayKey', v_occ.day_key,
      'sessionOrder', v_occ.session_order,
      'sessionSlotId', v_occ.session_slot_id::text,
      'weekNumber', v_occ.week_number
    );

    SELECT * INTO v_next_occ
    FROM public.programme_schedule_occurrences o
    WHERE o.assignment_id = v_assignment_id
      AND o.disposition = 'scheduled'
      AND o.session_slot_id IS DISTINCT FROM v_slot_id
      AND (
        (o.week_number * 1000000)
        + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
        + o.session_order
      ) > v_anchor_order
    ORDER BY o.week_number,
             COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100),
             o.session_order
    LIMIT 1;

    IF NOT FOUND THEN
      SELECT * INTO v_next_occ
      FROM public.programme_schedule_occurrences o
      WHERE o.assignment_id = v_assignment_id
        AND o.disposition = 'scheduled'
        AND o.session_slot_id IS DISTINCT FROM v_slot_id
      ORDER BY o.week_number,
               COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100),
               o.session_order
      LIMIT 1;
    END IF;

    v_has_next := FOUND;

    IF v_has_next THEN
      v_cursor_after := jsonb_build_object(
        'dayKey', v_next_occ.day_key,
        'sessionOrder', v_next_occ.session_order,
        'sessionSlotId', v_next_occ.session_slot_id::text,
        'weekNumber', v_next_occ.week_number
      );
    ELSE
      v_cursor_after := NULL;
    END IF;

    v_operation := jsonb_build_object(
      'type', 'skip',
      'sessionSlotId', v_slot_id::text
    );

    v_affected := jsonb_build_array(
      jsonb_build_object(
        'dayKey', v_occ.day_key,
        'originalDate', to_char(v_occ.scheduled_date, 'YYYY-MM-DD'),
        'originalDisposition', v_occ.disposition,
        'programmedSessionKey', v_occ.programmed_session_key,
        'proposedDate', to_char(v_occ.scheduled_date, 'YYYY-MM-DD'),
        'proposedDisposition', 'skipped',
        'protocolId', v_occ.protocol_id,
        'sessionOrder', v_occ.session_order,
        'sessionSlotId', v_occ.session_slot_id::text,
        'weekNumber', v_occ.week_number
      )
    );

    v_collisions := '[]'::jsonb;
    v_keys := ARRAY[v_occ.programmed_session_key];
  END IF;

  v_fp_payload := jsonb_build_object(
    'affected', v_affected,
    'assignmentId', v_assignment_id::text,
    'collidingDates', v_collisions,
    'operation', v_operation,
    'packageContentHash', v_hash,
    'policyVersion', v_policy,
    'programmeVersionId', v_version_id::text,
    'scheduleRevision', v_expected_rev,
    'timezone', v_projection.timezone
  );

  IF v_op = 'skip' THEN
    v_fp_payload := v_fp_payload || jsonb_build_object(
      'cursorAfter', v_cursor_after,
      'cursorBefore', v_cursor_before
    );
  END IF;

  v_server_fp := public.cohort_scheduling_apply_fingerprint(v_fp_payload);

  IF v_server_fp IS DISTINCT FROM v_fingerprint THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_preview_fingerprint',
      'expected_fingerprint', v_fingerprint,
      'server_fingerprint', v_server_fp
    );
  END IF;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);
  IF v_op = 'skip' THEN
    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
  END IF;

  v_result_rev := v_expected_rev + 1;
  v_undo_expires := NOW() + INTERVAL '72 hours';

  IF v_op = 'move' THEN
    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'move',
      'session_slot_id', v_slot_id,
      'scheduled_date', to_char(v_occ.scheduled_date, 'YYYY-MM-DD')
    );

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_target,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
      AND disposition = 'scheduled'
      AND scheduled_date = v_occ.scheduled_date;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'move_update_race' USING ERRCODE = 'serialization_failure';
    END IF;

  ELSIF v_op = 'swap' THEN
    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'swap',
      'session_slot_id_a', v_slot_a,
      'session_slot_id_b', v_slot_b,
      'scheduled_date_a', to_char(v_date_a, 'YYYY-MM-DD'),
      'scheduled_date_b', to_char(v_date_b, 'YYYY-MM-DD')
    );

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_date_b,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_a
      AND disposition = 'scheduled'
      AND scheduled_date = v_date_a;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'swap_update_race_a' USING ERRCODE = 'serialization_failure';
    END IF;

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = v_date_a,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_b
      AND disposition = 'scheduled'
      AND scheduled_date = v_date_b;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'swap_update_race_b' USING ERRCODE = 'serialization_failure';
    END IF;

  ELSIF v_op = 'push' THEN
    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'push',
      'session_slot_id', v_slot_id,
      'day_delta', v_day_delta,
      'dates_before', (
        SELECT COALESCE(
          jsonb_agg(
            jsonb_build_object(
              'session_slot_id', o.session_slot_id,
              'scheduled_date', to_char(o.scheduled_date, 'YYYY-MM-DD')
            )
            ORDER BY o.session_slot_id::text
          ),
          '[]'::jsonb
        )
        FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = v_assignment_id
          AND o.disposition = 'scheduled'
          AND (
            (o.week_number * 1000000)
            + (COALESCE((regexp_match(o.day_key, '^day_(\d+)$'))[1]::int, o.week_number * 100) * 1000)
            + o.session_order
          ) >= v_anchor_order
      )
    );

    UPDATE public.programme_schedule_occurrences
    SET scheduled_date = scheduled_date + v_day_delta,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND disposition = 'scheduled'
      AND (
        (week_number * 1000000)
        + (COALESCE((regexp_match(day_key, '^day_(\d+)$'))[1]::int, week_number * 100) * 1000)
        + session_order
      ) >= v_anchor_order;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      RAISE EXCEPTION 'push_update_race' USING ERRCODE = 'serialization_failure';
    END IF;

  ELSIF v_op = 'skip' THEN
    v_prior_snapshot := jsonb_build_object(
      'operation_type', 'skip',
      'session_slot_id', v_slot_id,
      'disposition_before', v_occ.disposition,
      'cursor_before', jsonb_build_object(
        'week_number', v_assignment.current_week_number,
        'day_key', v_assignment.current_day_key,
        'session_order', v_assignment.current_slot_order
      )
    );

    INSERT INTO public.programme_slot_outcomes (
      assignment_id,
      session_slot_id,
      week_number,
      day_key,
      session_order,
      outcome_status,
      programme_version_id,
      materialised_package_content_hash,
      programmed_session_key,
      resolved_at
    ) VALUES (
      v_assignment_id,
      v_slot_id,
      v_occ.week_number,
      v_occ.day_key,
      v_occ.session_order,
      'skipped',
      v_version_id,
      v_hash,
      v_occ.programmed_session_key,
      NOW()
    )
    ON CONFLICT (assignment_id, session_slot_id) DO UPDATE SET
      outcome_status = EXCLUDED.outcome_status,
      training_session_id = NULL,
      completion_record_id = NULL,
      actuals_fingerprint = NULL,
      logical_completion_key = NULL,
      idempotency_key = NULL,
      programme_version_id = EXCLUDED.programme_version_id,
      materialised_package_content_hash = EXCLUDED.materialised_package_content_hash,
      programmed_session_key = EXCLUDED.programmed_session_key,
      resolved_at = EXCLUDED.resolved_at,
      updated_at = NOW()
    WHERE public.programme_slot_outcomes.outcome_status IN ('scheduled', 'in_progress');

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
      RAISE EXCEPTION 'skip_outcome_race' USING ERRCODE = 'serialization_failure';
    END IF;

    UPDATE public.programme_schedule_occurrences
    SET disposition = 'skipped',
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND session_slot_id = v_slot_id
      AND disposition = 'scheduled';

    IF NOT FOUND THEN
      RAISE EXCEPTION 'skip_occurrence_race' USING ERRCODE = 'serialization_failure';
    END IF;

    IF v_cursor_after IS NULL THEN
      UPDATE public.programme_assignments
      SET status = 'completed',
          completed_at = COALESCE(completed_at, NOW()),
          schedule_revision = v_result_rev,
          updated_at = NOW()
      WHERE id = v_assignment_id
        AND schedule_revision = v_expected_rev
        AND status = 'active'
        AND current_week_number = v_occ.week_number
        AND current_day_key IS NOT DISTINCT FROM v_occ.day_key
        AND current_slot_order = v_occ.session_order;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'skip_terminal_cursor_cas_failed' USING ERRCODE = 'serialization_failure';
      END IF;
    ELSE
      UPDATE public.programme_assignments
      SET current_week_number = (v_cursor_after->>'weekNumber')::int,
          current_day_key = v_cursor_after->>'dayKey',
          current_slot_order = (v_cursor_after->>'sessionOrder')::int,
          schedule_revision = v_result_rev,
          updated_at = NOW()
      WHERE id = v_assignment_id
        AND schedule_revision = v_expected_rev
        AND current_week_number = v_occ.week_number
        AND current_day_key IS NOT DISTINCT FROM v_occ.day_key
        AND current_slot_order = v_occ.session_order;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'skip_cursor_cas_failed' USING ERRCODE = 'serialization_failure';
      END IF;
    END IF;
  END IF;

  IF v_op <> 'skip' THEN
    UPDATE public.programme_schedule_projections
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND schedule_revision = v_expected_rev;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'projection_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;

    UPDATE public.programme_assignments
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE id = v_assignment_id
      AND schedule_revision = v_expected_rev;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'assignment_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;
  ELSE
    UPDATE public.programme_schedule_projections
    SET schedule_revision = v_result_rev,
        updated_at = NOW()
    WHERE assignment_id = v_assignment_id
      AND schedule_revision = v_expected_rev;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'projection_revision_cas_failed' USING ERRCODE = 'serialization_failure';
    END IF;
  END IF;

  INSERT INTO public.programme_schedule_operations (
    assignment_id,
    athlete_id,
    operation_type,
    idempotency_key,
    preview_fingerprint,
    base_revision,
    result_revision,
    policy_version,
    affected_before,
    affected_after,
    prior_snapshot,
    operated_at,
    undo_expires_at
  ) VALUES (
    v_assignment_id,
    v_athlete_id,
    v_op,
    v_idem,
    v_fingerprint,
    v_expected_rev,
    v_result_rev,
    v_policy,
    v_affected,
    CASE
      WHEN v_op = 'skip' THEN
        jsonb_build_object(
          'cleared_programmed_session_keys', to_jsonb(v_keys),
          'colliding_dates', v_collisions,
          'local_prepared_clear_required', true,
          'cursor_after', v_cursor_after
        )
      ELSE
        jsonb_build_object(
          'cleared_programmed_session_keys', to_jsonb(v_keys),
          'colliding_dates', v_collisions,
          'local_prepared_clear_required', true
        )
    END,
    v_prior_snapshot,
    NOW(),
    v_undo_expires
  );

  v_projection_json := public.cohort_programme_schedule_projection_json(v_assignment_id);

  v_result := jsonb_build_object(
    'status', 'applied',
    'code', 'applied',
    'assignment_id', v_assignment_id,
    'schedule_revision', v_result_rev,
    'operation_type', v_op,
    'preview_fingerprint', v_fingerprint,
    'cleared_programmed_session_keys', to_jsonb(v_keys),
    'colliding_dates', v_collisions,
    'undo_expires_at', v_undo_expires,
    'projection', v_projection_json
  );

  IF v_op = 'skip' THEN
    v_result := v_result || jsonb_build_object('cursor_after', v_cursor_after);
  END IF;

  RETURN v_result;
EXCEPTION
  WHEN serialization_failure THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'stale_schedule_revision'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM anon;
GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO service_role;

COMMENT ON FUNCTION public.apply_programme_schedule_operation(JSONB) IS
  'Sprint 1.7E: exact-preview Move/Swap/Push/Skip apply with revision CAS and idempotency. Skip advances scheduling cursor and writes skipped slot outcome. Undo unsupported (1.7F). Does not mutate prescription.';
