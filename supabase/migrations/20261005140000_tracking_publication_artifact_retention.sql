-- Future-only publication evidence. Existing publishers, hashes and legacy rows
-- are unchanged. The service-role retained entry point is opt-in and atomic.
CREATE TABLE public.programme_publication_artifacts (
  programme_version_id uuid PRIMARY KEY REFERENCES public.programme_versions(id) ON DELETE RESTRICT,
  package_schema_version integer NOT NULL CHECK (package_schema_version IN (1,2)),
  package_content_hash text NOT NULL CHECK (package_content_hash ~ '^[0-9a-f]{64}$'),
  canonical_text text NOT NULL CHECK (octet_length(canonical_text) <= 1048576),
  scope_seal_text text NOT NULL CHECK (octet_length(scope_seal_text) <= 1048576),
  scope_seal_hash text NOT NULL CHECK (scope_seal_hash ~ '^[0-9a-f]{64}$'),
  compiler_release text NOT NULL DEFAULT 'cohort_plan_package@1.0.0',
  compiler_contract text NOT NULL DEFAULT 'cohort_plan_package.v1-v2.canonical.v1',
  capture_contract text NOT NULL DEFAULT 'tracking.publication.scope.v1',
  captured_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  publisher text NOT NULL DEFAULT 'publish_private_exact_programme_version_retained_v1',
  CHECK (package_content_hash = encode(extensions.digest(convert_to(canonical_text,'UTF8'),'sha256'),'hex')),
  CHECK (scope_seal_hash = encode(extensions.digest(convert_to(scope_seal_text,'UTF8'),'sha256'),'hex'))
);
ALTER TABLE public.programme_publication_artifacts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.programme_publication_artifacts FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.cohort_tracking_artifact_immutable() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN RAISE EXCEPTION 'tracking_publication_artifact_immutable' USING ERRCODE='integrity_constraint_violation'; END $$;
CREATE TRIGGER tracking_artifact_immutable BEFORE UPDATE OR DELETE ON public.programme_publication_artifacts
FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();
REVOKE ALL ON FUNCTION public.cohort_tracking_artifact_immutable() FROM PUBLIC, anon, authenticated, service_role;

-- Compact sorted-key JSON, independent of jsonb's object display ordering.
CREATE FUNCTION public.cohort_tracking_canonical_text(p jsonb) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
SELECT CASE jsonb_typeof(p)
 WHEN 'object' THEN '{'||coalesce((SELECT string_agg(to_jsonb(k)::text||':'||public.cohort_tracking_canonical_text(v),',' ORDER BY k COLLATE "C") FROM jsonb_each(p) e(k,v)),'')||'}'
 WHEN 'array' THEN '['||coalesce((SELECT string_agg(public.cohort_tracking_canonical_text(v),',' ORDER BY n) FROM jsonb_array_elements(p) WITH ORDINALITY e(v,n)),'')||']'
 ELSE p::text END;
$$;
REVOKE ALL ON FUNCTION public.cohort_tracking_canonical_text(jsonb) FROM PUBLIC, anon, authenticated, service_role;

