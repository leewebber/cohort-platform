-- Programme-scoped server-issued review/consent and existing canonical-start extension.
BEGIN;
CREATE TABLE public.programme_v3_prescription_reviews (
 review_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 athlete_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 assignment_id uuid NOT NULL REFERENCES public.programme_assignments(id) ON DELETE RESTRICT,
 programme_version_id uuid NOT NULL REFERENCES public.programme_versions(id) ON DELETE RESTRICT,
 expected_consent_id uuid,
 selection jsonb NOT NULL,
 increment_grams bigint CHECK(increment_grams BETWEEN 1 AND 1000000000),
 document jsonb NOT NULL,
 issued_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 UNIQUE(review_id,athlete_id,assignment_id,programme_version_id)
);
CREATE TABLE public.programme_v3_prescription_consents (
 consent_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 athlete_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 assignment_id uuid NOT NULL REFERENCES public.programme_assignments(id) ON DELETE RESTRICT,
 programme_version_id uuid NOT NULL REFERENCES public.programme_versions(id) ON DELETE RESTRICT,
 generation bigint NOT NULL CHECK(generation>0),
 previous_consent_id uuid,
 review_id uuid,
 disposition text NOT NULL CHECK(disposition IN ('accepted','withdrawn')),
 command_id uuid NOT NULL UNIQUE,
 request jsonb NOT NULL,
 accepted_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 UNIQUE(consent_id,athlete_id,assignment_id,programme_version_id),
 UNIQUE(assignment_id,generation), UNIQUE(previous_consent_id),
 FOREIGN KEY(previous_consent_id,athlete_id,assignment_id,programme_version_id)
 REFERENCES public.programme_v3_prescription_consents(consent_id,athlete_id,assignment_id,programme_version_id) ON DELETE RESTRICT,
 FOREIGN KEY(review_id,athlete_id,assignment_id,programme_version_id)
 REFERENCES public.programme_v3_prescription_reviews(review_id,athlete_id,assignment_id,programme_version_id) ON DELETE RESTRICT,
 CHECK((generation=1 AND previous_consent_id IS NULL) OR (generation>1 AND previous_consent_id IS NOT NULL)),
 CHECK((disposition='accepted' AND review_id IS NOT NULL) OR (disposition='withdrawn' AND review_id IS NULL))
);
ALTER TABLE public.programme_v3_prescription_reviews ADD CONSTRAINT programme_v3_review_expected_consent_fk
 FOREIGN KEY(expected_consent_id,athlete_id,assignment_id,programme_version_id)
 REFERENCES public.programme_v3_prescription_consents(consent_id,athlete_id,assignment_id,programme_version_id) ON DELETE RESTRICT;
