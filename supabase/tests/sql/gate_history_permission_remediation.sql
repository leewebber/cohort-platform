-- Role switches/claims represent ONLY synthetic users in the disposable DB.
BEGIN;
DO $$ DECLARE t text; role_name text; privilege text; expected boolean; BEGIN
 FOREACH t IN ARRAY ARRAY['training_sessions','training_session_records','training_block_results',
  'training_exercise_results','training_set_results','performance_result_corrections','coach_athlete_relationships','profiles'] LOOP
  FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
   FOREACH privilege IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'] LOOP
    expected:=role_name='authenticated' AND (privilege='SELECT' OR (privilege IN ('INSERT','UPDATE')
     AND t IN ('training_session_records','training_block_results','training_exercise_results','training_set_results','profiles')));
    PERFORM public.history_permission_assert(has_table_privilege(role_name,'public.'||t,privilege)=expected,role_name||' exact '||t||' '||privilege);
   END LOOP;
  END LOOP;
  PERFORM public.history_permission_assert(NOT EXISTS(SELECT 1 FROM pg_class c,aclexplode(c.relacl) x
   WHERE c.oid=('public.'||t)::regclass AND (x.grantee=0 OR (x.grantee IN ('anon'::regrole,'authenticated'::regrole) AND x.is_grantable))), 'no PUBLIC table grants or client grant options: '||t);
  PERFORM public.history_permission_assert(NOT EXISTS(SELECT 1 FROM pg_attribute a,aclexplode(a.attacl) x
   WHERE a.attrelid=('public.'||t)::regclass AND x.grantee IN (0,'anon'::regrole,'authenticated'::regrole)), 'no residual client column ACL: '||t);
 END LOOP;
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
  FOREACH privilege IN ARRAY ARRAY['SELECT','USAGE','UPDATE'] LOOP
   PERFORM public.history_permission_assert(NOT has_sequence_privilege(role_name,'public.training_sessions_id_seq',privilege),'server-only identity sequence');
  END LOOP;
 END LOOP;
 PERFORM public.history_permission_assert((SELECT relrowsecurity FROM pg_class WHERE oid='public.training_sessions'::regclass)
  AND (SELECT count(*) FROM pg_policy WHERE polrelid='public.training_sessions'::regclass)=1,'one enabled session owner-read policy');
END $$;

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub','',true);
DO $$ DECLARE t text; operation text; BEGIN
 PERFORM public.history_permission_assert(current_user='anon','actual anonymous SQL role');
 FOREACH t IN ARRAY ARRAY['training_sessions','training_session_records','training_block_results',
  'training_exercise_results','training_set_results','performance_result_corrections','coach_athlete_relationships','profiles'] LOOP
  FOREACH operation IN ARRAY ARRAY['SELECT * FROM public.%I LIMIT 1','INSERT INTO public.%I DEFAULT VALUES',
   'UPDATE','DELETE FROM public.%I WHERE false','TRUNCATE public.%I CASCADE'] LOOP
   BEGIN
    IF operation LIKE 'UPDATE%%' THEN
     IF t='training_sessions' THEN EXECUTE 'UPDATE public.training_sessions SET athlete_id=athlete_id WHERE false';
     ELSIF t='profiles' THEN EXECUTE 'UPDATE public.profiles SET display_name=display_name WHERE false';
     ELSE EXECUTE format('UPDATE public.%I SET %I=%I WHERE false',t,
      CASE t WHEN 'training_session_records' THEN 'athlete_id' WHEN 'training_block_results' THEN 'source_block_id'
       WHEN 'training_exercise_results' THEN 'position' WHEN 'training_set_results' THEN 'set_number'
       WHEN 'performance_result_corrections' THEN 'athlete_id' ELSE 'status' END,
      CASE t WHEN 'training_session_records' THEN 'athlete_id' WHEN 'training_block_results' THEN 'source_block_id'
       WHEN 'training_exercise_results' THEN 'position' WHEN 'training_set_results' THEN 'set_number'
       WHEN 'performance_result_corrections' THEN 'athlete_id' ELSE 'status' END); END IF;
    ELSE EXECUTE format(operation,t); END IF;
    RAISE EXCEPTION 'HISTORY_PERMISSION_GATE: anon operation accepted on %',t;
   EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
 END LOOP;
 BEGIN PERFORM public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010');
  RAISE EXCEPTION 'anon RPC accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
