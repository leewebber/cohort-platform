-- Synthetic only: authenticated roles and trusted publication, never hosted.
CREATE TABLE public.c2p_original_authority AS
SELECT oid,md5(pg_get_functiondef(oid)) hash FROM pg_proc WHERE oid IN
 ('public.correct_completed_performance_record(jsonb)'::regprocedure,
  'public.read_performance_tracking_history_v1(uuid,jsonb)'::regprocedure);
DO $$ DECLARE p jsonb; r jsonb; a public.programme_publication_artifacts%ROWTYPE; BEGIN
 FOR p IN SELECT payload FROM public.c2p_payload ORDER BY kind LOOP
  r:=public.publish_private_exact_programme_version_retained_v1(p);
  PERFORM public.c2_assert(r->>'status'='published' AND r->'package_schema_version'=p->'package_schema_version','v1/v2 retained publication and strict tool response');
  SELECT * INTO STRICT a FROM public.programme_publication_artifacts WHERE programme_version_id=(p->>'programme_version_id')::uuid;
  PERFORM public.c2_assert(a.canonical_text=p->>'package_canonical_json' AND a.package_content_hash=p->>'package_content_hash','exact original bytes and hash retained');
  PERFORM public.c2_assert(a.scope_seal_text::jsonb=public.cohort_tracking_scope_seal(a.programme_version_id,a.canonical_text::jsonb),'separate server-derived scope seal');
  r:=public.publish_private_exact_programme_version_retained_v1(p);
  PERFORM public.c2_assert(r->>'status'='already_published','idempotent publication retry');
  r:=public.publish_private_exact_programme_version_retained_v1(jsonb_set(p,'{protocol_graphs,0,blocks,0,content}','"Contradictory synthetic body"'));
  PERFORM public.c2_assert(r->>'code'='immutable_version_conflict','same package hash cannot change sealed body on retry');
  PERFORM public.c2_assert((SELECT count(*) FROM public.programme_publication_artifacts WHERE programme_version_id=a.programme_version_id)=1,'retry never adds revision');
  r:=public.publish_private_exact_programme_version_retained_v1(p||jsonb_build_object('package_canonical_json',p->>'package_canonical_json'||' '));
  PERFORM public.c2_assert(r->>'code'='canonical_hash_mismatch','changed exact canonical bytes fail');
 END LOOP;
 BEGIN UPDATE public.programme_publication_artifacts SET captured_at=now(); RAISE EXCEPTION 'gate immutable update accepted'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;
 BEGIN DELETE FROM public.programme_publication_artifacts; RAISE EXCEPTION 'gate immutable delete accepted'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;
END $$;
-- Force capture failure AFTER original publication: its entire version/graph
-- must roll back, not leave published content lacking retained evidence.
CREATE FUNCTION public.c2p_fail_capture() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic_capture_failure'; END $$;
CREATE TRIGGER c2p_fail_capture BEFORE INSERT ON public.programme_publication_artifacts FOR EACH ROW EXECUTE FUNCTION public.c2p_fail_capture();
DO $$ DECLARE p jsonb; BEGIN
 SELECT payload INTO p FROM public.c2p_payload WHERE kind='v1';
 p:=jsonb_set(p,'{programme,lineage_code}','"C2-SYNTHETIC-ROLLBACK"')||'{"programme_version_id":"c2000000-0000-4000-8000-000000000063"}';
 p:=jsonb_set(p,'{package_canonical_json}',to_jsonb(public.cohort_tracking_canonical_text(jsonb_set((p->>'package_canonical_json')::jsonb,'{programme,lineage_code}','"C2-SYNTHETIC-ROLLBACK"'))));
 p:=p||jsonb_build_object('package_content_hash',encode(extensions.digest(convert_to(p->>'package_canonical_json','UTF8'),'sha256'),'hex'));
 BEGIN PERFORM public.publish_private_exact_programme_version_retained_v1(p); RAISE EXCEPTION 'gate capture failure expected';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'synthetic_capture_failure' THEN RAISE; END IF; END;
 PERFORM public.c2_assert(NOT EXISTS(SELECT 1 FROM public.programme_versions WHERE id='c2000000-0000-4000-8000-000000000063'),'capture failure rolls publication back');
 -- Legacy retry never manufactures an artifact, even with valid original bytes.
 p:=jsonb_set(p,'{programme,lineage_code}','"C2-SYNTHETIC-LEGACY"')||'{"programme_version_id":"c2000000-0000-4000-8000-000000000064"}';
 p:=jsonb_set(p,'{package_canonical_json}',to_jsonb(public.cohort_tracking_canonical_text(jsonb_set((p->>'package_canonical_json')::jsonb,'{programme,lineage_code}','"C2-SYNTHETIC-LEGACY"'))));
 p:=p||jsonb_build_object('package_content_hash',encode(extensions.digest(convert_to(p->>'package_canonical_json','UTF8'),'sha256'),'hex'));
 PERFORM public.c2_assert(public.publish_private_exact_programme_version(p)->>'status'='published','original publisher compatibility');
 PERFORM public.c2_assert(public.publish_private_exact_programme_version_retained_v1(p)->>'status'='already_published','legacy retry semantics');
 PERFORM public.c2_assert(NOT EXISTS(SELECT 1 FROM public.programme_publication_artifacts WHERE programme_version_id='c2000000-0000-4000-8000-000000000064'),'no fabricated legacy seal');
