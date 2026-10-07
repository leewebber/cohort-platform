-- Synthetic disposable ownership proof; every mutation rolls back, even failure.
-- Requires Gate Q's published package/assignment fixture. No real identities.
BEGIN;
DO $$ DECLARE p jsonb; actor uuid; started jsonb; resumed jsonb; result jsonb;
 foreign_status text; own_session bigint; BEGIN
 SELECT payload,athlete_id INTO p,actor FROM public.sprint12_gate_q_fixture WHERE fixture_key='concurrency';
 PERFORM public.history_permission_assert(p IS NOT NULL,'canonical ownership fixture present');
 -- A foreign in-progress session; ownership is different from Q's caller.
 UPDATE public.training_sessions SET status='in_progress',completed_at=NULL WHERE id=987010;
 PERFORM set_config('request.jwt.claim.sub',actor::text,true);
 PERFORM set_config('role','authenticated',true);
 PERFORM public.history_permission_assert(current_user='authenticated','canonical proof actual authenticated role');
 started:=public.create_or_resume_programme_training_session(p);
 resumed:=public.create_or_resume_programme_training_session(p);
 own_session:=(started#>>'{training_session,id}')::bigint;
 PERFORM public.history_permission_assert(started->>'status'='created' AND resumed->>'status'='resumed'
  AND (resumed#>>'{training_session,id}')::bigint=own_session,'canonical owned start and resume');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_sessions WHERE id=own_session)=1,'canonical restore reads own created session');
 PERFORM public.history_permission_assert((SELECT count(*) FROM public.training_sessions WHERE id=987010)=0,'foreign target not visible before RPC');
 result:=public.complete_programme_session_and_advance(p||jsonb_build_object(
  'protocol_id',p->>'planned_protocol_id','logical_completion_key',p->>'programmed_session_key',
  'idempotency_key','permission-foreign-owner-probe','actuals_fingerprint','permission-synthetic-fingerprint',
  'training_session_id',987010,'record_id','d7300000-0000-4000-8000-000000000001','status','completed',
  'completion_record',jsonb_build_object('session_snapshot','{}'::jsonb,'source_protocol_id',p->>'planned_protocol_id')));
 PERFORM set_config('role','postgres',true);
 SELECT status INTO foreign_status FROM public.training_sessions WHERE id=987010;
 IF foreign_status IS DISTINCT FROM 'in_progress' OR result->>'status'='committed' THEN
  RAISE EXCEPTION 'HISTORY_PERMISSION_BLOCKED: rpc_committed=% foreign_parent_changed=%',
   result->>'status'='committed', foreign_status IS DISTINCT FROM 'in_progress';
 END IF;
END $$;
ROLLBACK;
\echo HISTORY_PERMISSION_CANONICAL_COMPLETION_OWNER=PASS
