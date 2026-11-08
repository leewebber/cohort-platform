-- Future-only. One reviewed strength substitution per private v2 version.
CREATE TABLE public.programme_equipment_substitution_approvals (
  version_id uuid PRIMARY KEY REFERENCES public.programme_publication_artifacts(programme_version_id)
    DEFERRABLE INITIALLY DEFERRED,
  package_hash text NOT NULL CHECK (package_hash ~ '^[0-9a-f]{64}$'),
  approval jsonb NOT NULL,
  source_label text NOT NULL,
  replacement_label text NOT NULL,
  permission jsonb NOT NULL
);

ALTER TABLE public.programme_equipment_substitution_approvals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.programme_equipment_substitution_approvals
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER programme_equipment_substitution_approval_immutable
  BEFORE UPDATE OR DELETE ON public.programme_equipment_substitution_approvals
  FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();

-- The existing retained writer checks canonical child rows after the private
-- writer publishes. Materialise the staged canonical permission before that
-- transition, while its normal immutable-content guard still allows insertion.
CREATE FUNCTION public.cohort_seed_approved_equipment_permission()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE approved public.programme_equipment_substitution_approvals%ROWTYPE;
BEGIN
  SELECT * INTO approved FROM public.programme_equipment_substitution_approvals
    WHERE version_id = NEW.id;
  IF FOUND THEN
    IF OLD.package_schema_version IS DISTINCT FROM 2
       OR OLD.library_scope IS DISTINCT FROM 'coach_private'
       OR OLD.package_content_hash IS DISTINCT FROM approved.package_hash THEN
      RAISE EXCEPTION 'equipment approval publication pin mismatch';
    END IF;
    INSERT INTO public.programme_version_adaptation_permissions (
      version_id, permission_key, change_kind, target_ref, athlete_agreement_required, scope_note
    ) VALUES (
      OLD.id, approved.permission->>'id', 'substitute_approved_equipment',
      approved.permission->>'target_ref', true, approved.permission->>'scope_note'
    );
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.cohort_seed_approved_equipment_permission()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER programme_versions_seed_approved_equipment_permission
  BEFORE UPDATE OF lifecycle_status ON public.programme_versions FOR EACH ROW
  WHEN (OLD.lifecycle_status = 'draft' AND NEW.lifecycle_status = 'published')
  EXECUTE FUNCTION public.cohort_seed_approved_equipment_permission();

