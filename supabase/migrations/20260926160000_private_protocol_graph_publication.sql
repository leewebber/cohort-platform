-- Private protocol-graph publication and incomplete-graph repair.
-- Forward-only. Does not edit 20260926120000–20260926150000.

CREATE TABLE IF NOT EXISTS public.private_programme_graph_repair_events (
  id BIGSERIAL PRIMARY KEY,
  programme_version_id UUID NOT NULL,
  package_content_hash TEXT NOT NULL,
  status TEXT NOT NULL,
  inserted_blocks INT NOT NULL DEFAULT 0,
  existing_blocks INT NOT NULL DEFAULT 0,
  inserted_exercises INT NOT NULL DEFAULT 0,
  existing_exercises INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.cohort_stable_uuid(p_seed TEXT)
RETURNS UUID
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    substr(md5(p_seed), 1, 8) || '-' ||
    substr(md5(p_seed), 9, 4) || '-4' ||
    substr(md5(p_seed), 13, 3) || '-' ||
    '8' || substr(md5(p_seed), 17, 3) || '-' ||
    substr(md5(p_seed), 21, 12)
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION public.cohort_private_protocol_is_executable(p_protocol_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.session_blocks b
    WHERE b.session_id = TRIM(p_protocol_id)
      AND (
        length(TRIM(COALESCE(b.content, ''))) > 0
        OR length(TRIM(COALESCE(b.coach_notes, ''))) > 0
        OR b.workout_format IS DISTINCT FROM 'none'
        OR EXISTS (
          SELECT 1
          FROM public.session_block_exercises e
          WHERE e.block_id = b.block_id
        )
      )
  )
  OR EXISTS (
    SELECT 1
    FROM public.protocol_steps s
    WHERE s.protocol_id = TRIM(p_protocol_id)
  );
$$;

CREATE OR REPLACE FUNCTION public.cohort_private_version_graphs_are_executable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM public.programme_version_session_slots s
    JOIN public.programme_version_days d ON d.id = s.day_id
    JOIN public.programme_version_weeks w ON w.id = d.week_id
    WHERE w.version_id = p_version_id
      AND d.day_type IS DISTINCT FROM 'rest'
      AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
      AND NOT public.cohort_private_protocol_is_executable(s.protocol_id)
  );
$$;

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
    );
$$;