DO $$ DECLARE row_count integer; op text; t text; BEGIN
 PERFORM public.history_permission_assert(current_user='authenticated','actual authenticated SQL role');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_sessions WHERE id=987001)=1,'A reads own session for restore');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_sessions WHERE id=987010)=0,'A cannot read B session');
 FOREACH op IN ARRAY ARRAY['INSERT INTO public.training_sessions(athlete_id) VALUES (''c2000000-0000-4000-8000-000000000001'')',
  'UPDATE public.training_sessions SET status=''completed'' WHERE id=987001',
  'UPDATE public.training_sessions SET status=''completed'' WHERE id=987010',
  'DELETE FROM public.training_sessions WHERE id=987001','DELETE FROM public.training_sessions WHERE id=987010',
  'TRUNCATE public.training_sessions CASCADE'] LOOP
  BEGIN EXECUTE op; RAISE EXCEPTION 'direct session mutation accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
 -- Every scoped relation denies destructive client operations, independent of RLS.
 FOREACH t IN ARRAY ARRAY['training_sessions','training_session_records','training_block_results',
  'training_exercise_results','training_set_results','performance_result_corrections','coach_athlete_relationships','profiles'] LOOP
  FOREACH op IN ARRAY ARRAY['DELETE FROM public.%I WHERE false','TRUNCATE public.%I'] LOOP
   BEGIN EXECUTE format(op,t); RAISE EXCEPTION 'destructive authenticated operation accepted on %',t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
 END LOOP;
 -- Actual draft operations permitted by the existing in-progress RLS.
 INSERT INTO public.training_session_records(record_id,athlete_id,status,session_snapshot,started_at)
 VALUES('d7000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','in_progress','{}',now());
 INSERT INTO public.training_block_results(block_result_id,session_record_id,source_block_id,block_snapshot,status,result_type,result_data,position)
 VALUES('d7000000-0000-4000-8000-000000000002','d7000000-0000-4000-8000-000000000001','exact.distance',
  '{"sourceBlockId":"exact.distance"}','in_progress','distance','{"resultType":"distance","distanceUnit":"km","distance":0}',1);
 INSERT INTO public.training_exercise_results(exercise_result_id,block_result_id,exercise_snapshot,position)
 VALUES('d7000000-0000-4000-8000-000000000003','d7000000-0000-4000-8000-000000000002','{}',1);
 INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,position)
 VALUES('d7000000-0000-4000-8000-000000000004','d7000000-0000-4000-8000-000000000003',1,1);
 UPDATE public.training_session_records SET athlete_note='synthetic draft' WHERE record_id='d7000000-0000-4000-8000-000000000001';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=1,'own record update');
 UPDATE public.training_block_results SET athlete_note='synthetic draft' WHERE block_result_id='d7000000-0000-4000-8000-000000000002';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=1,'own block update');
 UPDATE public.training_exercise_results SET position=2 WHERE exercise_result_id='d7000000-0000-4000-8000-000000000003';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=1,'own exercise update');
 UPDATE public.training_set_results SET reps=1 WHERE set_result_id='d7000000-0000-4000-8000-000000000004';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=1,'own set update');
 UPDATE public.profiles SET display_name='Synthetic owner edit' WHERE id='c2000000-0000-4000-8000-000000000001';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=1,'existing self-profile update');
 UPDATE public.profiles SET display_name='foreign' WHERE id='c2000000-0000-4000-8000-000000000002';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=0,'foreign profile update denied');
END $$;

SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000002',true);
DO $$ DECLARE row_count integer; BEGIN
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_sessions WHERE id=987010)=1,'B reads own session');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_sessions WHERE id=987001)=0,'B cannot read A session');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_session_records WHERE record_id='d7000000-0000-4000-8000-000000000001')=0,'foreign discovery metadata absent');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_block_results WHERE block_result_id='d7000000-0000-4000-8000-000000000002')=0,'foreign block absent');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_exercise_results WHERE exercise_result_id='d7000000-0000-4000-8000-000000000003')=0,'foreign exercise absent');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_set_results WHERE set_result_id='d7000000-0000-4000-8000-000000000004')=0,'foreign set absent');
 UPDATE public.training_session_records SET athlete_note='foreign' WHERE record_id='d7000000-0000-4000-8000-000000000001';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=0,'foreign record update denied');
 UPDATE public.training_block_results SET athlete_note='foreign' WHERE block_result_id='d7000000-0000-4000-8000-000000000002';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=0,'foreign block update denied');
 UPDATE public.training_exercise_results SET position=9 WHERE exercise_result_id='d7000000-0000-4000-8000-000000000003';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=0,'foreign exercise update denied');
 UPDATE public.training_set_results SET reps=9 WHERE set_result_id='d7000000-0000-4000-8000-000000000004';
 GET DIAGNOSTICS row_count=ROW_COUNT; PERFORM public.history_permission_assert(row_count=0,'foreign set update denied');
 BEGIN INSERT INTO public.training_session_records(athlete_id,session_snapshot,status) VALUES('c2000000-0000-4000-8000-000000000001','{}','in_progress');
  RAISE EXCEPTION 'foreign record insert accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.training_block_results(session_record_id,source_block_id,block_snapshot,position)
  VALUES('d7000000-0000-4000-8000-000000000001','foreign','{}',2);
  RAISE EXCEPTION 'foreign child insert accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM public.history_permission_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010')=
  public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000099'),'foreign and absent C2 envelopes equal');
END $$;

SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000003',true);
DO $$ DECLARE row_count integer; BEGIN
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_session_records WHERE record_id='c2000000-0000-4000-8000-000000000010')=1,'linked coach History access');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_block_results WHERE session_record_id='c2000000-0000-4000-8000-000000000010')=2,'linked coach child access');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_sessions WHERE id=987001)=0,'no invented coach session-table access');
 PERFORM public.history_permission_assert(public.read_performance_tracking_history_v1('c2000000-0000-4000-8000-000000000010')->>'status'='no_visible_record','C2 requires owner despite coach History visibility');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.performance_result_corrections WHERE record_id='c2000000-0000-4000-8000-000000000010')=0,'coach correction audits remain owner-only');
 BEGIN INSERT INTO public.coach_athlete_relationships(coach_id,athlete_id,status)
  VALUES('c2000000-0000-4000-8000-000000000003','c2000000-0000-4000-8000-000000000002','active');
  RAISE EXCEPTION 'client relationship forge accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE public.coach_athlete_relationships SET status='ended'
WHERE coach_id='c2000000-0000-4000-8000-000000000003' AND athlete_id='c2000000-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000003',true);
SELECT public.history_permission_assert((SELECT count(*) FROM public.training_session_records WHERE record_id='c2000000-0000-4000-8000-000000000010')=0,'ended coach relationship denies History');
RESET ROLE;
ROLLBACK;
\echo HISTORY_PERMISSION_EXACT_ACL_AND_ROLE_GATE=PASS