-- Seal attests only the exact referenced revision/block/exercise and slot scope
-- observed by trusted publication. It is NOT the original package hash, proof
-- of performance, or a general immutable protocol archive.
CREATE FUNCTION public.cohort_tracking_scope_seal(p_version uuid, p_package jsonb) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
SELECT jsonb_build_object('schema_version',1,'programme_version_id',p_version,
 'package_hash',v.package_content_hash,
 'sessions',coalesce((SELECT jsonb_agg(jsonb_build_object(
  'session_key',r->>'session_key','protocol_id',p.protocol_id,
  'session_lineage_id',p.session_lineage_id,'revision_number',p.revision_number,
  'blocks',coalesce((SELECT jsonb_agg(jsonb_build_object(
    'block_id',b.block_id,'session_id',b.session_id,'position',b.position,
    'block_type',b.block_type,'title',b.title,'content',b.content,
    'workout_format',b.workout_format,'timer_config',b.timer_config,
    'coach_notes',b.coach_notes,'performance_capture_mode',b.performance_capture_mode,
    'exercises',coalesce((SELECT jsonb_agg(jsonb_build_object('id',e.id,'block_id',e.block_id,'exercise_id',e.exercise_id,'position',e.position,'display_label_override',e.display_label_override,'prescription',e.prescription,'execution_group_key',e.execution_group_key,'execution_group_label',e.execution_group_label,'execution_group_rounds',e.execution_group_rounds) ORDER BY e.position,e.id)
      FROM public.session_block_exercises e WHERE e.block_id=b.block_id),'[]'::jsonb)
  ) ORDER BY b.position,b.block_id) FROM public.session_blocks b WHERE b.session_id=p.protocol_id),'[]'::jsonb)
 ) ORDER BY r->>'session_key') FROM jsonb_array_elements(p_package->'sessions') r
 JOIN public.performance_protocols p ON p.protocol_id=r->>'protocol_id'
  AND p.session_lineage_id::text=r->>'session_lineage_id' AND p.revision_number::text=r->>'revision_number'
  AND p.lifecycle_status IN ('published','archived')),'[]'::jsonb),
 'slots',coalesce((SELECT jsonb_agg(jsonb_build_object(
  'slot_id',s.id,'slot_key',s.package_slot_key,'week_number',w.week_number,
  'day_key',d.day_key,'day_order',d.day_order,'session_order',s.session_order,
  'protocol_id',s.protocol_id,'authored_running_v1',s.authored_running_v1
 ) ORDER BY w.week_number,d.day_order,s.session_order,s.id)
 FROM public.programme_version_session_slots s JOIN public.programme_version_days d ON d.id=s.day_id
 JOIN public.programme_version_weeks w ON w.id=d.week_id WHERE w.version_id=p_version),'[]'::jsonb))
FROM public.programme_versions v WHERE v.id=p_version;
$$;
REVOKE ALL ON FUNCTION public.cohort_tracking_scope_seal(uuid,jsonb) FROM PUBLIC, anon, authenticated, service_role;

