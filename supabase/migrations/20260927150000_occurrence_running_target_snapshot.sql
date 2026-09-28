-- Running Pace Foundation B2: immutable occurrence-scoped advisory target
-- snapshots frozen atomically by the existing fixed-occurrence start authority.

CREATE TABLE public.programme_occurrence_running_target_snapshots (
  occurrence_id UUID PRIMARY KEY
    REFERENCES public.programme_schedule_occurrences(id) ON DELETE RESTRICT,
  athlete_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  assignment_id UUID NOT NULL
    REFERENCES public.programme_assignments(id) ON DELETE RESTRICT,
  training_session_id BIGINT
    REFERENCES public.training_sessions(id) ON DELETE RESTRICT,
  snapshot JSONB NOT NULL,
  frozen_at TIMESTAMPTZ NOT NULL,
  freeze_source TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_occurrence_running_target_freeze_source_check
    CHECK (freeze_source IN ('in_app_start', 'device_export')),
  CONSTRAINT programme_occurrence_running_target_start_session_check
    CHECK (freeze_source <> 'in_app_start' OR training_session_id IS NOT NULL),
  CONSTRAINT programme_occurrence_running_target_snapshot_shape_check CHECK (
    jsonb_typeof(snapshot) = 'object'
    AND snapshot ?& ARRAY[
      'schema_version', 'authority', 'occurrence_id', 'athlete_id',
      'assignment_id', 'programme_version_id', 'session_slot_id',
      'package_content_hash', 'workout_id', 'frozen_at_utc',
      'freeze_source', 'targets'
    ]::TEXT[]
    AND snapshot - ARRAY[
      'schema_version', 'authority', 'occurrence_id', 'athlete_id',
      'assignment_id', 'programme_version_id', 'session_slot_id',
      'package_content_hash', 'workout_id', 'frozen_at_utc',
      'freeze_source', 'targets'
    ]::TEXT[] = '{}'::JSONB
    AND snapshot->>'schema_version' = '1'
    AND snapshot->>'authority' = 'advisory'
    AND snapshot->>'occurrence_id' = occurrence_id::TEXT
    AND snapshot->>'athlete_id' = athlete_id::TEXT
    AND snapshot->>'assignment_id' = assignment_id::TEXT
    AND snapshot->>'freeze_source' = freeze_source
    AND (snapshot->>'frozen_at_utc')::TIMESTAMPTZ = frozen_at
    AND jsonb_typeof(snapshot->'targets') = 'array'
    AND jsonb_array_length(snapshot->'targets') > 0
  )
);

CREATE UNIQUE INDEX programme_occurrence_running_target_session_unique
  ON public.programme_occurrence_running_target_snapshots(training_session_id)
  WHERE training_session_id IS NOT NULL;

COMMENT ON TABLE public.programme_occurrence_running_target_snapshots IS
  'Insert-once advisory running target aggregate frozen at execution commitment for one occurrence.';

CREATE OR REPLACE FUNCTION public.cohort_reject_running_target_snapshot_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'occurrence running target snapshot is immutable'
    USING ERRCODE = 'integrity_constraint_violation';
END;
$$;

CREATE TRIGGER programme_occurrence_running_target_snapshot_immutable
  BEFORE UPDATE OR DELETE
  ON public.programme_occurrence_running_target_snapshots
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_reject_running_target_snapshot_mutation();

