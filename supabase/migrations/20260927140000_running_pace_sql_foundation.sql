-- Running Pace Foundation B2: fail closed unproven Cohort ingestion and add
-- side-effect-free benchmark selection / exact pace calculation primitives.

CREATE OR REPLACE FUNCTION public.record_cohort_completed_5k_benchmark(
  payload JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'status', 'blocked',
    'code', 'cohort_test_completion_unproven'
  );
$$;

COMMENT ON FUNCTION public.record_cohort_completed_5k_benchmark(JSONB) IS
  'Fail-closed until a hashed authored running step maps to an executable block and completion is server-validated.';

REVOKE ALL ON FUNCTION public.record_cohort_completed_5k_benchmark(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_cohort_completed_5k_benchmark(JSONB)
  TO service_role;

-- Existing unproven Cohort rows, if any, are not exposed as eligible evidence.
-- Manual evidence remains available only when it passed the explicit manual
-- completed-test command contract.
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
    RAISE EXCEPTION 'athlete authentication required'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_as_of_local_date IS NULL OR p_freshness_local_civil_days IS NULL
     OR p_freshness_local_civil_days < 0 THEN
    RAISE EXCEPTION 'invalid freshness boundary'
      USING ERRCODE = 'invalid_parameter_value';
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
    AND e.source_kind = 'manual'
    AND r.declaration = 'completed_five_kilometre_test'
    AND r.local_test_date <= p_as_of_local_date
    AND p_as_of_local_date - r.local_test_date
      <= p_freshness_local_civil_days
  ORDER BY r.local_test_date DESC, e.evidence_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_select_running_5k_benchmark(
  p_evidence JSONB,
  p_policy JSONB,
  p_athlete_id TEXT,
  p_evaluation_local_date DATE,
  p_iana_timezone TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_candidate JSONB;
  v_selected JSONB;
  v_eligibility JSONB;
  v_freshness INT;
  v_date DATE;
BEGIN
  IF p_evidence IS NULL OR jsonb_typeof(p_evidence) <> 'array' THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'invalidEvidence');
  END IF;
  IF jsonb_array_length(p_evidence) = 0 THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'noEvidence');
  END IF;
  IF p_policy IS NULL OR jsonb_typeof(p_policy) <> 'object'
     OR NOT (p_policy ?& ARRAY[
       'policy_id', 'policy_version', 'method_id', 'method_version',
       'benchmark_eligibility', 'freshness_local_civil_days',
       'minimum_speed_basis_points', 'maximum_speed_basis_points',
       'display_rounding'
     ]::TEXT[])
     OR p_policy - ARRAY[
       'policy_id', 'policy_version', 'method_id', 'method_version',
       'benchmark_eligibility', 'freshness_local_civil_days',
       'minimum_speed_basis_points', 'maximum_speed_basis_points',
       'display_rounding'
     ]::TEXT[] <> '{}'::JSONB THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'invalidPolicy');
  END IF;
  BEGIN
    v_freshness := (p_policy->>'freshness_local_civil_days')::INT;
    IF length(trim(p_policy->>'policy_id')) = 0
       OR length(trim(p_policy->>'method_id')) = 0
       OR (p_policy->>'policy_version')::INT <= 0
       OR (p_policy->>'method_version')::INT <= 0
       OR v_freshness < 0
       OR (p_policy->>'minimum_speed_basis_points')::INT <= 0
       OR (p_policy->>'maximum_speed_basis_points')::INT
          <= (p_policy->>'minimum_speed_basis_points')::INT THEN
      RETURN jsonb_build_object('status', 'failure', 'code', 'invalidPolicy');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'invalidPolicy');
  END;
  v_eligibility := p_policy->'benchmark_eligibility';
  IF jsonb_typeof(v_eligibility) <> 'object'
     OR NOT (v_eligibility ?& ARRAY[
       'cohort_completed_tests_eligible', 'manual_completed_tests_eligible',
       'external_completed_tests_eligible'
     ]::TEXT[])
     OR v_eligibility - ARRAY[
       'cohort_completed_tests_eligible', 'manual_completed_tests_eligible',
       'external_completed_tests_eligible'
     ]::TEXT[] <> '{}'::JSONB
     OR jsonb_typeof(v_eligibility->'cohort_completed_tests_eligible') <> 'boolean'
     OR jsonb_typeof(v_eligibility->'manual_completed_tests_eligible') <> 'boolean'
     OR jsonb_typeof(v_eligibility->'external_completed_tests_eligible') <> 'boolean'
     OR NOT (
       (v_eligibility->>'cohort_completed_tests_eligible')::BOOLEAN
       OR (v_eligibility->>'manual_completed_tests_eligible')::BOOLEAN
       OR (v_eligibility->>'external_completed_tests_eligible')::BOOLEAN
     ) THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'invalidPolicy');
  END IF;
  IF jsonb_typeof(p_policy->'display_rounding') <> 'object'
     OR (p_policy->'display_rounding') - ARRAY[
       'increment_milliseconds_per_kilometre', 'direction'
     ]::TEXT[] <> '{}'::JSONB
     OR NOT ((p_policy->'display_rounding') ?& ARRAY[
       'increment_milliseconds_per_kilometre', 'direction'
     ]::TEXT[]) THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'invalidPolicy');
  END IF;
  BEGIN
    IF (p_policy#>>'{display_rounding,increment_milliseconds_per_kilometre}')::INT <= 0
       OR p_policy#>>'{display_rounding,direction}' NOT IN ('down', 'nearest', 'up') THEN
      RETURN jsonb_build_object('status', 'failure', 'code', 'invalidPolicy');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'invalidPolicy');
  END;

  FOR v_candidate IN SELECT value FROM jsonb_array_elements(p_evidence)
  LOOP
    IF jsonb_typeof(v_candidate) <> 'object'
       OR NOT (v_candidate ?& ARRAY[
         'evidence_id', 'athlete_id', 'distance_metres',
         'elapsed_duration_milliseconds', 'local_test_date', 'iana_timezone',
         'source_kind', 'source_reference', 'declaration', 'surface_context'
       ]::TEXT[])
       OR v_candidate - ARRAY[
         'evidence_id', 'athlete_id', 'distance_metres',
         'elapsed_duration_milliseconds', 'local_test_date', 'iana_timezone',
         'source_kind', 'source_reference', 'declaration', 'surface_context'
       ]::TEXT[] <> '{}'::JSONB THEN
      RETURN jsonb_build_object('status', 'failure', 'code', 'invalidEvidence');
    END IF;
    BEGIN
      v_date := (v_candidate->>'local_test_date')::DATE;
      IF length(trim(v_candidate->>'evidence_id')) = 0
         OR length(trim(v_candidate->>'athlete_id')) = 0
         OR (v_candidate->>'distance_metres')::INT <> 5000
         OR (v_candidate->>'elapsed_duration_milliseconds')::BIGINT <= 0
         OR v_candidate->>'iana_timezone' !~
            '^[A-Za-z_]+/[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$'
         OR v_candidate->>'iana_timezone' LIKE 'Etc/%'
         OR v_candidate->>'iana_timezone' LIKE 'posix/%'
         OR v_candidate->>'iana_timezone' LIKE 'right/%'
         OR v_candidate->>'source_kind' NOT IN ('cohort', 'manual', 'external')
         OR length(trim(v_candidate->>'source_reference')) = 0
         OR v_candidate->>'declaration' NOT IN (
           'completed_five_kilometre_test', 'five_kilometre_activity'
         )
         OR v_candidate->>'surface_context' NOT IN (
           'outdoor', 'treadmill', 'unspecified'
         ) THEN
        RETURN jsonb_build_object('status', 'failure', 'code', 'invalidEvidence');
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('status', 'failure', 'code', 'invalidEvidence');
    END;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_evidence) AS items(candidate)
    GROUP BY candidate->>'evidence_id' HAVING count(*) > 1
  ) THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'duplicateEvidenceIdentity'
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_evidence) AS items(candidate)
    WHERE candidate->>'athlete_id' = trim(p_athlete_id)
  ) THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'noAthleteScopedEvidence'
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_evidence) AS items(candidate)
    WHERE candidate->>'athlete_id' = trim(p_athlete_id)
      AND candidate->>'iana_timezone' = trim(p_iana_timezone)
  ) THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'noTimezoneMatchedEvidence'
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_evidence) AS items(candidate)
    WHERE candidate->>'athlete_id' = trim(p_athlete_id)
      AND candidate->>'iana_timezone' = trim(p_iana_timezone)
      AND candidate->>'declaration' = 'completed_five_kilometre_test'
      AND CASE candidate->>'source_kind'
        WHEN 'cohort' THEN
          (v_eligibility->>'cohort_completed_tests_eligible')::BOOLEAN
        WHEN 'manual' THEN
          (v_eligibility->>'manual_completed_tests_eligible')::BOOLEAN
        WHEN 'external' THEN
          (v_eligibility->>'external_completed_tests_eligible')::BOOLEAN
        ELSE FALSE
      END
  ) THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'noEligibleCompletedTest'
    );
  END IF;

  SELECT candidate INTO v_selected
  FROM jsonb_array_elements(p_evidence) AS items(candidate)
  WHERE candidate->>'athlete_id' = trim(p_athlete_id)
    AND candidate->>'iana_timezone' = trim(p_iana_timezone)
    AND candidate->>'declaration' = 'completed_five_kilometre_test'
    AND CASE candidate->>'source_kind'
      WHEN 'cohort' THEN
        (v_eligibility->>'cohort_completed_tests_eligible')::BOOLEAN
      WHEN 'manual' THEN
        (v_eligibility->>'manual_completed_tests_eligible')::BOOLEAN
      WHEN 'external' THEN
        (v_eligibility->>'external_completed_tests_eligible')::BOOLEAN
      ELSE FALSE
    END
    AND (candidate->>'local_test_date')::DATE <= p_evaluation_local_date
    AND p_evaluation_local_date - (candidate->>'local_test_date')::DATE
      <= v_freshness
  ORDER BY (candidate->>'local_test_date')::DATE DESC,
           candidate->>'evidence_id' ASC
  LIMIT 1;
  IF v_selected IS NULL THEN
    RETURN jsonb_build_object('status', 'failure', 'code', 'noFreshEvidence');
  END IF;
  RETURN jsonb_build_object(
    'status', 'success',
    'selected_evidence_id', v_selected->>'evidence_id',
    'age_local_civil_days',
      p_evaluation_local_date - (v_selected->>'local_test_date')::DATE
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_running_gcd(
  p_left NUMERIC,
  p_right NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_left NUMERIC := abs(p_left);
  v_right NUMERIC := abs(p_right);
  v_remainder NUMERIC;
BEGIN
  WHILE v_right <> 0 LOOP
    v_remainder := mod(v_left, v_right);
    v_left := v_right;
    v_right := v_remainder;
  END LOOP;
  RETURN v_left;
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_exact_running_pace(
  p_benchmark_duration_milliseconds BIGINT,
  p_speed_basis_points INT,
  p_rounding_increment_milliseconds BIGINT,
  p_rounding_direction TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_numerator NUMERIC := p_benchmark_duration_milliseconds::NUMERIC * 2000;
  v_denominator NUMERIC := p_speed_basis_points::NUMERIC;
  v_divisor NUMERIC;
  v_scaled_denominator NUMERIC;
  v_quotient NUMERIC;
  v_remainder NUMERIC;
  v_rounded_quotient NUMERIC;
BEGIN
  v_divisor := public.cohort_running_gcd(v_numerator, v_denominator);
  v_numerator := v_numerator / v_divisor;
  v_denominator := v_denominator / v_divisor;
  v_scaled_denominator := v_denominator * p_rounding_increment_milliseconds;
  v_quotient := floor(v_numerator / v_scaled_denominator);
  v_remainder := mod(v_numerator, v_scaled_denominator);
  v_rounded_quotient := CASE p_rounding_direction
    WHEN 'down' THEN v_quotient
    WHEN 'nearest' THEN
      CASE WHEN v_remainder * 2 < v_scaled_denominator
        THEN v_quotient ELSE v_quotient + 1 END
    WHEN 'up' THEN
      CASE WHEN v_remainder = 0 THEN v_quotient ELSE v_quotient + 1 END
  END;
  RETURN jsonb_build_object(
    'numerator_milliseconds_per_kilometre', v_numerator,
    'denominator', v_denominator,
    'display_milliseconds_per_kilometre',
      v_rounded_quotient * p_rounding_increment_milliseconds
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_calculate_running_pace_range(
  p_benchmark_duration_milliseconds BIGINT,
  p_minimum_speed_basis_points INT,
  p_maximum_speed_basis_points INT,
  p_rounding_increment_milliseconds BIGINT,
  p_rounding_direction TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_benchmark_duration_milliseconds IS NULL
     OR p_benchmark_duration_milliseconds <= 0 THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'invalid_benchmark_duration'
    );
  END IF;
  IF p_minimum_speed_basis_points IS NULL
     OR p_maximum_speed_basis_points IS NULL
     OR p_minimum_speed_basis_points <= 0
     OR p_maximum_speed_basis_points <= 0 THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'invalid_speed_percentage'
    );
  END IF;
  IF p_minimum_speed_basis_points >= p_maximum_speed_basis_points THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'invalid_speed_range'
    );
  END IF;
  IF p_rounding_increment_milliseconds IS NULL
     OR p_rounding_increment_milliseconds <= 0
     OR p_rounding_direction IS NULL
     OR p_rounding_direction NOT IN ('down', 'nearest', 'up') THEN
    RETURN jsonb_build_object(
      'status', 'failure', 'code', 'invalid_display_rounding'
    );
  END IF;
  RETURN jsonb_build_object(
    'status', 'success',
    'faster_pace', public.cohort_exact_running_pace(
      p_benchmark_duration_milliseconds,
      p_maximum_speed_basis_points,
      p_rounding_increment_milliseconds,
      p_rounding_direction
    ),
    'slower_pace', public.cohort_exact_running_pace(
      p_benchmark_duration_milliseconds,
      p_minimum_speed_basis_points,
      p_rounding_increment_milliseconds,
      p_rounding_direction
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.select_my_running_5k_benchmark(
  p_policy JSONB,
  p_evaluation_local_date DATE,
  p_iana_timezone TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_evidence JSONB;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_authentication_required'
    );
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'evidence_id', e.evidence_id::TEXT,
    'athlete_id', e.athlete_id::TEXT,
    'distance_metres', r.distance_metres,
    'elapsed_duration_milliseconds', r.elapsed_duration_milliseconds,
    'local_test_date', r.local_test_date::TEXT,
    'iana_timezone', r.iana_timezone,
    'source_kind', e.source_kind,
    'source_reference', e.source_reference,
    'declaration', r.declaration,
    'surface_context', r.surface_context
  ) ORDER BY r.local_test_date DESC, e.evidence_id), '[]'::JSONB)
  INTO v_evidence
  FROM public.running_5k_benchmark_evidence e
  JOIN LATERAL (
    SELECT x.* FROM public.running_5k_benchmark_evidence_revisions x
    WHERE x.evidence_id = e.evidence_id
    ORDER BY x.revision_number DESC LIMIT 1
  ) r ON TRUE
  WHERE e.athlete_id = v_athlete
    AND e.source_kind = 'manual';
  RETURN public.cohort_select_running_5k_benchmark(
    v_evidence,
    p_policy,
    v_athlete::TEXT,
    p_evaluation_local_date,
    p_iana_timezone
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_select_running_5k_benchmark(
  JSONB, JSONB, TEXT, DATE, TEXT
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_running_gcd(NUMERIC, NUMERIC)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_exact_running_pace(
  BIGINT, INT, BIGINT, TEXT
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_calculate_running_pace_range(
  BIGINT, INT, INT, BIGINT, TEXT
) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.select_my_running_5k_benchmark(
  JSONB, DATE, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.select_my_running_5k_benchmark(
  JSONB, DATE, TEXT
) TO authenticated;

COMMENT ON FUNCTION public.cohort_select_running_5k_benchmark(
  JSONB, JSONB, TEXT, DATE, TEXT
) IS 'Pure B2 selector matching the Dart athlete, source, timezone, freshness, and stable tie-break rules.';
COMMENT ON FUNCTION public.cohort_calculate_running_pace_range(
  BIGINT, INT, INT, BIGINT, TEXT
) IS 'Pure exact-rational percentage-of-benchmark-speed calculation; maximum speed yields the faster pace.';
