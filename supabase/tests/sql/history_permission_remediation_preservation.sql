DO $$ DECLARE t record; d text; BEGIN
 FOR t IN SELECT * FROM public.history_permission_data_before LOOP
  EXECUTE format('SELECT md5(coalesce(string_agg(to_jsonb(t)::text, chr(10) ORDER BY to_jsonb(t)::text),%L)) FROM public.%I t','',t.relation_name) INTO d;
  PERFORM public.history_permission_assert(d=t.digest,'existing public evidence unchanged: '||t.relation_name);
 END LOOP;
 PERFORM public.history_permission_assert(NOT EXISTS(SELECT 1 FROM public.history_permission_functions_before b
  LEFT JOIN pg_proc p ON p.oid=b.oid WHERE p.oid IS NULL OR md5(pg_get_functiondef(p.oid))<>b.digest OR p.proacl::text IS DISTINCT FROM b.acl), 'all existing public functions and grants unchanged');
 PERFORM public.history_permission_assert(NOT EXISTS(
  (SELECT polrelid,polname,polcmd,polroles,polpermissive,pg_get_expr(polqual,polrelid),pg_get_expr(polwithcheck,polrelid)
   FROM pg_policy WHERE polrelid<>'public.training_sessions'::regclass EXCEPT SELECT * FROM public.history_permission_policies_before)
  UNION ALL (SELECT * FROM public.history_permission_policies_before EXCEPT
   SELECT polrelid,polname,polcmd,polroles,polpermissive,pg_get_expr(polqual,polrelid),pg_get_expr(polwithcheck,polrelid)
   FROM pg_policy WHERE polrelid<>'public.training_sessions'::regclass)), 'all other RLS policies unchanged');
 PERFORM public.history_permission_assert(NOT EXISTS(SELECT 1 FROM public.history_permission_server_grants_before
  WHERE allowed IS DISTINCT FROM has_table_privilege(rolname,oid,privilege)), 'postgres and service-role table operations unchanged');
END $$;
\echo HISTORY_PERMISSION_REPLAY_AND_EVIDENCE_PRESERVATION=PASS
