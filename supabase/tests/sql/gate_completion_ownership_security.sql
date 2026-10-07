-- Local synthetic-role isolation and zero-residue proof; rollback all SQL probes.
CREATE FUNCTION public.completion_security_digest() RETURNS text LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,pg_temp AS $$
DECLARE t text; part text; acc text:=''; BEGIN
 FOREACH t IN ARRAY ARRAY['training_sessions','training_session_records','training_block_results',
  'training_exercise_results','training_set_results','programme_slot_outcomes','programme_assignments',
  'programme_schedule_occurrences','performance_result_corrections'] LOOP
  EXECUTE format('SELECT coalesce(string_agg(to_jsonb(x)::text,chr(10) ORDER BY to_jsonb(x)::text),%L) FROM public.%I x','',t) INTO part;
  acc:=acc||t||part;
 END LOOP; RETURN md5(acc);
END $$;
BEGIN;
DO $$ DECLARE fn text; BEGIN
 FOREACH fn IN ARRAY ARRAY['cohort_completion_programme_body_v1(jsonb)','cohort_completion_fixed_body_v1(jsonb)',
  'cohort_completion_standalone_body_v1(jsonb)','cohort_completion_correction_body_v1(jsonb)',
  'cohort_completion_backfill_body_v1(jsonb,timestamptz)','cohort_assert_completion_request_v1(jsonb,text)',
  'cohort_assert_record_parent_v1(public.training_session_records)','cohort_sync_training_session_from_terminal_record()',
  'cohort_guard_completion_record_identity_v1()','cohort_complete_backfilled_fixed_occurrence_at(jsonb,timestamptz)'] LOOP
  PERFORM public.history_permission_assert(NOT has_function_privilege('anon','public.'||fn,'EXECUTE')
   AND NOT has_function_privilege('authenticated','public.'||fn,'EXECUTE')
   AND NOT has_function_privilege('service_role','public.'||fn,'EXECUTE'),'no unguarded client/server bypass: '||fn);
 END LOOP;
 FOREACH fn IN ARRAY ARRAY['complete_programme_session_and_advance(jsonb)','complete_fixed_programme_occurrence_and_advance(jsonb)',
  'complete_training_session_record(jsonb)','correct_completed_performance_record(jsonb)','complete_backfilled_fixed_programme_occurrence(jsonb)'] LOOP
  PERFORM public.history_permission_assert(has_function_privilege('authenticated','public.'||fn,'EXECUTE')
   AND NOT has_function_privilege('anon','public.'||fn,'EXECUTE'),'only authenticated completion access: '||fn);
  PERFORM public.history_permission_assert(has_function_privilege('service_role','public.'||fn,'EXECUTE')=
   (fn IN ('complete_programme_session_and_advance(jsonb)','complete_fixed_programme_occurrence_and_advance(jsonb)','complete_training_session_record(jsonb)')),'exact retained server entrypoint ACL: '||fn);
  PERFORM public.history_permission_assert(NOT EXISTS(SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) acl
   WHERE p.oid=('public.'||fn)::regprocedure AND acl.grantee<>p.proowner AND
    (acl.grantee NOT IN ('authenticated'::regrole,'service_role'::regrole) OR acl.is_grantable)),'no PUBLIC/other client/grant-option bypass: '||fn);
 END LOOP;
END $$;
INSERT INTO public.training_sessions(id,athlete_id,protocol_id,status) VALUES
 (987101,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','security.standalone','in_progress'),
 (987111,'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','security.standalone','in_progress');
INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,source_protocol_id,status,session_snapshot,started_at)
 VALUES('d7500000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',987101,'security.standalone','in_progress','{}',now()),
 ('d7500000-0000-4000-8000-000000000011','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',987111,'security.standalone','in_progress','{}',now());
INSERT INTO public.training_block_results(block_result_id,session_record_id,source_block_id,block_snapshot,status,result_type,result_data,position)
 VALUES('d7500000-0000-4000-8000-000000000002','d7500000-0000-4000-8000-000000000001','security.block','{"sourceBlockId":"security.block"}','completed','distance','{"resultType":"distance","distance":0,"distanceUnit":"km"}',1),
 ('d7500000-0000-4000-8000-000000000012','d7500000-0000-4000-8000-000000000011','security.block','{"sourceBlockId":"security.block"}','completed','distance','{"resultType":"distance","distance":0,"distanceUnit":"km"}',1);