CREATE FUNCTION public.publish_private_equipment_substitution_v1(
  p_payload jsonb, p_approval jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  vid uuid;
  hash text := p_payload->>'package_content_hash';
  prior public.programme_equipment_substitution_approvals%ROWTYPE;
  permission jsonb := p_payload#>'{adaptation_permissions,0}';
  slot jsonb;
  exercise jsonb;
  source_name text;
  replacement_name text;
  rx jsonb := p_approval->'prescription';
  reps jsonb := rx->'reps';
  capture jsonb := rx->'performance_capture';
  bounds jsonb;
  result jsonb;
BEGIN
  IF p_payload->>'package_schema_version' IS DISTINCT FROM '2'
     OR p_payload->>'library_scope' IS DISTINCT FROM 'coach_private'
     OR coalesce(hash, '') !~ '^[0-9a-f]{64}$'
     OR coalesce(p_payload->>'programme_version_id', '') !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
     OR jsonb_typeof(p_approval) IS DISTINCT FROM 'object'
     OR octet_length(p_approval::text) > 8192 THEN
    RAISE EXCEPTION 'invalid equipment approval envelope' USING ERRCODE = '22023';
  END IF;
  vid := (p_payload->>'programme_version_id')::uuid;
  -- Share the retained publisher lock, including exact/conflicting retries.
  PERFORM pg_advisory_xact_lock(hashtextextended('tracking-publication:' || vid::text, 0));
  SELECT * INTO prior FROM public.programme_equipment_substitution_approvals WHERE version_id = vid;
  IF FOUND THEN
    IF prior.approval IS DISTINCT FROM p_approval OR prior.package_hash IS DISTINCT FROM hash THEN
      RETURN jsonb_build_object('status', 'conflict', 'code', 'immutable_equipment_approval_conflict');
    END IF;
    RETURN public.publish_private_exact_programme_version_retained_v1(p_payload);
  END IF;
  IF EXISTS (SELECT 1 FROM public.programme_versions WHERE id = vid) THEN
    RETURN jsonb_build_object('status', 'conflict', 'code', 'existing_version_without_equipment_approval');
  END IF;

  IF NOT (p_approval ?& ARRAY['slot_key','protocol_id','source_occurrence_id','block_position',
        'exercise_position','source_exercise_id','replacement_exercise_id','missing_equipment',
        'required_equipment','matching_dumbbell_pair','explanation','prescription'])
     OR p_approval - ARRAY['slot_key','protocol_id','source_occurrence_id','block_position',
        'exercise_position','source_exercise_id','replacement_exercise_id','missing_equipment',
        'required_equipment','matching_dumbbell_pair','explanation','prescription'] <> '{}'::jsonb
     OR jsonb_typeof(p_approval->'matching_dumbbell_pair') IS DISTINCT FROM 'boolean'
     OR coalesce(p_approval->>'block_position','') !~ '^[1-9][0-9]{0,3}$'
     OR coalesce(p_approval->>'exercise_position','') !~ '^[1-9][0-9]{0,3}$'
     OR coalesce(p_approval->>'missing_equipment','') !~ '^cohort[.]equipment[.][a-z0-9_]+$'
     OR coalesce(p_approval->>'required_equipment','') !~ '^cohort[.]equipment[.][a-z0-9_]+$'
     OR p_approval->>'missing_equipment' = p_approval->>'required_equipment'
     OR p_approval->>'required_equipment' = 'cohort.equipment.bodyweight'
     OR coalesce(btrim(p_approval->>'explanation'),'') = ''
     OR coalesce(btrim(p_approval->>'source_occurrence_id'),'') = ''
     OR p_approval->>'source_exercise_id' = p_approval->>'replacement_exercise_id'
     OR (p_approval->'matching_dumbbell_pair' = 'true'::jsonb
         AND p_approval->>'required_equipment' <> 'cohort.equipment.dumbbell') THEN
    RAISE EXCEPTION 'invalid equipment approval fields' USING ERRCODE = '22023';
  END IF;

  -- This first reusable prescription contract is bilateral, external load,
  -- athlete-selected kg. No fixed loads, per-side doses or legacy carryover.
  IF jsonb_typeof(rx) IS DISTINCT FROM 'object'
     OR NOT (rx ?& ARRAY['sets','reps','rir_range','rest_seconds_range','tempo','coach_cue','load','performance_capture'])
     OR rx - ARRAY['sets','reps','rir_range','rest_seconds_range','tempo','coach_cue','load','performance_capture'] <> '{}'::jsonb
     OR rx->'load' IS DISTINCT FROM '{"type":"athleteSelected"}'::jsonb
     OR jsonb_typeof(rx->'sets') IS DISTINCT FROM 'number'
     OR rx->>'sets' !~ '^[1-9][0-9]?$'
     OR coalesce(btrim(rx->>'tempo'),'') = '' OR coalesce(btrim(rx->>'coach_cue'),'') = ''
     OR jsonb_typeof(reps) IS DISTINCT FROM 'object'
     OR reps->>'type' IS DISTINCT FROM 'range'
     OR reps - ARRAY['type','min_reps','max_reps'] <> '{}'::jsonb
     OR jsonb_typeof(reps->'min_reps') IS DISTINCT FROM 'number'
     OR jsonb_typeof(reps->'max_reps') IS DISTINCT FROM 'number'
     OR reps->>'min_reps' !~ '^[1-9][0-9]?$' OR reps->>'max_reps' !~ '^[1-9][0-9]?$'
     OR jsonb_typeof(capture) IS DISTINCT FROM 'object'
     OR capture - ARRAY['load_unit','load_label','duration_optional'] <> '{}'::jsonb
     OR capture->>'load_unit' IS DISTINCT FROM 'kg'
     OR capture->>'load_label' IS DISTINCT FROM (CASE
       WHEN p_approval->'matching_dumbbell_pair' = 'true'::jsonb THEN 'kg per dumbbell' ELSE 'Load (kg)' END)
     OR coalesce(capture->'duration_optional','false'::jsonb) <> 'false'::jsonb THEN
    RAISE EXCEPTION 'invalid equipment approval prescription' USING ERRCODE = '22023';
  END IF;
  IF (reps->>'min_reps')::int > (reps->>'max_reps')::int THEN
    RAISE EXCEPTION 'reversed equipment rep range' USING ERRCODE = '22023';
  END IF;
  FOREACH bounds IN ARRAY ARRAY[rx->'rir_range',rx->'rest_seconds_range'] LOOP
    IF jsonb_typeof(bounds) IS DISTINCT FROM 'array' THEN
      RAISE EXCEPTION 'invalid equipment prescription range' USING ERRCODE = '22023';
    END IF;
    IF jsonb_array_length(bounds) <> 2 OR jsonb_typeof(bounds->0) IS DISTINCT FROM 'number'
       OR jsonb_typeof(bounds->1) IS DISTINCT FROM 'number'
       OR bounds->>0 !~ '^[0-9]{1,4}$' OR bounds->>1 !~ '^[0-9]{1,4}$' THEN
      RAISE EXCEPTION 'invalid equipment prescription range' USING ERRCODE = '22023';
    END IF;
    IF (bounds->>0)::int > (bounds->>1)::int THEN
      RAISE EXCEPTION 'reversed equipment prescription range' USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF jsonb_typeof(p_payload->'adaptation_permissions') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'canonical equipment permission required' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_payload->'adaptation_permissions') <> 1
     OR coalesce(btrim(permission->>'id'),'') = ''
     OR permission->>'change_kind' IS DISTINCT FROM 'substitute_approved_equipment'
     OR permission->'athlete_agreement_required' IS DISTINCT FROM 'true'::jsonb
     OR coalesce(btrim(p_approval->>'slot_key'),'') = ''
     OR permission->>'target_ref' IS DISTINCT FROM p_approval->>'slot_key' THEN
    RAISE EXCEPTION 'canonical equipment permission mismatch' USING ERRCODE = '22023';
  END IF;
  SELECT s INTO STRICT slot FROM jsonb_array_elements(p_payload->'weeks') w
  CROSS JOIN LATERAL jsonb_array_elements(w->'days') d
  CROSS JOIN LATERAL jsonb_array_elements(d->'slots') s
  WHERE s->>'slot_key' = p_approval->>'slot_key';
  PERFORM 1 FROM jsonb_array_elements(p_payload->'sessions') s
  WHERE s->>'session_key' = slot->>'session_key' AND s->>'protocol_id' = p_approval->>'protocol_id';
  IF NOT FOUND THEN RAISE EXCEPTION 'equipment approval slot protocol mismatch'; END IF;
  SELECT e INTO STRICT exercise
  FROM jsonb_array_elements(p_payload->'protocol_graphs') g
  CROSS JOIN LATERAL jsonb_array_elements(g->'blocks') b
  CROSS JOIN LATERAL jsonb_array_elements(b->'exercises') e
  WHERE g->>'protocol_id' = p_approval->>'protocol_id'
    AND b->'position' = p_approval->'block_position' AND b->>'block_type' IN ('strength','accessory')
    AND e->'position' = p_approval->'exercise_position'
    AND e->>'exercise_id' = p_approval->>'source_exercise_id'
    AND e#>>'{prescription,authored_details,source_occurrence_id}' = p_approval->>'source_occurrence_id';
  SELECT name INTO STRICT source_name FROM public.exercises_v2
    WHERE exercise_id = p_approval->>'source_exercise_id' AND published;
  SELECT name INTO STRICT replacement_name FROM public.exercises_v2
    WHERE exercise_id = p_approval->>'replacement_exercise_id' AND published;

  INSERT INTO public.programme_equipment_substitution_approvals
    (version_id, package_hash, approval, source_label, replacement_label, permission)
  VALUES (vid, hash, p_approval, coalesce(nullif(btrim(exercise->>'display_label_override'),''),source_name),
          replacement_name, permission);
  result := public.publish_private_exact_programme_version_retained_v1(p_payload);
  IF result->>'status' IS DISTINCT FROM 'published' THEN
    RAISE EXCEPTION 'retained equipment publication refused: %', result->>'code';
  END IF;
  -- The FK requires a retained artifact at transaction commit. The existing
  -- retained writer checks the permission and exact persisted graph first.
  RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.publish_private_equipment_substitution_v1(jsonb,jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.publish_private_equipment_substitution_v1(jsonb,jsonb) TO service_role;

CREATE FUNCTION public.read_my_approved_equipment_substitution_v1(
  p_assignment_id uuid, p_version_id uuid, p_occurrence_id uuid, p_slot_key text
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT approval.approval || jsonb_build_object(
    'package_hash', approval.package_hash, 'source_label', approval.source_label,
    'replacement_label', approval.replacement_label, 'permission_key', perm.permission_key
  )
  FROM public.programme_assignments a
  JOIN public.programme_versions v ON v.id = a.programme_version_id
  JOIN public.programme_publication_artifacts seal
    ON seal.programme_version_id = v.id AND seal.package_content_hash = v.package_content_hash
  JOIN public.programme_equipment_substitution_approvals approval
    ON approval.version_id = seal.programme_version_id AND approval.package_hash = seal.package_content_hash
  JOIN public.programme_schedule_occurrences o
    ON o.assignment_id = a.id AND o.programme_version_id = v.id
    AND o.package_content_hash = approval.package_hash
  JOIN public.programme_version_session_slots slot
    ON slot.id = o.session_slot_id AND slot.protocol_id = o.protocol_id AND slot.package_slot_key = p_slot_key
  JOIN public.programme_version_adaptation_permissions perm
    ON perm.version_id = v.id AND perm.target_ref = slot.package_slot_key
    AND perm.permission_key = approval.permission->>'id'
  WHERE a.id = p_assignment_id AND a.athlete_id = (SELECT auth.uid())
    AND a.status = 'active' AND a.ended_at IS NULL AND a.schedule_mode = 'fixed_schedule'
    AND a.materialised_at IS NOT NULL AND a.materialised_package_content_hash = approval.package_hash
    AND v.id = p_version_id AND v.lifecycle_status = 'published' AND v.library_scope = 'coach_private'
    AND v.package_schema_version = 2 AND seal.package_schema_version = 2
    AND o.id = p_occurrence_id AND o.disposition = 'scheduled'
    AND slot.package_slot_key = approval.approval->>'slot_key'
    AND o.protocol_id = approval.approval->>'protocol_id'
    AND perm.change_kind = 'substitute_approved_equipment' AND perm.athlete_agreement_required;
$$;
REVOKE ALL ON FUNCTION public.read_my_approved_equipment_substitution_v1(uuid,uuid,uuid,text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.read_my_approved_equipment_substitution_v1(uuid,uuid,uuid,text) TO authenticated;

-- Prevent the legacy private writer from consuming a version ID declared for
-- an equipment approval without the matching staged approval. Other payloads,
-- the writer's identity and its existing authority remain unchanged.
DO $migration$
DECLARE
  original text;
  anchor constant text := '  v_imported_by := nullif(trim(COALESCE(payload->>''imported_by'', '''')), '''');';
  guard constant text := $guard$
  IF v_scope = 'coach_private' AND payload->>'package_schema_version' = '2'
     AND jsonb_path_exists(payload, '$.adaptation_permissions[*] ? (@.change_kind == "substitute_approved_equipment")')
     AND NOT EXISTS (
       SELECT 1 FROM public.programme_equipment_substitution_approvals a
       WHERE a.version_id = v_version_id AND a.package_hash = v_hash
         AND payload->'adaptation_permissions' = jsonb_build_array(a.permission)
     ) THEN
    RETURN jsonb_build_object('status', 'validation_failure', 'code', 'sealed_equipment_approval_required');
  END IF;

$guard$;
BEGIN
  PERFORM set_config('search_path', 'pg_catalog, pg_temp', true);
  original := pg_get_functiondef('public.publish_private_exact_programme_version(jsonb)'::regprocedure);
  IF encode(extensions.digest(convert_to(original, 'UTF8'), 'sha256'), 'hex')
      IS DISTINCT FROM 'b1370b16a2579397a41566e655c5c236f8e36592e451f3e10e3854f56eb4e6f8'
     OR length(original) - length(replace(original, anchor, '')) <> length(anchor) THEN
    RAISE EXCEPTION 'private publication baseline differs from reviewed source';
  END IF;
  EXECUTE replace(original, anchor, guard || anchor);
END;
$migration$;
