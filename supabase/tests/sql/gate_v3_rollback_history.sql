\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION public.v3_gate_snapshot_fault() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'injected snapshot failure' USING ERRCODE='23514'; END $$;
CREATE TRIGGER v3_gate_inject_snapshot_fault BEFORE INSERT ON public.programme_occurrence_v3_prescription_snapshots
FOR EACH ROW EXECUTE FUNCTION public.v3_gate_snapshot_fault();
DO $$ DECLARE actor uuid:='bc230000-0000-4000-8000-000000000003'; aid uuid; version uuid:='bc230000-0000-4000-8000-000000000040';
 occurrence uuid; r jsonb; review uuid; consent uuid; count_sessions bigint; count_outcomes bigint;
BEGIN
 SELECT (document->>'id')::uuid INTO aid FROM public.v3_gate_data WHERE key='assignment-b';
 SELECT id INTO occurrence FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=1;
 SELECT count(*) INTO count_sessions FROM public.training_sessions;
 SELECT count(*) INTO count_outcomes FROM public.programme_slot_outcomes;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);PERFORM set_config('role','authenticated',true);
 r:=public.review_hyrox_programme_prescription(jsonb_build_object('assignment_id',aid,'programme_version_id',version,'selected_revisions','{}'::jsonb,'increment_grams',NULL));
 PERFORM public.v3_gate_assert(r->>'status'='review','missing evidence is explicit review, not zero');review:=(r->>'review_id')::uuid;
 PERFORM public.v3_gate_assert((SELECT count(*) FROM jsonb_array_elements(r#>'{document,prescriptions}') x WHERE x#>>'{calculated,status}'='unavailable')=6,'all missing numerical targets unavailable');
 r:=public.consent_hyrox_programme_prescription(jsonb_build_object('command_id',gen_random_uuid(),'assignment_id',aid,'programme_version_id',version,'action','accept','review_id',review,'expected_consent_id',NULL));
 consent:=(r->>'consent_id')::uuid;
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent);
 PERFORM public.v3_gate_assert(r->>'status'='refused','injected snapshot insertion fails closed');
 PERFORM set_config('role','none',true);
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.training_sessions)=count_sessions,'canonical session insert rolled back');
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.programme_slot_outcomes)=count_outcomes,'canonical outcome insert rolled back');
 INSERT INTO public.v3_gate_data VALUES('rollback-consent',jsonb_build_object('id',consent));
END $$;
DROP TRIGGER v3_gate_inject_snapshot_fault ON public.programme_occurrence_v3_prescription_snapshots;
DO $$ DECLARE actor uuid:='bc230000-0000-4000-8000-000000000003'; aid uuid; occurrence uuid; next_occurrence uuid; consent uuid; r jsonb; original jsonb;
 o public.programme_schedule_occurrences%ROWTYPE; record_id uuid:=gen_random_uuid();
BEGIN
 SELECT (document->>'id')::uuid INTO aid FROM public.v3_gate_data WHERE key='assignment-b';
 SELECT * INTO o FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=1;
 occurrence:=o.id;
 SELECT id INTO next_occurrence FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=2;
 SELECT (document->>'id')::uuid INTO consent FROM public.v3_gate_data WHERE key='rollback-consent';
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);PERFORM set_config('role','authenticated',true);
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent);
 PERFORM public.v3_gate_assert(r->>'status'='created','retry after rollback creates one canonical session');
 original:=r->'bound_prescription_snapshot';
 r:=public.complete_fixed_programme_occurrence_and_advance(jsonb_build_object('occurrence_id',occurrence,
   'assignment_id',aid,'session_slot_id',o.session_slot_id,'programme_version_id',o.programme_version_id,
   'materialised_package_content_hash',o.package_content_hash,'programmed_session_key',o.programmed_session_key,
   'logical_completion_key',o.programmed_session_key,'idempotency_key',gen_random_uuid(),'actuals_fingerprint',repeat('a',64),
   'protocol_id',o.protocol_id,'expected_week',1,'expected_day_key','day_1','expected_slot_order',1,
   'training_session_id',(original->>'training_session_id')::bigint,'record_id',record_id,'status','completed',
   'completion_record',jsonb_build_object('record_id',record_id,'source_protocol_id',o.protocol_id,'programme_id',o.programme_version_id,'session_snapshot',jsonb_build_object('boundPrescriptionV1',original))));
 PERFORM public.v3_gate_assert(r->>'status'='committed','existing canonical completion remains functional');
 PERFORM public.v3_gate_assert((SELECT snapshot FROM public.programme_occurrence_v3_prescription_snapshots WHERE occurrence_id=occurrence)=original,'completion never rewrites prescription');
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent);
 PERFORM public.v3_gate_assert(r->>'status' NOT IN ('created','resumed') AND r->'bound_prescription_snapshot'=original,'completed retry preserves snapshot and existing refusal');
 PERFORM set_config('role','none',true);
 UPDATE public.exercises_v2 SET published=false WHERE exercise_id='EX-900900';
 PERFORM set_config('role','authenticated',true);
 r:=public.create_or_resume_fixed_programme_occurrence_session(next_occurrence,consent);
 PERFORM public.v3_gate_assert(r->>'status'='refused','retired catalogue identity cannot acquire future target authority');
 PERFORM set_config('role','none',true);
 BEGIN DELETE FROM public.programme_occurrence_v3_prescription_snapshots WHERE occurrence_id=occurrence;
  RAISE EXCEPTION 'snapshot deletion accepted'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;
 BEGIN UPDATE public.programme_occurrence_v3_prescription_snapshots SET snapshot='{}' WHERE occurrence_id=occurrence;
  RAISE EXCEPTION 'snapshot update accepted'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;
 BEGIN
   INSERT INTO public.programme_v3_prescription_consents(athlete_id,assignment_id,programme_version_id,generation,review_id,disposition,command_id,request)
   SELECT actor,aid,o.programme_version_id,999,review_id,'accepted',gen_random_uuid(),'{}'
   FROM public.programme_v3_prescription_reviews WHERE athlete_id<>actor LIMIT 1;
   RAISE EXCEPTION 'foreign review linkage accepted'; EXCEPTION WHEN foreign_key_violation OR check_violation THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'V3_ATOMIC_ROLLBACK_COMPLETION_HISTORY_SOURCE_RETIREMENT=PASS' AS result;
