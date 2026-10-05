-- B4 Programme Studio: canonical rejection of overlapping advisory scopes.
-- Each authored running step may be claimed by at most one attachment.

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
  v_core_document JSONB;
  v_has_execution_mapping BOOLEAN;
  v_uuid_pattern CONSTANT TEXT :=
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
BEGIN
  IF document IS NULL OR jsonb_typeof(document) <> 'object' THEN
    RETURN FALSE;
  END IF;

  v_has_execution_mapping := document ? 'executable_step_bindings'
    OR document ? 'execution_mapping_sha256';
  IF v_has_execution_mapping
     AND NOT (document ?& ARRAY[
       'executable_step_bindings', 'execution_mapping_sha256'
     ]::TEXT[]) THEN
    RETURN FALSE;
  END IF;

  v_core_document := CASE
    WHEN v_has_execution_mapping THEN document - ARRAY[
      'executable_step_bindings', 'execution_mapping_sha256'
    ]::TEXT[]
    ELSE document
  END;
  IF NOT public.cohort_authored_running_v1_b2_is_valid(v_core_document) THEN
    RETURN FALSE;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(v_core_document->'advisory_attachments') attachment
    CROSS JOIN LATERAL jsonb_array_elements_text(
      attachment->'step_ids'
    ) AS scoped(step_id)
    GROUP BY scoped.step_id
    HAVING count(*) > 1
  ) THEN
    RETURN FALSE;
  END IF;

  -- B2 authored-running documents remain valid and deliberately unattached.
  IF NOT v_has_execution_mapping THEN
    RETURN TRUE;
  END IF;

  IF jsonb_typeof(document->'executable_step_bindings') <> 'array'
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

ALTER FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  TO service_role;

COMMENT ON FUNCTION public.cohort_authored_running_v1_is_valid(JSONB) IS
  'Validates canonical authored_running_v1 documents, exact B3 mappings, and one advisory attachment per authored step.';
