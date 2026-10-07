-- Synthetic fixtures in a disposable database only. No production data.
CREATE FUNCTION public.c2_assert(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'C2_GATE_FAILURE: %', label; END IF;
END $$;

INSERT INTO auth.users(id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
VALUES ('c2000000-0000-4000-8000-000000000001','authenticated','authenticated','c2-a@example.invalid','{}','{}'),
 ('c2000000-0000-4000-8000-000000000002','authenticated','authenticated','c2-b@example.invalid','{}','{}'),
 ('c2000000-0000-4000-8000-000000000003','authenticated','authenticated','c2-coach@example.invalid','{}','{}');
INSERT INTO public.profiles(id, display_name, is_athlete, is_coach) VALUES
 ('c2000000-0000-4000-8000-000000000001','C2 synthetic A',true,false),
 ('c2000000-0000-4000-8000-000000000002','C2 synthetic B',true,false),
 ('c2000000-0000-4000-8000-000000000003','C2 synthetic Coach',false,true);
INSERT INTO public.coach_athlete_relationships(coach_id,athlete_id,status) VALUES
 ('c2000000-0000-4000-8000-000000000003','c2000000-0000-4000-8000-000000000001','active');
INSERT INTO public.training_sessions(id,athlete_id,protocol_id,status) VALUES
 (987001,'c2000000-0000-4000-8000-000000000001','synthetic.protocol','completed');
INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,
 source_protocol_id,assignment_id,status,session_snapshot,started_at,completed_at) VALUES
 ('c2000000-0000-4000-8000-000000000010','c2000000-0000-4000-8000-000000000001',987001,
  'synthetic.protocol','c2000000-0000-4000-8000-000000000020','in_progress','{}','2026-01-01T12:00:00Z',null),
 ('c2000000-0000-4000-8000-000000000030','c2000000-0000-4000-8000-000000000002',null,
  null,null,'completed','{}','2026-01-01T12:00:00Z','2026-01-01T12:01:00Z'),
 ('c2000000-0000-4000-8000-000000000040','c2000000-0000-4000-8000-000000000001',null,
  null,null,'completed','{}','2026-01-01T12:00:00Z','2026-01-01T12:01:00Z');
INSERT INTO public.training_block_results(block_result_id,session_record_id,source_block_id,
 block_snapshot,status,result_type,result_data,position) VALUES
 ('c2000000-0000-4000-8000-000000000011','c2000000-0000-4000-8000-000000000010','synthetic.block',
  '{"sourceBlockId":"synthetic.block"}','completed','duration','{"resultType":"duration","durationSeconds":12}',1),
 ('c2000000-0000-4000-8000-000000000015','c2000000-0000-4000-8000-000000000010','synthetic.skipped',
  '{"sourceBlockId":"synthetic.skipped"}','skipped','duration',null,2);
INSERT INTO public.training_exercise_results(exercise_result_id,block_result_id,exercise_snapshot,position) VALUES
 ('c2000000-0000-4000-8000-000000000012','c2000000-0000-4000-8000-000000000011','{"loadKind":"external"}',1);
INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,reps,duration_seconds,completed,position)
SELECT ('c2100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'c2000000-0000-4000-8000-000000000012',n,3,12,true,n FROM generate_series(1,1001) n;
UPDATE public.training_session_records SET status='completed',completed_at='2026-01-01T12:01:00Z'
WHERE record_id='c2000000-0000-4000-8000-000000000010';

-- Existing privileges/mutation definitions are fingerprinted for the race gate.
CREATE TABLE public.c2_unchanged_permissions AS
SELECT c.oid, c.relacl::text AS acl, c.relrowsecurity, c.relforcerowsecurity
FROM pg_class c WHERE c.oid IN (
 'public.training_session_records'::regclass,'public.training_block_results'::regclass,
 'public.training_exercise_results'::regclass,'public.training_set_results'::regclass,
 'public.performance_result_corrections'::regclass,'public.training_sessions'::regclass);
CREATE TABLE public.c2_unchanged_mutation AS
SELECT md5(pg_get_functiondef('public.correct_completed_performance_record(jsonb)'::regprocedure)) AS hash;

SELECT public.c2_assert(has_table_privilege('authenticated','public.training_sessions','SELECT')
 AND (SELECT relrowsecurity FROM pg_class WHERE oid='public.training_sessions'::regclass),
 'owner session SELECT requires RLS; no programme attribution authority');
SELECT public.c2_assert(NOT has_table_privilege('authenticated','public.performance_result_corrections','INSERT'), 'no audit insert grant');
SELECT public.c2_assert(NOT has_table_privilege('authenticated','public.training_sessions','UPDATE'), 'no session update grant');
SELECT public.c2_assert(NOT has_function_privilege('anon','public.read_performance_tracking_history_v1(uuid,jsonb)','EXECUTE'), 'anon execution denied');
SELECT public.c2_assert(NOT has_function_privilege('service_role','public.read_performance_tracking_history_v1(uuid,jsonb)','EXECUTE'), 'no service role execution');
SELECT public.c2_assert(has_function_privilege('authenticated','public.read_performance_tracking_history_v1(uuid,jsonb)','EXECUTE'), 'authenticated execution');
SELECT public.c2_assert(NOT EXISTS(SELECT 1 FROM pg_proc p,aclexplode(p.proacl) a
 WHERE p.oid='public.read_performance_tracking_history_v1(uuid,jsonb)'::regprocedure AND a.grantee=0 AND a.privilege_type='EXECUTE'), 'PUBLIC execution denied');
SELECT public.c2_assert((SELECT NOT p.prosecdef AND p.provolatile='s' AND l.lanname='sql'
 AND p.proconfig=ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
 WHERE p.oid='public.read_performance_tracking_history_v1(uuid,jsonb)'::regprocedure), 'stable invoker fixed search path');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',false);
DO $$ DECLARE r jsonb; claim jsonb := '{"assignment_id":"c2000000-0000-4000-8000-000000000020","occurrence_id":"c2000000-0000-4000-8000-000000000021","training_session_id":"987001","programme_version_id":"c2000000-0000-4000-8000-000000000022","package_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","slot_key":"synthetic.slot","protocol_id":"synthetic.protocol","protocol_revision":1,"block_id":"synthetic.block"}'; BEGIN
 PERFORM public.c2_assert(current_user='authenticated', 'permission proof uses authenticated role');
 -- Exercise owner RLS itself, not only pg_catalog ACL metadata.
 PERFORM public.c2_assert((SELECT count(*) FROM public.training_sessions WHERE id=987001)=1,
   'owner session SELECT succeeds under RLS');
 r:=public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010');
 PERFORM public.c2_assert(r->>'status'='ok' AND r#>>'{record,training_session_id}'='987001',
   'independent History with linked session succeeds with owner-only session SELECT');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim)->>'code'='programme_authority_unavailable',
   'same owned record with claim explicitly blocked, no fallback');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000030',claim)=
   public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000099',claim),
   'supplied claim does not distinguish foreign from absent');
 PERFORM public.c2_assert(r->>'status'='ok' AND jsonb_array_length(r->'blocks')=2
  AND jsonb_array_length(r->'exercises')=1 AND jsonb_array_length(r->'sets')=1001
  AND r#>>'{counts,sets}'='1001' AND r->>'complete_audit_set'='true', 'full tree beyond PostgREST max_rows');
 PERFORM public.c2_assert(r#>>'{blocks,1,status}'='skipped' AND r#>'{blocks,1,result_data}'='null'::jsonb, 'raw skipped missing value');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000030')=
  public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000099'),'foreign and absent indistinguishable');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim)->>'code'='programme_authority_unavailable','matching record links cannot bypass stopped join');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim||'{"protocol_id":"contradictory"}')->>'code'='programme_scope_conflict','contradictory retained protocol');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000040',claim)->>'code'='programme_scope_unproven','missing historical links');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim||'{"unexpected":true}')->>'code'='invalid_programme_claim','closed claim keys');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim-'block_id')->>'code'='invalid_programme_claim','partial claim');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim||'{"workout_id":"x"}')->>'code'='invalid_programme_claim','partial running identity');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim||'{"training_session_id":"9999999999999999999"}')->>'code'='invalid_programme_claim','out-of-range session identity');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010',claim||jsonb_build_object('block_id',repeat('x',16384)))->>'code'='invalid_programme_claim','claim input byte bound');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010','[]')->>'code'='invalid_programme_claim','malformed claim');
