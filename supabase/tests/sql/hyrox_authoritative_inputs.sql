SELECT jsonb_build_object('source',public.cohort_v3_session_source('{"session_key":"synthetic-source","protocol_id":"v3.synthetic.source","session_lineage_id":"bc230000-0000-4000-8000-000000000010","revision_number":1}'::jsonb),
 'dependencies',(SELECT jsonb_agg(to_jsonb(d) ORDER BY kind) FROM public.hyrox_prescription_dependencies d),
 'exercises',(SELECT jsonb_agg(to_jsonb(e) ORDER BY exercise_id) FROM public.published_exercise_definition_versions e));
