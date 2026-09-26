-- Capture-only repair may proceed when the only athlete evidence is an
-- in-progress session with no logged loads. Terminal outcomes, skipped
-- occurrences, and any set load still block. Assignments and sessions
-- are not mutated.

CREATE OR REPLACE FUNCTION public.repair_private_programme_exercise_capture(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $repair$
DECLARE
  v_version_id UUID;
  v_hash TEXT;
  v_existing public.programme_versions%ROWTYPE;
  v_graph JSONB;
  v_counts JSONB;
  v_updated INT := 0;
  v_unchanged INT := 0;
  v_started INT;
BEGIN
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_payload');
  END IF;
  IF trim(COALESCE(payload->>'publication_kind', '')) IS DISTINCT FROM 'private_exact_version' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_publication_kind');
  END IF;
  BEGIN
    v_version_id := (payload->>'programme_version_id')::UUID;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_identity');
  END;
  v_hash := lower(trim(COALESCE(payload->>'package_content_hash', '')));
  IF v_version_id IS NULL OR v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_identity');
  END IF;
  IF NOT public.cohort_payload_protocol_graphs_complete(payload) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'protocol_graph_required');
  END IF;
  IF NOT public.cohort_payload_exercise_capture_complete(payload) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'exercise_capture_required');
  END IF;

  SELECT * INTO v_existing FROM public.programme_versions WHERE id = v_version_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'not_found', 'code', 'version_not_found');
  END IF;
  IF v_existing.package_content_hash IS DISTINCT FROM v_hash
     OR v_existing.lifecycle_status IS DISTINCT FROM 'published'
     OR v_existing.approved_for_global IS TRUE
     OR v_existing.library_scope NOT IN ('coach_private', 'organisation') THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'version_not_repairable');
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(payload->'sessions') sess
    WHERE NOT EXISTS (
      SELECT 1 FROM public.performance_protocols p
      WHERE p.protocol_id = trim(sess->>'protocol_id')
        AND p.revision_number = COALESCE(NULLIF(sess->>'revision_number','')::INT, 1)
        AND p.lifecycle_status = 'published'
    )
  ) THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'protocol_header_mismatch');
  END IF;

  SELECT count(*) INTO v_started
  FROM public.programme_assignments a
  WHERE a.programme_version_id = v_version_id
    AND (
      EXISTS (
        SELECT 1 FROM public.programme_schedule_occurrences o
        WHERE o.assignment_id = a.id
          AND o.disposition IS DISTINCT FROM 'scheduled'
      )
      OR EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes so
        WHERE so.assignment_id = a.id
          AND so.outcome_status IN (
            'completed',
            'completed_partial',
            'skipped',
            'rescheduled',
            'replaced'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes so
        JOIN public.training_session_records r
          ON r.training_session_id = so.training_session_id
        JOIN public.training_block_results br
          ON br.session_record_id = r.record_id
        JOIN public.training_exercise_results er
          ON er.block_result_id = br.block_result_id
        JOIN public.training_set_results sr
          ON sr.exercise_result_id = er.exercise_result_id
        WHERE so.assignment_id = a.id
          AND sr.load IS NOT NULL
      )
    );
  IF v_started > 0 THEN
    RETURN jsonb_build_object('status', 'blocked', 'code', 'session_evidence_exists');
  END IF;

  BEGIN
    FOR v_graph IN SELECT value FROM jsonb_array_elements(payload->'protocol_graphs')
    LOOP
      v_counts := public.cohort_update_private_exercise_capture(
        trim(v_graph->>'protocol_id'),
        v_graph
      );
      v_updated := v_updated + COALESCE((v_counts->>'updated_exercises')::INT, 0);
      v_unchanged := v_unchanged + COALESCE((v_counts->>'unchanged_exercises')::INT, 0);
    END LOOP;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'protocol_graph_conflict');
  END;

  INSERT INTO public.private_programme_graph_repair_events (
    programme_version_id, package_content_hash, status,
    inserted_blocks, existing_blocks, inserted_exercises, existing_exercises
  ) VALUES (
    v_version_id, v_hash, 'capture_repaired',
    0, 0, v_updated, v_unchanged
  );

  RETURN jsonb_build_object(
    'status', 'repaired',
    'programme_version_id', v_version_id,
    'package_content_hash', v_hash,
    'updated_exercises', v_updated,
    'unchanged_exercises', v_unchanged
  );
END;
$repair$;

REVOKE ALL ON FUNCTION public.repair_private_programme_exercise_capture(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.repair_private_programme_exercise_capture(JSONB)
  TO service_role;

COMMENT ON FUNCTION public.repair_private_programme_exercise_capture(JSONB) IS
  'Service-role capture-metadata repair. Allows empty-load in-progress sessions. Does not mutate assignments, sessions, or outcomes.';
