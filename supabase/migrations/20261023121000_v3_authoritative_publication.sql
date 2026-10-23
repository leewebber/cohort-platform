-- Strict accepting private v3 publication over existing published sources only.
-- Existing global import and v1/v2 publication entrypoints remain unchanged.
BEGIN;
CREATE FUNCTION public.cohort_v3_hash(d jsonb) RETURNS text LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,pg_temp AS $$
 SELECT encode(extensions.digest(convert_to(public.cohort_tracking_canonical_text(d),'UTF8'),'sha256'),'hex');
$$;
CREATE FUNCTION public.cohort_v3_object(d jsonb, required text[], optional text[] DEFAULT '{}') RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,pg_temp AS $$
 SELECT coalesce(jsonb_typeof(d)='object' AND d ?& required AND d-(required||optional)='{}'::jsonb,false);
$$;
CREATE FUNCTION public.cohort_v3_texts(d jsonb, keys text[]) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,pg_temp AS $$
 SELECT NOT EXISTS(SELECT 1 FROM unnest(keys) k WHERE d ? k AND
   (jsonb_typeof(d->k) IS DISTINCT FROM 'string' OR coalesce(length(btrim(d->>k)),0)=0 OR btrim(d->>k)<>d->>k));
$$;
CREATE FUNCTION public.cohort_v3_positive(d jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,pg_temp AS $$
 SELECT coalesce(jsonb_typeof(d)='number' AND d#>>'{}' ~ '^[1-9][0-9]{0,8}$',false);
$$;

-- Exactly the established retained physical session shape, independently queried.
CREATE FUNCTION public.cohort_v3_session_source(p_ref jsonb) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog,pg_temp AS $$
 SELECT jsonb_build_object('session_key',p_ref->>'session_key','protocol_id',p.protocol_id,
 'session_lineage_id',p.session_lineage_id,'revision_number',p.revision_number,
 'blocks',coalesce((SELECT jsonb_agg(jsonb_build_object(
  'block_id',b.block_id,'session_id',b.session_id,'position',b.position,'block_type',b.block_type,'title',b.title,
  'content',b.content,'workout_format',b.workout_format,'timer_config',b.timer_config,'coach_notes',b.coach_notes,
  'performance_capture_mode',b.performance_capture_mode,'exercises',coalesce((SELECT jsonb_agg(jsonb_build_object(
    'id',e.id,'block_id',e.block_id,'exercise_id',e.exercise_id,'position',e.position,
    'display_label_override',e.display_label_override,'prescription',e.prescription,'execution_group_key',e.execution_group_key,
    'execution_group_label',e.execution_group_label,'execution_group_rounds',e.execution_group_rounds) ORDER BY e.position,e.id)
    FROM public.session_block_exercises e WHERE e.block_id=b.block_id),'[]'::jsonb)
 ) ORDER BY b.position,b.block_id) FROM public.session_blocks b WHERE b.session_id=p.protocol_id),'[]'::jsonb))
 FROM public.performance_protocols p WHERE p.protocol_id=p_ref->>'protocol_id'
 AND p.session_lineage_id::text=p_ref->>'session_lineage_id' AND p.revision_number::text=p_ref->>'revision_number'
 AND p.lifecycle_status='published' AND p.published='true';
$$;

CREATE FUNCTION public.cohort_v3_validate(c jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path=pg_catalog,pg_temp AS $$
DECLARE s jsonb; w jsonb; d jsonb; sl jsonb; t jsonb; ref jsonb; b jsonb; source jsonb; dep public.hyrox_prescription_dependencies%ROWTYPE;
 ex public.published_exercise_definition_versions%ROWTYPE; expected jsonb; targets jsonb; seen text[]:='{}'; scopes text[]:='{}';
 all_slots jsonb:='[]'; sources jsonb:='[]'; dependencies jsonb:='[]'; n integer; previous integer; prior_text text:=''; k text;
BEGIN
 IF NOT public.cohort_v3_object(c,ARRAY['package_schema_version','programme','sessions','phases','weeks','adaptation_permissions',
   'protected_invariants','assessments','performance_evidence_requirements','comparison_identities','personalisation_binding'])
   OR c->>'package_schema_version' IS DISTINCT FROM '3' OR jsonb_typeof(c->'package_schema_version') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'unsupported_v3_shape'; END IF;
 -- Initial accepting scope is deliberately closed. Unsupported authoring features
 -- refuse rather than disappearing from canonical hashes or scope seals.
 FOREACH k IN ARRAY ARRAY['phases','adaptation_permissions','protected_invariants','assessments','performance_evidence_requirements','comparison_identities'] LOOP
   IF c->k IS DISTINCT FROM '[]'::jsonb THEN RAISE EXCEPTION 'unsupported_v3_feature:%',k; END IF;
 END LOOP;
 IF NOT public.cohort_v3_object(c->'programme',ARRAY['lineage_code','version_number','name','library_scope','owner_type','coaching_intent'],
   ARRAY['description','duration_weeks','sessions_per_week','primary_goal'])
   OR NOT public.cohort_v3_positive(c#>'{programme,version_number}') OR c#>>'{programme,owner_type}'<>'coach'
   OR c#>>'{programme,library_scope}' NOT IN ('coach_private','organisation') THEN RAISE EXCEPTION 'invalid_v3_programme'; END IF;
 FOR k IN SELECT jsonb_object_keys(c->'programme') LOOP
   IF k NOT IN ('version_number','duration_weeks','sessions_per_week') AND
      (jsonb_typeof(c#>ARRAY['programme',k])<>'string' OR length(btrim(c#>>ARRAY['programme',k]))=0
      OR btrim(c#>>ARRAY['programme',k])<>c#>>ARRAY['programme',k]) THEN RAISE EXCEPTION 'invalid_programme_field'; END IF;
 END LOOP;
 FOREACH k IN ARRAY ARRAY['duration_weeks','sessions_per_week'] LOOP
   IF c->'programme' ? k AND NOT public.cohort_v3_positive(c#>ARRAY['programme',k]) THEN RAISE EXCEPTION 'invalid_programme_count'; END IF;
 END LOOP;
 IF jsonb_typeof(c->'sessions') IS DISTINCT FROM 'array' OR jsonb_array_length(c->'sessions') NOT BETWEEN 1 AND 64
   OR jsonb_typeof(c->'weeks') IS DISTINCT FROM 'array' OR jsonb_array_length(c->'weeks') NOT BETWEEN 1 AND 8 THEN RAISE EXCEPTION 'invalid_source_limits'; END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(c->'sessions') LOOP
   IF NOT public.cohort_v3_object(s,ARRAY['session_key','protocol_id','session_lineage_id','revision_number','title'])
     OR NOT public.cohort_v3_positive(s->'revision_number') OR s->>'session_key'<=prior_text THEN RAISE EXCEPTION 'invalid_session_reference'; END IF;
   FOREACH k IN ARRAY ARRAY['session_key','protocol_id','title','session_lineage_id'] LOOP
     IF jsonb_typeof(s->k) IS DISTINCT FROM 'string' OR coalesce(length(btrim(s->>k)),0)=0 OR btrim(s->>k)<>s->>k THEN RAISE EXCEPTION 'invalid_session_text'; END IF;
   END LOOP;
   IF (SELECT count(*) FROM jsonb_array_elements(c->'sessions') x WHERE x->>'protocol_id'=s->>'protocol_id')<>1 THEN RAISE EXCEPTION 'ambiguous_protocol_alias'; END IF;
   source:=public.cohort_v3_session_source(s);
   IF source IS NULL OR jsonb_array_length(source->'blocks')=0 THEN RAISE EXCEPTION 'unresolved_published_session'; END IF;
   sources:=sources||jsonb_build_array(source); prior_text:=s->>'session_key';
 END LOOP;
 previous:=0;
 FOR w IN SELECT value FROM jsonb_array_elements(c->'weeks') LOOP
   IF NOT public.cohort_v3_object(w,ARRAY['week_number','days'],ARRAY['title','coach_note'])
     OR NOT public.cohort_v3_texts(w,ARRAY['title','coach_note'])
     OR NOT public.cohort_v3_positive(w->'week_number') OR (w->>'week_number')::int<>previous+1
     OR jsonb_typeof(w->'days') IS DISTINCT FROM 'array' OR jsonb_array_length(w->'days') NOT BETWEEN 1 AND 7 THEN RAISE EXCEPTION 'invalid_week'; END IF;
   previous:=(w->>'week_number')::int; n:=0;
   FOR d IN SELECT value FROM jsonb_array_elements(w->'days') LOOP
     IF NOT public.cohort_v3_object(d,ARRAY['day_key','day_order','day_type','slots'],ARRAY['title','coach_note'])
       OR NOT public.cohort_v3_texts(d,ARRAY['day_key','day_type','title','coach_note'])
       OR NOT public.cohort_v3_positive(d->'day_order') OR (d->>'day_order')::int<>n+1
       OR d->>'day_key' !~ '^[A-Za-z][A-Za-z0-9._:-]*$' OR d->>'day_type' NOT IN ('training','rest')
       OR jsonb_typeof(d->'slots') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid_day'; END IF;
     n:=(d->>'day_order')::int;
     IF (SELECT count(*) FROM jsonb_array_elements(w->'days') x WHERE x->>'day_key'=d->>'day_key')<>1 THEN RAISE EXCEPTION 'duplicate_day'; END IF;
     IF (d->>'day_type'='rest' AND d->'slots'<>'[]') OR (d->>'day_type'='training' AND jsonb_array_length(d->'slots') NOT BETWEEN 1 AND 8) THEN RAISE EXCEPTION 'invalid_day_slots'; END IF;
     IF d->'slots' IS DISTINCT FROM (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'session_order')::int),'[]'::jsonb) FROM jsonb_array_elements(d->'slots') x) THEN RAISE EXCEPTION 'noncanonical_slot_order'; END IF;
     FOR sl IN SELECT value FROM jsonb_array_elements(d->'slots') LOOP
       IF NOT public.cohort_v3_object(sl,ARRAY['slot_key','session_order','session_key','time_of_day','is_optional','completion_expectation','progression'],ARRAY['display_title','coach_note'])
         OR NOT public.cohort_v3_texts(sl,ARRAY['slot_key','session_key','time_of_day','completion_expectation','display_title','coach_note'])
         OR NOT public.cohort_v3_texts(sl->'progression',ARRAY['prescription_summary','volume_note','intensity_note','coach_note'])
         OR NOT public.cohort_v3_positive(sl->'session_order') OR sl->>'slot_key' !~ '^[A-Za-z][A-Za-z0-9._:-]*$'
         OR sl->'is_optional' IS DISTINCT FROM 'false'::jsonb OR sl->>'time_of_day' IS DISTINCT FROM 'any'
         OR sl->>'completion_expectation' IS DISTINCT FROM 'required'
         OR NOT public.cohort_v3_object(sl->'progression',ARRAY['prescription_summary'],ARRAY['volume_note','intensity_note','coach_note'])
         OR coalesce(length(btrim(sl#>>'{progression,prescription_summary}')),0)=0
         OR (SELECT count(*) FROM jsonb_array_elements(c->'sessions') x WHERE x->>'session_key'=sl->>'session_key')<>1
         OR sl->>'slot_key'=ANY(seen) THEN RAISE EXCEPTION 'invalid_slot'; END IF;
       IF (SELECT count(*) FROM jsonb_array_elements(d->'slots') x WHERE (x->>'session_order')::int <= (sl->>'session_order')::int)<>(sl->>'session_order')::int THEN RAISE EXCEPTION 'invalid_slot_order'; END IF;
       seen:=array_append(seen,sl->>'slot_key');
       all_slots:=all_slots||jsonb_build_array(sl||jsonb_build_object('week_number',w->'week_number'));
     END LOOP;
   END LOOP;
 END LOOP;
 IF c->'programme' ? 'duration_weeks' AND (c#>>'{programme,duration_weeks}')::int<>jsonb_array_length(c->'weeks') THEN RAISE EXCEPTION 'duration_mismatch'; END IF;
 IF NOT public.cohort_v3_object(c->'personalisation_binding',ARRAY['binding_schema_version','targets','freshness','replacement_policy','missing_input_policy'])
   OR c#>>'{personalisation_binding,binding_schema_version}' IS DISTINCT FROM '1' OR jsonb_typeof(c#>'{personalisation_binding,binding_schema_version}') IS DISTINCT FROM 'number'
   OR c#>>'{personalisation_binding,freshness}' IS DISTINCT FROM 'none'
   OR c#>>'{personalisation_binding,replacement_policy}' IS DISTINCT FROM 'explicit_consent_future_unstarted_only'
   OR c#>>'{personalisation_binding,missing_input_policy}' IS DISTINCT FROM 'unavailable_with_authored_effort_only'
   OR jsonb_typeof(c#>'{personalisation_binding,targets}') IS DISTINCT FROM 'array'
   OR jsonb_array_length(c#>'{personalisation_binding,targets}') NOT BETWEEN 1 AND 512 THEN RAISE EXCEPTION 'invalid_binding'; END IF;
 targets:=c#>'{personalisation_binding,targets}'; seen:='{}';
 FOR t IN SELECT value FROM jsonb_array_elements(targets) LOOP
   IF NOT public.cohort_v3_object(t,ARRAY['id','slot_key','week_number','session_key','protocol_id','protocol_revision','session_body_sha256',
     'block_id','step_ids','identity_namespace','exercise','benchmark','rule','kind','input_unit','output_unit','parameters'])
     OR t->>'identity_namespace' IS DISTINCT FROM 'canonical_exercise'
     OR NOT public.cohort_v3_positive(t->'week_number') OR (t->>'week_number')::int NOT BETWEEN 1 AND 8
     OR NOT public.cohort_v3_positive(t->'protocol_revision') THEN RAISE EXCEPTION 'invalid_target'; END IF;
   FOREACH k IN ARRAY ARRAY['id','slot_key','session_key','protocol_id','block_id'] LOOP
     IF jsonb_typeof(t->k) IS DISTINCT FROM 'string' OR t->>k !~ (CASE WHEN k='block_id' THEN '^[A-Za-z0-9][A-Za-z0-9._:-]*$' ELSE '^[A-Za-z][A-Za-z0-9._:-]*$' END) THEN RAISE EXCEPTION 'invalid_target_identity'; END IF;
   END LOOP;
   IF t->>'id'=ANY(seen) OR (t->>'slot_key'||'/'||(t->>'block_id'))=ANY(scopes) THEN RAISE EXCEPTION 'duplicate_target'; END IF;
   seen:=array_append(seen,t->>'id'); scopes:=array_append(scopes,t->>'slot_key'||'/'||(t->>'block_id'));
   FOREACH k IN ARRAY ARRAY['exercise','rule','benchmark'] LOOP
     IF NOT public.cohort_v3_object(t->k,ARRAY['id','version','digest']) OR NOT public.cohort_v3_positive(t#>ARRAY[k,'version'])
       OR jsonb_typeof(t#>ARRAY[k,'id']) IS DISTINCT FROM 'string'
       OR jsonb_typeof(t#>ARRAY[k,'digest']) IS DISTINCT FROM 'string' OR t#>>ARRAY[k,'digest'] !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'invalid_reference'; END IF;
   END LOOP;
   SELECT * INTO dep FROM public.hyrox_prescription_dependencies WHERE kind=t->>'kind';
   IF NOT FOUND OR t->'rule'<>jsonb_build_object('id',dep.rule_document->'id','version',1,'digest',public.cohort_v3_hash(dep.rule_document))
     OR t->'benchmark'<>jsonb_build_object('id',dep.benchmark_document->'id','version',1,'digest',public.cohort_v3_hash(dep.benchmark_document))
     OR t->'input_unit'<>dep.rule_document->'input_unit' OR t->'output_unit'<>dep.rule_document->'output_unit' THEN RAISE EXCEPTION 'unsupported_rule_or_units'; END IF;
   expected:=(dep.rule_document->'weeks'->((t->>'week_number')::int-1))-'week';
   IF t->'parameters' IS DISTINCT FROM expected THEN RAISE EXCEPTION 'unapproved_parameters'; END IF;
   FOR k IN SELECT jsonb_object_keys(expected) LOOP
     IF k<>'rir' AND NOT public.cohort_v3_positive(t#>ARRAY['parameters',k]) THEN RAISE EXCEPTION 'noninteger_authored_parameter'; END IF;
   END LOOP;
   SELECT * INTO ex FROM public.published_exercise_definition_versions WHERE exercise_id=t#>>'{exercise,id}'
     AND definition_version=t#>>'{exercise,version}' AND content_digest=t#>>'{exercise,digest}';
   IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.exercises_v2 WHERE exercise_id=ex.exercise_id AND published IS TRUE) OR EXISTS(SELECT 1 FROM public.published_exercise_version_retirements WHERE exercise_id=ex.exercise_id AND definition_version=ex.definition_version) OR NOT (ex.publication->'approved_binding_kinds' ? (t->>'kind')) THEN RAISE EXCEPTION 'unresolved_approved_exercise_version'; END IF;
   IF (SELECT count(*) FROM jsonb_array_elements(all_slots) x WHERE x->>'slot_key'=t->>'slot_key'
     AND x->'week_number'=t->'week_number' AND x->>'session_key'=t->>'session_key')<>1 THEN RAISE EXCEPTION 'wrong_slot'; END IF;
   SELECT x INTO ref FROM jsonb_array_elements(c->'sessions') x WHERE x->>'session_key'=t->>'session_key';
   IF ref->>'protocol_id' IS DISTINCT FROM t->>'protocol_id' OR ref->'revision_number' IS DISTINCT FROM t->'protocol_revision' THEN RAISE EXCEPTION 'wrong_session'; END IF;
   SELECT x INTO source FROM jsonb_array_elements(sources) x WHERE x->>'session_key'=t->>'session_key';
   IF public.cohort_v3_hash(source) IS DISTINCT FROM t->>'session_body_sha256' THEN RAISE EXCEPTION 'source_body_mismatch'; END IF;
   SELECT x INTO b FROM jsonb_array_elements(source->'blocks') x WHERE x->>'block_id'=t->>'block_id';
   IF b IS NULL OR jsonb_array_length(b->'exercises')<>1 OR b#>>'{exercises,0,exercise_id}' IS DISTINCT FROM ex.exercise_id
     OR b#>'{exercises,0,execution_group_key}' IS DISTINCT FROM 'null'::jsonb
     OR b#>'{exercises,0,execution_group_label}' IS DISTINCT FROM 'null'::jsonb OR b#>'{exercises,0,execution_group_rounds}' IS DISTINCT FROM 'null'::jsonb THEN RAISE EXCEPTION 'wrong_exercise_block'; END IF;
   IF t->>'kind'='backSquat' THEN
     IF t->'step_ids' IS DISTINCT FROM '[]'::jsonb OR b->>'block_type' IS DISTINCT FROM 'strength'
       OR b#>'{exercises,0,prescription}' IS DISTINCT FROM expected THEN RAISE EXCEPTION 'wrong_squat_scope'; END IF;
   ELSE
     SELECT jsonb_agg('work-'||i ORDER BY i) INTO expected FROM generate_series(1,(t#>>'{parameters,repetitions}')::int) i;
     IF t->'step_ids' IS DISTINCT FROM expected OR b->>'workout_format' IS DISTINCT FROM 'intervals'
       OR b->>'block_type' IS DISTINCT FROM 'conditioning'
       OR NOT public.cohort_v3_object(b->'timer_config',ARRAY['workSeconds','restSeconds','rounds'],ARRAY['stopwatchEnabled'])
       OR (b->'timer_config' ? 'stopwatchEnabled' AND b#>'{timer_config,stopwatchEnabled}' IS DISTINCT FROM 'false'::jsonb)
       OR b#>'{timer_config,workSeconds}' IS DISTINCT FROM t#>'{parameters,work_seconds}'
       OR b#>'{timer_config,restSeconds}' IS DISTINCT FROM t#>'{parameters,recovery_seconds}'
       OR b#>'{timer_config,rounds}' IS DISTINCT FROM t#>'{parameters,repetitions}' THEN RAISE EXCEPTION 'wrong_dedicated_interval_scope'; END IF;
   END IF;
   dependencies:=dependencies||jsonb_build_array(jsonb_build_object('target_id',t->>'id','exercise',to_jsonb(ex),
     'rule',dep.rule_document,'benchmark',dep.benchmark_document));
 END LOOP;
 RETURN jsonb_build_object('sessions',sources,'dependencies',dependencies);
END $$;

CREATE TABLE public.programme_v3_publication_artifacts (
 programme_version_id uuid PRIMARY KEY REFERENCES public.programme_versions(id) ON DELETE RESTRICT,
 canonical_text text NOT NULL CHECK(octet_length(canonical_text)<=1048576),
 package_hash text NOT NULL CHECK(package_hash=encode(extensions.digest(convert_to(canonical_text,'UTF8'),'sha256'),'hex')),
 resolved_sources jsonb NOT NULL,
 physical_seal jsonb NOT NULL,
 captured_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
ALTER TABLE public.programme_v3_publication_artifacts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.programme_v3_publication_artifacts FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER v3_artifact_immutable BEFORE UPDATE OR DELETE ON public.programme_v3_publication_artifacts
FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();
CREATE TABLE public.cohort_v3_publication_claims(version_id uuid PRIMARY KEY, transaction_id xid8 NOT NULL, package_hash text NOT NULL);
ALTER TABLE public.cohort_v3_publication_claims ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cohort_v3_publication_claims FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.cohort_reject_unresolved_package_version() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE claim public.cohort_v3_publication_claims%ROWTYPE;
BEGIN
 SELECT * INTO claim FROM public.cohort_v3_publication_claims WHERE version_id=NEW.id AND transaction_id=pg_current_xact_id();
 IF FOUND AND NEW.package_schema_version=1 AND NEW.package_content_hash=claim.package_hash THEN NEW.package_schema_version:=3;
 ELSIF NEW.package_schema_version>=3 THEN
   IF NOT FOUND OR NEW.package_schema_version<>3 OR NEW.package_content_hash<>claim.package_hash THEN
     RAISE EXCEPTION 'v3 trusted publication claim required' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;

CREATE FUNCTION public.publish_private_exact_programme_version_v3(payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE c jsonb; txt text; vid uuid; resolved jsonb; seal jsonb; result jsonb; old public.programme_v3_publication_artifacts%ROWTYPE;
BEGIN
 IF NOT public.cohort_v3_object(payload,ARRAY['package_schema_version','programme','sessions','phases','weeks','adaptation_permissions',
   'protected_invariants','assessments','performance_evidence_requirements','comparison_identities','package_canonical_json','package_content_hash',
   'publication_kind','programme_version_id','library_scope','owner_id','imported_by','protocol_graphs'],ARRAY['authorised_timezone','authorised_local_start_date']) THEN
   RAISE EXCEPTION 'invalid_v3_publication_payload'; END IF;
 txt:=payload->>'package_canonical_json'; c:=txt::jsonb; vid:=(payload->>'programme_version_id')::uuid;
 IF txt IS NULL OR octet_length(txt)>1048576 OR vid IS NULL OR txt IS DISTINCT FROM public.cohort_tracking_canonical_text(c)
   OR payload->>'package_content_hash' IS DISTINCT FROM public.cohort_v3_hash(c)
   OR payload->>'package_schema_version' IS DISTINCT FROM '3' OR jsonb_typeof(payload->'package_schema_version') IS DISTINCT FROM 'number'
   OR payload->'programme' IS DISTINCT FROM ((c->'programme')-'owner_type'-'library_scope')
   OR payload->>'library_scope' IS DISTINCT FROM c#>>'{programme,library_scope}'
   OR EXISTS(SELECT 1 FROM unnest(ARRAY['sessions','weeks','phases','adaptation_permissions','protected_invariants','assessments','performance_evidence_requirements','comparison_identities']) k WHERE payload->k IS DISTINCT FROM c->k) THEN
   RAISE EXCEPTION 'v3_canonical_payload_mismatch'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('tracking-publication:'||vid::text,0));
 SELECT * INTO old FROM public.programme_v3_publication_artifacts WHERE programme_version_id=vid;
 IF FOUND THEN
   IF old.canonical_text<>txt OR NOT public.cohort_tracking_payload_graphs_match(payload,old.physical_seal) THEN RAISE EXCEPTION 'immutable_v3_publication_conflict'; END IF;
   -- Preserve the established owner/scope/lifecycle retry checks as well.
   result:=public.publish_private_exact_programme_version(payload);
   IF result->>'status' IS DISTINCT FROM 'already_published' THEN RAISE EXCEPTION 'legacy_publication_retry_refused:%',result; END IF;
   RETURN result||jsonb_build_object('package_schema_version',3);
 END IF;
 resolved:=public.cohort_v3_validate(c);
 INSERT INTO public.cohort_v3_publication_claims VALUES(vid,pg_current_xact_id(),public.cohort_v3_hash(c));
 result:=public.publish_private_exact_programme_version(payload);
 IF result->>'status' IS DISTINCT FROM 'published' THEN RAISE EXCEPTION 'legacy_publication_refused:%',result; END IF;
 seal:=public.cohort_tracking_scope_seal(vid,c);
 IF seal->'sessions' IS DISTINCT FROM resolved->'sessions' OR NOT public.cohort_tracking_payload_graphs_match(payload,seal)
   OR NOT public.cohort_authored_plan_package_graph_matches(vid,payload) THEN RAISE EXCEPTION 'v3_physical_source_conflict'; END IF;
 INSERT INTO public.programme_v3_publication_artifacts VALUES(vid,txt,public.cohort_v3_hash(c),resolved,seal,transaction_timestamp());
 DELETE FROM public.cohort_v3_publication_claims WHERE version_id=vid;
 RETURN result||jsonb_build_object('package_schema_version',3);
EXCEPTION WHEN invalid_parameter_value OR invalid_text_representation OR raise_exception OR integrity_constraint_violation OR numeric_value_out_of_range THEN
 RETURN jsonb_build_object('status','validation_failure','code','v3_admission_refused','reason',SQLERRM);
END $$;

CREATE FUNCTION public.read_v3_publication_dependencies(p_canonical_text text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN RETURN public.cohort_v3_validate(p_canonical_text::jsonb); END $$;

-- Private functions are never general-purpose admission/computation APIs.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN ('cohort_v3_hash','cohort_v3_object','cohort_v3_texts','cohort_v3_positive','cohort_v3_session_source','cohort_v3_validate',
   'publish_private_exact_programme_version_v3','read_v3_publication_dependencies','cohort_reject_unresolved_package_version') LOOP
   EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.signature);
 END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION public.publish_private_exact_programme_version_v3(jsonb),public.read_v3_publication_dependencies(text) TO service_role;
COMMIT;