CREATE OR REPLACE FUNCTION public.cohort_insert_private_protocol_graph(
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
  v_inserted_blocks INT := 0;
  v_existing_blocks INT := 0;
  v_inserted_ex INT := 0;
  v_existing_ex INT := 0;
  v_ex_count INT;
  v_ex_match INT;
BEGIN
  IF trim(COALESCE(p_graph->>'protocol_id', '')) IS DISTINCT FROM trim(p_protocol_id) THEN
    RAISE EXCEPTION 'protocol_graph_identity_mismatch';
  END IF;
  IF jsonb_typeof(p_graph->'blocks') <> 'array' OR jsonb_array_length(p_graph->'blocks') < 1 THEN
    RAISE EXCEPTION 'protocol_graph_empty';
  END IF;

  FOR v_block IN SELECT value FROM jsonb_array_elements(p_graph->'blocks')
  LOOP
    v_block_id := public.cohort_stable_uuid(
      trim(p_protocol_id) || ':block:' || trim(COALESCE(v_block->>'position', ''))
    );
    SELECT * INTO v_existing
    FROM public.session_blocks
    WHERE session_id = trim(p_protocol_id)
      AND position = (v_block->>'position')::INT;
    IF FOUND THEN
      IF v_existing.title IS DISTINCT FROM trim(v_block->>'title')
         OR v_existing.block_type IS DISTINCT FROM trim(v_block->>'block_type')
         OR v_existing.workout_format IS DISTINCT FROM COALESCE(nullif(trim(v_block->>'workout_format'), ''), 'none')
         OR COALESCE(v_existing.coach_notes, '') IS DISTINCT FROM COALESCE(nullif(trim(v_block->>'coach_notes'), ''), '')
      THEN
        RAISE EXCEPTION 'protocol_graph_conflict';
      END IF;
      SELECT count(*) INTO v_ex_count
      FROM jsonb_array_elements(COALESCE(v_block->'exercises', '[]'::JSONB));
      SELECT count(*) INTO v_ex_match
      FROM public.session_block_exercises e
      WHERE e.block_id = v_existing.block_id;
      IF v_ex_count IS DISTINCT FROM v_ex_match THEN
        RAISE EXCEPTION 'protocol_graph_conflict';
      END IF;
      FOR v_ex IN SELECT value FROM jsonb_array_elements(COALESCE(v_block->'exercises', '[]'::JSONB))
      LOOP
        IF NOT EXISTS (
          SELECT 1 FROM public.session_block_exercises e
          WHERE e.block_id = v_existing.block_id
            AND e.position = (v_ex->>'position')::INT
            AND e.exercise_id = trim(v_ex->>'exercise_id')
        ) THEN
          RAISE EXCEPTION 'protocol_graph_conflict';
        END IF;
        v_existing_ex := v_existing_ex + 1;
      END LOOP;
      v_existing_blocks := v_existing_blocks + 1;
    ELSE
      INSERT INTO public.session_blocks (
        block_id, session_id, block_type, title, content, workout_format,
        timer_config, coach_notes, position, performance_capture_mode
      ) VALUES (
        v_block_id,
        trim(p_protocol_id),
        trim(v_block->>'block_type'),
        trim(v_block->>'title'),
        COALESCE(v_block->>'content', ''),
        COALESCE(nullif(trim(v_block->>'workout_format'), ''), 'none'),
        v_block->'timer_config',
        nullif(trim(COALESCE(v_block->>'coach_notes', '')), ''),
        (v_block->>'position')::INT,
        COALESCE(nullif(trim(v_block->>'performance_capture_mode'), ''), 'auto')
      );
      FOR v_ex IN SELECT value FROM jsonb_array_elements(COALESCE(v_block->'exercises', '[]'::JSONB))
      LOOP
        INSERT INTO public.session_block_exercises (
          id, block_id, exercise_id, position, display_label_override, prescription,
          execution_group_key, execution_group_label, execution_group_rounds
        ) VALUES (
          public.cohort_stable_uuid(
            trim(p_protocol_id) || ':ex:' || trim(v_block->>'position') || ':' || trim(v_ex->>'position')
          ),
          v_block_id,
          trim(v_ex->>'exercise_id'),
          (v_ex->>'position')::INT,
          nullif(trim(COALESCE(v_ex->>'display_label_override', '')), ''),
          v_ex->'prescription',
          CASE WHEN nullif(trim(COALESCE(v_ex->>'execution_group_key', '')), '') IS NULL
            THEN NULL ELSE trim(v_ex->>'execution_group_key') END,
          CASE WHEN nullif(trim(COALESCE(v_ex->>'execution_group_key', '')), '') IS NULL
            THEN NULL ELSE nullif(trim(COALESCE(v_ex->>'execution_group_label', '')), '') END,
          CASE WHEN nullif(trim(COALESCE(v_ex->>'execution_group_key', '')), '') IS NULL
            THEN NULL ELSE NULLIF(v_ex->>'execution_group_rounds', '')::INT END
        );
        v_inserted_ex := v_inserted_ex + 1;
      END LOOP;
      v_inserted_blocks := v_inserted_blocks + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'inserted_blocks', v_inserted_blocks,
    'existing_blocks', v_existing_blocks,
    'inserted_exercises', v_inserted_ex,
    'existing_exercises', v_existing_ex
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_apply_payload_protocol_graphs(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_graph JSONB;
  v_counts JSONB;
  v_inserted_blocks INT := 0;
  v_existing_blocks INT := 0;
  v_inserted_ex INT := 0;
  v_existing_ex INT := 0;
BEGIN
  FOR v_graph IN SELECT value FROM jsonb_array_elements(payload->'protocol_graphs')
  LOOP
    v_counts := public.cohort_insert_private_protocol_graph(
      trim(v_graph->>'protocol_id'),
      v_graph
    );
    v_inserted_blocks := v_inserted_blocks + COALESCE((v_counts->>'inserted_blocks')::INT, 0);
    v_existing_blocks := v_existing_blocks + COALESCE((v_counts->>'existing_blocks')::INT, 0);
    v_inserted_ex := v_inserted_ex + COALESCE((v_counts->>'inserted_exercises')::INT, 0);
    v_existing_ex := v_existing_ex + COALESCE((v_counts->>'existing_exercises')::INT, 0);
  END LOOP;
  RETURN jsonb_build_object(
    'inserted_blocks', v_inserted_blocks,
    'existing_blocks', v_existing_blocks,
    'inserted_exercises', v_inserted_ex,
    'existing_exercises', v_existing_ex
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_private_exact_programme_version(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_kind TEXT;
  v_version_id UUID;
  v_scope TEXT;
  v_owner UUID;
  v_hash TEXT;
  v_imported_by TEXT;
  v_programme JSONB;
  v_lineage_code TEXT;
  v_version_number INT;
  v_lineage public.programme_lineages%ROWTYPE;
  v_existing public.programme_versions%ROWTYPE;
  v_tz TEXT;
  v_start DATE;
  v_session JSONB;
  v_week JSONB;
  v_day JSONB;
  v_slot JSONB;
  v_item JSONB;
  v_phase JSONB;
  v_phase_id UUID;
  v_week_id UUID;
  v_day_id UUID;
  v_phase_map JSONB := '{}'::JSONB;
  v_protocol_id TEXT;
  v_session_lineage_id UUID;
  v_revision INT;
  v_title TEXT;
  v_session_count INT := 0;
BEGIN
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_payload');
  END IF;

  IF COALESCE((payload->>'approved_for_global')::BOOLEAN, FALSE) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'catalogue_approval_forbidden');
  END IF;

  v_kind := trim(COALESCE(payload->>'publication_kind', ''));
  IF v_kind IS DISTINCT FROM 'private_exact_version' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_publication_kind');
  END IF;

  BEGIN
    v_version_id := (payload->>'programme_version_id')::UUID;
    v_owner := (payload->>'owner_id')::UUID;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_identity');
  END;
  IF v_version_id IS NULL OR v_owner IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_identity');
  END IF;

  v_scope := trim(COALESCE(payload->>'library_scope', ''));
  IF v_scope NOT IN ('coach_private', 'organisation') THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'private_scope_required');
  END IF;

  v_hash := lower(trim(COALESCE(payload->>'package_content_hash', '')));
  IF v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_hash');
  END IF;

  v_imported_by := nullif(trim(COALESCE(payload->>'imported_by', '')), '');
  IF v_imported_by IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_imported_by');
  END IF;

  v_programme := payload->'programme';
  IF v_programme IS NULL OR jsonb_typeof(v_programme) <> 'object' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_programme');
  END IF;
  v_lineage_code := trim(COALESCE(v_programme->>'lineage_code', ''));
  v_version_number := NULLIF(v_programme->>'version_number', '')::INT;
  IF v_lineage_code = '' OR v_version_number IS NULL OR v_version_number < 1 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_programme_identity');
  END IF;
  IF nullif(trim(COALESCE(v_programme->>'name', '')), '') IS NULL
     OR nullif(trim(COALESCE(v_programme->>'coaching_intent', '')), '') IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_programme_fields');
  END IF;

  IF jsonb_typeof(payload->'sessions') <> 'array'
     OR jsonb_array_length(payload->'sessions') < 1 THEN
    RETURN jsonb_build_object('status', 'session_resolution_failure', 'code', 'sessions_required');
  END IF;
  IF jsonb_typeof(payload->'weeks') <> 'array'
     OR jsonb_array_length(payload->'weeks') < 1 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'weeks_required');
  END IF;

  IF NOT public.cohort_payload_protocol_graphs_complete(payload) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'protocol_graph_required');
  END IF;

  v_tz := nullif(trim(COALESCE(payload->>'authorised_timezone', '')), '');
  IF payload ? 'authorised_local_start_date' THEN
    BEGIN
      v_start := (payload->>'authorised_local_start_date')::DATE;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_authorised_start_date');
    END;
  END IF;
  IF v_tz IS NOT NULL
     AND (
       v_tz !~ '^[A-Za-z_]+/[A-Za-z0-9_+\-]+(/[A-Za-z0-9_+\-]+)*$'
       OR v_tz LIKE 'Etc/%'
       OR NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = v_tz)
     ) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_timezone');
  END IF;

  SELECT * INTO v_existing FROM public.programme_versions WHERE id = v_version_id;
  IF FOUND THEN
    IF v_existing.package_content_hash IS NOT DISTINCT FROM v_hash
       AND v_existing.library_scope IS NOT DISTINCT FROM v_scope
       AND v_existing.owner_id IS NOT DISTINCT FROM v_owner::text
       AND v_existing.lifecycle_status = 'published'
       AND v_existing.archived_at IS NULL
       AND v_existing.approved_for_global IS NOT TRUE THEN
      IF NOT public.cohort_private_version_graphs_are_executable(v_existing.id) THEN
        RETURN jsonb_build_object(
          'status', 'incomplete_published_graph',
          'code', 'incomplete_published_graph',
          'programme_version_id', v_existing.id,
          'package_content_hash', v_existing.package_content_hash
        );
      END IF;
      RETURN jsonb_build_object(
        'status', 'already_published',
        'programme_version_id', v_existing.id,
        'package_content_hash', v_existing.package_content_hash,
        'library_scope', v_existing.library_scope,
        'session_count', (
          SELECT count(*) FROM public.programme_version_session_slots s
          JOIN public.programme_version_days d ON d.id = s.day_id
          JOIN public.programme_version_weeks w ON w.id = d.week_id
          WHERE w.version_id = v_existing.id
        )
      );
    END IF;
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'immutable_version_conflict',
      'programme_version_id', v_existing.id
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.programme_versions v
    JOIN public.programme_lineages l ON l.id = v.lineage_id
    WHERE l.code = v_lineage_code
      AND v.version_number = v_version_number
      AND v.package_content_hash IS DISTINCT FROM v_hash
  ) THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'hash_conflict');
  END IF;

  FOR v_session IN SELECT value FROM jsonb_array_elements(payload->'sessions')
  LOOP
    v_protocol_id := trim(COALESCE(v_session->>'protocol_id', ''));
    v_title := trim(COALESCE(v_session->>'title', v_protocol_id));
    v_revision := COALESCE(NULLIF(v_session->>'revision_number', '')::INT, 1);
    BEGIN
      v_session_lineage_id := (v_session->>'session_lineage_id')::UUID;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('status', 'session_resolution_failure', 'code', 'incomplete_session_identity');
    END;
    IF v_protocol_id = '' OR v_session_lineage_id IS NULL THEN
      RETURN jsonb_build_object('status', 'session_resolution_failure', 'code', 'incomplete_session_identity');
    END IF;
    INSERT INTO public.session_lineages (id, display_name)
    VALUES (v_session_lineage_id, v_title)
    ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;
    INSERT INTO public.performance_protocols (
      protocol_id, name, published, content_kind, authoring_scope, endorsement_status,
      session_lineage_id, revision_number, lifecycle_status, published_at, owner_id
    ) VALUES (
      v_protocol_id, v_title, 'true', 'session', 'coach_private', 'coach_authored',
      v_session_lineage_id, v_revision, 'published', NOW(), v_owner::text
    )
    ON CONFLICT (protocol_id) DO UPDATE SET
      name = EXCLUDED.name,
      published = 'true',
      lifecycle_status = 'published',
      published_at = COALESCE(public.performance_protocols.published_at, NOW()),
      session_lineage_id = EXCLUDED.session_lineage_id,
      revision_number = EXCLUDED.revision_number
    WHERE public.performance_protocols.session_lineage_id IS NOT DISTINCT FROM EXCLUDED.session_lineage_id
      AND public.performance_protocols.revision_number IS NOT DISTINCT FROM EXCLUDED.revision_number;
    IF NOT EXISTS (
      SELECT 1 FROM public.performance_protocols p
      WHERE p.protocol_id = v_protocol_id
        AND p.lifecycle_status = 'published'
        AND p.session_lineage_id = v_session_lineage_id
        AND p.revision_number = v_revision
    ) THEN
      RETURN jsonb_build_object('status', 'session_resolution_failure', 'code', 'session_identity_mismatch');
    END IF;
    v_session_count := v_session_count + 1;
  END LOOP;

  PERFORM public.cohort_apply_payload_protocol_graphs(payload);

  SELECT * INTO v_lineage FROM public.programme_lineages WHERE code = v_lineage_code;
  IF NOT FOUND THEN
    INSERT INTO public.programme_lineages (code, created_by, import_key)
    VALUES (
      v_lineage_code,
      v_imported_by,
      nullif(trim(COALESCE(v_programme->>'import_key', payload->>'import_key', '')), '')
    )
    RETURNING * INTO v_lineage;
  END IF;

  INSERT INTO public.programme_versions (
    id,
    lineage_id,
    version_number,
    lifecycle_status,
    library_scope,
    owner_type,
    owner_id,
    created_by,
    name,
    description,
    duration_weeks,
    sessions_per_week,
    primary_goal,
    coaching_intent,
    difficulty,
    equipment_requirements,
    package_schema_version,
    package_content_hash,
    package_imported_at,
    package_imported_by,
    approved_for_global,
    approved_for_adaptation,
    published_at,
    authorised_timezone,
    authorised_local_start_date
  ) VALUES (
    v_version_id,
    v_lineage.id,
    v_version_number,
    'draft',
    v_scope,
    'coach',
    v_owner::text,
    v_imported_by,
    trim(v_programme->>'name'),
    nullif(trim(COALESCE(v_programme->>'description', '')), ''),
    NULLIF(v_programme->>'duration_weeks', '')::INT,
    NULLIF(v_programme->>'sessions_per_week', '')::INT,
    nullif(trim(COALESCE(v_programme->>'primary_goal', '')), ''),
    trim(v_programme->>'coaching_intent'),
    nullif(trim(COALESCE(v_programme->>'difficulty', '')), ''),
    nullif(trim(COALESCE(v_programme->>'equipment_requirements', '')), ''),
    1,
    v_hash,
    NOW(),
    v_imported_by,
    FALSE,
    FALSE,
    NULL,
    v_tz,
    v_start
  );

  IF jsonb_typeof(payload->'phases') = 'array' THEN
    FOR v_phase IN SELECT value FROM jsonb_array_elements(payload->'phases')
    LOOP
      INSERT INTO public.programme_version_phases (
        version_id, phase_order, title, intent, coach_note
      ) VALUES (
        v_version_id,
        (v_phase->>'phase_order')::INT,
        trim(v_phase->>'title'),
        nullif(trim(COALESCE(v_phase->>'intent', '')), ''),
        nullif(trim(COALESCE(v_phase->>'coach_note', '')), '')
      )
      RETURNING id INTO v_phase_id;
      v_phase_map := v_phase_map || jsonb_build_object(trim(v_phase->>'phase_key'), v_phase_id::TEXT);
    END LOOP;
  END IF;

  FOR v_week IN SELECT value FROM jsonb_array_elements(payload->'weeks')
  LOOP
    v_phase_id := NULL;
    IF nullif(trim(COALESCE(v_week->>'phase_key', '')), '') IS NOT NULL THEN
      v_phase_id := NULLIF(v_phase_map->>trim(v_week->>'phase_key'), '')::UUID;
    END IF;
    INSERT INTO public.programme_version_weeks (
      version_id, phase_id, week_number, title, intent, coach_note
    ) VALUES (
      v_version_id,
      v_phase_id,
      (v_week->>'week_number')::INT,
      nullif(trim(COALESCE(v_week->>'title', '')), ''),
      nullif(trim(COALESCE(v_week->>'intent', '')), ''),
      nullif(trim(COALESCE(v_week->>'coach_note', '')), '')
    )
    RETURNING id INTO v_week_id;

    FOR v_day IN SELECT value FROM jsonb_array_elements(COALESCE(v_week->'days', '[]'::JSONB))
    LOOP
      INSERT INTO public.programme_version_days (
        week_id, day_key, day_order, day_type, title, intent, coach_note
      ) VALUES (
        v_week_id,
        trim(v_day->>'day_key'),
        (v_day->>'day_order')::INT,
        trim(v_day->>'day_type'),
        nullif(trim(COALESCE(v_day->>'title', '')), ''),
        nullif(trim(COALESCE(v_day->>'intent', '')), ''),
        nullif(trim(COALESCE(v_day->>'coach_note', '')), '')
      )
      RETURNING id INTO v_day_id;

      FOR v_slot IN SELECT value FROM jsonb_array_elements(COALESCE(v_day->'slots', '[]'::JSONB))
      LOOP
        SELECT s.value->>'protocol_id' INTO v_protocol_id
        FROM jsonb_array_elements(payload->'sessions') AS s(value)
        WHERE trim(s.value->>'session_key') = trim(v_slot->>'session_key');

        INSERT INTO public.programme_version_session_slots (
          day_id,
          session_order,
          protocol_id,
          display_title,
          time_of_day,
          is_optional,
          completion_expectation,
          coach_note,
          package_slot_key,
          authored_progression
        ) VALUES (
          v_day_id,
          (v_slot->>'session_order')::INT,
          trim(v_protocol_id),
          nullif(trim(COALESCE(v_slot->>'display_title', '')), ''),
          COALESCE(nullif(trim(COALESCE(v_slot->>'time_of_day', '')), ''), 'any'),
          COALESCE((v_slot->>'is_optional')::BOOLEAN, FALSE),
          COALESCE(nullif(trim(COALESCE(v_slot->>'completion_expectation', '')), ''), 'required'),
          nullif(trim(COALESCE(v_slot->>'coach_note', '')), ''),
          trim(v_slot->>'slot_key'),
          v_slot->'progression'
        );
      END LOOP;
    END LOOP;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(payload->'comparison_identities', '[]'::JSONB))
  LOOP
    INSERT INTO public.programme_version_comparison_identities (
      version_id, comparison_key, session_lineage_id, label
    ) VALUES (
      v_version_id,
      trim(v_item->>'id'),
      trim(v_item->>'session_lineage_id'),
      trim(v_item->>'label')
    );
  END LOOP;

  IF NOT public.cohort_private_version_graphs_are_executable(v_version_id) THEN
    RAISE EXCEPTION 'non_executable_protocol';
  END IF;

  UPDATE public.programme_versions
  SET lifecycle_status = 'published',
      published_at = NOW(),
      updated_at = NOW()
  WHERE id = v_version_id
    AND lifecycle_status = 'draft';

  RETURN jsonb_build_object(
    'status', 'published',
    'programme_version_id', v_version_id,
    'package_content_hash', v_hash,
    'library_scope', v_scope,
    'session_count', (
      SELECT count(*) FROM public.programme_version_session_slots s
      JOIN public.programme_version_days d ON d.id = s.day_id
      JOIN public.programme_version_weeks w ON w.id = d.week_id
      WHERE w.version_id = v_version_id
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.publish_private_exact_programme_version(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_private_exact_programme_version(JSONB)
  TO service_role;


REVOKE ALL ON FUNCTION public.publish_private_exact_programme_version(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_private_exact_programme_version(JSONB)
  TO service_role;

CREATE OR REPLACE FUNCTION public.repair_incomplete_private_programme_graph(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $repair$
DECLARE
  v_version_id UUID;
  v_hash TEXT;
  v_existing public.programme_versions%ROWTYPE;
  v_counts JSONB;
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
    v_counts := public.cohort_apply_payload_protocol_graphs(payload);
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'protocol_graph_conflict');
  END;

  IF NOT public.cohort_private_version_graphs_are_executable(v_version_id) THEN
    RAISE EXCEPTION 'non_executable_protocol';
  END IF;

  INSERT INTO public.private_programme_graph_repair_events (
    programme_version_id, package_content_hash, status,
    inserted_blocks, existing_blocks, inserted_exercises, existing_exercises
  ) VALUES (
    v_version_id, v_hash, 'repaired',
    COALESCE((v_counts->>'inserted_blocks')::INT, 0),
    COALESCE((v_counts->>'existing_blocks')::INT, 0),
    COALESCE((v_counts->>'inserted_exercises')::INT, 0),
    COALESCE((v_counts->>'existing_exercises')::INT, 0)
  );

  RETURN jsonb_build_object(
    'status', 'repaired',
    'programme_version_id', v_version_id,
    'package_content_hash', v_hash
  ) || v_counts;
END;
$repair$;

REVOKE ALL ON FUNCTION public.repair_incomplete_private_programme_graph(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.repair_incomplete_private_programme_graph(JSONB)
  TO service_role;

REVOKE ALL ON FUNCTION public.cohort_insert_private_protocol_graph(TEXT, JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_insert_private_protocol_graph(TEXT, JSONB)
  TO service_role;

REVOKE ALL ON FUNCTION public.cohort_apply_payload_protocol_graphs(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_apply_payload_protocol_graphs(JSONB)
  TO service_role;

COMMENT ON FUNCTION public.repair_incomplete_private_programme_graph(JSONB) IS
  'Service-role completion of a published private version whose protocol child graph is missing. Insert-missing only.';
