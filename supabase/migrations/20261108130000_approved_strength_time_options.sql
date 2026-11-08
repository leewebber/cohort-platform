-- Future-only private v2 strength time options. Existing publications and grants are unchanged.
CREATE TABLE public.programme_strength_time_approvals (
  version_id uuid PRIMARY KEY REFERENCES public.programme_publication_artifacts(programme_version_id) ON DELETE RESTRICT,
  package_hash text NOT NULL CHECK (package_hash ~ '^[0-9a-f]{64}$'),
  scope_seal_hash text NOT NULL CHECK (scope_seal_hash ~ '^[0-9a-f]{64}$'),
  approval jsonb NOT NULL
);
ALTER TABLE public.programme_strength_time_approvals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.programme_strength_time_approvals FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER programme_strength_time_approval_immutable
  BEFORE UPDATE OR DELETE ON public.programme_strength_time_approvals
  FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();

CREATE FUNCTION public.publish_private_strength_time_option_v1(p_payload jsonb, p_approval jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  vid uuid;
  hash text := p_payload->>'package_content_hash';
  protocol text := p_approval->>'protocol_id';
  prior public.programme_strength_time_approvals%ROWTYPE;
  session_entry jsonb := p_payload#>'{sessions,0}';
  graph jsonb := p_payload#>'{protocol_graphs,0}';
  blocks jsonb := graph->'blocks';
  slot jsonb;
  result jsonb;
  full_seconds integer;
  short_seconds integer;
  seal_hash text;
BEGIN
  IF p_payload->>'package_schema_version' IS DISTINCT FROM '2'
     OR p_payload->>'library_scope' IS DISTINCT FROM 'coach_private'
     OR p_payload->'adaptation_permissions' IS DISTINCT FROM '[]'::jsonb
     OR coalesce(hash, '') !~ '^[0-9a-f]{64}$'
     OR coalesce(p_payload->>'programme_version_id', '') !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
     OR jsonb_typeof(p_approval) IS DISTINCT FROM 'object'
     OR NOT (p_approval ?& ARRAY['permission_key','slot_key','protocol_id','session_intent',
                                  'full_minutes','short_minutes','omitted_block_position'])
     OR p_approval - ARRAY['permission_key','slot_key','protocol_id','session_intent',
                            'full_minutes','short_minutes','omitted_block_position'] <> '{}'::jsonb
     OR coalesce(p_approval->>'permission_key', '') !~ '^[a-z0-9][a-z0-9_-]{0,63}$'
     OR coalesce(btrim(p_approval->>'slot_key'), '') = ''
     OR p_approval->>'session_intent' IS DISTINCT FROM 'upper_body_strength'
     OR jsonb_typeof(p_approval->'full_minutes') IS DISTINCT FROM 'number'
     OR jsonb_typeof(p_approval->'short_minutes') IS DISTINCT FROM 'number'
     OR p_approval->>'full_minutes' !~ '^[1-9][0-9]{0,2}$'
     OR p_approval->>'short_minutes' !~ '^[1-9][0-9]{0,2}$'
     OR p_approval->'omitted_block_position' IS DISTINCT FROM '3'::jsonb THEN
    RAISE EXCEPTION 'invalid strength time approval envelope' USING ERRCODE = '22023';
  END IF;

  vid := (p_payload->>'programme_version_id')::uuid;
  PERFORM pg_advisory_xact_lock(hashtextextended('tracking-publication:' || vid::text, 0));
  SELECT * INTO prior FROM public.programme_strength_time_approvals WHERE version_id = vid;
  IF FOUND THEN
    IF prior.package_hash IS DISTINCT FROM hash OR prior.approval IS DISTINCT FROM p_approval THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'immutable_time_approval_conflict');
    END IF;
    RETURN public.publish_private_exact_programme_version_retained_v1(p_payload);
  END IF;
  IF EXISTS (SELECT 1 FROM public.programme_versions WHERE id = vid) THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'existing_version_without_time_approval');
  END IF;

  IF jsonb_array_length(p_payload->'sessions') IS DISTINCT FROM 1
     OR jsonb_array_length(p_payload->'protocol_graphs') IS DISTINCT FROM 1
     OR session_entry->>'protocol_id' IS DISTINCT FROM protocol
     OR graph->>'protocol_id' IS DISTINCT FROM protocol
     OR jsonb_array_length(blocks) IS DISTINCT FROM 3
     OR blocks#>'{0,position}' IS DISTINCT FROM '1'::jsonb
     OR blocks#>'{1,position}' IS DISTINCT FROM '2'::jsonb
     OR blocks#>'{2,position}' IS DISTINCT FROM '3'::jsonb
     OR blocks#>>'{0,block_type}' IS DISTINCT FROM 'warm_up'
     OR blocks#>>'{0,workout_format}' IS DISTINCT FROM 'steady_state'
     OR blocks#>>'{0,performance_capture_mode}' IS DISTINCT FROM 'completion'
     OR blocks#>>'{1,block_type}' IS DISTINCT FROM 'strength'
     OR blocks#>>'{2,block_type}' IS DISTINCT FROM 'accessory'
     OR EXISTS (
       SELECT FROM jsonb_array_elements(blocks) WITH ORDINALITY b(value,n)
       WHERE (n > 1 AND (value->>'workout_format' IS DISTINCT FROM 'other'
                     OR value->>'performance_capture_mode' IS DISTINCT FROM 'strength'))
          OR (value->'timer_config') - 'duration_seconds'::text IS DISTINCT FROM '{}'::jsonb
          OR jsonb_typeof(value#>'{timer_config,duration_seconds}') IS DISTINCT FROM 'number'
          OR coalesce(value#>>'{timer_config,duration_seconds}', '') !~ '^[1-9][0-9]{0,4}$'
          OR jsonb_array_length(value->'exercises') IS DISTINCT FROM 1
          OR NOT EXISTS (SELECT 1 FROM public.exercises_v2 e
                         WHERE e.exercise_id = value#>>'{exercises,0,exercise_id}' AND e.published)
     ) THEN
    RAISE EXCEPTION 'unsupported strength time graph' USING ERRCODE = '22023';
  END IF;
  SELECT s INTO STRICT slot FROM jsonb_array_elements(p_payload->'weeks') w
    CROSS JOIN LATERAL jsonb_array_elements(w->'days') d
    CROSS JOIN LATERAL jsonb_array_elements(d->'slots') s;
  short_seconds := (blocks#>>'{0,timer_config,duration_seconds}')::integer
                 + (blocks#>>'{1,timer_config,duration_seconds}')::integer;
  full_seconds := short_seconds + (blocks#>>'{2,timer_config,duration_seconds}')::integer;
  IF slot->>'slot_key' IS DISTINCT FROM p_approval->>'slot_key'
     OR slot->>'session_key' IS DISTINCT FROM session_entry->>'session_key'
     OR short_seconds <> (p_approval->>'short_minutes')::integer * 60
     OR full_seconds <> (p_approval->>'full_minutes')::integer * 60 THEN
    RAISE EXCEPTION 'strength time scope or duration mismatch' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT FROM public.performance_protocols p WHERE p.protocol_id = protocol)
     OR EXISTS (SELECT FROM public.session_lineages l WHERE l.id = (session_entry->>'session_lineage_id')::uuid)
     OR EXISTS (SELECT FROM public.programme_lineages l WHERE l.code = p_payload#>>'{programme,lineage_code}') THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'existing_time_trial_source_identity');
  END IF;

  result := public.publish_private_exact_programme_version_retained_v1(p_payload);
  IF result->>'status' IS DISTINCT FROM 'published' THEN
    RAISE EXCEPTION 'retained time publication refused: %', result->>'code';
  END IF;
  SELECT s.scope_seal_hash INTO STRICT seal_hash
    FROM public.programme_publication_artifacts s WHERE s.programme_version_id = vid;
  INSERT INTO public.programme_strength_time_approvals(version_id, package_hash, scope_seal_hash, approval)
  VALUES (vid, hash, seal_hash, p_approval);
  RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.publish_private_strength_time_option_v1(jsonb,jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.publish_private_strength_time_option_v1(jsonb,jsonb) TO service_role;

CREATE FUNCTION public.read_my_approved_time_option_v1(
  p_assignment_id uuid, p_version_id uuid, p_occurrence_id uuid, p_slot_key text
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT approved.approval || jsonb_build_object('package_hash', approved.package_hash)
  FROM public.programme_assignments a
  JOIN public.programme_versions v ON v.id = a.programme_version_id
  JOIN public.programme_publication_artifacts seal
    ON seal.programme_version_id = v.id AND seal.package_content_hash = v.package_content_hash
  JOIN public.programme_strength_time_approvals approved
    ON approved.version_id = seal.programme_version_id
    AND approved.package_hash = seal.package_content_hash AND approved.scope_seal_hash = seal.scope_seal_hash
  JOIN public.programme_schedule_occurrences o ON o.assignment_id = a.id
    AND o.programme_version_id = v.id AND o.package_content_hash = approved.package_hash
  JOIN public.programme_version_session_slots slot ON slot.id = o.session_slot_id
    AND slot.protocol_id = o.protocol_id AND slot.package_slot_key = p_slot_key
  WHERE a.id = p_assignment_id AND a.athlete_id = (SELECT auth.uid())
    AND public.cohort_auth_is_athlete()
    AND a.status = 'active' AND a.ended_at IS NULL AND a.schedule_mode = 'fixed_schedule'
    AND a.materialised_at IS NOT NULL AND a.materialised_package_content_hash = approved.package_hash
    AND v.id = p_version_id AND v.lifecycle_status = 'published' AND v.archived_at IS NULL
    AND v.library_scope = 'coach_private' AND v.package_schema_version = 2 AND seal.package_schema_version = 2
    AND o.id = p_occurrence_id AND o.disposition = 'scheduled'
    AND slot.package_slot_key = approved.approval->>'slot_key'
    AND o.protocol_id = approved.approval->>'protocol_id'
    AND public.cohort_tracking_scope_seal(v.id, seal.canonical_text::jsonb) = seal.scope_seal_text::jsonb;
$$;
REVOKE ALL ON FUNCTION public.read_my_approved_time_option_v1(uuid,uuid,uuid,text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.read_my_approved_time_option_v1(uuid,uuid,uuid,text) TO authenticated;