END $$;
DROP TRIGGER c2p_fail_capture ON public.programme_publication_artifacts;
-- A trusted synthetic materialised graph (no real assignment/start RPC).
CREATE FUNCTION public.c2p_make_links(p_version uuid,p_assignment uuid,p_occurrence uuid,p_record uuid,p_block uuid,p_session bigint) RETURNS jsonb
LANGUAGE plpgsql AS $$ DECLARE run jsonb; occ public.programme_schedule_occurrences%ROWTYPE; snap jsonb; BEGIN
PERFORM set_config('cohort.allow_schedule_write','on',true);
INSERT INTO public.programme_assignments(id,athlete_id,programme_version_id,lineage_code,status,started_at,timezone,materialised_at,materialisation_source,materialised_package_content_hash,materialised_package_schema_version)
SELECT p_assignment,'c2000000-0000-4000-8000-000000000001',id,'C2-SYNTHETIC-RETENTION-1','paused','2026-01-01','Asia/Makassar',now(),'athlete_start_programme',package_content_hash,package_schema_version
FROM public.programme_versions WHERE id=p_version;
INSERT INTO public.programme_schedule_projections(assignment_id,athlete_id,programme_version_id,package_content_hash,timezone,started_at)
SELECT id,athlete_id::uuid,programme_version_id,materialised_package_content_hash,timezone,started_at FROM public.programme_assignments WHERE id=p_assignment;
INSERT INTO public.programme_schedule_occurrences(id,assignment_id,session_slot_id,programme_version_id,package_content_hash,week_number,day_key,session_order,protocol_id,programmed_session_key,scheduled_date,disposition)
SELECT p_occurrence,a.id,s.id,a.programme_version_id,a.materialised_package_content_hash,w.week_number,d.day_key,s.session_order,s.protocol_id,
 public.cohort_programme_schedule_programmed_session_key(a.id,a.programme_version_id,w.week_number,d.day_key,s.session_order,s.protocol_id),'2026-01-01','completed'
FROM public.programme_assignments a JOIN public.programme_version_weeks w ON w.version_id=a.programme_version_id JOIN public.programme_version_days d ON d.week_id=w.id JOIN public.programme_version_session_slots s ON s.day_id=d.id WHERE a.id=p_assignment;
INSERT INTO public.training_sessions(id,athlete_id,protocol_id,status) VALUES(p_session,'c2000000-0000-4000-8000-000000000001',(SELECT protocol_id FROM public.programme_schedule_occurrences WHERE id=p_occurrence),'completed');
INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,source_protocol_id,assignment_id,programme_session_id,status,session_snapshot,started_at)
SELECT p_record,'c2000000-0000-4000-8000-000000000001',p_session,protocol_id,assignment_id,session_slot_id,'in_progress','{}','2026-01-01T12:00:00Z'
FROM public.programme_schedule_occurrences WHERE id=p_occurrence;
SELECT * INTO occ FROM public.programme_schedule_occurrences WHERE id=p_occurrence;
SELECT authored_running_v1 INTO run FROM public.programme_version_session_slots WHERE id=occ.session_slot_id;
IF run IS NOT NULL THEN
 snap:=jsonb_build_object('schema_version',1,'authority','advisory','occurrence_id',p_occurrence,'athlete_id','c2000000-0000-4000-8000-000000000001','assignment_id',p_assignment,'programme_version_id',p_version,'session_slot_id',occ.session_slot_id,'package_content_hash',occ.package_content_hash,'workout_id',run->>'workout_id','frozen_at_utc',now(),'freeze_source','in_app_start','targets',jsonb_build_array(jsonb_build_object('state','intent_only','scope',jsonb_build_object('step_ids',run->'step_ids'))));
 INSERT INTO public.programme_occurrence_running_target_snapshots(occurrence_id,athlete_id,assignment_id,training_session_id,snapshot,frozen_at,freeze_source) VALUES(p_occurrence,'c2000000-0000-4000-8000-000000000001',p_assignment,p_session,snap,now(),'in_app_start');
