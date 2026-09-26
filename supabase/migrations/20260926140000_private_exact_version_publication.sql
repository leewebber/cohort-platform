-- Private exact-version publication, ownership-scoped discovery, and
-- explicit civil start-date enrolment. Does not edit 20260926120000 or
-- 20260926130000. Does not change catalogue enrolment or defaults.

ALTER TABLE public.programme_versions
  ADD COLUMN IF NOT EXISTS authorised_timezone TEXT;

ALTER TABLE public.programme_versions
  ADD COLUMN IF NOT EXISTS authorised_local_start_date DATE;

COMMENT ON COLUMN public.programme_versions.authorised_timezone IS
  'Optional IANA timezone captured at private publication. Unused by catalogue enrolment.';

COMMENT ON COLUMN public.programme_versions.authorised_local_start_date IS
  'Optional athlete-local civil start date captured at private publication. Unused by catalogue enrolment.';

CREATE OR REPLACE FUNCTION public.cohort_private_programme_visible_to_caller(
  p_version_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_version public.programme_versions%ROWTYPE;
BEGIN
  IF v_caller IS NULL OR p_version_id IS NULL THEN
    RETURN FALSE;
  END IF;
  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN FALSE;
  END IF;
  IF NOT public.cohort_programme_version_is_private_assignable(p_version_id) THEN
    RETURN FALSE;
  END IF;
  SELECT * INTO v_version FROM public.programme_versions WHERE id = p_version_id;
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  IF nullif(trim(COALESCE(v_version.owner_id, '')), '') IS NOT NULL
     AND v_version.owner_id = v_caller::text THEN
    RETURN TRUE;
  END IF;
  RETURN EXISTS (
    SELECT 1
    FROM public.coach_athlete_relationships r
    WHERE r.status = 'active'
      AND r.athlete_id = v_caller
      AND r.coach_id::text = v_version.owner_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_private_programme_visible_to_caller(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_private_programme_visible_to_caller(UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.cohort_private_programme_visible_to_caller(UUID) IS
  'TRUE only when the caller is an athlete entitled to a published private version. Guessed ids return FALSE.';

CREATE OR REPLACE FUNCTION public.list_my_private_programme_versions()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_active UUID;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'not_authenticated',
      'programmes', '[]'::JSONB
    );
  END IF;
  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_role_required',
      'programmes', '[]'::JSONB
    );
  END IF;

  SELECT a.programme_version_id INTO v_active
  FROM public.programme_assignments a
  WHERE a.athlete_id = v_caller AND a.status = 'active';

  RETURN jsonb_build_object(
    'status', 'ok',
    'programmes', COALESCE((
      SELECT jsonb_agg(item ORDER BY item->>'title')
      FROM (
        SELECT jsonb_build_object(
          'version_id', v.id,
          'title', v.name,
          'summary', COALESCE(v.description, v.primary_goal, v.coaching_intent),
          'duration_weeks', v.duration_weeks,
          'sessions_per_week', v.sessions_per_week,
          'level', v.difficulty,
          'equipment', v.equipment_requirements,
          'classification', 'private',
          'start_eligible', TRUE,
          'already_active', v.id IS NOT DISTINCT FROM v_active,
          'authorised_timezone', v.authorised_timezone,
          'authorised_local_start_date', v.authorised_local_start_date
        ) AS item
        FROM public.programme_versions v
        WHERE public.cohort_private_programme_visible_to_caller(v.id)
      ) visible
    ), '[]'::JSONB)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.list_my_private_programme_versions()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_my_private_programme_versions()
  TO authenticated, service_role;

COMMENT ON FUNCTION public.list_my_private_programme_versions() IS
  'Ownership-scoped private programme list. Empty for missing identity or unrelated callers. No hashes.';

CREATE OR REPLACE FUNCTION public.enrol_athlete_in_private_programme_version(
  p_programme_version_id UUID,
  p_timezone TEXT,
  p_started_at DATE,
  p_replace_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_version public.programme_versions%ROWTYPE;
  v_lineage_code TEXT;
  v_active public.programme_assignments%ROWTYPE;
  v_replaced_id UUID := NULL;
  v_new_id UUID;
  v_week INT;
  v_day_key TEXT;
  v_slot INT;
  v_tz TEXT;
  v_started DATE;
  v_source TEXT;
  v_materialise JSONB;
  v_ensure JSONB;
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'not_authenticated');
  END IF;
  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'athlete_role_required');
  END IF;
  IF p_programme_version_id IS NULL OR p_started_at IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_args');
  END IF;

  SELECT * INTO v_version FROM public.programme_versions WHERE id = p_programme_version_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'version_not_found');
  END IF;
  IF public.cohort_programme_version_is_catalogue_eligible(p_programme_version_id) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'use_catalogue_enrolment');
  END IF;
  IF v_version.lifecycle_status IS DISTINCT FROM 'published'
     OR v_version.archived_at IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'version_not_private_eligible');
  END IF;
  IF NOT public.cohort_programme_version_is_private_assignable(p_programme_version_id) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'version_not_private_eligible');
  END IF;
  IF NOT public.cohort_athlete_may_enrol_private_programme_version(p_programme_version_id) THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'private_enrolment_not_authorised');
  END IF;

  SELECT l.code INTO v_lineage_code FROM public.programme_lineages l WHERE l.id = v_version.lineage_id;
  IF v_lineage_code IS NULL OR length(trim(v_lineage_code)) = 0 THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'lineage_missing');
  END IF;

  SELECT w.week_number, d.day_key,
         COALESCE((
           SELECT MIN(s.session_order)
           FROM public.programme_version_session_slots s
           WHERE s.day_id = d.id
         ), 1)
    INTO v_week, v_day_key, v_slot
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  WHERE w.version_id = p_programme_version_id
  ORDER BY w.week_number ASC, d.day_order ASC
  LIMIT 1;
  IF v_week IS NULL OR v_day_key IS NULL THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'empty_programme_structure');
  END IF;

  v_tz := nullif(trim(COALESCE(p_timezone, '')), '');
  IF v_tz IS NULL
     OR v_tz !~ '^[A-Za-z_]+/[A-Za-z0-9_+\-]+(/[A-Za-z0-9_+\-]+)*$'
     OR v_tz LIKE 'Etc/%'
     OR v_tz LIKE 'posix/%'
     OR v_tz LIKE 'right/%'
     OR NOT EXISTS (
       SELECT 1 FROM pg_timezone_names WHERE name = v_tz
     ) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_timezone');
  END IF;

  v_started := p_started_at;

  PERFORM pg_advisory_xact_lock(84202613, hashtext(v_athlete_id::text));

  SELECT * INTO v_active
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete_id AND status = 'active'
  FOR UPDATE;

  IF FOUND THEN
    IF v_active.programme_version_id = p_programme_version_id THEN
      IF v_active.timezone IS NOT DISTINCT FROM v_tz
         AND v_active.started_at IS NOT DISTINCT FROM v_started THEN
        RETURN jsonb_build_object(
          'status', 'already_enrolled',
          'enrolment_id', v_active.id,
          'programme_version_id', v_active.programme_version_id,
          'lineage_code', v_active.lineage_code,
          'enrolment_source', v_active.enrolment_source,
          'athlete_id', v_athlete_id,
          'started_at', v_active.started_at,
          'timezone', v_active.timezone
        );
      END IF;
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'start_date_mismatch',
        'enrolment_id', v_active.id,
        'programme_version_id', v_active.programme_version_id,
        'started_at', v_active.started_at,
        'timezone', v_active.timezone
      );
    END IF;
    IF NOT COALESCE(p_replace_active, FALSE) THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'active_enrolment_exists',
        'enrolment_id', v_active.id,
        'programme_version_id', v_active.programme_version_id
      );
    END IF;
    v_replaced_id := v_active.id;
  END IF;

  v_new_id := gen_random_uuid();
  IF nullif(trim(COALESCE(v_version.owner_id, '')), '') = v_athlete_id::text THEN
    v_source := 'dual_role_self';
  ELSE
    v_source := 'coach_assigned';
  END IF;

  IF v_replaced_id IS NOT NULL THEN
    PERFORM set_config('cohort.allow_materialisation_write', 'on', true);
    UPDATE public.programme_assignments
    SET status = 'reassigned', updated_at = NOW()
    WHERE id = v_replaced_id
      AND athlete_id = v_athlete_id
      AND status = 'active';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'active assignment replacement lost concurrent ownership'
        USING ERRCODE = '40001';
    END IF;
  END IF;

  INSERT INTO public.programme_assignments (
    id, athlete_id, programme_version_id, lineage_code, status, started_at,
    timezone, current_week_number, current_day_key, current_slot_order, enrolment_source
  ) VALUES (
    v_new_id, v_athlete_id, p_programme_version_id, v_lineage_code, 'active', v_started,
    v_tz, v_week, v_day_key, v_slot, v_source
  );

  IF v_replaced_id IS NOT NULL THEN
    UPDATE public.programme_assignments
    SET superseded_by_assignment_id = v_new_id, updated_at = NOW()
    WHERE id = v_replaced_id;
  END IF;

  v_materialise := public.materialise_athlete_plan_from_enrolment(v_new_id, v_tz);
  IF v_materialise->>'status' IS DISTINCT FROM 'materialised'
     AND v_materialise->>'status' IS DISTINCT FROM 'already_materialised' THEN
    RAISE EXCEPTION 'private enrolment materialisation failed: %', v_materialise::text
      USING ERRCODE = '40001';
  END IF;

  v_ensure := public.ensure_programme_schedule_projection(v_new_id);
  IF v_ensure->>'status' NOT IN ('initialised', 'already_exists') THEN
    RAISE EXCEPTION 'private enrolment projection failed: %', v_ensure::text
      USING ERRCODE = '40001';
  END IF;

  RETURN jsonb_build_object(
    'status', 'enrolled',
    'enrolment_id', v_new_id,
    'programme_version_id', p_programme_version_id,
    'lineage_code', v_lineage_code,
    'enrolment_source', v_source,
    'athlete_id', v_athlete_id,
    'replaced_enrolment_id', v_replaced_id,
    'started_at', v_started,
    'timezone', v_tz,
    'materialised', TRUE
  );
END;
$$;

REVOKE ALL ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, DATE, BOOLEAN)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, DATE, BOOLEAN)
  TO authenticated, service_role;

COMMENT ON FUNCTION public.enrol_athlete_in_private_programme_version(UUID, TEXT, DATE, BOOLEAN) IS
  'Authenticated private enrol with an explicit athlete-local civil start date. The three-argument RPC is unchanged.';

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
    'published',
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
    NOW(),
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

COMMENT ON FUNCTION public.publish_private_exact_programme_version(JSONB) IS
  'Service-role private exact-version publication. Never catalogue-eligible. Idempotent for the identical artifact.';