ALTER TABLE public.programme_occurrence_running_target_snapshots
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.programme_occurrence_running_target_snapshots
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.cohort_reject_running_target_snapshot_mutation()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.cohort_build_running_target_snapshot_aggregate(
  p_authored_running JSONB,
  p_occurrence_id UUID,
  p_athlete_id UUID,
  p_assignment_id UUID,
  p_programme_version_id UUID,
  p_session_slot_id UUID,
  p_package_content_hash TEXT,
  p_evaluation_local_date DATE,
  p_iana_timezone TEXT,
  p_frozen_at TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_evidence JSONB;
  v_attachment JSONB;
  v_policy JSONB;
  v_selection JSONB;
  v_benchmark JSONB;
  v_calculation JSONB;
  v_policy_snapshot JSONB;
  v_target JSONB;
  v_targets JSONB := '[]'::JSONB;
  v_reason TEXT;
BEGIN
  IF p_occurrence_id IS NULL
     OR p_athlete_id IS NULL
     OR p_assignment_id IS NULL
     OR p_programme_version_id IS NULL
     OR p_session_slot_id IS NULL
     OR p_evaluation_local_date IS NULL
     OR p_frozen_at IS NULL
     OR length(trim(COALESCE(p_package_content_hash, ''))) = 0
     OR NOT public.cohort_authored_running_v1_is_valid(p_authored_running) THEN
    RAISE EXCEPTION 'invalid authored running snapshot authority'
      USING ERRCODE = 'integrity_constraint_violation';
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
    SELECT revision.*
    FROM public.running_5k_benchmark_evidence_revisions revision
    WHERE revision.evidence_id = e.evidence_id
    ORDER BY revision.revision_number DESC
    LIMIT 1
  ) r ON TRUE
  WHERE e.athlete_id = p_athlete_id
    AND e.source_kind = 'manual';

  FOR v_attachment IN
    SELECT value
    FROM jsonb_array_elements(p_authored_running->'advisory_attachments')
  LOOP
    v_policy := v_attachment->'policy';
    v_policy_snapshot := jsonb_build_object(
      'policy_id', v_policy->>'policy_id',
      'policy_version', (v_policy->>'policy_version')::INT,
      'method_id', v_policy->>'method_id',
      'method_version', (v_policy->>'method_version')::INT,
      'minimum_speed_basis_points',
        (v_policy->>'minimum_speed_basis_points')::INT,
      'maximum_speed_basis_points',
        (v_policy->>'maximum_speed_basis_points')::INT,
      'display_rounding', v_policy->'display_rounding'
    );
    v_selection := public.cohort_select_running_5k_benchmark(
      v_evidence,
      v_policy,
      p_athlete_id::TEXT,
      p_evaluation_local_date,
      p_iana_timezone
    );

    v_target := jsonb_build_object(
      'schema_version', 1,
      'authority', 'advisory',
      'attachment_id', v_attachment->>'attachment_id',
      'scope', jsonb_build_object(
        'workout_id', p_authored_running->>'workout_id',
        'step_ids', v_attachment->'step_ids'
      ),
      'frozen_at_utc', to_jsonb(p_frozen_at),
      'freeze_source', 'in_app_start',
      'policy', v_policy_snapshot
    );

    IF v_selection->>'status' = 'success' THEN
      SELECT candidate INTO STRICT v_benchmark
      FROM jsonb_array_elements(v_evidence) AS items(candidate)
      WHERE candidate->>'evidence_id' = v_selection->>'selected_evidence_id';
      v_calculation := public.cohort_calculate_running_pace_range(
        (v_benchmark->>'elapsed_duration_milliseconds')::BIGINT,
        (v_policy->>'minimum_speed_basis_points')::INT,
        (v_policy->>'maximum_speed_basis_points')::INT,
        (v_policy#>>'{display_rounding,increment_milliseconds_per_kilometre}')::BIGINT,
        v_policy#>>'{display_rounding,direction}'
      );
      IF v_calculation->>'status' IS DISTINCT FROM 'success' THEN
        RAISE EXCEPTION 'running target calculation failed: %', v_calculation
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      v_target := v_target || jsonb_build_object(
        'state', 'calculated',
        'benchmark', v_benchmark || jsonb_build_object(
          'duration_basis', 'elapsed_including_pauses'
        ),
        'calculated_exact_range', jsonb_build_object(
          'unit', 'milliseconds_per_kilometre',
          'faster', jsonb_build_object(
            'numerator', v_calculation#>'{faster_pace,numerator_milliseconds_per_kilometre}',
            'denominator', v_calculation#>'{faster_pace,denominator}'
          ),
          'slower', jsonb_build_object(
            'numerator', v_calculation#>'{slower_pace,numerator_milliseconds_per_kilometre}',
            'denominator', v_calculation#>'{slower_pace,denominator}'
          )
        )
      );
    ELSE
      v_reason := CASE v_selection->>'code'
        WHEN 'noEvidence' THEN 'no_evidence'
        WHEN 'duplicateEvidenceIdentity' THEN 'duplicate_evidence_identity'
        WHEN 'noAthleteScopedEvidence' THEN 'no_athlete_scoped_evidence'
        WHEN 'noTimezoneMatchedEvidence' THEN 'no_timezone_matched_evidence'
        WHEN 'noEligibleCompletedTest' THEN 'no_eligible_completed_test'
        WHEN 'noFreshEvidence' THEN 'no_fresh_evidence'
        ELSE NULL
      END;
      IF v_reason IS NULL THEN
        RAISE EXCEPTION 'running benchmark selection failed: %', v_selection
          USING ERRCODE = 'integrity_constraint_violation';
      END IF;
      v_target := v_target || jsonb_build_object(
        'state', 'intent_only',
        'reason', v_reason
      );
    END IF;
    v_targets := v_targets || jsonb_build_array(v_target);
  END LOOP;

  RETURN jsonb_build_object(
    'schema_version', 1,
    'authority', 'advisory',
    'occurrence_id', p_occurrence_id,
    'athlete_id', p_athlete_id,
    'assignment_id', p_assignment_id,
    'programme_version_id', p_programme_version_id,
    'session_slot_id', p_session_slot_id,
    'package_content_hash', p_package_content_hash,
    'workout_id', p_authored_running->>'workout_id',
    'frozen_at_utc', to_jsonb(p_frozen_at),
    'freeze_source', 'in_app_start',
    'targets', v_targets
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_build_running_target_snapshot_aggregate(
  JSONB, UUID, UUID, UUID, UUID, UUID, TEXT, DATE, TEXT, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(
  p_occurrence_id UUID,
  p_now TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete UUID := auth.uid();
  v_occ public.programme_schedule_occurrences%ROWTYPE;
  v_assignment public.programme_assignments%ROWTYPE;
  v_version public.programme_versions%ROWTYPE;
  v_outcome public.programme_slot_outcomes%ROWTYPE;
  v_session public.training_sessions%ROWTYPE;
  v_snapshot_row public.programme_occurrence_running_target_snapshots%ROWTYPE;
  v_authored RECORD;
  v_today DATE;
  v_expected_key TEXT;
  v_outcome_found BOOLEAN := FALSE;
  v_participates BOOLEAN := FALSE;
  v_frozen_at TIMESTAMPTZ;
  v_snapshot JSONB;
  v_response JSONB;
BEGIN
  IF v_athlete IS NULL OR NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'authentication_required'
    );
  END IF;
  IF p_occurrence_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_occurrence_id'
    );
  END IF;

  PERFORM pg_advisory_xact_lock(84202408, hashtext(p_occurrence_id::TEXT));

  SELECT * INTO v_occ
  FROM public.programme_schedule_occurrences
  WHERE id = p_occurrence_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'occurrence_missing'
    );
  END IF;

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = v_occ.assignment_id
  FOR UPDATE;
  IF NOT FOUND OR v_assignment.athlete_id IS DISTINCT FROM v_athlete THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'cross_athlete_occurrence'
    );
  END IF;
  IF v_assignment.status IS DISTINCT FROM 'active'
     OR v_assignment.materialised_at IS NULL
     OR v_assignment.schedule_mode IS DISTINCT FROM 'fixed_schedule'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'fixed_assignment_ineligible'
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_timezone_names WHERE name = v_assignment.timezone
  ) THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_unavailable'
    );
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = v_assignment.programme_version_id
    AND lifecycle_status = 'published'
    AND archived_at IS NULL
    AND package_content_hash = v_assignment.materialised_package_content_hash;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'exact_version_missing'
    );
  END IF;

  SELECT
    w.version_id,
    w.week_number,
    d.day_key,
    s.session_order,
    s.protocol_id,
    s.authored_running_v1,
    p.lifecycle_status,
    p.archived_at
  INTO v_authored
  FROM public.programme_version_session_slots s
  JOIN public.programme_version_days d ON d.id = s.day_id
  JOIN public.programme_version_weeks w ON w.id = d.week_id
  JOIN public.performance_protocols p ON p.protocol_id = s.protocol_id
  WHERE s.id = v_occ.session_slot_id;

  v_expected_key := public.cohort_programme_schedule_programmed_session_key(
    v_occ.assignment_id,
    v_occ.programme_version_id,
    v_occ.week_number,
    v_occ.day_key,
    v_occ.session_order,
    v_occ.protocol_id
  );
  IF v_authored.version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_authored.week_number IS DISTINCT FROM v_occ.week_number
     OR v_authored.day_key IS DISTINCT FROM v_occ.day_key
     OR v_authored.session_order IS DISTINCT FROM v_occ.session_order
     OR v_authored.protocol_id IS DISTINCT FROM v_occ.protocol_id
     OR v_authored.lifecycle_status IS DISTINCT FROM 'published'
     OR v_authored.archived_at IS NOT NULL
     OR v_occ.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
     OR v_occ.package_content_hash IS DISTINCT FROM v_assignment.materialised_package_content_hash
     OR v_occ.programmed_session_key IS DISTINCT FROM v_expected_key
  THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', 'occurrence_lineage_mismatch'
    );
  END IF;

  v_participates := v_version.package_schema_version = 2
    AND v_authored.authored_running_v1 IS NOT NULL;
  IF v_participates
     AND NOT public.cohort_authored_running_v1_is_valid(
       v_authored.authored_running_v1
     ) THEN
    RETURN jsonb_build_object(
      'status', 'integrity_failure',
      'code', 'authored_running_authority_invalid'
    );
  END IF;

  SELECT * INTO v_outcome
  FROM public.programme_slot_outcomes
  WHERE assignment_id = v_occ.assignment_id
    AND session_slot_id = v_occ.session_slot_id
  FOR UPDATE;
  v_outcome_found := FOUND;

  IF v_outcome_found
     AND v_outcome.training_session_id IS NOT NULL
  THEN
    SELECT * INTO v_session
    FROM public.training_sessions
    WHERE id = v_outcome.training_session_id
    FOR UPDATE;
    IF NOT FOUND
       OR v_outcome.outcome_status IS DISTINCT FROM 'in_progress'
       OR v_session.athlete_id IS DISTINCT FROM v_athlete::TEXT
       OR v_session.status IS DISTINCT FROM 'in_progress'
       OR v_session.protocol_id IS DISTINCT FROM v_occ.protocol_id
       OR v_session.programme_id NOT IN (
         v_assignment.lineage_code,
         v_assignment.programme_version_id::TEXT
       )
       OR v_session.week_number IS DISTINCT FROM v_occ.week_number
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'occurrence_session_integrity_failure'
      );
    END IF;
    v_response := jsonb_build_object(
      'status', 'resumed',
      'code', 'existing_session',
      'training_session', to_jsonb(v_session) || jsonb_build_object('day', v_occ.day_key),
      'occurrence_id', v_occ.id,
      'original_scheduled_date', v_occ.original_scheduled_date,
      'programmed_session_key', v_occ.programmed_session_key
    );
    IF NOT v_participates THEN
      RETURN v_response;
    END IF;
    SELECT * INTO v_snapshot_row
    FROM public.programme_occurrence_running_target_snapshots
    WHERE occurrence_id = v_occ.id
    FOR UPDATE;
    IF NOT FOUND
       OR v_snapshot_row.athlete_id IS DISTINCT FROM v_athlete
       OR v_snapshot_row.assignment_id IS DISTINCT FROM v_occ.assignment_id
       OR v_snapshot_row.training_session_id IS DISTINCT FROM v_session.id THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'occurrence_target_snapshot_integrity_failure'
      );
    END IF;
    RETURN v_response || jsonb_build_object(
      'running_target_snapshot', v_snapshot_row.snapshot
    );
  END IF;

  IF v_outcome_found
     AND v_outcome.outcome_status IN ('completed', 'completed_partial')
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'completed_occurrence'
    );
  END IF;
  IF v_outcome_found AND v_outcome.outcome_status = 'skipped' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_skipped'
    );
  END IF;
  IF v_outcome_found AND v_outcome.outcome_status = 'in_progress' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_session_integrity_failure'
    );
  END IF;
  IF v_participates AND EXISTS (
    SELECT 1
    FROM public.programme_occurrence_running_target_snapshots snapshot
    WHERE snapshot.occurrence_id = v_occ.id
  ) THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'orphan_occurrence_target_snapshot'
    );
  END IF;

  v_today := (p_now AT TIME ZONE v_assignment.timezone)::DATE;
  IF v_occ.disposition = 'completed' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'completed_occurrence'
    );
  END IF;
  IF v_occ.disposition = 'skipped' THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'occurrence_skipped'
    );
  END IF;
  IF v_occ.disposition IS DISTINCT FROM 'scheduled'
     AND v_occ.disposition IS DISTINCT FROM 'missed'
  THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'fixed_occurrence_ineligible'
    );
  END IF;
  IF v_occ.scheduled_date > v_today THEN
    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'future_occurrence'
    );
  END IF;

  IF v_occ.disposition = 'missed' THEN
    PERFORM set_config('cohort.allow_schedule_write', 'on', true);
    UPDATE public.programme_schedule_occurrences
    SET disposition = 'scheduled',
        updated_at = NOW()
    WHERE id = v_occ.id
      AND disposition = 'missed';
    v_occ.disposition := 'scheduled';
  END IF;

  INSERT INTO public.training_sessions (
    athlete_id,
    protocol_id,
    programme_id,
    week_number,
    status,
    started_at,
    created_at,
    updated_at
  ) VALUES (
    v_athlete::TEXT,
    v_occ.protocol_id,
    v_assignment.lineage_code,
    v_occ.week_number,
    'in_progress',
    NOW(),
    NOW(),
    NOW()
  )
  RETURNING * INTO v_session;

  IF v_outcome_found THEN
    UPDATE public.programme_slot_outcomes
    SET outcome_status = 'in_progress',
        training_session_id = v_session.id,
        programme_version_id = v_occ.programme_version_id,
        materialised_package_content_hash = v_occ.package_content_hash,
        programmed_session_key = v_occ.programmed_session_key,
        resolved_at = NULL
    WHERE id = v_outcome.id;
  ELSE
    INSERT INTO public.programme_slot_outcomes (
      assignment_id,
      session_slot_id,
      week_number,
      day_key,
      session_order,
      outcome_status,
      training_session_id,
      programme_version_id,
      materialised_package_content_hash,
      programmed_session_key
    ) VALUES (
      v_occ.assignment_id,
      v_occ.session_slot_id,
      v_occ.week_number,
      v_occ.day_key,
      v_occ.session_order,
      'in_progress',
      v_session.id,
      v_occ.programme_version_id,
      v_occ.package_content_hash,
      v_occ.programmed_session_key
    );
  END IF;

  v_response := jsonb_build_object(
    'status', 'created',
    'code', 'session_created',
    'training_session', to_jsonb(v_session) || jsonb_build_object('day', v_occ.day_key),
    'occurrence_id', v_occ.id,
    'original_scheduled_date', v_occ.original_scheduled_date,
    'programmed_session_key', v_occ.programmed_session_key
  );
  IF NOT v_participates THEN
    RETURN v_response;
  END IF;

  v_frozen_at := transaction_timestamp();
  v_snapshot := public.cohort_build_running_target_snapshot_aggregate(
    v_authored.authored_running_v1,
    v_occ.id,
    v_athlete,
    v_occ.assignment_id,
    v_occ.programme_version_id,
    v_occ.session_slot_id,
    v_occ.package_content_hash,
    v_today,
    v_assignment.timezone,
    v_frozen_at
  );
  INSERT INTO public.programme_occurrence_running_target_snapshots (
    occurrence_id,
    athlete_id,
    assignment_id,
    training_session_id,
    snapshot,
    frozen_at,
    freeze_source
  ) VALUES (
    v_occ.id,
    v_athlete,
    v_occ.assignment_id,
    v_session.id,
    v_snapshot,
    v_frozen_at,
    'in_app_start'
  );

  RETURN v_response || jsonb_build_object(
    'running_target_snapshot', v_snapshot
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(
  UUID, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated, service_role;