END IF;
INSERT INTO public.training_block_results(block_result_id,session_record_id,source_block_id,block_snapshot,status,result_type,result_data,position)
SELECT p_block,p_record,block_id::text,jsonb_build_object('sourceBlockId',block_id::text),'completed',CASE WHEN run IS NULL THEN 'duration' ELSE 'interval' END,CASE WHEN run IS NULL THEN '{"resultType":"duration","durationSeconds":12}'::jsonb ELSE jsonb_build_object('resultType','interval','totalIntervals',1,'intervalsCompleted',1,'paceUnit','sec_per_km','intervals',jsonb_build_array(jsonb_build_object('workoutId',run->>'workout_id','sessionBlockId',block_id::text,'authoredStepId',run#>>'{step_ids,0}','repeatOrdinal',1,'ordinal',1,'workSeconds',12,'state','pace_unavailable','paceSecondsPerKm',null))) END,1
FROM public.session_blocks WHERE session_id=(SELECT protocol_id FROM public.programme_schedule_occurrences WHERE id=p_occurrence);
UPDATE public.training_session_records SET status='completed',completed_at='2026-01-01T12:01:00Z' WHERE record_id=p_record;
INSERT INTO public.programme_slot_outcomes(assignment_id,session_slot_id,week_number,day_key,session_order,outcome_status,training_session_id,programme_version_id,materialised_package_content_hash,programmed_session_key,completion_record_id)
SELECT assignment_id,session_slot_id,week_number,day_key,session_order,'completed',p_session,programme_version_id,package_content_hash,programmed_session_key,p_record FROM public.programme_schedule_occurrences WHERE id=p_occurrence;
RETURN (SELECT jsonb_build_object('assignment_id',o.assignment_id,'occurrence_id',o.id,'training_session_id',p_session::text,'programme_version_id',o.programme_version_id,'package_hash',o.package_content_hash,'slot_key','synthetic-slot','protocol_id',o.protocol_id,'protocol_revision',1,'block_id',b.block_id::text) claim
FROM public.programme_schedule_occurrences o JOIN public.session_blocks b ON b.session_id=o.protocol_id WHERE o.id=p_occurrence);
END $$;
REVOKE ALL ON FUNCTION public.c2p_make_links(uuid,uuid,uuid,uuid,uuid,bigint) FROM PUBLIC,anon,authenticated,service_role;
SELECT set_config('cohort.allow_schedule_write','on',false);
INSERT INTO public.programme_assignments(id,athlete_id,programme_version_id,lineage_code,status,started_at,timezone,materialised_at,materialisation_source,materialised_package_content_hash,materialised_package_schema_version)
SELECT 'c2000000-0000-4000-8000-000000000080','c2000000-0000-4000-8000-000000000001',id,'C2-SYNTHETIC-RETENTION-1','active','2026-01-01','Asia/Makassar',now(),'athlete_start_programme',package_content_hash,package_schema_version
FROM public.programme_versions WHERE id='c2000000-0000-4000-8000-000000000061';
INSERT INTO public.programme_schedule_projections(assignment_id,athlete_id,programme_version_id,package_content_hash,timezone,started_at)
SELECT id,athlete_id::uuid,programme_version_id,materialised_package_content_hash,timezone,started_at FROM public.programme_assignments WHERE id='c2000000-0000-4000-8000-000000000080';
INSERT INTO public.programme_schedule_occurrences(id,assignment_id,session_slot_id,programme_version_id,package_content_hash,week_number,day_key,session_order,protocol_id,programmed_session_key,scheduled_date,disposition)
SELECT 'c2000000-0000-4000-8000-000000000081',a.id,s.id,a.programme_version_id,a.materialised_package_content_hash,w.week_number,d.day_key,s.session_order,s.protocol_id,
 public.cohort_programme_schedule_programmed_session_key(a.id,a.programme_version_id,w.week_number,d.day_key,s.session_order,s.protocol_id),'2026-01-01','completed'
FROM public.programme_assignments a JOIN public.programme_version_weeks w ON w.version_id=a.programme_version_id JOIN public.programme_version_days d ON d.week_id=w.id JOIN public.programme_version_session_slots s ON s.day_id=d.id WHERE a.id='c2000000-0000-4000-8000-000000000080';
INSERT INTO public.training_sessions(id,athlete_id,protocol_id,status) VALUES(987002,'c2000000-0000-4000-8000-000000000001','c2.retained.synthetic.1','completed');
INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,source_protocol_id,assignment_id,programme_session_id,status,session_snapshot,started_at)
SELECT 'c2000000-0000-4000-8000-000000000070','c2000000-0000-4000-8000-000000000001',987002,protocol_id,assignment_id,session_slot_id,'in_progress','{}','2026-01-01T12:00:00Z'
FROM public.programme_schedule_occurrences WHERE id='c2000000-0000-4000-8000-000000000081';
INSERT INTO public.training_block_results(block_result_id,session_record_id,source_block_id,block_snapshot,status,result_type,result_data,position)
SELECT 'c2000000-0000-4000-8000-000000000071','c2000000-0000-4000-8000-000000000070',block_id::text,jsonb_build_object('sourceBlockId',block_id::text),'completed','duration','{"resultType":"duration","durationSeconds":12}',1
FROM public.session_blocks WHERE session_id='c2.retained.synthetic.1';
UPDATE public.training_session_records SET status='completed',completed_at='2026-01-01T12:01:00Z' WHERE record_id='c2000000-0000-4000-8000-000000000070';
INSERT INTO public.programme_slot_outcomes(assignment_id,session_slot_id,week_number,day_key,session_order,outcome_status,training_session_id,programme_version_id,materialised_package_content_hash,programmed_session_key,completion_record_id)
SELECT assignment_id,session_slot_id,week_number,day_key,session_order,'completed',987002,programme_version_id,package_content_hash,programmed_session_key,'c2000000-0000-4000-8000-000000000070' FROM public.programme_schedule_occurrences WHERE id='c2000000-0000-4000-8000-000000000081';
CREATE TABLE public.c2p_claim AS SELECT jsonb_build_object('assignment_id',o.assignment_id,'occurrence_id',o.id,'training_session_id','987002','programme_version_id',o.programme_version_id,'package_hash',o.package_content_hash,'slot_key','synthetic-slot','protocol_id',o.protocol_id,'protocol_revision',1,'block_id',b.block_id::text) claim
FROM public.programme_schedule_occurrences o JOIN public.session_blocks b ON b.session_id=o.protocol_id WHERE o.id='c2000000-0000-4000-8000-000000000081';
SELECT set_config('cohort.allow_schedule_write','off',false);
GRANT SELECT ON public.c2p_claim TO authenticated; -- Gate-only synthetic claim.
SELECT public.c2_assert(NOT has_table_privilege('authenticated','public.training_sessions','SELECT'),'no broad SELECT grant');
SELECT public.c2_assert(NOT has_table_privilege('authenticated','public.programme_publication_artifacts','SELECT'),'private artifacts not directly visible');
SELECT public.c2_assert(NOT has_function_privilege('authenticated','public.publish_private_exact_programme_version_retained_v1(jsonb)','EXECUTE'),'no athlete publication');
SELECT public.c2_assert(NOT has_function_privilege('anon','public.read_performance_tracking_programme_history_v1(uuid,jsonb)','EXECUTE') AND NOT has_function_privilege('service_role','public.read_performance_tracking_programme_history_v1(uuid,jsonb)','EXECUTE'),'authenticated-only read');
SELECT public.c2_assert((SELECT prosecdef AND provolatile='s' AND proconfig=ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_proc WHERE oid='public.read_performance_tracking_programme_history_v1(uuid,jsonb)'::regprocedure),'fixed stable definer');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',false);
CREATE TEMP TABLE training_session_records(record_id uuid,athlete_id text);
CREATE TEMP TABLE programme_publication_artifacts(canonical_text text);
DO $$ DECLARE c jsonb; r jsonb; BEGIN
 SELECT claim INTO c FROM public.c2p_claim;
 r:=public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',c);
 PERFORM public.c2_assert(r->>'status'='ok','own exact claim succeeds without training_sessions SELECT');
 PERFORM public.c2_assert(r#>>'{programme,artifact,canonical_text}' IS NOT NULL AND r->>'complete_audit_set'='true','complete coherent evidence and owner-gated artifact');
 PERFORM public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',c||'{"slot_key":"wrong"}')->>'code'='programme_scope_conflict','contradictory claim');
 PERFORM public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',c||'{"unexpected":true}')->>'code'='invalid_programme_claim','unknown claim rejected');
 PERFORM public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',c-'block_id')->>'code'='invalid_programme_claim','partial claim rejected');
 PERFORM public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',null)->>'code'='invalid_programme_claim','required claim');
 PERFORM public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000040',c)->>'code'='programme_scope_unproven','no historical authority');
END $$;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000002',false);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))=public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000099',(SELECT claim FROM public.c2p_claim)),'foreign/absent record no existence or artifact leak');
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000003',false);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))->>'code'='programme_scope_unproven','coach cannot use broader RLS to read athlete artifact');
RESET ROLE;
-- Live graph drift conflicts without rewriting the seal.
BEGIN;
UPDATE public.session_blocks SET content='synthetic contradictory content' WHERE session_id='c2.retained.synthetic.1';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))->>'code'='programme_scope_conflict','live body drift detected by separate seal');
ROLLBACK;
SELECT public.c2_assert(NOT EXISTS(SELECT 1 FROM public.c2p_original_authority a JOIN pg_proc p ON p.oid=a.oid WHERE a.hash<>md5(pg_get_functiondef(p.oid))),'original read/correction functions unchanged');

