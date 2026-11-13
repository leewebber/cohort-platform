-- One private Recovery trial. Neither Time nor generic adaptation can issue
-- or read this approval. No row is created by this migration.
CREATE TABLE public.programme_strength_recovery_approvals (
  version_id uuid PRIMARY KEY REFERENCES public.programme_publication_artifacts(programme_version_id) ON DELETE RESTRICT
    CHECK (version_id = '7e1d15e7-20ee-46d4-b5e9-0d6449010330'),
  slot_id uuid NOT NULL,
  occurrence_id uuid NOT NULL,
  scope jsonb NOT NULL
);
ALTER TABLE public.programme_strength_recovery_approvals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.programme_strength_recovery_approvals FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER programme_strength_recovery_approval_immutable
  BEFORE UPDATE OR DELETE ON public.programme_strength_recovery_approvals
  FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();

-- Internal scope shared by the trusted issuer and authenticated reader. The
-- athlete's current civil day is server-derived; no caller-supplied clock.
CREATE FUNCTION public.cohort_private_strength_recovery_scope_v1(
  p_version_id uuid, p_assignment_id uuid, p_slot_id uuid, p_occurrence_id uuid, p_now timestamptz
)
RETURNS jsonb LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object(
    'athlete_id', a.athlete_id, 'assignment_id', a.id, 'scheduled_date', o.scheduled_date,
    'package_hash', seal.package_content_hash, 'scope_seal_hash', seal.scope_seal_hash,
    'protocol_id', o.protocol_id, 'slot_key', s.package_slot_key,
    'session_title', coalesce(nullif(btrim(s.display_title), ''), btrim(v.name)),
    'programme_name', v.name, 'duration_min', p.duration_min, 'coach_notes', p.coaching_notes,
    'blocks', sealed.blocks,
    'permission_key', 'm33-poor-sleep-optional-lateral-raises',
    'session_intent', 'upper_body_strength', 'full_minutes', 45, 'short_minutes', 30,
    'omitted_block_position', 3,
    'omitted_block_id', sealed.blocks#>>'{2,block_id}'
  )
  FROM public.programme_schedule_occurrences o
  JOIN public.programme_assignments a ON a.id = o.assignment_id AND a.programme_version_id = o.programme_version_id
  JOIN public.programme_versions v ON v.id = a.programme_version_id
  JOIN public.programme_publication_artifacts seal ON seal.programme_version_id = v.id
    AND seal.package_content_hash = v.package_content_hash AND seal.package_schema_version = 2
  JOIN public.programme_version_session_slots s ON s.id = o.session_slot_id AND s.protocol_id = o.protocol_id
  JOIN public.performance_protocols p ON p.protocol_id = o.protocol_id
  JOIN pg_timezone_names tz ON tz.name = a.timezone
  CROSS JOIN LATERAL (SELECT seal.scope_seal_text::jsonb#>'{sessions,0,blocks}' AS blocks) sealed
  WHERE v.id = '7e1d15e7-20ee-46d4-b5e9-0d6449010330'
    AND v.id = p_version_id AND a.id = p_assignment_id
    AND s.id = p_slot_id AND o.id = p_occurrence_id
    AND v.lifecycle_status = 'published' AND v.archived_at IS NULL
    AND v.library_scope = 'coach_private' AND v.package_schema_version = 2
    AND seal.publisher = 'publish_private_exact_programme_version_retained_v1'
    AND seal.package_content_hash = 'f7a402a26fd4738cc6b1cc99add4c20a87ce1087b934ab197220a3c05379faed'
    AND a.status = 'active' AND a.ended_at IS NULL AND a.schedule_mode = 'fixed_schedule'
    AND a.materialised_at IS NOT NULL AND a.materialised_package_content_hash = seal.package_content_hash
    AND o.package_content_hash = seal.package_content_hash AND o.disposition = 'scheduled'
    AND o.scheduled_date = (p_now AT TIME ZONE tz.name)::date
    AND NOT EXISTS (
      SELECT FROM public.programme_slot_outcomes x
      WHERE x.assignment_id = a.id AND x.session_slot_id = s.id
        AND (x.training_session_id IS NOT NULL OR x.outcome_status <> 'scheduled')
    )
    AND s.package_slot_key = 'M33-W01-D01-STRENGTH'
    AND p.protocol_id = 'protocol-7e1d15e7-20ee-46d4-b5e9-0d6449010334'
    AND p.lifecycle_status = 'published'
    AND jsonb_array_length(seal.scope_seal_text::jsonb->'slots') = 1
    AND jsonb_array_length(seal.scope_seal_text::jsonb->'sessions') = 1
    AND seal.scope_seal_text::jsonb#>>'{slots,0,slot_id}' = s.id::text
    AND seal.scope_seal_text::jsonb#>>'{sessions,0,protocol_id}' = p.protocol_id
    AND public.cohort_tracking_scope_seal(v.id, seal.canonical_text::jsonb) = seal.scope_seal_text::jsonb;
$$;
REVOKE ALL ON FUNCTION public.cohort_private_strength_recovery_scope_v1(uuid,uuid,uuid,uuid,timestamptz) FROM PUBLIC, anon, authenticated, service_role;

-- The occurrence is materialised after publication. Only the trusted role may
-- attach the approval, after retained publication and acquisition. It takes
-- explicit identity pins but no caller-authored prescription or policy.
CREATE FUNCTION public.approve_private_strength_recovery_option_v1(
  p_version_id uuid, p_athlete_id uuid, p_assignment_id uuid, p_slot_id uuid,
  p_occurrence_id uuid, p_scheduled_date date, p_scope_seal_hash text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  candidate jsonb;
  prior public.programme_strength_recovery_approvals%ROWTYPE;
  request_scope jsonb := jsonb_build_object(
    'athlete_id', p_athlete_id, 'assignment_id', p_assignment_id,
    'scheduled_date', p_scheduled_date, 'scope_seal_hash', p_scope_seal_hash
  );
BEGIN
  IF p_version_id IS DISTINCT FROM '7e1d15e7-20ee-46d4-b5e9-0d6449010330'::uuid
    OR p_athlete_id IS NULL OR p_assignment_id IS NULL OR p_slot_id IS NULL
    OR p_occurrence_id IS NULL OR p_scheduled_date IS NULL
    OR coalesce(p_scope_seal_hash, '') !~ '^[0-9a-f]{64}$' THEN
    RETURN 'scope_mismatch';
  END IF;
  IF current_setting('transaction_isolation') <> 'read committed' THEN
    RETURN 'unavailable';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('tracking-publication:' || p_version_id::text, 0));
  SELECT * INTO prior FROM public.programme_strength_recovery_approvals WHERE version_id = p_version_id;
  IF FOUND THEN
    -- A receipt for the original write. The reader still checks live scope.
    RETURN CASE WHEN prior.slot_id = p_slot_id AND prior.occurrence_id = p_occurrence_id
      AND prior.scope @> request_scope THEN 'already_approved' ELSE 'approval_conflict' END;
  END IF;

  -- Start, end and schedule changes serialize here. Read the occurrence and
  -- outcome in a new statement after the lock without locking the occurrence:
  -- the start RPC takes the occurrence lock before the assignment lock.
  PERFORM 1 FROM public.programme_assignments
  WHERE id = p_assignment_id AND athlete_id = p_athlete_id
    AND programme_version_id = p_version_id FOR UPDATE;
  IF NOT FOUND THEN RETURN 'scope_mismatch'; END IF;

  candidate := public.cohort_private_strength_recovery_scope_v1(
    p_version_id, p_assignment_id, p_slot_id, p_occurrence_id, clock_timestamp()
  );
  IF candidate IS NULL OR NOT (candidate @> request_scope) OR NOT public.cohort_tracking_payload_graphs_match(
    '{"protocol_graphs":[{"protocol_id":"protocol-7e1d15e7-20ee-46d4-b5e9-0d6449010334","blocks":[
      {"position":1,"block_type":"warm_up","title":"Preparation","content":"Five minutes of easy walking to warm up.","workout_format":"steady_state","performance_capture_mode":"completion","timer_config":{"duration_seconds":300},"exercises":[{"position":1,"exercise_id":"EX-008","display_label_override":"Walking"}]},
      {"position":2,"block_type":"strength","title":"Bench press","content":"Four working sets of eight. Keep 120 seconds of rest between sets.","workout_format":"other","performance_capture_mode":"strength","timer_config":{"duration_seconds":1500},"exercises":[{"position":1,"exercise_id":"EX-083","display_label_override":"Barbell bench press","prescription":{"sets":4,"reps":{"type":"exact","exact_reps":8},"rest_seconds":120,"load":{"type":"athleteSelected"}}}]},
      {"position":3,"block_type":"accessory","title":"Optional upper-body accessories","content":"Dumbbell lateral raise, three sets of 12 with 60 seconds of rest.","workout_format":"other","performance_capture_mode":"strength","timer_config":{"duration_seconds":900},"exercises":[{"position":1,"exercise_id":"EX-044","display_label_override":"Dumbbell lateral raise","prescription":{"sets":3,"reps":{"type":"exact","exact_reps":12},"rest_seconds":60,"load":{"type":"athleteSelected"}}}]}
    ]}]}'::jsonb,
    jsonb_build_object('sessions', jsonb_build_array(
      jsonb_build_object('protocol_id', candidate->>'protocol_id', 'blocks', candidate->'blocks')
    ))
  ) THEN
    RETURN 'scope_mismatch';
  END IF;

  INSERT INTO public.programme_strength_recovery_approvals(version_id, slot_id, occurrence_id, scope)
  VALUES (p_version_id, p_slot_id, p_occurrence_id, candidate);
  RETURN 'approved';
