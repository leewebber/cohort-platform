-- SELECT-only catalogue/schema/five-consumer guard query; no restricted system identifier call.
SELECT jsonb_build_object(
      'identity',jsonb_build_object('database',current_database(),'role',current_user,
        'session_user',session_user,'system_identifier',NULL,
        'server_addr',inet_server_addr()::text,'server_port',inet_server_port(),
        'ssl',(SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid())),
      'captured_at',clock_timestamp()::text,
      'columns',(SELECT jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,
        'nullable',is_nullable,'default',column_default) ORDER BY ordinal_position)
        FROM information_schema.columns WHERE table_schema='public' AND table_name='exercises_v2'),
      'constraints',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',conname,'definition',pg_get_constraintdef(oid)) ORDER BY conname),'[]'::jsonb)
        FROM pg_constraint WHERE conrelid='public.exercises_v2'::regclass),
      'indexes',(SELECT jsonb_agg(indexdef ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='exercises_v2'),
      'rows',(SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY exercise_id),'[]'::jsonb) FROM public.exercises_v2 e),
      'consumer_guard',jsonb_build_object('performance_protocols',(SELECT jsonb_build_object('count',count(*),'digest',md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'null'))) FROM public.performance_protocols t),'session_blocks',(SELECT jsonb_build_object('count',count(*),'digest',md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'null'))) FROM public.session_blocks t),'session_block_exercises',(SELECT jsonb_build_object('count',count(*),'digest',md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'null'))) FROM public.session_block_exercises t),'training_sessions',(SELECT jsonb_build_object('count',count(*),'digest',md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'null'))) FROM public.training_sessions t),'programme_assignments',(SELECT jsonb_build_object('count',count(*),'digest',md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'null'))) FROM public.programme_assignments t)));
