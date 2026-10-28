-- Execute as postgres only in the disposable local gate.
CREATE FUNCTION pg_temp.m24_evidence_digest() RETURNS text LANGUAGE plpgsql AS $$
DECLARE t text; part text; acc text:=''; BEGIN
 FOREACH t IN ARRAY ARRAY['training_sessions','training_session_records','training_block_results',
  'training_exercise_results','training_set_results','programme_slot_outcomes','programme_assignments',
  'programme_schedule_occurrences','performance_result_corrections'] LOOP
  EXECUTE format('SELECT coalesce(string_agg(to_jsonb(x)::text,chr(10) ORDER BY to_jsonb(x)::text),%L) FROM public.%I x','',t) INTO part;
  acc:=acc||t||part;
 END LOOP; RETURN md5(acc);
END $$;
CREATE TEMP TABLE m24_before AS SELECT pg_temp.m24_evidence_digest() AS evidence,
 (SELECT jsonb_agg(jsonb_build_array(p.oid,p.proowner,p.proacl,pg_get_functiondef(p.oid)) ORDER BY p.oid)
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND (p.proname LIKE '%completion%' OR p.proname='correct_completed_performance_record')) AS definitions;
\i /tmp/m24-migration.sql
DO $$ DECLARE fn text; r text; after_definitions jsonb; BEGIN
 IF (SELECT evidence FROM m24_before) IS DISTINCT FROM pg_temp.m24_evidence_digest() THEN
  RAISE EXCEPTION 'M24 replay changed application evidence'; END IF;
 SELECT jsonb_agg(jsonb_build_array(p.oid,p.proowner,p.proacl,pg_get_functiondef(p.oid)) ORDER BY p.oid) INTO after_definitions
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND (p.proname LIKE '%completion%' OR p.proname='correct_completed_performance_record');
 IF (SELECT definitions FROM m24_before) IS DISTINCT FROM after_definitions THEN
  RAISE EXCEPTION 'M24 replay changed callable identity, ACL or definition'; END IF;
 FOREACH fn IN ARRAY ARRAY['cohort_completion_request_sha256_v1(jsonb)',
  'cohort_replay_programme_completion_v1(jsonb,boolean)','cohort_guard_completion_receipt_v1()'] LOOP
  FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
   IF has_function_privilege(r,'public.'||fn,'EXECUTE') THEN RAISE EXCEPTION 'M24 helper callable: % %',r,fn; END IF;
  END LOOP;
 END LOOP;
 FOREACH fn IN ARRAY ARRAY['complete_programme_session_and_advance(jsonb)',
  'complete_fixed_programme_occurrence_and_advance(jsonb)'] LOOP
  IF has_function_privilege('anon','public.'||fn,'EXECUTE') OR
   NOT has_function_privilege('authenticated','public.'||fn,'EXECUTE') OR
   NOT has_function_privilege('service_role','public.'||fn,'EXECUTE') THEN
   RAISE EXCEPTION 'M24 public ACL drift: %',fn; END IF;
 END LOOP;
 IF has_column_privilege('authenticated','public.programme_slot_outcomes','completion_request_sha256','UPDATE') THEN
  RAISE EXCEPTION 'M24 receipt writable by client'; END IF;
END $$;
\echo M24_REPLAY_EVIDENCE_OIDS_ACL=PASS