END $$;
-- Both existing corrections have identical transaction timestamps and incomplete
-- duration audit payloads. The read must retain both identities and raw inputs.
BEGIN;
SELECT public.correct_completed_performance_record('{"record_id":"c2000000-0000-4000-8000-000000000010","sets":[{"set_result_id":"c2100000-0000-4000-8000-000000000001","duration_seconds":13}]}');
SELECT public.correct_completed_performance_record('{"record_id":"c2000000-0000-4000-8000-000000000010","sets":[{"set_result_id":"c2100000-0000-4000-8000-000000000001","duration_seconds":14}]}');
COMMIT;
DO $$ DECLARE r jsonb; BEGIN
 r:=public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010');
 PERFORM public.c2_assert(jsonb_array_length(r->'corrections')=2, 'complete tied correction membership');
 PERFORM public.c2_assert(r#>>'{corrections,0,corrected_at}'=r#>>'{corrections,1,corrected_at}', 'timestamp ties preserved');
 PERFORM public.c2_assert(NOT (r#>'{corrections,0,after_values,set:c2100000-0000-4000-8000-000000000001}' ? 'duration_seconds'), 'incomplete audit not invented');
END $$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000002',false);
DO $$ BEGIN
 PERFORM public.c2_assert((SELECT count(*) FROM public.training_sessions WHERE id=987001)=0,
   'second athlete cannot read foreign session under RLS');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000030')->>'status'='ok',
   'second athlete independent own History read succeeds without session SELECT');
 PERFORM public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010')->>'status'='no_visible_record',
   'second athlete cannot read first athlete through RPC');
END $$;
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000003',false);
SELECT public.c2_assert((SELECT count(*) FROM public.training_session_records WHERE record_id='c2000000-0000-4000-8000-000000000010')=1,'coach RLS permits ordinary History');
SELECT public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010')->>'status'='no_visible_record','RPC still requires owner');
SELECT set_config('request.jwt.claim.sub','',false);
SELECT public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010')->>'code'='ownership_denied','unauthenticated identity denied');
RESET ROLE;

-- Output resource limits are errors, never apparently complete partial arrays.
BEGIN;
INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,position)
SELECT ('c2200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c2000000-0000-4000-8000-000000000012',n+1001,n+1001 FROM generate_series(1,10000) n;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010')->>'code'='evidence_limit_exceeded','row bound fails without truncation');
ROLLBACK;
BEGIN;
UPDATE public.training_session_records SET session_snapshot=jsonb_build_object('synthetic',repeat('x',4194304)) WHERE record_id='c2000000-0000-4000-8000-000000000040';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000040')->>'code'='evidence_limit_exceeded','byte bound fails without truncation');
ROLLBACK;
BEGIN;
REVOKE SELECT ON public.training_sessions FROM authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
SELECT public.c2_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010')->>'status'='ok',
 'independent RPC still succeeds with session SELECT revoked');
ROLLBACK;
\echo C2_HISTORY_SQL_GATE=PASS