END;
$$;
REVOKE ALL ON FUNCTION public.approve_private_strength_recovery_option_v1(uuid,uuid,uuid,uuid,uuid,date,text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_private_strength_recovery_option_v1(uuid,uuid,uuid,uuid,uuid,date,text) TO service_role;

CREATE FUNCTION public.read_my_approved_recovery_option_v1(
  p_assignment_id uuid, p_version_id uuid, p_slot_id uuid, p_occurrence_id uuid, p_protocol_id text
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT approval.scope || jsonb_build_object(
    'version_id', approval.version_id, 'slot_id', approval.slot_id, 'occurrence_id', approval.occurrence_id
  )
  FROM public.programme_strength_recovery_approvals approval
  WHERE approval.version_id = p_version_id AND approval.slot_id = p_slot_id
    AND approval.occurrence_id = p_occurrence_id
    AND approval.scope->>'athlete_id' = (SELECT auth.uid())::text
    AND public.cohort_auth_is_athlete()
    AND approval.scope->>'assignment_id' = p_assignment_id::text
    AND approval.scope->>'protocol_id' = p_protocol_id
    AND approval.scope = public.cohort_private_strength_recovery_scope_v1(
      approval.version_id, (approval.scope->>'assignment_id')::uuid,
      approval.slot_id, approval.occurrence_id, statement_timestamp()
    );
$$;
REVOKE ALL ON FUNCTION public.read_my_approved_recovery_option_v1(uuid,uuid,uuid,uuid,text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.read_my_approved_recovery_option_v1(uuid,uuid,uuid,uuid,text) TO authenticated;