DO $$ DECLARE actor text:='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; p jsonb; bad jsonb; r jsonb;
 o public.programme_slot_outcomes%ROWTYPE; a public.programme_assignments%ROWTYPE;
 before text; denied jsonb:='{"status":"authorization_failure","code":"completion_identity_denied"}';
 standalone jsonb; label text; foreign_assignment uuid; n int:=0; BEGIN
 SELECT id INTO foreign_assignment FROM public.programme_assignments WHERE athlete_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' LIMIT 1;
 PERFORM public.history_permission_assert(foreign_assignment IS NOT NULL,'foreign assignment fixture exists before role switch');
 SELECT * INTO o FROM public.programme_slot_outcomes WHERE completion_record_id='11111111-1111-4111-8111-111111111111';
 SELECT * INTO a FROM public.programme_assignments WHERE id=o.assignment_id;
 p:=jsonb_build_object('assignment_id',a.id,'session_slot_id',o.session_slot_id,'programme_version_id',a.programme_version_id,
  'materialised_package_content_hash',a.materialised_package_content_hash,'programmed_session_key',o.programmed_session_key,
  'logical_completion_key',o.logical_completion_key,'idempotency_key',o.idempotency_key,'actuals_fingerprint',o.actuals_fingerprint,
  'protocol_id','PROT-GATE-L-A','expected_week',1,'expected_day_key','day_1','expected_slot_order',1,
  'training_session_id',o.training_session_id,'record_id',o.completion_record_id,'status','completed',
  'completion_record',jsonb_build_object('source_protocol_id','PROT-GATE-L-A','session_snapshot','{}'::jsonb));
 PERFORM public.history_permission_assert(a.id IS NOT NULL,'active two-slot retry fixture');
 PERFORM set_config('request.jwt.claim.sub',actor,true); PERFORM set_config('role','authenticated',true);
 PERFORM public.history_permission_assert(current_user='authenticated','actual athlete SQL role');
 before:=public.completion_security_digest();
 r:=public.complete_programme_session_and_advance(p);
 PERFORM public.history_permission_assert(r->>'status'='already_committed','same-ID programme retry remains functional');
 PERFORM public.history_permission_assert(before=public.completion_security_digest(),'retry changes no rows');
 FOREACH label IN ARRAY ARRAY['foreign_parent','absent_parent','own_substituted_parent','foreign_record','absent_substituted_record',
  'own_rebound_record','inner_foreign_parent','inner_foreign_actor','inner_foreign_record','inner_foreign_assignment',
  'foreign_assignment','absent_assignment','wrong_slot','wrong_protocol','wrong_hash'] LOOP
  bad:=p;
  CASE label
   WHEN 'foreign_parent' THEN bad:=p||'{"training_session_id":987111}';
   WHEN 'absent_parent' THEN bad:=p||'{"training_session_id":987999}';
   WHEN 'own_substituted_parent' THEN bad:=p||'{"training_session_id":987101}';
   WHEN 'foreign_record' THEN bad:=p||'{"record_id":"d7500000-0000-4000-8000-000000000011"}';
   WHEN 'absent_substituted_record' THEN bad:=p||'{"record_id":"d7500000-0000-4000-8000-000000000099"}';
   WHEN 'own_rebound_record' THEN bad:=p||'{"record_id":"d7500000-0000-4000-8000-000000000001"}';
   WHEN 'inner_foreign_parent' THEN bad:=jsonb_set(p,'{completion_record,training_session_id}','987111');
   WHEN 'inner_foreign_actor' THEN bad:=jsonb_set(p,'{completion_record,athlete_id}','"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"');
   WHEN 'inner_foreign_record' THEN bad:=jsonb_set(p,'{completion_record,record_id}','"d7500000-0000-4000-8000-000000000011"');
   WHEN 'inner_foreign_assignment' THEN bad:=jsonb_set(p,'{completion_record,assignment_id}','"d7500000-0000-4000-8000-000000000099"');
   WHEN 'foreign_assignment' THEN bad:=p||jsonb_build_object('assignment_id',foreign_assignment);
   WHEN 'absent_assignment' THEN bad:=p||'{"assignment_id":"d7500000-0000-4000-8000-000000000099"}';
   WHEN 'wrong_slot' THEN bad:=p||'{"session_slot_id":"d7500000-0000-4000-8000-000000000099"}';
   WHEN 'wrong_protocol' THEN bad:=p||'{"protocol_id":"foreign.protocol"}';
   WHEN 'wrong_hash' THEN bad:=p||'{"materialised_package_content_hash":"foreign.hash"}';
  END CASE;
  before:=public.completion_security_digest(); r:=public.complete_programme_session_and_advance(bad);
  PERFORM public.history_permission_assert(r=denied,'uniform programme denial: '||label);
  PERFORM public.history_permission_assert(before=public.completion_security_digest(),'zero residue: '||label); n:=n+1;
 END LOOP;
 -- Each affected public completion route rejects foreign/missing identities uniformly.
 standalone:=jsonb_build_object('record_id','d7500000-0000-4000-8000-000000000001','athlete_id',actor,
  'training_session_id',987101,'source_protocol_id','security.standalone','status','completed','session_snapshot','{}'::jsonb,'started_at',now(),'completed_at',now());
 FOREACH label IN ARRAY ARRAY['foreign_parent','absent_parent','foreign_actor','foreign_record','inner_programme'] LOOP
  bad:=standalone;
  CASE label WHEN 'foreign_parent' THEN bad:=bad||'{"training_session_id":987111}';
   WHEN 'absent_parent' THEN bad:=bad||'{"training_session_id":987999}';
   WHEN 'foreign_actor' THEN bad:=bad||'{"athlete_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
   WHEN 'foreign_record' THEN bad:=bad||'{"record_id":"d7500000-0000-4000-8000-000000000011"}';
   WHEN 'inner_programme' THEN bad:=bad||jsonb_build_object('assignment_id',a.id);
  END CASE;
  before:=public.completion_security_digest(); r:=public.complete_training_session_record(bad);
  PERFORM public.history_permission_assert(r=denied,'uniform standalone denial: '||label);
  PERFORM public.history_permission_assert(before=public.completion_security_digest(),'standalone zero residue'); n:=n+1;
 END LOOP;
 FOREACH label IN ARRAY ARRAY['c2000000-0000-4000-8000-000000000081','d7500000-0000-4000-8000-000000000099'] LOOP
  before:=public.completion_security_digest();
  bad:=p||jsonb_build_object('occurrence_id',label);
  r:=public.complete_fixed_programme_occurrence_and_advance(bad);
  PERFORM public.history_permission_assert(r=denied,'fixed foreign/absent occurrence denied');
  PERFORM public.history_permission_assert(before=public.completion_security_digest(),'fixed zero cursor/parent residue');
  r:=public.complete_backfilled_fixed_programme_occurrence(bad);
  PERFORM public.history_permission_assert(r=denied,'backfill foreign/absent occurrence denied');
  PERFORM public.history_permission_assert(before=public.completion_security_digest(),'backfill zero residue'); n:=n+2;
 END LOOP;
 -- Independent AFTER-trigger defence: a trusted historical seed cannot close
 -- a foreign parent even with the new BEFORE guard disabled in this subtransaction.
 PERFORM set_config('role','postgres',true);
 before:=public.completion_security_digest();
 ALTER TABLE public.training_session_records DISABLE TRIGGER guard_completion_record_identity_v1;
 BEGIN INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,status,session_snapshot,started_at)
  VALUES('d7500000-0000-4000-8000-000000000098',actor,987111,'completed','{}',now());
  RAISE EXCEPTION 'AFTER trigger allowed foreign parent'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 ALTER TABLE public.training_session_records ENABLE TRIGGER guard_completion_record_identity_v1;
 PERFORM public.history_permission_assert(before=public.completion_security_digest(),'independent parent trigger has zero residue');
 PERFORM set_config('role','authenticated',true);
 -- Direct record writes reject cross-owner binding and immutable identity substitution.
 before:=public.completion_security_digest();
 BEGIN UPDATE public.training_session_records SET training_session_id=987111,status='completed'
  WHERE record_id='d7500000-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'direct record parent reassignment accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,status,session_snapshot,started_at)
  VALUES('d7500000-0000-4000-8000-000000000098',actor,987111,'completed','{}',now());
  RAISE EXCEPTION 'forged record parent accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN INSERT INTO public.training_block_results(session_record_id,source_block_id,block_snapshot,position)
  VALUES('d7500000-0000-4000-8000-000000000011','forged','{}',2);
  RAISE EXCEPTION 'foreign child insertion accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.training_block_results SET result_data='{"resultType":"distance","distance":1,"distanceUnit":"km"}'
 WHERE block_result_id='d7500000-0000-4000-8000-000000000012';
 GET DIAGNOSTICS n=ROW_COUNT; PERFORM public.history_permission_assert(n=0,'foreign child update hidden');
 PERFORM public.history_permission_assert(before=public.completion_security_digest(),'direct write denials leave all evidence unchanged');
 -- Own standalone terminal completion, retry and authorised correction.
 r:=public.complete_training_session_record(standalone);
 PERFORM public.history_permission_assert(r->>'status'='completed','own standalone completion');
 before:=public.completion_security_digest(); r:=public.complete_training_session_record(standalone);
 PERFORM public.history_permission_assert(r->>'record_id'=standalone->>'record_id' AND before=public.completion_security_digest(),'standalone exact retry without duplicate');
 r:=public.correct_completed_performance_record(jsonb_build_object('record_id',standalone->>'record_id',
  'blocks',jsonb_build_array(jsonb_build_object('block_result_id','d7500000-0000-4000-8000-000000000002',
   'result_data','{"resultType":"distance","distance":1,"distanceUnit":"km"}'::jsonb))));
 PERFORM public.history_permission_assert(r->>'status'='corrected','own correction preserved');
 FOREACH bad IN ARRAY ARRAY[
  '{"record_id":"d7500000-0000-4000-8000-000000000011","overall_rpe":5}'::jsonb,
  '{"record_id":"d7500000-0000-4000-8000-000000000099","overall_rpe":5}'::jsonb,
  '{"record_id":"d7500000-0000-4000-8000-000000000001","training_session_id":987111,"overall_rpe":5}'::jsonb,
  '{"record_id":"d7500000-0000-4000-8000-000000000001","athlete_note":"must roll back","blocks":[{"block_result_id":"d7500000-0000-4000-8000-000000000012","result_data":{"resultType":"distance","distance":2,"distanceUnit":"km"}}]}'::jsonb
 ] LOOP
  before:=public.completion_security_digest();
  BEGIN PERFORM public.correct_completed_performance_record(bad); RAISE EXCEPTION 'forged correction accepted';
   EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public.history_permission_assert(before=public.completion_security_digest(),'correction denial has zero residue');
 END LOOP;
 PERFORM set_config('role','postgres',true);
 PERFORM public.history_permission_assert((SELECT status='completed' FROM public.training_sessions WHERE id=987101),'standalone parent closes via bounded trigger');
 PERFORM public.history_permission_assert((SELECT status='in_progress' FROM public.training_sessions WHERE id=987111),'foreign parent never changes');
