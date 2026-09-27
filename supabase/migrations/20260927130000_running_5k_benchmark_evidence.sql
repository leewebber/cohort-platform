-- Running Pace Foundation B2: athlete-scoped, append-only 5 km benchmark evidence.
-- This store is intentionally not wired to target calculation or session start.

CREATE TABLE public.running_5k_benchmark_evidence (
  evidence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  source_kind TEXT NOT NULL,
  source_reference TEXT NOT NULL,
  cohort_session_record_id UUID
    REFERENCES public.training_session_records(record_id) ON DELETE RESTRICT,
  authored_test_reference TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT running_5k_benchmark_evidence_source_check
    CHECK (source_kind IN ('cohort', 'manual')),
  CONSTRAINT running_5k_benchmark_evidence_reference_check
    CHECK (
      length(source_reference) BETWEEN 1 AND 512
      AND source_reference ~ '^[A-Za-z0-9][A-Za-z0-9._:-]*$'
    ),
  CONSTRAINT running_5k_benchmark_evidence_source_shape_check CHECK (
    (source_kind = 'manual'
      AND cohort_session_record_id IS NULL
      AND authored_test_reference IS NULL)
    OR
    (source_kind = 'cohort'
      AND cohort_session_record_id IS NOT NULL
      AND length(authored_test_reference) BETWEEN 1 AND 256
      AND authored_test_reference ~ '^[A-Za-z0-9][A-Za-z0-9._:-]*$')
  ),
  CONSTRAINT running_5k_benchmark_evidence_source_unique
    UNIQUE (athlete_id, source_kind, source_reference)
);

CREATE TABLE public.running_5k_benchmark_evidence_revisions (
  revision_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_id UUID NOT NULL
    REFERENCES public.running_5k_benchmark_evidence(evidence_id) ON DELETE RESTRICT,
  revision_number INT NOT NULL,
  supersedes_revision_id UUID
    REFERENCES public.running_5k_benchmark_evidence_revisions(revision_id)
    ON DELETE RESTRICT,
  command_id UUID NOT NULL UNIQUE,
  request_fingerprint TEXT NOT NULL,
  distance_metres INT NOT NULL,
  elapsed_duration_milliseconds BIGINT NOT NULL,
  duration_basis TEXT NOT NULL,
  local_test_date DATE NOT NULL,
  iana_timezone TEXT NOT NULL,
  declaration TEXT NOT NULL,
  surface_context TEXT NOT NULL,
  correction_reason TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT running_5k_benchmark_revision_number_check
    CHECK (revision_number > 0),
  CONSTRAINT running_5k_benchmark_exact_distance_check
    CHECK (distance_metres = 5000),
  CONSTRAINT running_5k_benchmark_elapsed_check
    CHECK (elapsed_duration_milliseconds > 0),
  CONSTRAINT running_5k_benchmark_duration_basis_check
    CHECK (duration_basis = 'elapsed_including_pauses'),
  CONSTRAINT running_5k_benchmark_declaration_check
    CHECK (declaration = 'completed_five_kilometre_test'),
  CONSTRAINT running_5k_benchmark_surface_check
    CHECK (surface_context IN ('outdoor', 'treadmill')),
  CONSTRAINT running_5k_benchmark_timezone_check
    CHECK (length(trim(iana_timezone)) BETWEEN 1 AND 128),
  CONSTRAINT running_5k_benchmark_local_date_check
    CHECK (local_test_date BETWEEN DATE '0001-01-01' AND DATE '9999-12-31'),
  CONSTRAINT running_5k_benchmark_request_fingerprint_check
    CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
  CONSTRAINT running_5k_benchmark_correction_reason_check
    CHECK (
      (revision_number = 1
        AND supersedes_revision_id IS NULL
        AND correction_reason IS NULL)
      OR
      (revision_number > 1
        AND supersedes_revision_id IS NOT NULL
        AND length(trim(correction_reason)) BETWEEN 1 AND 500)
    ),
  CONSTRAINT running_5k_benchmark_evidence_revision_unique
    UNIQUE (evidence_id, revision_number),
  CONSTRAINT running_5k_benchmark_superseded_once
    UNIQUE (supersedes_revision_id)
);

CREATE INDEX running_5k_benchmark_evidence_athlete_idx
  ON public.running_5k_benchmark_evidence(athlete_id, created_at DESC);