CREATE TABLE public.c2p_legacy_claim AS SELECT public.c2p_make_links('c2000000-0000-4000-8000-000000000064','c2000000-0000-4000-8000-000000000084','c2000000-0000-4000-8000-000000000085','c2000000-0000-4000-8000-000000000074','c2000000-0000-4000-8000-000000000075',987004) claim;
GRANT SELECT ON public.c2p_legacy_claim,public.c2p_payload TO authenticated,service_role;
SET ROLE service_role;
SELECT public.c2_assert(public.publish_private_exact_programme_version_retained_v1((SELECT payload FROM public.c2p_payload WHERE kind='v1'))->>'status'='already_published','service-role retained entry point retry');
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',false);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000074',(SELECT claim FROM public.c2p_legacy_claim))->>'code'='programme_scope_unproven','all legacy links agree but absent artifact remains unproven');
RESET ROLE;
BEGIN;
UPDATE public.training_sessions SET athlete_id='c2000000-0000-4000-8000-000000000002' WHERE id=987002;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))->>'code'='programme_scope_unproven','actual-session ownership explicitly required');
ROLLBACK;
BEGIN;
INSERT INTO public.performance_result_corrections(record_id,athlete_id,actor_id,training_session_id,before_values,after_values) VALUES('c2000000-0000-4000-8000-000000000070','c2000000-0000-4000-8000-000000000002','c2000000-0000-4000-8000-000000000002',987002,'{}','{}');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))->>'code'='programme_scope_conflict','foreign audit fails without being returned or filtered');
ROLLBACK;
BEGIN;
UPDATE public.training_session_records SET session_snapshot=jsonb_build_object('synthetic',repeat('x',4194304)) WHERE record_id='c2000000-0000-4000-8000-000000000070';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))->>'code'='evidence_limit_exceeded','combined response byte bound is explicit');
ROLLBACK;

