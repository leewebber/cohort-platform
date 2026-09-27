-- Plan Package v2: optional, hash-attested authored_running_v1 slot authority.
-- The existing v1 publication function and persisted v1 packages remain unchanged.

ALTER TABLE public.programme_version_session_slots
  ADD COLUMN IF NOT EXISTS authored_running_v1 JSONB;

CREATE OR REPLACE FUNCTION public.cohort_authored_running_v1_is_valid(document JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_step JSONB;
  v_attachment JSONB;
  v_policy JSONB;
  v_eligibility JSONB;
  v_rounding JSONB;
  v_step_ids TEXT[] := ARRAY[]::TEXT[];
  v_attachment_ids TEXT[] := ARRAY[]::TEXT[];
  v_identity_pattern CONSTANT TEXT := '^[A-Za-z][A-Za-z0-9._:-]*$';
BEGIN
  IF document IS NULL OR jsonb_typeof(document) <> 'object'
     OR NOT (document ?& ARRAY['schema_version', 'workout_id', 'step_ids', 'advisory_attachments']::TEXT[])
     OR document - ARRAY['schema_version', 'workout_id', 'step_ids', 'advisory_attachments']::TEXT[] <> '{}'::JSONB
     OR jsonb_typeof(document->'schema_version') <> 'number'
     OR document->>'schema_version' <> '1'
     OR COALESCE(document->>'workout_id', '') !~ v_identity_pattern
     OR jsonb_typeof(document->'step_ids') <> 'array'
     OR jsonb_array_length(document->'step_ids') < 1
     OR jsonb_typeof(document->'advisory_attachments') <> 'array'
     OR jsonb_array_length(document->'advisory_attachments') < 1 THEN
    RETURN FALSE;
  END IF;

  FOR v_step IN SELECT value FROM jsonb_array_elements(document->'step_ids')
  LOOP
    IF jsonb_typeof(v_step) <> 'string'
       OR trim(v_step #>> '{}') !~ v_identity_pattern
       OR trim(v_step #>> '{}') = ANY(v_step_ids) THEN
      RETURN FALSE;
    END IF;
    v_step_ids := array_append(v_step_ids, trim(v_step #>> '{}'));
  END LOOP;

  FOR v_attachment IN
    SELECT value FROM jsonb_array_elements(document->'advisory_attachments')
  LOOP
    IF jsonb_typeof(v_attachment) <> 'object'
       OR NOT (v_attachment ?& ARRAY['attachment_id', 'step_ids', 'policy']::TEXT[])
       OR v_attachment - ARRAY['attachment_id', 'step_ids', 'policy']::TEXT[] <> '{}'::JSONB
       OR COALESCE(v_attachment->>'attachment_id', '') !~ v_identity_pattern
       OR trim(v_attachment->>'attachment_id') = ANY(v_attachment_ids)
       OR jsonb_typeof(v_attachment->'step_ids') <> 'array'
       OR jsonb_array_length(v_attachment->'step_ids') < 1
       OR jsonb_typeof(v_attachment->'policy') <> 'object' THEN
      RETURN FALSE;
    END IF;
    v_attachment_ids := array_append(
      v_attachment_ids,
      trim(v_attachment->>'attachment_id')
    );

    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_attachment->'step_ids') WITH ORDINALITY AS scoped(value, ordinal)
      WHERE jsonb_typeof(scoped.value) <> 'string'
         OR trim(scoped.value #>> '{}') !~ v_identity_pattern
         OR NOT (trim(scoped.value #>> '{}') = ANY(v_step_ids))
         OR EXISTS (
           SELECT 1
           FROM jsonb_array_elements(v_attachment->'step_ids') WITH ORDINALITY AS other(value, ordinal)
           WHERE other.ordinal < scoped.ordinal
             AND other.value = scoped.value
         )
    ) THEN
      RETURN FALSE;
    END IF;

    v_policy := v_attachment->'policy';
    IF NOT (v_policy ?& ARRAY[
         'policy_id', 'policy_version', 'method_id', 'method_version',
         'benchmark_eligibility', 'freshness_local_civil_days',
         'minimum_speed_basis_points', 'maximum_speed_basis_points',
         'display_rounding'
       ]::TEXT[])
       OR v_policy - ARRAY[
         'policy_id', 'policy_version', 'method_id', 'method_version',
         'benchmark_eligibility', 'freshness_local_civil_days',
         'minimum_speed_basis_points', 'maximum_speed_basis_points',
         'display_rounding'
       ]::TEXT[] <> '{}'::JSONB
       OR COALESCE(v_policy->>'policy_id', '') !~ v_identity_pattern
       OR COALESCE(v_policy->>'method_id', '') !~ v_identity_pattern
       OR jsonb_typeof(v_policy->'policy_version') <> 'number'
       OR (v_policy->>'policy_version') !~ '^[1-9][0-9]*$'
       OR jsonb_typeof(v_policy->'method_version') <> 'number'
       OR (v_policy->>'method_version') !~ '^[1-9][0-9]*$'
       OR jsonb_typeof(v_policy->'freshness_local_civil_days') <> 'number'
       OR (v_policy->>'freshness_local_civil_days') !~ '^[0-9]+$'
       OR jsonb_typeof(v_policy->'minimum_speed_basis_points') <> 'number'
       OR (v_policy->>'minimum_speed_basis_points') !~ '^[1-9][0-9]*$'
       OR jsonb_typeof(v_policy->'maximum_speed_basis_points') <> 'number'
       OR (v_policy->>'maximum_speed_basis_points') !~ '^[1-9][0-9]*$'
       OR (v_policy->>'maximum_speed_basis_points')::NUMERIC
          <= (v_policy->>'minimum_speed_basis_points')::NUMERIC
       OR jsonb_typeof(v_policy->'benchmark_eligibility') <> 'object'
       OR jsonb_typeof(v_policy->'display_rounding') <> 'object' THEN
      RETURN FALSE;
    END IF;

    v_eligibility := v_policy->'benchmark_eligibility';
    IF NOT (v_eligibility ?& ARRAY[
         'cohort_completed_tests_eligible',
         'manual_completed_tests_eligible',
         'external_completed_tests_eligible'
       ]::TEXT[])
       OR v_eligibility - ARRAY[
         'cohort_completed_tests_eligible',
         'manual_completed_tests_eligible',
         'external_completed_tests_eligible'
       ]::TEXT[] <> '{}'::JSONB
       OR jsonb_typeof(v_eligibility->'cohort_completed_tests_eligible') <> 'boolean'
       OR jsonb_typeof(v_eligibility->'manual_completed_tests_eligible') <> 'boolean'
       OR jsonb_typeof(v_eligibility->'external_completed_tests_eligible') <> 'boolean'
       OR NOT (
         (v_eligibility->>'cohort_completed_tests_eligible')::BOOLEAN
         OR (v_eligibility->>'manual_completed_tests_eligible')::BOOLEAN
       )
       OR (v_eligibility->>'external_completed_tests_eligible')::BOOLEAN THEN
      RETURN FALSE;
    END IF;

    v_rounding := v_policy->'display_rounding';
    IF NOT (v_rounding ?& ARRAY[
         'increment_milliseconds_per_kilometre', 'direction'
       ]::TEXT[])
       OR v_rounding - ARRAY[
         'increment_milliseconds_per_kilometre', 'direction'
       ]::TEXT[] <> '{}'::JSONB
       OR jsonb_typeof(v_rounding->'increment_milliseconds_per_kilometre') <> 'number'
       OR (v_rounding->>'increment_milliseconds_per_kilometre') !~ '^[1-9][0-9]*$'
       OR COALESCE(v_rounding->>'direction', '') NOT IN ('down', 'nearest', 'up') THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  RETURN TRUE;
EXCEPTION WHEN others THEN
  RETURN FALSE;
END;
$$;

ALTER TABLE public.programme_version_session_slots
  DROP CONSTRAINT IF EXISTS programme_version_session_slots_authored_running_v1_check;
ALTER TABLE public.programme_version_session_slots
  ADD CONSTRAINT programme_version_session_slots_authored_running_v1_check
  CHECK (
    authored_running_v1 IS NULL
    OR public.cohort_authored_running_v1_is_valid(authored_running_v1)
  );

COMMENT ON COLUMN public.programme_version_session_slots.authored_running_v1 IS
  'Optional immutable Plan Package v2 authored running workout and explicit advisory attachments.';

CREATE OR REPLACE FUNCTION public.cohort_plan_package_v2_version_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_setting('cohort.plan_package_v2_publication', TRUE) = 'on' THEN
    IF NEW.package_schema_version IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION 'Plan Package v2 wrapper expected legacy publisher schema marker'
        USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    NEW.package_schema_version := 2;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS plan_package_v2_version_insert
  ON public.programme_versions;
CREATE TRIGGER plan_package_v2_version_insert
  BEFORE INSERT ON public.programme_versions
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_plan_package_v2_version_insert();

CREATE OR REPLACE FUNCTION public.cohort_plan_package_v2_slot_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_setting('cohort.plan_package_v2_publication', TRUE) = 'on' THEN
    SELECT staged.authored_running_v1
    INTO NEW.authored_running_v1
    FROM pg_temp.cohort_plan_package_v2_running_slots staged
    WHERE staged.package_slot_key = NEW.package_slot_key;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS plan_package_v2_slot_insert
  ON public.programme_version_session_slots;
CREATE TRIGGER plan_package_v2_slot_insert
  BEFORE INSERT ON public.programme_version_session_slots
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_plan_package_v2_slot_insert();

CREATE OR REPLACE FUNCTION public.publish_private_exact_programme_version_v2(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_canonical_text TEXT;
  v_canonical JSONB;
  v_hash TEXT;
  v_result JSONB;
  v_version_id UUID;
  v_slot JSONB;
BEGIN
  IF payload IS NULL OR jsonb_typeof(payload) <> 'object'
     OR payload->>'package_schema_version' IS DISTINCT FROM '2' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'plan_package_v2_required');
  END IF;

  v_canonical_text := payload->>'package_canonical_json';
  v_hash := lower(trim(COALESCE(payload->>'package_content_hash', '')));
  IF v_canonical_text IS NULL OR v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'canonical_attestation_required');
  END IF;
  BEGIN
    v_canonical := v_canonical_text::JSONB;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_canonical_json');
  END;
  IF v_canonical->>'package_schema_version' IS DISTINCT FROM '2'
     OR encode(digest(convert_to(v_canonical_text, 'UTF8'), 'sha256'), 'hex') IS DISTINCT FROM v_hash
     OR payload->'programme' IS DISTINCT FROM (
       (v_canonical->'programme')
         - 'library_scope'::TEXT
         - 'owner_type'::TEXT
     )
     OR payload->'weeks' IS DISTINCT FROM v_canonical->'weeks'
     OR payload->'sessions' IS DISTINCT FROM v_canonical->'sessions'
     OR payload->'phases' IS DISTINCT FROM v_canonical->'phases'
     OR payload->'adaptation_permissions' IS DISTINCT FROM v_canonical->'adaptation_permissions'
     OR payload->'protected_invariants' IS DISTINCT FROM v_canonical->'protected_invariants'
     OR payload->'assessments' IS DISTINCT FROM v_canonical->'assessments'
     OR payload->'performance_evidence_requirements' IS DISTINCT FROM v_canonical->'performance_evidence_requirements'
     OR payload->'comparison_identities' IS DISTINCT FROM v_canonical->'comparison_identities' THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'canonical_hash_mismatch');
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS cohort_plan_package_v2_running_slots (
    package_slot_key TEXT PRIMARY KEY,
    authored_running_v1 JSONB
  ) ON COMMIT DROP;
  TRUNCATE pg_temp.cohort_plan_package_v2_running_slots;

  FOR v_slot IN
    SELECT slot.value
    FROM jsonb_array_elements(payload->'weeks') week(value)
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(week.value->'days', '[]'::JSONB)) day(value)
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(day.value->'slots', '[]'::JSONB)) slot(value)
  LOOP
    IF COALESCE(v_slot->>'slot_key', '') = '' THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'missing_slot_key');
    END IF;
    IF v_slot ? 'authored_running_v1'
       AND NOT public.cohort_authored_running_v1_is_valid(v_slot->'authored_running_v1') THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_authored_running_v1');
    END IF;
    BEGIN
      INSERT INTO pg_temp.cohort_plan_package_v2_running_slots (
        package_slot_key,
        authored_running_v1
      ) VALUES (
        trim(v_slot->>'slot_key'),
        v_slot->'authored_running_v1'
      );
    EXCEPTION WHEN unique_violation THEN
      RETURN jsonb_build_object('status', 'validation_failure', 'code', 'duplicate_slot_key');
    END;
  END LOOP;

  PERFORM set_config('cohort.plan_package_v2_publication', 'on', TRUE);
  v_result := public.publish_private_exact_programme_version(payload);
  PERFORM set_config('cohort.plan_package_v2_publication', 'off', TRUE);

  IF v_result->>'status' NOT IN ('published', 'already_published') THEN
    RETURN v_result;
  END IF;
  v_version_id := (v_result->>'programme_version_id')::UUID;
  IF NOT EXISTS (
    SELECT 1
    FROM public.programme_versions version
    WHERE version.id = v_version_id
      AND version.package_schema_version = 2
      AND version.package_content_hash = v_hash
  ) OR EXISTS (
    SELECT 1
    FROM public.programme_version_session_slots persisted
    JOIN public.programme_version_days day ON day.id = persisted.day_id
    JOIN public.programme_version_weeks week ON week.id = day.week_id
    LEFT JOIN pg_temp.cohort_plan_package_v2_running_slots staged
      ON staged.package_slot_key = persisted.package_slot_key
    WHERE week.version_id = v_version_id
      AND persisted.authored_running_v1 IS DISTINCT FROM staged.authored_running_v1
  ) OR (
    SELECT count(*)
    FROM public.programme_version_session_slots persisted
    JOIN public.programme_version_days day ON day.id = persisted.day_id
    JOIN public.programme_version_weeks week ON week.id = day.week_id
    WHERE week.version_id = v_version_id
  ) IS DISTINCT FROM (
    SELECT count(*) FROM pg_temp.cohort_plan_package_v2_running_slots
  ) THEN
    RAISE EXCEPTION 'Plan Package v2 publication did not preserve canonical authored running authority'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;

  RETURN v_result || jsonb_build_object('package_schema_version', 2);
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_authored_running_v1_is_valid(JSONB)
  TO service_role;
REVOKE ALL ON FUNCTION public.publish_private_exact_programme_version_v2(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_private_exact_programme_version_v2(JSONB)
  TO service_role;
