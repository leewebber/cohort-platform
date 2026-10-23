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

DO $$ DECLARE actor uuid:='bc230000-0000-4000-8000-000000000002'; aid uuid; version uuid:='bc230000-0000-4000-8000-000000000040';
 selection jsonb:='{}'; p jsonb; r jsonb; rev uuid; review uuid; consent uuid; head uuid; occurrence uuid; other uuid; original jsonb; command uuid;
 metric text; val text; unit text; before_count bigint;
BEGIN
 SELECT (document->>'id')::uuid INTO aid FROM public.v3_gate_data WHERE key='assignment-a';
 SELECT id INTO occurrence FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=1;
 SELECT id INTO other FROM public.programme_schedule_occurrences WHERE assignment_id=aid AND session_order=2;
 PERFORM public.v3_gate_assert(occurrence IS NOT NULL AND other IS NOT NULL,'two exact canonical occurrences');
 PERFORM set_config('request.jwt.claim.sub',actor::text,true); PERFORM set_config('role','authenticated',true);
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence);
 PERFORM public.v3_gate_assert(r->>'code'='v3_start_unavailable','start without consent refuses');
 FOR metric,val,unit IN SELECT * FROM (VALUES('run10km','40','minutes'),('row2km','480','seconds'),('backSquat5rm','100','kilograms')) x LOOP
   r:=public.record_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric',metric,'value',val,'unit',unit,
     'test_date','2026-10-23','source_type','knownResult','source_reference','v3-synthetic-'||metric,'previous_revision_id',NULL,'correction_reason',NULL));
   PERFORM public.v3_gate_assert(r->>'status'='recorded','owned declared evidence '||metric);
   selection:=selection||jsonb_build_object(metric,r->>'revision_id');
 END LOOP;
 r:=public.review_hyrox_programme_prescription(jsonb_build_object('assignment_id',aid,'programme_version_id',version,'selected_revisions',selection,'increment_grams',2500));
 PERFORM public.v3_gate_assert(r->>'status'='review','server review'); review:=(r->>'review_id')::uuid;
 PERFORM public.v3_gate_assert((SELECT count(*) FROM jsonb_array_elements(r#>'{document,prescriptions}') x WHERE x#>>'{binding,kind}'='runningIntervals'
   AND x#>'{calculated,faster}'='{"numerator":240000000,"denominator":1000}')=2,'40 minute run reviewed from trusted SQL');
 p:=jsonb_build_object('command_id',gen_random_uuid(),'assignment_id',aid,'programme_version_id',version,'action','accept','review_id',review,'expected_consent_id',NULL);
 r:=public.consent_hyrox_programme_prescription(p); consent:=(r->>'consent_id')::uuid;
 PERFORM public.v3_gate_assert(r->>'status'='accepted','programme consent');
 PERFORM public.v3_gate_assert(public.consent_hyrox_programme_prescription(p)->>'status'='replayed','idempotent consent');
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent);
 PERFORM public.v3_gate_assert(r->>'status'='created','canonical start'); original:=r->'bound_prescription_snapshot';
 PERFORM public.v3_gate_assert(jsonb_array_length(original->'prescriptions')=3,'exact target slot only');
 PERFORM public.v3_gate_assert(original#>>'{consent,consent_id}'=consent::text AND original#>>'{source,protocol_id}'='v3.synthetic.source'
   AND original->>'canonical_text' IS NOT NULL AND original->'resolved_sources' IS NOT NULL,'complete frozen source/version/binding/dependencies/consent');
 r:=public.consent_hyrox_programme_prescription(jsonb_build_object('command_id',gen_random_uuid(),'assignment_id',aid,'programme_version_id',version,
   'action','withdraw','review_id',NULL,'expected_consent_id',consent)); head:=(r->>'consent_id')::uuid;
 PERFORM public.v3_gate_assert(r->>'disposition'='withdrawn','explicit withdrawal');
 r:=public.create_or_resume_fixed_programme_occurrence_session(other,consent);
 PERFORM public.v3_gate_assert(r->>'code'='v3_start_unavailable','withdrawal blocks future starts');
 r:=public.create_or_resume_fixed_programme_occurrence_session(occurrence,consent);
 PERFORM public.v3_gate_assert(r->>'status'='resumed' AND r->'bound_prescription_snapshot'=original,'started retry immutable after withdrawal');
 r:=public.review_hyrox_programme_prescription(jsonb_build_object('assignment_id',aid,'programme_version_id',version,'selected_revisions',selection,'increment_grams',2500));
 review:=(r->>'review_id')::uuid;
 -- Correction after review makes the accepted proposal stale; nothing auto-selects.
 rev:=(selection->>'run10km')::uuid;
 r:=public.record_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','run10km','value','60','unit','minutes',
   'test_date','2026-10-23','source_type','knownResult','source_reference','v3-synthetic-run10km','previous_revision_id',rev,'correction_reason','synthetic correction'));
 selection:=selection||jsonb_build_object('run10km',r->>'revision_id');
 r:=public.consent_hyrox_programme_prescription(jsonb_build_object('command_id',gen_random_uuid(),'assignment_id',aid,'programme_version_id',version,
   'action','accept','review_id',review,'expected_consent_id',head));
 PERFORM public.v3_gate_assert(r->>'status'='refused','stale benchmark review refused');
 r:=public.review_hyrox_programme_prescription(jsonb_build_object('assignment_id',aid,'programme_version_id',version,'selected_revisions',selection,'increment_grams',2500));
 review:=(r->>'review_id')::uuid;
 PERFORM public.v3_gate_assert((SELECT count(*) FROM jsonb_array_elements(r#>'{document,prescriptions}') x WHERE x#>>'{binding,kind}'='runningIntervals'
   AND x#>'{calculated,faster}'='{"numerator":360000000,"denominator":1000}')=2,'60 minute corrected benchmark reviewed');
 r:=public.consent_hyrox_programme_prescription(jsonb_build_object('command_id',gen_random_uuid(),'assignment_id',aid,'programme_version_id',version,
   'action','accept','review_id',review,'expected_consent_id',head)); consent:=(r->>'consent_id')::uuid;
 r:=public.create_or_resume_fixed_programme_occurrence_session(other,consent);
 PERFORM public.v3_gate_assert(r->>'status'='created','new consent changes eligible unstarted occurrence');
 PERFORM public.v3_gate_assert((SELECT snapshot FROM public.programme_occurrence_v3_prescription_snapshots WHERE occurrence_id=occurrence)=original,'old snapshot unchanged after correction/new start');
 PERFORM set_config('role','none',true);
 INSERT INTO public.v3_gate_data VALUES('selection-a',selection),('consent-a',jsonb_build_object('id',consent)),('snapshot-a',original);
END $$;
SELECT 'V3_COMPILE_ADMISSION_REVIEW_CONSENT_CANONICAL_START=PASS' AS result;