END $$;
-- Retained real link chain, not merely a foreign occurrence token: both fixed
-- entrypoints reject substitutions on an occurrence actually owned by the caller.
DO $$ DECLARE occ public.programme_schedule_occurrences%ROWTYPE; o public.programme_slot_outcomes%ROWTYPE;
 p jsonb; bad jsonb; r jsonb; before text;
 denied jsonb:='{"status":"authorization_failure","code":"completion_identity_denied"}'; BEGIN
 SELECT * INTO occ FROM public.programme_schedule_occurrences WHERE id='c2000000-0000-4000-8000-000000000081';
 SELECT * INTO o FROM public.programme_slot_outcomes WHERE assignment_id=occ.assignment_id AND session_slot_id=occ.session_slot_id;
 p:=jsonb_build_object('assignment_id',occ.assignment_id,'occurrence_id',occ.id,'session_slot_id',occ.session_slot_id,
  'programme_version_id',occ.programme_version_id,'materialised_package_content_hash',occ.package_content_hash,
  'programmed_session_key',occ.programmed_session_key,'logical_completion_key',occ.programmed_session_key,
  'protocol_id',occ.protocol_id,'expected_week',occ.week_number,'expected_day_key',occ.day_key,'expected_slot_order',occ.session_order,
  'record_id',o.completion_record_id,'training_session_id',o.training_session_id,'status','completed');
 PERFORM set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
 PERFORM set_config('role','authenticated',true);
 FOREACH bad IN ARRAY ARRAY[p||'{"training_session_id":987010}',p||'{"training_session_id":987999}',
  p||'{"record_id":"d7500000-0000-4000-8000-000000000099"}'] LOOP
  before:=public.completion_security_digest(); r:=public.complete_fixed_programme_occurrence_and_advance(bad);
  PERFORM public.history_permission_assert(r=denied AND before=public.completion_security_digest(),'owned fixed occurrence rejects substituted parent/record without residue');
 END LOOP;
 FOREACH bad IN ARRAY ARRAY[p||'{"training_session_id":987010}',
  (p-'training_session_id')||'{"record_id":"c2000000-0000-4000-8000-000000000010"}',
  (p-'training_session_id')||'{"completion_record":{"training_session_id":987010}}'] LOOP
  before:=public.completion_security_digest(); r:=public.complete_backfilled_fixed_programme_occurrence(bad);
  PERFORM public.history_permission_assert(r=denied AND before=public.completion_security_digest(),'owned backfill occurrence rejects nominated parent/rebound existing record without residue');
 END LOOP;
 PERFORM set_config('role','postgres',true);
END $$;
ROLLBACK;
-- Persistent synthetic fixtures used by the subsequent loopback API proof only.
INSERT INTO public.training_sessions(id,athlete_id,protocol_id,status) VALUES
 (987121,'c2000000-0000-4000-8000-000000000001','security.http','in_progress');
\echo COMPLETION_OWNERSHIP_ROLE_SECURITY=PASS
