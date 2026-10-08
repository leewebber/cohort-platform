-- Synthetic backfill child collisions and exact-edge preservation; no real data.
BEGIN;
SELECT set_config('cohort.allow_materialisation_write','on',true);
SELECT set_config('cohort.allow_schedule_write','on',true);
UPDATE public.programme_assignments SET status='paused' WHERE athlete_id='c2000000-0000-4000-8000-000000000001' AND status='active';
INSERT INTO public.programme_assignments(id,athlete_id,programme_version_id,lineage_code,status,started_at,timezone,
 materialised_at,materialisation_source,materialised_package_content_hash,materialised_package_schema_version,schedule_mode)
SELECT 'd8100000-0000-4000-8000-000000000001',athlete_id,programme_version_id,lineage_code,'active','2026-01-01',timezone,
 materialised_at,materialisation_source,materialised_package_content_hash,materialised_package_schema_version,'fixed_schedule'
FROM public.programme_assignments WHERE id='c2000000-0000-4000-8000-000000000080';
INSERT INTO public.programme_schedule_projections(assignment_id,athlete_id,programme_version_id,package_content_hash,timezone,started_at)
SELECT id,athlete_id,programme_version_id,materialised_package_content_hash,timezone,started_at FROM public.programme_assignments
WHERE id='d8100000-0000-4000-8000-000000000001';
INSERT INTO public.programme_schedule_occurrences(id,assignment_id,session_slot_id,programme_version_id,package_content_hash,
 week_number,day_key,session_order,protocol_id,programmed_session_key,scheduled_date,disposition)
SELECT 'd8100000-0000-4000-8000-000000000002',a.id,o.session_slot_id,a.programme_version_id,a.materialised_package_content_hash,
 o.week_number,o.day_key,o.session_order,o.protocol_id,
 public.cohort_programme_schedule_programmed_session_key(a.id,a.programme_version_id,o.week_number,o.day_key,o.session_order,o.protocol_id),
 '2026-01-01','missed' FROM public.programme_assignments a CROSS JOIN public.programme_schedule_occurrences o
 WHERE a.id='d8100000-0000-4000-8000-000000000001' AND o.id='c2000000-0000-4000-8000-000000000081';
