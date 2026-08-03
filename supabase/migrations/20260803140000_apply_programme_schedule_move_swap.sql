-- Sprint 1.7D: Exact-preview Move/Swap apply RPC.
-- Replaces the fail-closed apply placeholder. Grants EXECUTE to authenticated.
-- Push/Skip remain unsupported. Prepared clearing is local-only (client-side).

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 0. RPC-only mutation guard for schedule tables (closes direct table writers)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_schedule_require_rpc_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- RPC paths set cohort.allow_schedule_write. Cascade cleanup by DB owners may
  -- DELETE without that flag. INSERT/UPDATE remain RPC-gated for all roles.
  IF TG_OP = 'DELETE'
     AND current_user IN ('postgres', 'supabase_admin', 'service_role')
  THEN
    RETURN OLD;
  END IF;

  IF COALESCE(current_setting('cohort.allow_schedule_write', true), '') = 'on' THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'programme schedule tables are RPC-only'
    USING ERRCODE = '42501';
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_schedule_require_rpc_write() FROM PUBLIC;

DROP TRIGGER IF EXISTS programme_schedule_projections_rpc_only
  ON public.programme_schedule_projections;
CREATE TRIGGER programme_schedule_projections_rpc_only
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_schedule_projections
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_programme_schedule_require_rpc_write();

DROP TRIGGER IF EXISTS programme_schedule_occurrences_rpc_only
  ON public.programme_schedule_occurrences;
CREATE TRIGGER programme_schedule_occurrences_rpc_only
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_schedule_occurrences
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_programme_schedule_require_rpc_write();

DROP TRIGGER IF EXISTS programme_schedule_operations_rpc_only
  ON public.programme_schedule_operations;
CREATE TRIGGER programme_schedule_operations_rpc_only
  BEFORE INSERT OR UPDATE OR DELETE ON public.programme_schedule_operations
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_programme_schedule_require_rpc_write();

-- ---------------------------------------------------------------------------
-- 1. Canonical JSON + SHA-256 matching Dart ProgrammeSchedulingPreviewFingerprint
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_scheduling_canonical_json(p_value JSONB)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_type TEXT;
  v_keys TEXT[];
  v_key TEXT;
  v_parts TEXT[] := ARRAY[]::TEXT[];
  v_elem JSONB;
  v_i INT;
  v_n INT;
BEGIN
  IF p_value IS NULL OR p_value = 'null'::jsonb THEN
    RETURN 'null';
  END IF;

  v_type := jsonb_typeof(p_value);

  IF v_type = 'string' THEN
    RETURN to_json(p_value #>> '{}')::text;
  ELSIF v_type = 'number' THEN
    RETURN (p_value #>> '{}');
  ELSIF v_type = 'boolean' THEN
    RETURN lower(p_value #>> '{}');
  ELSIF v_type = 'array' THEN
    v_n := jsonb_array_length(p_value);
    IF v_n = 0 THEN
      RETURN '[]';
    END IF;
    FOR v_i IN 0 .. (v_n - 1) LOOP
      v_parts := array_append(
        v_parts,
        public.cohort_scheduling_canonical_json(p_value -> v_i)
      );
    END LOOP;
    RETURN '[' || array_to_string(v_parts, ',') || ']';
  ELSIF v_type = 'object' THEN
    SELECT COALESCE(array_agg(k ORDER BY k), ARRAY[]::TEXT[])
      INTO v_keys
    FROM jsonb_object_keys(p_value) AS k;
    IF COALESCE(array_length(v_keys, 1), 0) = 0 THEN
      RETURN '{}';
    END IF;
    FOREACH v_key IN ARRAY v_keys LOOP
      v_parts := array_append(
        v_parts,
        to_json(v_key)::text || ':' ||
          public.cohort_scheduling_canonical_json(p_value -> v_key)
      );
    END LOOP;
    RETURN '{' || array_to_string(v_parts, ',') || '}';
  END IF;

  RETURN to_json(p_value #>> '{}')::text;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_scheduling_canonical_json(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_scheduling_canonical_json(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_scheduling_canonical_json(JSONB) TO service_role;

CREATE OR REPLACE FUNCTION public.cohort_scheduling_apply_fingerprint(p_payload JSONB)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = public, extensions, pg_temp
AS $$
  SELECT encode(
    extensions.digest(
      convert_to(public.cohort_scheduling_canonical_json(p_payload), 'UTF8'),
      'sha256'::text
    ),
    'hex'
  );
$$;

REVOKE ALL ON FUNCTION public.cohort_scheduling_apply_fingerprint(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_scheduling_apply_fingerprint(JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_scheduling_apply_fingerprint(JSONB) TO service_role;

COMMENT ON FUNCTION public.cohort_scheduling_apply_fingerprint(JSONB) IS
  'Sprint 1.7D: SHA-256 of Dart-compatible canonical JSON for Move/Swap apply fingerprint parity.';

-- ---------------------------------------------------------------------------
-- 2. Apply Move / Swap (exact preview)
-- ---------------------------------------------------------------------------

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
  v_assignment public.programme_assignments%ROWTYPE;
  v_projection public.programme_schedule_projections%ROWTYPE;
  v_prior public.programme_schedule_operations%ROWTYPE;
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_occ_a public.programme_schedule_occurrences%ROWTYPE;
  v_occ_b public.programme_schedule_occurrences%ROWTYPE;
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

  -- Reject client-supplied proposed projections / occurrence rows.
  IF payload ? 'projection'
     OR payload ? 'proposed_projection'
     OR payload ? 'occurrences'
     OR payload ? 'affected'
     OR payload ? 'impacts'
     OR payload ? 'colliding_dates'
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

  IF v_op IN ('push', 'skip', 'undo') THEN
    RETURN jsonb_build_object(
      'status', 'unsupported',
      'code', 'unsupported_operation',
      'operation_type', v_op
    );
  END IF;

  IF v_op NOT IN ('move', 'swap') THEN
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
      RETURN jsonb_build_object(
        'status', 'already_applied',
        'code', 'idempotent_replay',
        'assignment_id', v_assignment_id,
        'schedule_revision', v_projection.schedule_revision,
        'operation_id', v_prior.id,
        'cleared_programmed_session_keys', COALESCE(v_prior.affected_after->'cleared_programmed_session_keys', '[]'::jsonb),
        'projection', v_projection_json
      );
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
  ELSE
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
  END IF;

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
    jsonb_build_object(
      'cleared_programmed_session_keys', to_jsonb(v_keys),
      'colliding_dates', v_collisions,
      'local_prepared_clear_required', true
    ),
    v_prior_snapshot,
    NOW(),
    v_undo_expires
  );

  v_projection_json := public.cohort_programme_schedule_projection_json(v_assignment_id);

  RETURN jsonb_build_object(
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
  'Sprint 1.7D: exact-preview Move/Swap apply with revision CAS and idempotency. Push/Skip unsupported. Does not mutate dispositions, cursor, or completion.';
