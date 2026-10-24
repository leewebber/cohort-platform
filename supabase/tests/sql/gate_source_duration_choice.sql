\set ON_ERROR_STOP on
CREATE FUNCTION public.v3_gate_assert(ok boolean,description text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'V3_GATE: %',description; END IF; END $$;
REVOKE ALL ON FUNCTION public.v3_gate_assert(boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.v3_gate_assert(boolean,text) TO authenticated;

DO $$ DECLARE r jsonb; p jsonb; aid uuid; b uuid; v public.programme_versions%ROWTYPE; BEGIN
 SELECT document INTO p FROM public.v3_gate_data WHERE key='payload';
 PERFORM set_config('role','service_role',true);
 r:=public.publish_private_exact_programme_version_v3(p);
 PERFORM set_config('role','none',true);
 PERFORM public.v3_gate_assert(r->>'status'='published','accept compiled authoritative v3 source');
 PERFORM set_config('role','service_role',true);
 r:=public.publish_private_exact_programme_version_v3(p);
 PERFORM set_config('role','none',true);
 PERFORM public.v3_gate_assert(r->>'status'='already_published','exact publication retry');
 PERFORM set_config('role','service_role',true);
 r:=public.publish_private_exact_programme_version_v3(p||jsonb_build_object('owner_id','bc230000-0000-4000-8000-000000000003'));
 PERFORM set_config('role','none',true);
 PERFORM public.v3_gate_assert(r->>'status'='validation_failure','retry cannot change publication ownership');
 r:=(SELECT document FROM public.v3_gate_data WHERE key='payload');
 r:=jsonb_build_object('programme_version_id',r->'programme_version_id');
 SELECT * INTO v FROM public.programme_versions WHERE id=(r->>'programme_version_id')::uuid;
 PERFORM public.v3_gate_assert(v.package_schema_version=3 AND v.lifecycle_status='published','exact explicit v3 persisted');
 INSERT INTO public.v3_gate_data VALUES('publication',r);
 INSERT INTO public.coach_athlete_relationships(coach_id,athlete_id,status)
 SELECT 'bc230000-0000-4000-8000-000000000001',id,'active' FROM auth.users WHERE id::text IN
 ('bc230000-0000-4000-8000-000000000002','bc230000-0000-4000-8000-000000000003','bc230000-0000-4000-8000-000000000004','bc230000-0000-4000-8000-000000000005');
 PERFORM set_config('request.jwt.claim.sub','bc230000-0000-4000-8000-000000000002',true);
 PERFORM set_config('request.jwt.claim.role','authenticated',true); PERFORM set_config('role','authenticated',true);
 r:=public.enrol_athlete_in_private_programme_version(v.id,'Asia/Makassar',false);
 PERFORM public.v3_gate_assert(r->>'status' IN ('enrolled','materialised','enrolled_materialised'),'existing canonical v3 enrol/materialise');
 aid:=(r->>'enrolment_id')::uuid;
 PERFORM set_config('role','none',true); INSERT INTO public.v3_gate_data VALUES('assignment-a',jsonb_build_object('id',aid,'response',r));
 PERFORM set_config('request.jwt.claim.sub','bc230000-0000-4000-8000-000000000003',true); PERFORM set_config('role','authenticated',true);
 r:=public.enrol_athlete_in_private_programme_version(v.id,'Asia/Makassar',false); b:=(r->>'enrolment_id')::uuid;
 PERFORM set_config('role','none',true); INSERT INTO public.v3_gate_data VALUES('assignment-b',jsonb_build_object('id',b,'response',r));
 PERFORM set_config('request.jwt.claim.sub','bc230000-0000-4000-8000-000000000004',true); PERFORM set_config('role','authenticated',true);
 r:=public.enrol_athlete_in_private_programme_version(v.id,'Asia/Makassar',false); b:=(r->>'enrolment_id')::uuid;
 PERFORM set_config('role','none',true); INSERT INTO public.v3_gate_data VALUES('assignment-c',jsonb_build_object('id',b,'response',r));
 PERFORM set_config('request.jwt.claim.sub','bc230000-0000-4000-8000-000000000005',true); PERFORM set_config('role','authenticated',true);
 r:=public.enrol_athlete_in_private_programme_version(v.id,'Asia/Makassar',false); b:=(r->>'enrolment_id')::uuid;
 PERFORM set_config('role','none',true); INSERT INTO public.v3_gate_data VALUES('assignment-d',jsonb_build_object('id',b,'response',r));
END $$;

DO $$ DECLARE aid uuid; version uuid:='bc230000-0000-4000-8000-000000000040'; actor uuid:='bc230000-0000-4000-8000-000000000002';
 occurrence uuid; other uuid; review uuid; consent uuid; r jsonb; first jsonb; count_before bigint; choice jsonb; bad jsonb; prior_consent uuid;
 window_key text:=public.cohort_stable_uuid('v3.synthetic.source:duration')::text;
BEGIN
 SELECT (document->>'id')::uuid INTO aid FROM public.v3_gate_data WHERE key='assignment-a';
 SELECT id INTO occurrence FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=1;
 SELECT id INTO other FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=2;
 SELECT count(*) INTO count_before FROM public.training_sessions;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true); PERFORM set_config('request.jwt.claim.role','authenticated',true); PERFORM set_config('role','authenticated',true);
 r:=public.review_hyrox_programme_prescription(jsonb_build_object('assignment_id',aid,'programme_version_id',version,'selected_revisions','{}'::jsonb,'increment_grams',NULL));
 PERFORM public.v3_gate_assert(r->>'status'='review','new source with squat rest/range reviews through existing SQL authority');
 review:=(r->>'review_id')::uuid;
 r:=public.consent_hyrox_programme_prescription(jsonb_build_object('command_id',gen_random_uuid(),'assignment_id',aid,'programme_version_id',version,'action','accept','review_id',review,'expected_consent_id',NULL));
 consent:=(r->>'consent_id')::uuid;
 PERFORM public.v3_gate_assert(r->>'status'='accepted','existing explicit consent accepted');
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent);
 PERFORM public.v3_gate_assert(r->>'code'='duration_choice_unavailable','old two-argument call cannot bypass choice');
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.programme_occurrence_v3_prescription_snapshots WHERE occurrence_id=occurrence)=0,'missing choice leaves no original snapshot');
 FOR bad IN SELECT value FROM jsonb_array_elements('[null,"3000",2699,3601,0]'::jsonb) LOOP
   r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent,jsonb_build_object(window_key,bad));
   PERFORM public.v3_gate_assert(r->>'code'='duration_choice_unavailable','invalid/out-of-range choice refuses');
 END LOOP;
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent,jsonb_build_object(window_key,3000,'foreign',3000));
 PERFORM public.v3_gate_assert(r->>'reason'='incomplete_or_foreign_duration_choices','foreign extra choice refuses');
 PERFORM set_config('role','none',true);
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.training_sessions)=count_before,'all failed choice transactions roll back canonical session creation');
 PERFORM set_config('role','authenticated',true);
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent,jsonb_build_object(window_key,3600));
 PERFORM public.v3_gate_assert(r->>'status'='created','upper inclusive duration starts'); first:=r->'duration_choice_snapshot';
 PERFORM public.v3_gate_assert(first#>ARRAY['choices',window_key,'authored_range_seconds']='[2700,3600]'::jsonb AND first#>>ARRAY['choices',window_key,'selected_seconds']='3600','original range and chosen duration frozen separately');
 PERFORM public.v3_gate_assert(first->>'training_session_id'=r#>>'{training_session,id}','choice linked to same canonical training session');
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent,jsonb_build_object(window_key,2700));
 PERFORM public.v3_gate_assert(r->>'status'='resumed' AND r->'duration_choice_snapshot'=first,'retry cannot replace frozen duration');
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent);
 PERFORM public.v3_gate_assert(r->'duration_choice_snapshot'=first,'two-argument retry returns original choice');
 PERFORM set_config('role','none',true);
 EXECUTE 'CREATE FUNCTION public.inject_choice_failure() RETURNS trigger LANGUAGE plpgsql AS $f$ BEGIN RAISE EXCEPTION ''injected_choice_failure''; END $f$';
 EXECUTE 'CREATE TRIGGER inject_choice_failure BEFORE INSERT ON public.programme_occurrence_duration_choices FOR EACH ROW EXECUTE FUNCTION public.inject_choice_failure()';
 PERFORM set_config('role','authenticated',true);
 r:=public.create_or_resume_fixed_programme_occurrence_session(other,consent,jsonb_build_object(window_key,3000));
 PERFORM public.v3_gate_assert(r->>'reason'='injected_choice_failure','choice insertion failure reported');
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.programme_occurrence_v3_prescription_snapshots WHERE occurrence_id=other)=0,'choice failure rolls back parent v3 snapshot');
 PERFORM set_config('role','none',true);
 EXECUTE 'DROP TRIGGER inject_choice_failure ON public.programme_occurrence_duration_choices';
 EXECUTE 'DROP FUNCTION public.inject_choice_failure()';
 PERFORM set_config('role','authenticated',true);
 r:=public.create_or_resume_fixed_programme_occurrence_session(other,consent,jsonb_build_object(window_key,2700));
 PERFORM public.v3_gate_assert(r->>'status'='created' AND r#>>ARRAY['duration_choice_snapshot','choices',window_key,'selected_seconds']='2700','lower inclusive duration starts after rollback');
 r:=public.consent_hyrox_programme_prescription(jsonb_build_object('command_id',gen_random_uuid(),'assignment_id',aid,'programme_version_id',version,'action','withdraw','review_id',NULL,'expected_consent_id',consent));
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent,jsonb_build_object(window_key,3200));
 PERFORM public.v3_gate_assert(r->'duration_choice_snapshot'=first,'withdrawal cannot rewrite started choice');
 PERFORM set_config('request.jwt.claim.sub','bc230000-0000-4000-8000-000000000003',true);
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.programme_occurrence_duration_choices)=0,'other athlete cannot read duration snapshots');
 BEGIN
   r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent,jsonb_build_object(window_key,3000));
   PERFORM public.v3_gate_assert(r->>'status'='refused','foreign owner start refuses');
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM set_config('role','none',true);
 PERFORM public.v3_gate_assert(NOT has_table_privilege('authenticated','public.programme_occurrence_duration_choices','INSERT') AND NOT has_table_privilege('service_role','public.programme_occurrence_duration_choices','UPDATE'),'no direct runtime write authority');
 PERFORM public.v3_gate_assert(NOT has_function_privilege('authenticated','public.cohort_fixed_occurrence_before_duration_choice(uuid,uuid)','EXECUTE'),'prior entrypoint cannot bypass choice validation');
 BEGIN
   UPDATE public.programme_occurrence_duration_choices SET snapshot='{}';
   RAISE EXCEPTION 'immutable snapshot unexpectedly updated';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM<>'tracking_publication_artifact_immutable' THEN RAISE; END IF;
 END;