INSERT INTO public.training_block_results(block_result_id,session_record_id,source_block_id,block_snapshot,status,result_type,position)
VALUES('d8100000-0000-4000-8000-000000000011','c2000000-0000-4000-8000-000000000030','foreign','{}','completed','completion',1);
INSERT INTO public.training_exercise_results(exercise_result_id,block_result_id,exercise_snapshot,position)
VALUES('d8100000-0000-4000-8000-000000000013','d8100000-0000-4000-8000-000000000011','{}',1);
INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,position)
VALUES('d8100000-0000-4000-8000-000000000014','d8100000-0000-4000-8000-000000000013',1,1);
DO $$ DECLARE p jsonb; r jsonb; before text; label text; block_id uuid; exercise_id uuid; set_id uuid; tree jsonb; BEGIN
 p:=jsonb_build_object('assignment_id','d8100000-0000-4000-8000-000000000001',
  'occurrence_id','d8100000-0000-4000-8000-000000000002','record_id','d8100000-0000-4000-8000-000000000003',
  'idempotency_key','backfill:c2000000-0000-4000-8000-000000000001:d8100000-0000-4000-8000-000000000001:d8100000-0000-4000-8000-000000000002',
  'actuals_fingerprint','child-collision-proof','status','completed','performed_on','2026-01-01',
  'completion_record',jsonb_build_object('session_snapshot','{}'::jsonb,'block_results',jsonb_build_array(
   jsonb_build_object('block_result_id','d8100000-0000-4000-8000-000000000011','status','completed','result_type','completion',
    'exercise_results',jsonb_build_array(jsonb_build_object('exercise_result_id','d8100000-0000-4000-8000-000000000012','exercise_snapshot','{}'::jsonb))))));
 FOREACH label IN ARRAY ARRAY['foreign_block','foreign_exercise','foreign_set','own_other_block'] LOOP
  block_id:='d8100000-0000-4000-8000-000000000021'; exercise_id:='d8100000-0000-4000-8000-000000000022'; set_id:='d8100000-0000-4000-8000-000000000023';
  CASE label WHEN 'foreign_block' THEN block_id:='d8100000-0000-4000-8000-000000000011';
   WHEN 'foreign_exercise' THEN exercise_id:='d8100000-0000-4000-8000-000000000013';
   WHEN 'foreign_set' THEN set_id:='d8100000-0000-4000-8000-000000000014';
   WHEN 'own_other_block' THEN block_id:='c2000000-0000-4000-8000-000000000011'; END CASE;
  tree:=jsonb_build_array(jsonb_build_object('block_result_id',block_id,'status','completed','result_type','completion',
   'exercise_results',jsonb_build_array(jsonb_build_object('exercise_result_id',exercise_id,'exercise_snapshot','{}'::jsonb,
    'set_results',jsonb_build_array(jsonb_build_object('set_result_id',set_id,'set_number',1,'position',1))))));
  p:=jsonb_set(p,'{completion_record,block_results}',tree);
  before:=public.completion_security_digest();
  PERFORM set_config('request.jwt.claim.sub','c2000000-0000-4000-8000-000000000001',true);
  PERFORM set_config('role','authenticated',true);
  r:=public.complete_backfilled_fixed_programme_occurrence(p);
  PERFORM public.history_permission_assert(r='{"status":"authorization_failure","code":"completion_identity_denied"}'::jsonb
   AND before=public.completion_security_digest(),'backfill exact child collision denied with zero residue: '||label);
  PERFORM set_config('role','postgres',true);
 END LOOP;
 -- The legitimate tree can still complete partially and reconcile a second device.
 p:=jsonb_set(p,'{completion_record,block_results}',jsonb_build_array(jsonb_build_object(
  'block_result_id','d8100000-0000-4000-8000-000000000021','status','completed','result_type','completion')))||'{"status":"partially_completed"}';
 PERFORM set_config('role','authenticated',true); r:=public.complete_backfilled_fixed_programme_occurrence(p);
 PERFORM public.history_permission_assert(r->>'status'='committed','owned backfill partial tree preserved');
 before:=public.completion_security_digest();
 r:=public.complete_backfilled_fixed_programme_occurrence(p||'{"record_id":"d8100000-0000-4000-8000-000000000099"}');
 PERFORM public.history_permission_assert(r->>'status'='already_committed' AND before=public.completion_security_digest(),'second-device logical retry preserves winner identity');
 PERFORM set_config('role','postgres',true);
END $$;
DO $$ DECLARE fn text; BEGIN
 FOREACH fn IN ARRAY ARRAY['complete_programme_session_and_advance','complete_fixed_programme_occurrence_and_advance',
  'complete_training_session_record','correct_completed_performance_record','complete_backfilled_fixed_programme_occurrence'] LOOP
  PERFORM public.history_permission_assert((SELECT count(*)=1 AND bool_and(oid=(('public.'||fn||'(jsonb)')::regprocedure)::oid)
   FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=fn),'no alternate completion overload: '||fn);
 END LOOP;
 FOREACH fn IN ARRAY ARRAY['cohort_guard_direct_result_write_v1()','cohort_guard_result_identity_v1()','cohort_insert_training_session_result_tree(uuid,jsonb)'] LOOP
  PERFORM public.history_permission_assert(NOT has_function_privilege('anon','public.'||fn,'EXECUTE')
   AND NOT has_function_privilege('authenticated','public.'||fn,'EXECUTE')
   AND NOT has_function_privilege('service_role','public.'||fn,'EXECUTE'),'private child helper ACL: '||fn);
 END LOOP;
 PERFORM public.history_permission_assert((SELECT count(*)=6 AND bool_and(tgenabled='O') FROM pg_trigger
  WHERE tgname IN ('guard_result_identity_v1','guard_direct_result_write_v1') AND tgrelid IN ('public.training_block_results'::regclass,
   'public.training_exercise_results'::regclass,'public.training_set_results'::regclass)),'all child identity triggers enabled');
END $$;
ROLLBACK;
\echo COMPLETION_CHILD_IDENTITY_SECURITY=PASS