-- Pure exact supported body comparison. Original private graph retries compare
-- only selected fields; retention must not silently seal a different body.
CREATE FUNCTION public.cohort_tracking_payload_graphs_match(p_payload jsonb,p_seal jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
DECLARE s jsonb; g jsonb; b jsonb; wanted jsonb; e jsonb; ex jsonb;
BEGIN
 IF jsonb_typeof(p_payload->'protocol_graphs') IS DISTINCT FROM 'array' THEN RETURN false; END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(p_seal->'sessions') LOOP
  IF (SELECT count(*) FROM jsonb_array_elements(p_payload->'protocol_graphs') x WHERE x->>'protocol_id'=s->>'protocol_id')<>1 THEN RETURN false; END IF;
  SELECT x INTO g FROM jsonb_array_elements(p_payload->'protocol_graphs') x WHERE x->>'protocol_id'=s->>'protocol_id';
  IF jsonb_typeof(g->'blocks') IS DISTINCT FROM 'array' OR jsonb_array_length(g->'blocks')<>jsonb_array_length(s->'blocks') THEN RETURN false; END IF;
  FOR b IN SELECT value FROM jsonb_array_elements(s->'blocks') LOOP
   IF (SELECT count(*) FROM jsonb_array_elements(g->'blocks') x WHERE x->>'position'=b->>'position')<>1 THEN RETURN false; END IF;
   SELECT x INTO wanted FROM jsonb_array_elements(g->'blocks') x WHERE x->>'position'=b->>'position';
   IF b->>'title' IS DISTINCT FROM btrim(wanted->>'title') OR b->>'block_type' IS DISTINCT FROM btrim(wanted->>'block_type')
    OR b->>'content' IS DISTINCT FROM coalesce(wanted->>'content','')
    OR b->>'workout_format' IS DISTINCT FROM coalesce(nullif(btrim(wanted->>'workout_format'),''),'none')
    OR b->'timer_config' IS DISTINCT FROM coalesce(wanted->'timer_config','null'::jsonb)
    OR b->>'coach_notes' IS DISTINCT FROM nullif(btrim(wanted->>'coach_notes'),'')
    OR b->>'performance_capture_mode' IS DISTINCT FROM coalesce(nullif(btrim(wanted->>'performance_capture_mode'),''),'auto')
    OR jsonb_array_length(b->'exercises')<>jsonb_array_length(coalesce(wanted->'exercises','[]'::jsonb)) THEN RETURN false; END IF;
   FOR e IN SELECT value FROM jsonb_array_elements(b->'exercises') LOOP
    IF (SELECT count(*) FROM jsonb_array_elements(coalesce(wanted->'exercises','[]'::jsonb)) x WHERE x->>'position'=e->>'position')<>1 THEN RETURN false; END IF;
    SELECT x INTO ex FROM jsonb_array_elements(coalesce(wanted->'exercises','[]'::jsonb)) x WHERE x->>'position'=e->>'position';
    IF e->>'exercise_id' IS DISTINCT FROM btrim(ex->>'exercise_id')
     OR e->>'display_label_override' IS DISTINCT FROM nullif(btrim(ex->>'display_label_override'),'')
     OR e->'prescription' IS DISTINCT FROM coalesce(ex->'prescription','null'::jsonb)
     OR e->>'execution_group_key' IS DISTINCT FROM nullif(btrim(ex->>'execution_group_key'),'')
     OR e->>'execution_group_label' IS DISTINCT FROM (CASE WHEN nullif(btrim(ex->>'execution_group_key'),'') IS NULL THEN NULL ELSE nullif(btrim(ex->>'execution_group_label'),'') END)
     OR e->>'execution_group_rounds' IS DISTINCT FROM (CASE WHEN nullif(btrim(ex->>'execution_group_key'),'') IS NULL THEN NULL ELSE ex->>'execution_group_rounds' END) THEN RETURN false; END IF;
   END LOOP;
  END LOOP;
 END LOOP;
 RETURN true;
EXCEPTION WHEN others THEN RETURN false;
END $$;
REVOKE ALL ON FUNCTION public.cohort_tracking_payload_graphs_match(jsonb,jsonb) FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION public.publish_private_exact_programme_version_retained_v1(payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
 c jsonb; txt text; hash text; result jsonb; vid uuid; seal jsonb; seal_txt text;
 old public.programme_publication_artifacts%ROWTYPE;
BEGIN
 txt:=payload->>'package_canonical_json'; hash:=payload->>'package_content_hash';
 IF txt IS NULL OR octet_length(txt)>1048576 OR hash IS NULL OR hash !~ '^[0-9a-f]{64}$' THEN
  RETURN jsonb_build_object('status','validation_failure','code','canonical_attestation_required'); END IF;
 BEGIN c:=txt::jsonb; EXCEPTION WHEN invalid_text_representation THEN
  RETURN jsonb_build_object('status','validation_failure','code','invalid_canonical_json'); END;
 IF coalesce(c->>'package_schema_version','') NOT IN ('1','2') OR jsonb_typeof(c) IS DISTINCT FROM 'object'
  OR txt IS DISTINCT FROM public.cohort_tracking_canonical_text(c)
  OR hash IS DISTINCT FROM encode(extensions.digest(convert_to(txt,'UTF8'),'sha256'),'hex')
  OR payload->'package_schema_version' IS DISTINCT FROM c->'package_schema_version'
  OR payload->'programme' IS DISTINCT FROM ((c->'programme')-'library_scope'-'owner_type')
  OR payload->>'library_scope' IS DISTINCT FROM c#>>'{programme,library_scope}'
  OR c#>>'{programme,owner_type}' IS DISTINCT FROM 'coach'
  OR EXISTS(SELECT 1 FROM unnest(ARRAY['sessions','phases','weeks','adaptation_permissions','protected_invariants','assessments','performance_evidence_requirements','comparison_identities']) k
    WHERE jsonb_typeof(c->k) IS DISTINCT FROM 'array' OR payload->k IS DISTINCT FROM c->k)
  OR EXISTS(SELECT 1 FROM jsonb_object_keys(c) k WHERE k NOT IN ('package_schema_version','programme','sessions','phases','weeks','adaptation_permissions','protected_invariants','assessments','performance_evidence_requirements','comparison_identities')) THEN
  RETURN jsonb_build_object('status','validation_failure','code','canonical_hash_mismatch'); END IF;
 -- Serialize only publication of this exact version; no athlete writes/locks.
 BEGIN vid:=(payload->>'programme_version_id')::uuid; EXCEPTION WHEN invalid_text_representation THEN
  RETURN jsonb_build_object('status','validation_failure','code','invalid_identity'); END;
 IF vid IS NULL THEN RETURN jsonb_build_object('status','validation_failure','code','invalid_identity'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('tracking-publication:'||vid::text,0));
 SELECT * INTO old FROM public.programme_publication_artifacts WHERE programme_version_id=vid;
 IF FOUND AND (old.canonical_text IS DISTINCT FROM txt OR old.package_content_hash IS DISTINCT FROM hash OR NOT public.cohort_tracking_payload_graphs_match(payload,old.scope_seal_text::jsonb)) THEN
  RETURN jsonb_build_object('status','conflict','code','immutable_version_conflict','programme_version_id',vid); END IF;
 -- Roll back any partially unsuccessful original publication, without changing
 -- its returned validation/retry outcomes or redefining the original functions.
 BEGIN
  IF c->>'package_schema_version'='2' THEN result:=public.publish_private_exact_programme_version_v2(payload);
  ELSE result:=public.publish_private_exact_programme_version(payload); END IF;
  IF result->>'status' NOT IN ('published','already_published') THEN RAISE EXCEPTION 'tracking_original_publication_failed' USING ERRCODE='PT001'; END IF;
 EXCEPTION WHEN SQLSTATE 'PT001' THEN RETURN result; END;
 IF result->>'status'='already_published' THEN RETURN result || jsonb_build_object('package_schema_version',(c->>'package_schema_version')::integer); END IF; -- Never backfill legacy retries.
 IF NOT public.cohort_authored_plan_package_graph_matches(vid,payload) THEN
  RAISE EXCEPTION 'tracking_publication_graph_mismatch'; END IF;
 seal:=public.cohort_tracking_scope_seal(vid,c);
 IF seal IS NULL OR jsonb_array_length(seal->'sessions')<>jsonb_array_length(c->'sessions')
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(seal->'sessions') s WHERE jsonb_array_length(s->'blocks')=0) THEN
  RAISE EXCEPTION 'tracking_publication_scope_unproven'; END IF;
 IF NOT public.cohort_tracking_payload_graphs_match(payload,seal) THEN RAISE EXCEPTION 'tracking_publication_body_conflict'; END IF;
 seal_txt:=public.cohort_tracking_canonical_text(seal);
 IF octet_length(seal_txt)>1048576 THEN RAISE EXCEPTION 'tracking_publication_evidence_limit_exceeded'; END IF;
 INSERT INTO public.programme_publication_artifacts(programme_version_id,package_schema_version,package_content_hash,canonical_text,scope_seal_text,scope_seal_hash)
 VALUES(vid,(c->>'package_schema_version')::integer,hash,txt,seal_txt,encode(extensions.digest(convert_to(seal_txt,'UTF8'),'sha256'),'hex'));
 RETURN result || jsonb_build_object('package_schema_version',(c->>'package_schema_version')::integer);
END $$;
REVOKE ALL ON FUNCTION public.publish_private_exact_programme_version_retained_v1(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_private_exact_programme_version_retained_v1(jsonb) TO service_role;