BEGIN;
INSERT INTO public.training_exercise_results(exercise_result_id,block_result_id,exercise_snapshot,position) VALUES('c2000000-0000-4000-8000-000000000072','c2000000-0000-4000-8000-000000000071','{}',1);
INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,position)
SELECT ('c2300000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c2000000-0000-4000-8000-000000000072',n,n FROM generate_series(1,1001) n;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))#>>'{counts,sets}'='1001','combined read never truncates at PostgREST limit');
RESET ROLE;
INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,position)
SELECT ('c2400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c2000000-0000-4000-8000-000000000072',n+1001,n+1001 FROM generate_series(1,10000) n;
SET LOCAL ROLE authenticated;
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000070',(SELECT claim FROM public.c2p_claim))->>'code'='evidence_limit_exceeded','combined row bound explicit');
ROLLBACK;
CREATE TABLE public.c2p_running_claim AS SELECT public.c2p_make_links('c2000000-0000-4000-8000-000000000062','c2000000-0000-4000-8000-000000000088','c2000000-0000-4000-8000-000000000089','c2000000-0000-4000-8000-000000000078','c2000000-0000-4000-8000-000000000079',987006) || (SELECT jsonb_build_object('workout_id',authored_running_v1->>'workout_id','step_id',authored_running_v1#>>'{step_ids,0}','repeat_ordinal',1,'mapping_hash',authored_running_v1->>'execution_mapping_sha256') FROM public.programme_version_session_slots WHERE protocol_id='c2.retained.synthetic.2') claim;
GRANT SELECT ON public.c2p_running_claim TO authenticated;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',false);
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000078',(SELECT claim FROM public.c2p_running_claim))->>'status'='ok','retained B3 mapping and owned frozen scope read');
SELECT public.c2_assert(public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000078',(SELECT claim||'{"repeat_ordinal":2}' FROM public.c2p_running_claim))->>'status'='failure','running ordinal cannot be guessed');
RESET ROLE;
\echo C2_PROGRAMME_SQL_GATE=PASS