CREATE INDEX running_5k_benchmark_revisions_evidence_idx
  ON public.running_5k_benchmark_evidence_revisions(
    evidence_id, revision_number DESC
  );

COMMENT ON TABLE public.running_5k_benchmark_evidence IS
  'Stable athlete-scoped identities for explicitly declared completed 5 km benchmark evidence.';
COMMENT ON TABLE public.running_5k_benchmark_evidence_revisions IS
  'Append-only values and correction history for 5 km benchmark evidence; elapsed time includes pauses.';
COMMENT ON COLUMN public.running_5k_benchmark_evidence.authored_test_reference IS
  'Trusted Cohort attestation reference. Current Plan Package v2 does not independently encode 5 km test intent.';

CREATE OR REPLACE FUNCTION public.cohort_reject_running_5k_evidence_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'running 5 km benchmark evidence is append-only'
    USING ERRCODE = 'integrity_constraint_violation';
END;
$$;

CREATE TRIGGER running_5k_benchmark_evidence_append_only
  BEFORE UPDATE OR DELETE ON public.running_5k_benchmark_evidence
  FOR EACH ROW EXECUTE FUNCTION public.cohort_reject_running_5k_evidence_mutation();
CREATE TRIGGER running_5k_benchmark_revisions_append_only
  BEFORE UPDATE OR DELETE ON public.running_5k_benchmark_evidence_revisions
  FOR EACH ROW EXECUTE FUNCTION public.cohort_reject_running_5k_evidence_mutation();

