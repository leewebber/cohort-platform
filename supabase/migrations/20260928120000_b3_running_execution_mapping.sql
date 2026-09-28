-- Structured Running B3 slice 1: hash-attested step-to-block execution mapping.
-- Local-only until separately authorised for hosted application.

ALTER FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  RENAME TO cohort_authored_running_v1_b2_is_valid;

REVOKE ALL ON FUNCTION public.cohort_authored_running_v1_b2_is_valid(JSONB)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.cohort_authored_running_v1_is_valid(document JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_binding JSONB;
  v_ordinal BIGINT;
  v_block_ids TEXT[] := ARRAY[]::TEXT[];
  v_canonical TEXT;
  v_expected_hash TEXT;
  v_uuid_pattern CONSTANT TEXT :=
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
BEGIN
  IF document IS NULL OR jsonb_typeof(document) <> 'object' THEN
    RETURN FALSE;
  END IF;

  -- B2 authored-running documents remain valid and deliberately unattached.
  IF NOT (document ? 'executable_step_bindings')
     AND NOT (document ? 'execution_mapping_sha256') THEN
    RETURN public.cohort_authored_running_v1_b2_is_valid(document);
  END IF;

  IF NOT (document ?& ARRAY[
       'executable_step_bindings', 'execution_mapping_sha256'
     ]::TEXT[])
     OR NOT public.cohort_authored_running_v1_b2_is_valid(
       document - ARRAY[
         'executable_step_bindings', 'execution_mapping_sha256'
       ]::TEXT[]
     )
     OR jsonb_typeof(document->'executable_step_bindings') <> 'array'
     OR jsonb_array_length(document->'executable_step_bindings') < 1
     OR jsonb_array_length(document->'executable_step_bindings')
        <> jsonb_array_length(document->'step_ids')
     OR COALESCE(document->>'execution_mapping_sha256', '')
        !~ '^[0-9a-f]{64}$' THEN
    RETURN FALSE;
  END IF;

  v_canonical := 'cohort.running_execution_mapping.v1|workout_id='
    || (document->>'workout_id');
  FOR v_binding, v_ordinal IN
    SELECT value, ordinality
    FROM jsonb_array_elements(document->'executable_step_bindings')
      WITH ORDINALITY
  LOOP
    IF jsonb_typeof(v_binding) <> 'object'
       OR NOT (v_binding ?& ARRAY['step_id', 'session_block_id']::TEXT[])
       OR v_binding - ARRAY['step_id', 'session_block_id']::TEXT[] <> '{}'::JSONB
       OR v_binding->>'step_id' IS DISTINCT FROM
          (document->'step_ids')->>((v_ordinal - 1)::INT)
       OR COALESCE(v_binding->>'session_block_id', '') !~ v_uuid_pattern THEN
      RETURN FALSE;
    END IF;
    v_block_ids := array_append(
      v_block_ids,
      v_binding->>'session_block_id'
    );
    v_canonical := v_canonical
      || '|step_id=' || (v_binding->>'step_id')
      || ',session_block_id=' || (v_binding->>'session_block_id');
  END LOOP;

  IF (SELECT count(DISTINCT block_id) FROM unnest(v_block_ids) block_id) <> 1 THEN
    RETURN FALSE;
  END IF;
  v_expected_hash := encode(
    digest(convert_to(v_canonical, 'UTF8'), 'sha256'),
    'hex'
  );
  RETURN v_expected_hash = document->>'execution_mapping_sha256';
EXCEPTION WHEN others THEN
  RETURN FALSE;
END;
$$;

-- The existing CHECK remains bound to the renamed B2 function by OID, so
-- recreate it against the compatibility wrapper above.
ALTER TABLE public.programme_version_session_slots
  DROP CONSTRAINT IF EXISTS programme_version_session_slots_authored_running_v1_check;
ALTER TABLE public.programme_version_session_slots
  ADD CONSTRAINT programme_version_session_slots_authored_running_v1_check
  CHECK (
    authored_running_v1 IS NULL
    OR public.cohort_authored_running_v1_is_valid(authored_running_v1)
  );

CREATE OR REPLACE FUNCTION public.cohort_running_execution_mapping_matches_protocol(
  document JSONB,
  p_protocol_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_block public.session_blocks%ROWTYPE;
  v_timer JSONB;
  v_duration TEXT;
  v_work TEXT;
  v_rest TEXT;
  v_rounds TEXT;
  v_token TEXT;
  v_workout_id TEXT;
  v_expected_steps JSONB;
BEGIN
  IF NOT public.cohort_authored_running_v1_is_valid(document)
     OR NOT (document ? 'executable_step_bindings') THEN
    RETURN FALSE;
  END IF;

  SELECT block.* INTO v_block
  FROM public.session_blocks block
  WHERE block.block_id = (
      document#>>'{executable_step_bindings,0,session_block_id}'
    )::UUID
    AND block.session_id = trim(p_protocol_id);
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(document->'executable_step_bindings') binding
    WHERE binding->>'session_block_id' IS DISTINCT FROM v_block.block_id::TEXT
  ) THEN
    RETURN FALSE;
  END IF;

  v_timer := v_block.timer_config;
  IF jsonb_typeof(v_timer) <> 'object' THEN
    RETURN FALSE;
  END IF;
  v_duration := COALESCE(v_timer->>'durationSeconds', v_timer->>'duration_seconds');
  v_work := COALESCE(v_timer->>'workSeconds', v_timer->>'work_seconds');
  v_rest := COALESCE(
    v_timer->>'restSeconds',
    v_timer->>'rest_seconds',
    v_timer->>'recovery_seconds'
  );
  v_rounds := v_timer->>'rounds';
  v_token := v_block.workout_format
    || '|d=' || COALESCE(v_duration, '')
    || '|w=' || COALESCE(v_work, '')
    || '|r=' || COALESCE(v_rest, '')
    || '|n=' || COALESCE(v_rounds, '')
    || '|src=' || v_block.block_id::TEXT;
  v_workout_id := 'rw1:p:' || substr(
    encode(digest(convert_to(v_token, 'UTF8'), 'sha256'), 'hex'),
    1,
    16
  );
  IF document->>'workout_id' IS DISTINCT FROM v_workout_id THEN
    RETURN FALSE;
  END IF;

  IF v_block.workout_format = 'steady_state' THEN
    IF v_duration IS NULL OR v_duration !~ '^[1-9][0-9]*$' THEN
      RETURN FALSE;
    END IF;
    v_expected_steps := jsonb_build_array(v_workout_id || ':s:0');
  ELSIF v_block.workout_format = 'intervals' THEN
    IF v_work IS NULL OR v_work !~ '^[1-9][0-9]*$'
       OR v_rounds IS NULL OR v_rounds !~ '^[1-9][0-9]*$'
       OR (v_rest IS NOT NULL AND v_rest !~ '^[0-9]+$')
       OR COALESCE(jsonb_array_length(v_timer->'stations'), 0) > 0
       OR COALESCE(
         v_timer->>'restBetweenRoundsSeconds',
         v_timer->>'rest_between_rounds_seconds',
         v_timer->>'between_round_recovery_seconds'
       ) IS NOT NULL THEN
      RETURN FALSE;
    END IF;
    v_expected_steps := jsonb_build_array(v_workout_id || ':s:work');
    IF COALESCE(v_rest::INT, 0) > 0 THEN
      v_expected_steps := v_expected_steps
        || jsonb_build_array(v_workout_id || ':s:recovery');
    END IF;
  ELSE
    RETURN FALSE;
  END IF;

  RETURN document->'step_ids' = v_expected_steps;
EXCEPTION WHEN others THEN
  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_validate_running_execution_mapping_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  IF NEW.authored_running_v1 ? 'executable_step_bindings'
     AND NOT public.cohort_running_execution_mapping_matches_protocol(
       NEW.authored_running_v1,
       NEW.protocol_id
     ) THEN
    RAISE EXCEPTION 'running execution mapping does not match exact B1 protocol block'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS running_execution_mapping_scope
  ON public.programme_version_session_slots;
CREATE TRIGGER running_execution_mapping_scope
  BEFORE INSERT OR UPDATE OF authored_running_v1, protocol_id
  ON public.programme_version_session_slots
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_validate_running_execution_mapping_scope();

REVOKE ALL ON FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  TO service_role;
REVOKE ALL ON FUNCTION public.cohort_running_execution_mapping_matches_protocol(JSONB, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_validate_running_execution_mapping_scope()
  FROM PUBLIC, anon, authenticated, service_role;
