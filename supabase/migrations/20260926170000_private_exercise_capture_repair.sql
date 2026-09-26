-- Private graph exercise-capture metadata and bounded hosted repair.
-- Forward-only. Does not edit 20260926120000–20260926160000.

CREATE OR REPLACE FUNCTION public.cohort_payload_exercise_capture_complete(
  payload JSONB
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(payload->'protocol_graphs') g,
         jsonb_array_elements(g->'blocks') b,
         jsonb_array_elements(COALESCE(b->'exercises', '[]'::JSONB)) e
    WHERE trim(COALESCE(b->>'block_type', '')) IN ('strength', 'accessory')
      AND jsonb_typeof(e->'prescription'->'load') = 'object'
      AND trim(COALESCE(e->'prescription'->'load'->>'type', ''))
            IS DISTINCT FROM 'bodyweight'
      AND trim(COALESCE(e->'prescription'->'load'->>'type', ''))
            NOT IN ('athleteSelected', 'rpe', 'rir', 'fixedKg', 'percent1rm')
      AND nullif(trim(COALESCE(e->'prescription'->'performance_capture'->>'load_unit', '')), '')
            IS NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.cohort_update_private_exercise_capture(
  p_protocol_id TEXT,
  p_graph JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_block JSONB;
  v_ex JSONB;
  v_block_id UUID;
  v_existing public.session_blocks%ROWTYPE;
  v_row public.session_block_exercises%ROWTYPE;
  v_updated INT := 0;
  v_unchanged INT := 0;
  v_new_rx JSONB;
BEGIN
  IF trim(COALESCE(p_graph->>'protocol_id', '')) IS DISTINCT FROM trim(p_protocol_id) THEN
    RAISE EXCEPTION 'protocol_graph_identity_mismatch';
  END IF;

  FOR v_block IN SELECT value FROM jsonb_array_elements(p_graph->'blocks')
  LOOP
    SELECT * INTO v_existing
    FROM public.session_blocks
    WHERE session_id = trim(p_protocol_id)
      AND position = (v_block->>'position')::INT;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'protocol_graph_conflict';
    END IF;
    IF v_existing.title IS DISTINCT FROM trim(v_block->>'title')
       OR v_existing.block_type IS DISTINCT FROM trim(v_block->>'block_type') THEN
      RAISE EXCEPTION 'protocol_graph_conflict';
    END IF;
    v_block_id := v_existing.block_id;

    FOR v_ex IN SELECT value FROM jsonb_array_elements(COALESCE(v_block->'exercises', '[]'::JSONB))
    LOOP
      SELECT * INTO v_row
      FROM public.session_block_exercises e
      WHERE e.block_id = v_block_id
        AND e.position = (v_ex->>'position')::INT;
      IF NOT FOUND OR v_row.exercise_id IS DISTINCT FROM trim(v_ex->>'exercise_id') THEN
        RAISE EXCEPTION 'protocol_graph_conflict';
      END IF;
      v_new_rx := COALESCE(v_ex->'prescription', '{}'::JSONB);
      IF COALESCE(v_row.prescription->'sets', 'null'::JSONB)
           IS DISTINCT FROM COALESCE(v_new_rx->'sets', 'null'::JSONB)
         AND v_row.prescription IS NOT NULL
         AND v_new_rx ? 'sets' THEN
        -- Volume identity must not drift; capture-only updates keep sets.
        IF (v_row.prescription->>'sets') IS DISTINCT FROM (v_new_rx->>'sets') THEN
          RAISE EXCEPTION 'protocol_graph_conflict';
        END IF;
      END IF;
      IF v_row.prescription IS NOT DISTINCT FROM v_new_rx THEN
        v_unchanged := v_unchanged + 1;
      ELSE
        UPDATE public.session_block_exercises
        SET prescription = v_new_rx
        WHERE id = v_row.id;
        v_updated := v_updated + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'updated_exercises', v_updated,
    'unchanged_exercises', v_unchanged
  );
END;
$$;

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
        SELECT 1 FROM public.training_sessions t
        WHERE t.athlete_id::text = a.athlete_id::text
          AND t.protocol_id IN (
            SELECT trim(s.value->>'protocol_id')
            FROM jsonb_array_elements(payload->'sessions') s(value)
          )
      )
      OR EXISTS (
        SELECT 1
        FROM public.programme_slot_outcomes so
        WHERE so.assignment_id = a.id
          AND so.outcome_status IS DISTINCT FROM 'scheduled'
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

CREATE OR REPLACE FUNCTION public.cohort_payload_protocol_graphs_complete(payload JSONB)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_typeof(payload->'protocol_graphs') = 'array'
    AND jsonb_array_length(payload->'protocol_graphs') >= jsonb_array_length(payload->'sessions')
    AND NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(payload->'sessions') sess
      WHERE NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(payload->'protocol_graphs') g
        WHERE trim(g->>'protocol_id') = trim(sess->>'protocol_id')
          AND jsonb_typeof(g->'blocks') = 'array'
          AND jsonb_array_length(g->'blocks') >= 1
      )
    )
    AND public.cohort_payload_exercise_capture_complete(payload);
$$;

REVOKE ALL ON FUNCTION public.repair_private_programme_exercise_capture(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.repair_private_programme_exercise_capture(JSONB)
  TO service_role;

REVOKE ALL ON FUNCTION public.cohort_update_private_exercise_capture(TEXT, JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_update_private_exercise_capture(TEXT, JSONB)
  TO service_role;

COMMENT ON FUNCTION public.repair_private_programme_exercise_capture(JSONB) IS
  'Service-role capture-metadata repair for an already-published private graph. Does not mutate assignments or sessions.';