END $$;
SELECT 'SOURCE_DURATION_CHOICE_SQL=PASS' AS result;

DO $$ DECLARE actor uuid:='bc230000-0000-4000-8000-000000000002'; aid uuid; o public.programme_schedule_occurrences%ROWTYPE;
 bound jsonb; chosen jsonb; record_key uuid:=gen_random_uuid(); r jsonb; snapshot jsonb;
BEGIN
 SELECT (document->>'id')::uuid INTO aid FROM public.v3_gate_data WHERE key='assignment-a';
 SELECT * INTO o FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=1;
 SELECT f.snapshot INTO bound FROM public.programme_occurrence_v3_prescription_snapshots f WHERE f.occurrence_id=o.id;
 SELECT c.snapshot INTO chosen FROM public.programme_occurrence_duration_choices c WHERE c.occurrence_id=o.id;
 snapshot:=jsonb_build_object('boundPrescriptionV1',bound,'durationChoiceV1',chosen);
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);PERFORM set_config('role','authenticated',true);
 BEGIN
   INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,source_protocol_id,programme_id,assignment_id,programme_session_id,status,session_snapshot,started_at)
   VALUES(record_key,actor::text,(bound->>'training_session_id')::bigint,o.protocol_id,o.programme_version_id::text,aid,o.session_slot_id,'in_progress',snapshot-'durationChoiceV1',now());
   RAISE EXCEPTION 'missing chosen prescription unexpectedly saved';
 EXCEPTION WHEN check_violation THEN
   IF SQLERRM<>'authoritative_duration_choice_required' THEN RAISE; END IF;
 END;
 INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,source_protocol_id,programme_id,assignment_id,programme_session_id,status,session_snapshot,started_at)
 VALUES(record_key,actor::text,(bound->>'training_session_id')::bigint,o.protocol_id,o.programme_version_id::text,aid,o.session_slot_id,'in_progress',snapshot,now());
 BEGIN
   UPDATE public.training_session_records SET session_snapshot=jsonb_set(session_snapshot,'{durationChoiceV1}','{}') WHERE record_id=record_key;
   RAISE EXCEPTION 'forged chosen prescription unexpectedly saved';
 EXCEPTION WHEN check_violation THEN
   IF SQLERRM<>'authoritative_duration_choice_required' THEN RAISE; END IF;
 END;
 r:=public.complete_fixed_programme_occurrence_and_advance(jsonb_build_object('occurrence_id',o.id,
   'assignment_id',aid,'session_slot_id',o.session_slot_id,'programme_version_id',o.programme_version_id,
   'materialised_package_content_hash',o.package_content_hash,'programmed_session_key',o.programmed_session_key,
   'logical_completion_key',o.programmed_session_key,'idempotency_key',gen_random_uuid(),'actuals_fingerprint',repeat('a',64),
   'protocol_id',o.protocol_id,'expected_week',1,'expected_day_key','day_1','expected_slot_order',1,
   'training_session_id',(bound->>'training_session_id')::bigint,'record_id',record_key,'status','completed',
   'completion_record',jsonb_build_object('record_id',record_key,'source_protocol_id',o.protocol_id,'programme_id',o.programme_version_id,'session_snapshot',snapshot)));
 PERFORM public.v3_gate_assert(r->>'status'='committed','existing completion accepts exact frozen range/choice packet');
 PERFORM public.v3_gate_assert((SELECT session_snapshot->'durationChoiceV1' FROM public.training_session_records WHERE record_id=record_key)=chosen,'completed History retains exact chosen prescription');
 r:=public.create_or_resume_fixed_programme_occurrence_session(o.id,NULL,'{}');
 PERFORM public.v3_gate_assert(r->>'status' NOT IN ('created','resumed') AND r->'duration_choice_snapshot'=chosen,'completed retry preserves frozen choice and existing refusal');
 PERFORM set_config('role','none',true);
END $$;
SELECT 'SOURCE_DURATION_SAVE_COMPLETION_HISTORY=PASS' AS result;