CREATE OR REPLACE FUNCTION public.cohort_running_5k_payload_is_valid(
  payload JSONB,
  allowed_keys TEXT[]
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT payload IS NOT NULL
    AND jsonb_typeof(payload) = 'object'
    AND payload - allowed_keys = '{}'::JSONB
    AND payload ?& allowed_keys;
$$;

CREATE OR REPLACE FUNCTION public.cohort_running_5k_timezone_is_valid(
  timezone_name TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT length(trim(COALESCE(timezone_name, ''))) BETWEEN 1 AND 128
    AND EXISTS (
      SELECT 1 FROM pg_timezone_names
      WHERE name = trim(timezone_name)
    );
$$;

CREATE OR REPLACE FUNCTION public.record_manual_completed_5k_benchmark(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_command UUID;
  v_date DATE;
  v_elapsed BIGINT;
  v_timezone TEXT;
  v_reference TEXT;
  v_fingerprint TEXT;
  v_existing RECORD;
  v_evidence UUID;
  v_revision UUID;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'athlete_authentication_required');
  END IF;
  IF NOT public.cohort_running_5k_payload_is_valid(payload, ARRAY[
    'command_id', 'source_reference', 'source', 'declaration',
    'distance_metres', 'elapsed_duration_milliseconds', 'duration_basis',
    'local_test_date', 'iana_timezone', 'surface_context'
  ]) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_manual_evidence_payload');
  END IF;
  BEGIN
    v_command := (payload->>'command_id')::UUID;
    v_date := (payload->>'local_test_date')::DATE;
    v_elapsed := (payload->>'elapsed_duration_milliseconds')::BIGINT;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_manual_evidence_payload');
  END;
  v_timezone := trim(payload->>'iana_timezone');
  v_reference := trim(payload->>'source_reference');
  IF payload->>'source' IS DISTINCT FROM 'manual'
     OR payload->>'declaration' IS DISTINCT FROM 'completed_five_kilometre_test'
     OR payload->>'duration_basis' IS DISTINCT FROM 'elapsed_including_pauses'
     OR payload->>'distance_metres' IS DISTINCT FROM '5000'
     OR v_elapsed <= 0
     OR payload->>'surface_context' NOT IN ('outdoor', 'treadmill')
     OR length(v_reference) NOT BETWEEN 1 AND 512
     OR v_reference !~ '^[A-Za-z0-9][A-Za-z0-9._:-]*$'
     OR NOT public.cohort_running_5k_timezone_is_valid(v_timezone)
     OR v_date > (NOW() AT TIME ZONE v_timezone)::DATE
  THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'ineligible_manual_evidence');
  END IF;
  v_fingerprint := encode(digest(convert_to(payload::TEXT, 'UTF8'), 'sha256'), 'hex');
  PERFORM pg_advisory_xact_lock(84260927, hashtext(v_command::TEXT));
  SELECT e.athlete_id, r.request_fingerprint, e.evidence_id, r.revision_id, r.revision_number
  INTO v_existing
  FROM public.running_5k_benchmark_evidence_revisions r
  JOIN public.running_5k_benchmark_evidence e USING (evidence_id)
  WHERE r.command_id = v_command;
  IF FOUND THEN
    IF v_existing.athlete_id IS DISTINCT FROM v_athlete THEN
      RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'cross_athlete_command');
    END IF;
    IF v_existing.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'idempotency_key_reused');
    END IF;
    RETURN jsonb_build_object('status', 'already_recorded', 'evidence_id', v_existing.evidence_id,
      'revision_id', v_existing.revision_id, 'revision_number', v_existing.revision_number);
  END IF;

  PERFORM pg_advisory_xact_lock(84260928, hashtext(v_athlete::TEXT || ':manual:' || v_reference));
  SELECT e.evidence_id, r.revision_id, r.revision_number,
         r.distance_metres, r.elapsed_duration_milliseconds, r.local_test_date,
         r.iana_timezone, r.surface_context
  INTO v_existing
  FROM public.running_5k_benchmark_evidence e
  JOIN LATERAL (
    SELECT * FROM public.running_5k_benchmark_evidence_revisions x
    WHERE x.evidence_id = e.evidence_id ORDER BY x.revision_number DESC LIMIT 1
  ) r ON TRUE
  WHERE e.athlete_id = v_athlete AND e.source_kind = 'manual'
    AND e.source_reference = v_reference;
  IF FOUND THEN
    IF v_existing.distance_metres = 5000
       AND v_existing.elapsed_duration_milliseconds = v_elapsed
       AND v_existing.local_test_date = v_date
       AND v_existing.iana_timezone = v_timezone
       AND v_existing.surface_context = payload->>'surface_context' THEN
      RETURN jsonb_build_object('status', 'already_recorded', 'evidence_id', v_existing.evidence_id,
        'revision_id', v_existing.revision_id, 'revision_number', v_existing.revision_number);
    END IF;
    RETURN jsonb_build_object('status', 'conflict', 'code', 'correction_required');
  END IF;

  INSERT INTO public.running_5k_benchmark_evidence(
    athlete_id, source_kind, source_reference
  ) VALUES (v_athlete, 'manual', v_reference)
  RETURNING evidence_id INTO v_evidence;
  INSERT INTO public.running_5k_benchmark_evidence_revisions(
    evidence_id, revision_number, command_id, request_fingerprint,
    distance_metres, elapsed_duration_milliseconds, duration_basis,
    local_test_date, iana_timezone, declaration, surface_context, created_by
  ) VALUES (
    v_evidence, 1, v_command, v_fingerprint, 5000, v_elapsed,
    'elapsed_including_pauses', v_date, v_timezone,
    'completed_five_kilometre_test', payload->>'surface_context', v_athlete
  ) RETURNING revision_id INTO v_revision;
  RETURN jsonb_build_object('status', 'recorded', 'evidence_id', v_evidence,
    'revision_id', v_revision, 'revision_number', 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_cohort_completed_5k_benchmark(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_command UUID;
  v_athlete UUID;
  v_record_id UUID;
  v_date DATE;
  v_elapsed BIGINT;
  v_timezone TEXT;
  v_authored_ref TEXT;
  v_reference TEXT;
  v_fingerprint TEXT;
  v_record public.training_session_records%ROWTYPE;
  v_existing RECORD;
  v_evidence UUID;
  v_revision UUID;
BEGIN
  IF NOT public.cohort_running_5k_payload_is_valid(payload, ARRAY[
    'command_id', 'athlete_id', 'session_record_id', 'authored_test_reference',
    'source', 'declaration', 'distance_metres',
    'elapsed_duration_milliseconds', 'duration_basis', 'local_test_date',
    'iana_timezone', 'surface_context'
  ]) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_cohort_evidence_payload');
  END IF;
  BEGIN
    v_command := (payload->>'command_id')::UUID;
    v_athlete := (payload->>'athlete_id')::UUID;
    v_record_id := (payload->>'session_record_id')::UUID;
    v_date := (payload->>'local_test_date')::DATE;
    v_elapsed := (payload->>'elapsed_duration_milliseconds')::BIGINT;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_cohort_evidence_payload');
  END;
  v_timezone := trim(payload->>'iana_timezone');
  v_authored_ref := trim(payload->>'authored_test_reference');
  IF payload->>'source' IS DISTINCT FROM 'cohort'
     OR payload->>'declaration' IS DISTINCT FROM 'completed_five_kilometre_test'
     OR payload->>'duration_basis' IS DISTINCT FROM 'elapsed_including_pauses'
     OR payload->>'distance_metres' IS DISTINCT FROM '5000'
     OR v_elapsed <= 0
     OR payload->>'surface_context' NOT IN ('outdoor', 'treadmill')
     OR length(v_authored_ref) NOT BETWEEN 1 AND 256
     OR v_authored_ref !~ '^[A-Za-z0-9][A-Za-z0-9._:-]*$'
     OR NOT public.cohort_running_5k_timezone_is_valid(v_timezone)
     OR v_date > (NOW() AT TIME ZONE v_timezone)::DATE
  THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'ineligible_cohort_evidence');
  END IF;
  SELECT * INTO v_record FROM public.training_session_records
  WHERE record_id = v_record_id FOR SHARE;
  IF NOT FOUND OR v_record.athlete_id IS DISTINCT FROM v_athlete::TEXT
     OR v_record.status IS DISTINCT FROM 'completed'
     OR v_record.completed_at IS NULL
     OR v_date IS DISTINCT FROM
        (v_record.completed_at AT TIME ZONE v_timezone)::DATE THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'completed_cohort_test_missing');
  END IF;
  v_reference := 'cohort:' || v_record_id::TEXT || ':' || v_authored_ref;
  v_fingerprint := encode(digest(convert_to(payload::TEXT, 'UTF8'), 'sha256'), 'hex');
  PERFORM pg_advisory_xact_lock(84260927, hashtext(v_command::TEXT));
  SELECT e.athlete_id, r.request_fingerprint, e.evidence_id, r.revision_id, r.revision_number
  INTO v_existing
  FROM public.running_5k_benchmark_evidence_revisions r
  JOIN public.running_5k_benchmark_evidence e USING (evidence_id)
  WHERE r.command_id = v_command;
  IF FOUND THEN
    IF v_existing.athlete_id IS DISTINCT FROM v_athlete THEN
      RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'cross_athlete_command');
    END IF;
    IF v_existing.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'idempotency_key_reused');
    END IF;
    RETURN jsonb_build_object('status', 'already_recorded', 'evidence_id', v_existing.evidence_id,
      'revision_id', v_existing.revision_id, 'revision_number', v_existing.revision_number);
  END IF;
  PERFORM pg_advisory_xact_lock(84260928, hashtext(v_athlete::TEXT || ':' || v_reference));
  SELECT e.evidence_id, r.revision_id, r.revision_number,
         r.elapsed_duration_milliseconds, r.local_test_date,
         r.iana_timezone, r.surface_context
  INTO v_existing
  FROM public.running_5k_benchmark_evidence e
  JOIN LATERAL (
    SELECT * FROM public.running_5k_benchmark_evidence_revisions x
    WHERE x.evidence_id = e.evidence_id ORDER BY x.revision_number DESC LIMIT 1
  ) r ON TRUE
  WHERE e.athlete_id = v_athlete AND e.source_kind = 'cohort'
    AND e.source_reference = v_reference;
  IF FOUND THEN
    IF v_existing.elapsed_duration_milliseconds = v_elapsed
       AND v_existing.local_test_date = v_date
       AND v_existing.iana_timezone = v_timezone
       AND v_existing.surface_context = payload->>'surface_context' THEN
      RETURN jsonb_build_object('status', 'already_recorded', 'evidence_id', v_existing.evidence_id,
        'revision_id', v_existing.revision_id, 'revision_number', v_existing.revision_number);
    END IF;
    RETURN jsonb_build_object('status', 'conflict', 'code', 'correction_required');
  END IF;
  INSERT INTO public.running_5k_benchmark_evidence(
    athlete_id, source_kind, source_reference, cohort_session_record_id,
    authored_test_reference
  ) VALUES (v_athlete, 'cohort', v_reference, v_record_id, v_authored_ref)
  RETURNING evidence_id INTO v_evidence;
  INSERT INTO public.running_5k_benchmark_evidence_revisions(
    evidence_id, revision_number, command_id, request_fingerprint,
    distance_metres, elapsed_duration_milliseconds, duration_basis,
    local_test_date, iana_timezone, declaration, surface_context
  ) VALUES (
    v_evidence, 1, v_command, v_fingerprint, 5000, v_elapsed,
    'elapsed_including_pauses', v_date, v_timezone,
    'completed_five_kilometre_test', payload->>'surface_context'
  ) RETURNING revision_id INTO v_revision;
  RETURN jsonb_build_object('status', 'recorded', 'evidence_id', v_evidence,
    'revision_id', v_revision, 'revision_number', 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_append_running_5k_correction(
  payload JSONB,
  expected_source TEXT,
  actor UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_command UUID;
  v_evidence UUID;
  v_date DATE;
  v_elapsed BIGINT;
  v_timezone TEXT;
  v_fingerprint TEXT;
  v_root public.running_5k_benchmark_evidence%ROWTYPE;
  v_current public.running_5k_benchmark_evidence_revisions%ROWTYPE;
  v_existing RECORD;
  v_revision UUID;
BEGIN
  IF NOT public.cohort_running_5k_payload_is_valid(payload, ARRAY[
    'command_id', 'evidence_id', 'declaration', 'distance_metres',
    'elapsed_duration_milliseconds', 'duration_basis', 'local_test_date',
    'iana_timezone', 'surface_context', 'correction_reason'
  ]) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_correction_payload');
  END IF;
  BEGIN
    v_command := (payload->>'command_id')::UUID;
    v_evidence := (payload->>'evidence_id')::UUID;
    v_date := (payload->>'local_test_date')::DATE;
    v_elapsed := (payload->>'elapsed_duration_milliseconds')::BIGINT;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_correction_payload');
  END;
  v_timezone := trim(payload->>'iana_timezone');
  IF payload->>'declaration' IS DISTINCT FROM 'completed_five_kilometre_test'
     OR payload->>'duration_basis' IS DISTINCT FROM 'elapsed_including_pauses'
     OR payload->>'distance_metres' IS DISTINCT FROM '5000'
     OR v_elapsed <= 0
     OR payload->>'surface_context' NOT IN ('outdoor', 'treadmill')
     OR length(trim(payload->>'correction_reason')) NOT BETWEEN 1 AND 500
     OR NOT public.cohort_running_5k_timezone_is_valid(v_timezone)
     OR v_date > (NOW() AT TIME ZONE v_timezone)::DATE
  THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'invalid_correction_values');
  END IF;
  v_fingerprint := encode(digest(convert_to(payload::TEXT, 'UTF8'), 'sha256'), 'hex');
  PERFORM pg_advisory_xact_lock(84260929, hashtext(v_evidence::TEXT));
  SELECT * INTO v_root FROM public.running_5k_benchmark_evidence
  WHERE evidence_id = v_evidence FOR SHARE;
  IF NOT FOUND OR v_root.source_kind IS DISTINCT FROM expected_source THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'evidence_missing');
  END IF;
  IF actor IS NOT NULL AND v_root.athlete_id IS DISTINCT FROM actor THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'cross_athlete_evidence');
  END IF;
  SELECT e.athlete_id, r.request_fingerprint, r.revision_id, r.revision_number
  INTO v_existing
  FROM public.running_5k_benchmark_evidence_revisions r
  JOIN public.running_5k_benchmark_evidence e USING (evidence_id)
  WHERE r.command_id = v_command;
  IF FOUND THEN
    IF v_existing.athlete_id IS DISTINCT FROM v_root.athlete_id THEN
      RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'cross_athlete_command');
    END IF;
    IF v_existing.request_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'idempotency_key_reused');
    END IF;
    RETURN jsonb_build_object('status', 'already_corrected', 'evidence_id', v_evidence,
      'revision_id', v_existing.revision_id, 'revision_number', v_existing.revision_number);
  END IF;
  SELECT * INTO STRICT v_current
  FROM public.running_5k_benchmark_evidence_revisions
  WHERE evidence_id = v_evidence ORDER BY revision_number DESC LIMIT 1 FOR SHARE;
  INSERT INTO public.running_5k_benchmark_evidence_revisions(
    evidence_id, revision_number, supersedes_revision_id, command_id,
    request_fingerprint, distance_metres, elapsed_duration_milliseconds,
    duration_basis, local_test_date, iana_timezone, declaration,
    surface_context, correction_reason, created_by
  ) VALUES (
    v_evidence, v_current.revision_number + 1, v_current.revision_id,
    v_command, v_fingerprint, 5000, v_elapsed, 'elapsed_including_pauses',
    v_date, v_timezone, 'completed_five_kilometre_test',
    payload->>'surface_context', trim(payload->>'correction_reason'), actor
  ) RETURNING revision_id INTO v_revision;
  RETURN jsonb_build_object('status', 'corrected', 'evidence_id', v_evidence,
    'revision_id', v_revision, 'revision_number', v_current.revision_number + 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.correct_manual_completed_5k_benchmark(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_athlete UUID := auth.uid();
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object('status', 'authorization_failure', 'code', 'athlete_authentication_required');
  END IF;
  RETURN public.cohort_append_running_5k_correction(payload, 'manual', v_athlete);
END;
$$;

CREATE OR REPLACE FUNCTION public.correct_cohort_completed_5k_benchmark(payload JSONB)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.cohort_append_running_5k_correction(payload, 'cohort', NULL);
$$;

CREATE OR REPLACE FUNCTION public.list_my_eligible_5k_benchmark_evidence(
  p_as_of_local_date DATE,
  p_freshness_local_civil_days INT
)
RETURNS TABLE (
  evidence_id UUID,
  revision_id UUID,
  source_kind TEXT,
  source_reference TEXT,
  distance_metres INT,
  elapsed_duration_milliseconds BIGINT,
  duration_basis TEXT,
  local_test_date DATE,
  iana_timezone TEXT,
  declaration TEXT,
  surface_context TEXT,
  civil_age_days INT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE v_athlete UUID := auth.uid();
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RAISE EXCEPTION 'athlete authentication required' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_as_of_local_date IS NULL OR p_freshness_local_civil_days IS NULL
     OR p_freshness_local_civil_days < 0 THEN
    RAISE EXCEPTION 'invalid freshness boundary' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  RETURN QUERY
  SELECT e.evidence_id, r.revision_id, e.source_kind, e.source_reference,
    r.distance_metres, r.elapsed_duration_milliseconds, r.duration_basis,
    r.local_test_date, r.iana_timezone, r.declaration, r.surface_context,
    (p_as_of_local_date - r.local_test_date)::INT
  FROM public.running_5k_benchmark_evidence e
  JOIN LATERAL (
    SELECT x.* FROM public.running_5k_benchmark_evidence_revisions x
    WHERE x.evidence_id = e.evidence_id
    ORDER BY x.revision_number DESC LIMIT 1
  ) r ON TRUE
  WHERE e.athlete_id = v_athlete
    AND r.local_test_date <= p_as_of_local_date
    AND p_as_of_local_date - r.local_test_date <= p_freshness_local_civil_days
  ORDER BY r.local_test_date DESC, e.evidence_id;
END;
$$;

ALTER TABLE public.running_5k_benchmark_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.running_5k_benchmark_evidence_revisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY running_5k_benchmark_evidence_owner_select
  ON public.running_5k_benchmark_evidence FOR SELECT TO authenticated
  USING (athlete_id = auth.uid());
CREATE POLICY running_5k_benchmark_revisions_owner_select
  ON public.running_5k_benchmark_evidence_revisions FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.running_5k_benchmark_evidence e
    WHERE e.evidence_id = running_5k_benchmark_evidence_revisions.evidence_id
      AND e.athlete_id = auth.uid()
  ));

REVOKE ALL ON TABLE public.running_5k_benchmark_evidence FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE public.running_5k_benchmark_evidence_revisions FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.running_5k_benchmark_evidence TO authenticated;
GRANT SELECT ON TABLE public.running_5k_benchmark_evidence_revisions TO authenticated;

REVOKE ALL ON FUNCTION public.cohort_running_5k_payload_is_valid(JSONB, TEXT[]) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_running_5k_timezone_is_valid(TEXT) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_append_running_5k_correction(JSONB, TEXT, UUID) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_reject_running_5k_evidence_mutation() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.record_manual_completed_5k_benchmark(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_manual_completed_5k_benchmark(JSONB) TO authenticated;
REVOKE ALL ON FUNCTION public.correct_manual_completed_5k_benchmark(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.correct_manual_completed_5k_benchmark(JSONB) TO authenticated;
REVOKE ALL ON FUNCTION public.list_my_eligible_5k_benchmark_evidence(DATE, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_my_eligible_5k_benchmark_evidence(DATE, INT) TO authenticated;
REVOKE ALL ON FUNCTION public.record_cohort_completed_5k_benchmark(JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_cohort_completed_5k_benchmark(JSONB) TO service_role;
REVOKE ALL ON FUNCTION public.correct_cohort_completed_5k_benchmark(JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.correct_cohort_completed_5k_benchmark(JSONB) TO service_role;
