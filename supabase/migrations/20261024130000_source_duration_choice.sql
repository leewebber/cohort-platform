-- Additive source-preserving squat rest and immutable duration-choice start.
BEGIN;
CREATE OR REPLACE FUNCTION public.cohort_v3_validate(c jsonb) RETURNS jsonb
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
       OR ((b#>'{exercises,0,prescription}')-'rest_seconds_range') IS DISTINCT FROM expected
       OR ((b#>'{exercises,0,prescription}') ? 'rest_seconds_range' AND b#>'{exercises,0,prescription,rest_seconds_range}' IS DISTINCT FROM '[150,180]'::jsonb) THEN RAISE EXCEPTION 'wrong_squat_scope'; END IF;
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

-- Retain the same canonical start path; the existing v3 snapshot is the FK parent.
CREATE TABLE public.programme_occurrence_duration_choices (
 occurrence_id uuid PRIMARY KEY REFERENCES public.programme_occurrence_v3_prescription_snapshots(occurrence_id) ON DELETE RESTRICT,
 athlete_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 training_session_id bigint NOT NULL UNIQUE REFERENCES public.training_sessions(id) ON DELETE RESTRICT,
 snapshot jsonb NOT NULL
);
ALTER TABLE public.programme_occurrence_duration_choices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.programme_occurrence_duration_choices FROM PUBLIC,anon,authenticated,service_role,cohort_exercise_version_publisher;
GRANT SELECT ON public.programme_occurrence_duration_choices TO authenticated;
CREATE POLICY duration_choice_owner ON public.programme_occurrence_duration_choices FOR SELECT TO authenticated
 USING (athlete_id=(SELECT auth.uid()) AND public.cohort_auth_is_athlete());
CREATE TRIGGER duration_choice_immutable BEFORE UPDATE OR DELETE ON public.programme_occurrence_duration_choices
 FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable();

ALTER FUNCTION public.create_or_resume_fixed_programme_occurrence_session(uuid,uuid)
 RENAME TO cohort_fixed_occurrence_before_duration_choice;
REVOKE ALL ON FUNCTION public.cohort_fixed_occurrence_before_duration_choice(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.create_or_resume_fixed_programme_occurrence_session(
 p_occurrence_id uuid,p_consent_id uuid,p_duration_choices jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=public.cohort_base_actor(); response jsonb; bound jsonb; old public.programme_occurrence_duration_choices%ROWTYPE;
 b jsonb; r jsonb; selected jsonb; rows jsonb:='{}'; required_count int:=0; packet jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(84202408,hashtext(p_occurrence_id::text));
 -- The established function owns authentication, occurrence/assignment locking,
 -- source/version/retirement verification, consent, session creation and retry.
 response:=public.cohort_fixed_occurrence_before_duration_choice(p_occurrence_id,p_consent_id);
 bound:=response->'bound_prescription_snapshot';
 IF response->>'status' NOT IN ('created','resumed') THEN
   SELECT * INTO old FROM public.programme_occurrence_duration_choices WHERE occurrence_id=p_occurrence_id AND athlete_id=actor;
   IF FOUND AND bound->>'athlete_id'=actor::text AND bound->>'training_session_id'=old.training_session_id::text THEN
     RETURN response||jsonb_build_object('duration_choice_snapshot',old.snapshot);
   END IF;
   RETURN response;
 END IF;
 IF bound IS NULL OR bound->>'athlete_id' IS DISTINCT FROM actor::text
   OR bound->>'occurrence_id' IS DISTINCT FROM p_occurrence_id::text THEN RAISE EXCEPTION 'duration_choice_scope_mismatch'; END IF;
 SELECT * INTO old FROM public.programme_occurrence_duration_choices WHERE occurrence_id=p_occurrence_id;
 IF FOUND THEN
   IF old.athlete_id<>actor OR old.training_session_id<>(response#>>'{training_session,id}')::bigint THEN RAISE EXCEPTION 'duration_choice_link_mismatch'; END IF;
   -- Exact replay always returns the original choice. A new proposed choice can
   -- neither replace the source range nor rewrite a started prescription.
   RETURN response||jsonb_build_object('duration_choice_snapshot',old.snapshot);
 END IF;
 FOR b IN SELECT value FROM jsonb_array_elements(bound#>'{source,blocks}') LOOP
   IF NOT coalesce(b->'timer_config' ? 'durationRangeSeconds',false) THEN CONTINUE; END IF;
   required_count:=required_count+1; r:=b#>'{timer_config,durationRangeSeconds}';
   IF b->>'workout_format' IS DISTINCT FROM 'steady_state' OR jsonb_typeof(r) IS DISTINCT FROM 'array'
      OR jsonb_array_length(r)<>2 OR NOT public.cohort_v3_positive(r->0) OR NOT public.cohort_v3_positive(r->1)
      OR (r->>0)::int>(r->>1)::int OR b->'timer_config' ? 'durationSeconds' THEN RAISE EXCEPTION 'invalid_authored_duration_window'; END IF;
   selected:=p_duration_choices->(b->>'block_id');
   IF NOT public.cohort_v3_positive(selected) OR (selected#>>'{}')::int NOT BETWEEN (r->>0)::int AND (r->>1)::int THEN
     RAISE EXCEPTION 'explicit_duration_choice_required'; END IF;
   rows:=rows||jsonb_build_object(b->>'block_id',jsonb_build_object('authored_range_seconds',r,'selected_seconds',selected));
 END LOOP;
 IF required_count=0 THEN
   IF p_duration_choices IS NOT NULL AND p_duration_choices<>'{}'::jsonb THEN RAISE EXCEPTION 'unexpected_duration_choice'; END IF;
   RETURN response;
 END IF;
 IF response->>'status'<>'created' THEN RAISE EXCEPTION 'started_duration_snapshot_missing'; END IF;
 IF jsonb_typeof(p_duration_choices) IS DISTINCT FROM 'object' OR
   (SELECT count(*) FROM jsonb_object_keys(p_duration_choices))<>required_count THEN RAISE EXCEPTION 'incomplete_or_foreign_duration_choices'; END IF;
 packet:=jsonb_build_object('schema_version',1,'athlete_id',actor,'protocol_id',bound#>>'{source,protocol_id}',
   'occurrence_id',p_occurrence_id,'assignment_id',bound->'assignment_id','programme_version_id',bound->'programme_version_id',
   'training_session_id',bound->'training_session_id','choices',rows);
 INSERT INTO public.programme_occurrence_duration_choices VALUES(p_occurrence_id,actor,(response#>>'{training_session,id}')::bigint,packet);
 RETURN response||jsonb_build_object('duration_choice_snapshot',packet);
EXCEPTION WHEN invalid_text_representation OR invalid_parameter_value OR raise_exception OR integrity_constraint_violation OR numeric_value_out_of_range THEN
 -- Roll back the delegated session/outcome/v3 snapshot as well as the choice.
 RETURN jsonb_build_object('status','refused','code','duration_choice_unavailable','reason',SQLERRM);
END $$;

CREATE FUNCTION public.create_or_resume_fixed_programme_occurrence_session(p_occurrence_id uuid,p_consent_id uuid)
 RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
 SELECT public.create_or_resume_fixed_programme_occurrence_session(p_occurrence_id,p_consent_id,NULL);
$$;
REVOKE ALL ON FUNCTION public.create_or_resume_fixed_programme_occurrence_session(uuid,uuid,jsonb),
 public.create_or_resume_fixed_programme_occurrence_session(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.create_or_resume_fixed_programme_occurrence_session(uuid,uuid,jsonb),
 public.create_or_resume_fixed_programme_occurrence_session(uuid,uuid) TO authenticated;

-- Prescribed choices are canonical snapshot data, never client-owned actuals.
CREATE FUNCTION public.cohort_duration_record_prescription_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE frozen public.programme_occurrence_duration_choices%ROWTYPE;
BEGIN
 SELECT * INTO frozen FROM public.programme_occurrence_duration_choices WHERE training_session_id=NEW.training_session_id;
 IF FOUND THEN
   IF frozen.athlete_id::text IS DISTINCT FROM NEW.athlete_id OR frozen.snapshot IS DISTINCT FROM NEW.session_snapshot->'durationChoiceV1' THEN
     RAISE EXCEPTION 'authoritative_duration_choice_required' USING ERRCODE='23514';
   END IF;
 ELSIF NEW.session_snapshot ? 'durationChoiceV1' THEN
   RAISE EXCEPTION 'unexpected_duration_choice_snapshot' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.cohort_duration_record_prescription_guard() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_duration_record_prescription BEFORE INSERT OR UPDATE ON public.training_session_records
 FOR EACH ROW EXECUTE FUNCTION public.cohort_duration_record_prescription_guard();
COMMIT;