CREATE TABLE public.programme_occurrence_v3_prescription_snapshots (
 occurrence_id uuid PRIMARY KEY REFERENCES public.programme_schedule_occurrences(id) ON DELETE RESTRICT,
 athlete_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 assignment_id uuid NOT NULL REFERENCES public.programme_assignments(id) ON DELETE RESTRICT,
 programme_version_id uuid NOT NULL REFERENCES public.programme_versions(id) ON DELETE RESTRICT,
 training_session_id bigint NOT NULL UNIQUE REFERENCES public.training_sessions(id) ON DELETE RESTRICT,
 consent_id uuid NOT NULL,
 snapshot jsonb NOT NULL,
 frozen_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 FOREIGN KEY(consent_id,athlete_id,assignment_id,programme_version_id)
 REFERENCES public.programme_v3_prescription_consents(consent_id,athlete_id,assignment_id,programme_version_id) ON DELETE RESTRICT
);
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['programme_v3_prescription_reviews','programme_v3_prescription_consents','programme_occurrence_v3_prescription_snapshots'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated,service_role,cohort_exercise_version_publisher',t);
  EXECUTE format('CREATE POLICY v3_owner_read ON public.%I FOR SELECT TO authenticated USING (athlete_id=(SELECT auth.uid()) AND public.cohort_auth_is_athlete())',t);
  EXECUTE format('GRANT SELECT ON public.%I TO authenticated',t);
  EXECUTE format('CREATE TRIGGER v3_immutable BEFORE UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.cohort_tracking_artifact_immutable()',t);
 END LOOP;
END $$;

CREATE FUNCTION public.cohort_v3_review_document(p_assignment uuid,p_actor uuid,p_selection jsonb,p_increment bigint) RETURNS jsonb
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE a public.programme_assignments%ROWTYPE; v public.programme_versions%ROWTYPE; artifact public.programme_v3_publication_artifacts%ROWTYPE;
 c jsonb; resolved jsonb; t jsonb; dep public.hyrox_prescription_dependencies%ROWTYPE; selected public.hyrox_base_benchmark_revisions%ROWTYPE;
 rev uuid; v_metric text; output jsonb:='[]'; calculated jsonb; steps jsonb; n integer;
BEGIN
 SELECT * INTO a FROM public.programme_assignments WHERE id=p_assignment FOR UPDATE;
 IF NOT FOUND OR a.athlete_id<>p_actor OR a.status<>'active' OR a.schedule_mode<>'fixed_schedule' OR a.materialised_at IS NULL THEN
   RAISE EXCEPTION 'owned_materialised_fixed_assignment_required' USING ERRCODE='42501'; END IF;
 SELECT * INTO v FROM public.programme_versions WHERE id=a.programme_version_id FOR SHARE;
 IF v.lifecycle_status<>'published' OR v.archived_at IS NOT NULL OR v.package_schema_version<>3
   OR a.materialised_package_schema_version IS DISTINCT FROM '3' OR a.materialised_package_content_hash<>v.package_content_hash THEN RAISE EXCEPTION 'stale_programme_source'; END IF;
 SELECT * INTO artifact FROM public.programme_v3_publication_artifacts WHERE programme_version_id=v.id;
 IF NOT FOUND OR artifact.package_hash<>v.package_content_hash THEN RAISE EXCEPTION 'unresolved_v3_artifact'; END IF;
 c:=artifact.canonical_text::jsonb;
 -- Source retirement/archive serialises with review/accept/start. Published
 -- definition bodies stay immutable; current catalogue lifecycle is a separate
 -- operational gate and never becomes version authority.
 PERFORM 1 FROM public.performance_protocols p WHERE p.protocol_id IN
   (SELECT x->>'protocol_id' FROM jsonb_array_elements(c->'sessions') x) ORDER BY p.protocol_id FOR SHARE;
 PERFORM 1 FROM public.exercises_v2 e WHERE e.exercise_id IN
   (SELECT x#>>'{exercise,id}' FROM jsonb_array_elements(c#>'{personalisation_binding,targets}') x) ORDER BY e.exercise_id FOR SHARE;
 PERFORM 1 FROM public.published_exercise_definition_versions ev WHERE (ev.exercise_id,ev.definition_version) IN
   (SELECT x#>>'{exercise,id}',x#>>'{exercise,version}' FROM jsonb_array_elements(c#>'{personalisation_binding,targets}') x)
   ORDER BY ev.exercise_id,ev.definition_version FOR SHARE;
 resolved:=public.cohort_v3_validate(c);
 IF resolved<>artifact.resolved_sources OR public.cohort_tracking_scope_seal(v.id,c)<>artifact.physical_seal THEN RAISE EXCEPTION 'stale_source_resolution'; END IF;
 IF NOT public.cohort_v3_object(p_selection,'{}',ARRAY['run10km','row2km','backSquat5rm'])
   OR (p_increment IS NOT NULL AND p_increment NOT BETWEEN 1 AND 1000000000) THEN RAISE EXCEPTION 'invalid_selection_configuration'; END IF;
 -- Same locks as evidence correction. Sorted metric order; assignment always first.
 FOR v_metric IN SELECT x FROM unnest(ARRAY['backSquat5rm','row2km','run10km']) x ORDER BY x LOOP
   PERFORM pg_advisory_xact_lock(84202610,hashtext(p_actor::text||':'||v_metric));
   IF p_selection ? v_metric AND jsonb_typeof(p_selection->v_metric) NOT IN ('null','string') THEN RAISE EXCEPTION 'invalid_selected_revision'; END IF;
   rev:=(p_selection->>v_metric)::uuid;
   IF rev IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.hyrox_base_benchmark_revisions b WHERE b.revision_id=rev
     AND b.athlete_id=p_actor AND b.metric=v_metric) THEN RAISE EXCEPTION 'unresolved_owned_benchmark'; END IF;
 END LOOP;
 FOR t IN SELECT value FROM jsonb_array_elements(c#>'{personalisation_binding,targets}') LOOP
   SELECT * INTO dep FROM public.hyrox_prescription_dependencies WHERE kind=t->>'kind';
   rev:=(p_selection->>dep.metric)::uuid;
   selected:=NULL;
   IF rev IS NOT NULL THEN
     SELECT * INTO selected FROM public.hyrox_base_benchmark_revisions WHERE revision_id=rev AND athlete_id=p_actor AND metric=dep.metric;
     IF NOT FOUND OR EXISTS(SELECT 1 FROM public.hyrox_base_benchmark_revisions WHERE previous_revision_id=rev) THEN RAISE EXCEPTION 'stale_benchmark_revision'; END IF;
   END IF;
   calculated:=public.cohort_base_calculate_v1(t->>'kind',(t#>>'{rule,version}')::int,(t->>'week_number')::int,selected.canonical_value,p_increment);
   steps:='[]';
   IF t->>'kind'<>'backSquat' THEN
     FOR n IN 1..(t#>>'{parameters,repetitions}')::int LOOP
       steps:=steps||jsonb_build_array(jsonb_build_object('step_id','work-'||n,'kind','work','duration_seconds',t#>'{parameters,work_seconds}','target',calculated));
       IF n<(t#>>'{parameters,repetitions}')::int THEN
         steps:=steps||jsonb_build_array(jsonb_build_object('step_id','recovery-'||n,'kind','recovery','duration_seconds',t#>'{parameters,recovery_seconds}','target',NULL));
       END IF;
     END LOOP;
   END IF;
   output:=output||jsonb_build_array(jsonb_build_object('binding',t,'authored',t->'parameters','benchmark_revision',CASE WHEN rev IS NULL THEN NULL ELSE to_jsonb(selected) END,
     'calculated',calculated,'steps',steps,'authored_effort',CASE t->>'kind' WHEN 'runningIntervals' THEN 'approximate RPE 7 / repeatable' WHEN 'backSquat' THEN 'RIR '||(t#>>'{parameters,rir}') ELSE NULL END,'actual',NULL));
 END LOOP;
 RETURN jsonb_build_object('schema_version',1,'athlete_id',p_actor,'assignment_id',a.id,'programme_version_id',v.id,
   'package_hash',v.package_content_hash,'canonical_text',artifact.canonical_text,'resolved_sources',resolved,
   'physical_seal',artifact.physical_seal,'selection',p_selection,'increment_grams',p_increment,'prescriptions',output);
END $$;

CREATE FUNCTION public.review_hyrox_programme_prescription(payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=public.cohort_base_actor(); aid uuid; vid uuid; expected uuid; doc jsonb; result public.programme_v3_prescription_reviews%ROWTYPE;
BEGIN
 IF NOT public.cohort_v3_object(payload,ARRAY['assignment_id','programme_version_id','selected_revisions','increment_grams'])
   OR (jsonb_typeof(payload->'increment_grams') NOT IN ('null','number'))
   OR (jsonb_typeof(payload->'increment_grams')='number' AND NOT public.cohort_v3_positive(payload->'increment_grams')) THEN RAISE EXCEPTION 'invalid_review_payload'; END IF;
 aid:=(payload->>'assignment_id')::uuid; vid:=(payload->>'programme_version_id')::uuid;
 doc:=public.cohort_v3_review_document(aid,actor,payload->'selected_revisions',(payload->>'increment_grams')::bigint);
 IF doc->>'programme_version_id' IS DISTINCT FROM vid::text THEN RAISE EXCEPTION 'wrong_programme_version'; END IF;
 SELECT consent_id INTO expected FROM public.programme_v3_prescription_consents WHERE assignment_id=aid ORDER BY generation DESC LIMIT 1;
 INSERT INTO public.programme_v3_prescription_reviews(athlete_id,assignment_id,programme_version_id,expected_consent_id,selection,increment_grams,document)
 VALUES(actor,aid,vid,expected,payload->'selected_revisions',(payload->>'increment_grams')::bigint,doc) RETURNING * INTO result;
 RETURN jsonb_build_object('status','review','review_id',result.review_id,'expected_consent_id',expected,'document',doc);
EXCEPTION WHEN invalid_text_representation OR invalid_parameter_value OR raise_exception OR numeric_value_out_of_range THEN
 RETURN jsonb_build_object('status','refused','code','review_unavailable','reason',SQLERRM);
END $$;

CREATE FUNCTION public.consent_hyrox_programme_prescription(payload jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=public.cohort_base_actor(); aid uuid; vid uuid; expected uuid; command uuid; proposed uuid;
 head public.programme_v3_prescription_consents%ROWTYPE; replay public.programme_v3_prescription_consents%ROWTYPE;
 review public.programme_v3_prescription_reviews%ROWTYPE; result public.programme_v3_prescription_consents%ROWTYPE;
BEGIN
 IF NOT public.cohort_v3_object(payload,ARRAY['command_id','assignment_id','programme_version_id','action','review_id','expected_consent_id'])
   OR coalesce(payload->>'action','') NOT IN ('accept','withdraw') THEN RAISE EXCEPTION 'invalid_consent_payload'; END IF;
 aid:=(payload->>'assignment_id')::uuid; vid:=(payload->>'programme_version_id')::uuid; command:=(payload->>'command_id')::uuid;
 expected:=(payload->>'expected_consent_id')::uuid; proposed:=(payload->>'review_id')::uuid;
 PERFORM 1 FROM public.programme_assignments WHERE id=aid AND athlete_id=actor AND programme_version_id=vid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'wrong_owned_programme' USING ERRCODE='42501'; END IF;
 SELECT * INTO replay FROM public.programme_v3_prescription_consents WHERE command_id=command;
 IF FOUND THEN
   IF replay.athlete_id<>actor OR replay.request<>payload THEN RAISE EXCEPTION 'command_conflict'; END IF;
   RETURN jsonb_build_object('status','replayed','consent_id',replay.consent_id,'disposition',replay.disposition);
 END IF;
 SELECT * INTO head FROM public.programme_v3_prescription_consents WHERE assignment_id=aid ORDER BY generation DESC LIMIT 1;
 IF head.consent_id IS DISTINCT FROM expected THEN RAISE EXCEPTION 'stale_consent'; END IF;
 IF payload->>'action'='accept' THEN
   SELECT * INTO review FROM public.programme_v3_prescription_reviews WHERE review_id=proposed AND athlete_id=actor AND assignment_id=aid AND programme_version_id=vid;
   IF NOT FOUND OR review.expected_consent_id IS DISTINCT FROM head.consent_id THEN RAISE EXCEPTION 'stale_or_unresolved_review'; END IF;
   IF public.cohort_v3_review_document(aid,actor,review.selection,review.increment_grams) IS DISTINCT FROM review.document THEN RAISE EXCEPTION 'stale_review'; END IF;
 ELSE
   IF proposed IS NOT NULL THEN RAISE EXCEPTION 'withdrawal_has_no_review'; END IF;
 END IF;
 INSERT INTO public.programme_v3_prescription_consents(athlete_id,assignment_id,programme_version_id,generation,previous_consent_id,review_id,disposition,command_id,request)
 VALUES(actor,aid,vid,coalesce(head.generation,0)+1,head.consent_id,proposed,CASE payload->>'action' WHEN 'accept' THEN 'accepted' ELSE 'withdrawn' END,command,payload)
 RETURNING * INTO result;
 RETURN jsonb_build_object('status','accepted','consent_id',result.consent_id,'disposition',result.disposition,'generation',result.generation);
EXCEPTION WHEN invalid_text_representation OR invalid_parameter_value OR raise_exception OR integrity_constraint_violation THEN
 RETURN jsonb_build_object('status','refused','code','consent_unavailable','reason',SQLERRM);
END $$;

CREATE FUNCTION public.cohort_start_v3_occurrence_at(p_occurrence uuid,p_now timestamptz,p_consent uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor uuid:=public.cohort_base_actor(); o public.programme_schedule_occurrences%ROWTYPE; a public.programme_assignments%ROWTYPE;
 head public.programme_v3_prescription_consents%ROWTYPE; review public.programme_v3_prescription_reviews%ROWTYPE;
 frozen public.programme_occurrence_v3_prescription_snapshots%ROWTYPE; response jsonb; doc jsonb; prescriptions jsonb; snapshot jsonb; source jsonb;
BEGIN
 -- Preserve the canonical lock/owner/source path. All v3 starts, including other
 -- existing callers of the two-arg helper, pass through here.
 PERFORM pg_advisory_xact_lock(84202408,hashtext(p_occurrence::text));
 SELECT * INTO o FROM public.programme_schedule_occurrences WHERE id=p_occurrence FOR UPDATE;
 SELECT * INTO a FROM public.programme_assignments WHERE id=o.assignment_id FOR UPDATE;
 IF o.id IS NULL OR a.id IS NULL OR a.athlete_id<>actor THEN RAISE EXCEPTION 'owned_occurrence_required' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.programme_v3_publication_artifacts WHERE programme_version_id=a.programme_version_id) THEN
   RETURN jsonb_build_object('status','unavailable','code','v3_authoritative_admission_unavailable');
 END IF;
 SELECT * INTO frozen FROM public.programme_occurrence_v3_prescription_snapshots WHERE occurrence_id=o.id;
 IF FOUND THEN
   IF frozen.athlete_id<>actor OR frozen.assignment_id<>a.id OR frozen.programme_version_id<>a.programme_version_id
     OR NOT EXISTS(SELECT 1 FROM public.programme_slot_outcomes so JOIN public.training_sessions ts ON ts.id=so.training_session_id
       WHERE so.assignment_id=a.id AND so.session_slot_id=o.session_slot_id AND ts.id=frozen.training_session_id
       AND ts.athlete_id=actor::text AND ts.protocol_id=o.protocol_id) THEN RAISE EXCEPTION 'snapshot_link_conflict'; END IF;
   response:=public.cohort_create_or_resume_fixed_occurrence_pre_v3(o.id,p_now);
   RETURN response||jsonb_build_object('bound_prescription_snapshot',frozen.snapshot);
 END IF;
 IF EXISTS(SELECT 1 FROM public.programme_slot_outcomes WHERE assignment_id=a.id AND session_slot_id=o.session_slot_id AND training_session_id IS NOT NULL) THEN RAISE EXCEPTION 'v3_snapshot_missing'; END IF;
 SELECT * INTO head FROM public.programme_v3_prescription_consents WHERE assignment_id=a.id ORDER BY generation DESC LIMIT 1;
 IF p_consent IS NULL OR head.consent_id IS DISTINCT FROM p_consent OR head.disposition IS DISTINCT FROM 'accepted'
   OR head.athlete_id<>actor OR head.programme_version_id<>a.programme_version_id THEN RAISE EXCEPTION 'missing_stale_or_withdrawn_consent'; END IF;
 SELECT * INTO review FROM public.programme_v3_prescription_reviews WHERE review_id=head.review_id;
 doc:=public.cohort_v3_review_document(a.id,actor,review.selection,review.increment_grams);
 IF doc IS DISTINCT FROM review.document THEN RAISE EXCEPTION 'stale_review_or_benchmark'; END IF;
 SELECT coalesce(jsonb_agg(x),'[]') INTO prescriptions FROM jsonb_array_elements(doc->'prescriptions') x
 JOIN public.programme_version_session_slots sl ON sl.id=o.session_slot_id
 WHERE x#>>'{binding,slot_key}'=sl.package_slot_key;
 SELECT x INTO source FROM jsonb_array_elements(doc#>'{resolved_sources,sessions}') x WHERE x->>'protocol_id'=o.protocol_id;
 IF source IS NULL THEN RAISE EXCEPTION 'unresolved_occurrence_source'; END IF;
 response:=public.cohort_create_or_resume_fixed_occurrence_pre_v3(o.id,p_now);
 IF response->>'status' IS DISTINCT FROM 'created' THEN RETURN response; END IF;
 snapshot:=jsonb_build_object('schema_version',1,'athlete_id',actor,'assignment_id',a.id,'programme_version_id',a.programme_version_id,
   'occurrence_id',o.id,'session_slot_id',o.session_slot_id,'training_session_id',(response#>>'{training_session,id}')::bigint,
   'package_hash',doc->>'package_hash','canonical_text',doc->>'canonical_text','source',source,
   'resolved_sources',doc->'resolved_sources','physical_seal',doc->'physical_seal','consent',to_jsonb(head),
   'accepted_review',to_jsonb(review),'prescriptions',prescriptions,'frozen_at',transaction_timestamp());
 INSERT INTO public.programme_occurrence_v3_prescription_snapshots(occurrence_id,athlete_id,assignment_id,programme_version_id,training_session_id,consent_id,snapshot)
 VALUES(o.id,actor,a.id,a.programme_version_id,(response#>>'{training_session,id}')::bigint,head.consent_id,snapshot);
 RETURN response||jsonb_build_object('bound_prescription_snapshot',snapshot);
EXCEPTION WHEN invalid_text_representation OR invalid_parameter_value OR raise_exception OR integrity_constraint_violation THEN
 -- PL/pgSQL exception subtransaction rolls back canonical session/outcome inserts
 -- and the snapshot together. No partial successful start can survive refusal.
 RETURN jsonb_build_object('status','refused','code','v3_start_unavailable','reason',SQLERRM);
END $$;

CREATE OR REPLACE FUNCTION public.cohort_create_or_resume_fixed_occurrence_at(p_occurrence_id uuid,p_now timestamptz) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM public.programme_schedule_occurrences o JOIN public.programme_assignments a ON a.id=o.assignment_id
   JOIN public.programme_versions v ON v.id=a.programme_version_id WHERE o.id=p_occurrence_id AND a.athlete_id=auth.uid() AND v.package_schema_version=3) THEN
   RETURN public.cohort_start_v3_occurrence_at(p_occurrence_id,p_now,NULL);
 END IF;
 RETURN public.cohort_create_or_resume_fixed_occurrence_pre_v3(p_occurrence_id,p_now);
END $$;
CREATE FUNCTION public.create_or_resume_fixed_programme_occurrence_session(p_occurrence_id uuid,p_consent_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.programme_schedule_occurrences o JOIN public.programme_assignments a ON a.id=o.assignment_id
   JOIN public.programme_versions v ON v.id=a.programme_version_id WHERE o.id=p_occurrence_id AND a.athlete_id=auth.uid() AND v.package_schema_version=3) THEN
   RETURN jsonb_build_object('status','refused','code','wrong_bound_programme_occurrence');
 END IF;
 RETURN public.cohort_start_v3_occurrence_at(p_occurrence_id,transaction_timestamp(),p_consent_id);
END $$;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname IN ('cohort_v3_review_document','review_hyrox_programme_prescription','consent_hyrox_programme_prescription',
   'cohort_start_v3_occurrence_at','cohort_create_or_resume_fixed_occurrence_at') LOOP
   EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.signature);
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.create_or_resume_fixed_programme_occurrence_session(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.review_hyrox_programme_prescription(jsonb),public.consent_hyrox_programme_prescription(jsonb),
 public.create_or_resume_fixed_programme_occurrence_session(uuid,uuid) TO authenticated;
COMMIT;
