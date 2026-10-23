\set ON_ERROR_STOP on
DO $$ DECLARE f record; r text; t text; p text; body jsonb; result jsonb; changed jsonb; c jsonb; denied boolean; BEGIN
 FOR f IN SELECT p.oid,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND (p.proname LIKE 'cohort_v3_%' OR p.proname IN ('cohort_start_v3_occurrence_at','retain_published_exercise_definition_v1',
     'retire_published_exercise_version_v1','lookup_published_exercise_version','publish_private_exact_programme_version_v3','read_v3_publication_dependencies',
     'review_hyrox_programme_prescription','consent_hyrox_programme_prescription')) LOOP
   PERFORM public.v3_gate_assert(NOT EXISTS(SELECT 1 FROM aclexplode((SELECT proacl FROM pg_proc WHERE oid=f.oid))
     WHERE grantee=0 AND privilege_type='EXECUTE'),'no PUBLIC function execution '||f.proname);
   FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','cohort_exercise_version_publisher'] LOOP
     PERFORM public.v3_gate_assert(has_function_privilege(r,f.oid,'EXECUTE') =
       ((r='authenticated' AND f.proname IN ('review_hyrox_programme_prescription','consent_hyrox_programme_prescription'))
       OR (r='service_role' AND f.proname IN ('lookup_published_exercise_version','publish_private_exact_programme_version_v3','read_v3_publication_dependencies'))
       OR (r='cohort_exercise_version_publisher' AND f.proname IN ('retain_published_exercise_definition_v1','retire_published_exercise_version_v1'))),'exact function role '||r||'/'||f.proname);
   END LOOP;
 END LOOP;
 FOREACH t IN ARRAY ARRAY['published_exercise_definition_versions','published_exercise_version_retirements','hyrox_prescription_dependencies','programme_v3_publication_artifacts',
   'cohort_v3_publication_claims','programme_v3_prescription_reviews','programme_v3_prescription_consents','programme_occurrence_v3_prescription_snapshots'] LOOP
   PERFORM public.v3_gate_assert((SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass),'RLS '||t);
   PERFORM public.v3_gate_assert(NOT EXISTS(SELECT 1 FROM aclexplode((SELECT relacl FROM pg_class WHERE oid=('public.'||t)::regclass)) WHERE grantee=0),'PUBLIC table revoked '||t);
   FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','cohort_exercise_version_publisher'] LOOP
     PERFORM public.v3_gate_assert(has_table_privilege(r,'public.'||t,'SELECT') =
       (r='authenticated' AND t IN ('programme_v3_prescription_reviews','programme_v3_prescription_consents','programme_occurrence_v3_prescription_snapshots')),'scoped table reads '||r||'/'||t);
     FOREACH p IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
       PERFORM public.v3_gate_assert(NOT has_table_privilege(r,'public.'||t,p),'no direct mutation '||r||'/'||t||'/'||p);
     END LOOP;
     PERFORM public.v3_gate_assert(NOT has_any_column_privilege(r,'public.'||t,'INSERT,UPDATE,REFERENCES'),'no column mutation');
   END LOOP;
   IF t NOT IN ('cohort_v3_publication_claims','published_exercise_version_retirements') THEN
     BEGIN EXECUTE format('DELETE FROM public.%I',t); RAISE EXCEPTION 'delete succeeded on %',t;
       EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;
   END IF;
 END LOOP;
 PERFORM public.v3_gate_assert(NOT EXISTS(SELECT 1 FROM pg_auth_members WHERE
   (roleid='cohort_exercise_version_publisher'::regrole AND
    (member<>(SELECT proowner FROM pg_proc WHERE oid='public.retain_published_exercise_definition_v1(text,jsonb)'::regprocedure)
      OR inherit_option OR set_option OR NOT admin_option))
   OR member='cohort_exercise_version_publisher'::regrole),'no usable producer capability membership installed');
 SELECT document INTO body FROM public.v3_gate_data WHERE key='payload';
 FOREACH p IN ARRAY ARRAY['unresolved_exercise','wrong_digest','wrong_body','wrong_rule','wrong_parameters','wrong_unit','wrong_session','wrong_block','unknown_binding','wrong_kind','malformed_version','decimal_package_schema','decimal_binding_schema'] LOOP
   c:=(body->>'package_canonical_json')::jsonb;
   CASE p
     WHEN 'unresolved_exercise' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,exercise,id}','"EX-999999"');
     WHEN 'wrong_digest' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,exercise,digest}',to_jsonb(repeat('a',64)));
     WHEN 'wrong_body' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,session_body_sha256}',to_jsonb(repeat('b',64)));
     WHEN 'wrong_rule' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,rule,version}','2');
     WHEN 'wrong_parameters' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,parameters,reps}','99');
     WHEN 'wrong_unit' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,input_unit}','"milliseconds"');
     WHEN 'wrong_session' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,protocol_id}','"foreign.source"');
     WHEN 'wrong_block' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,block_id}','"00000000-0000-4000-8000-000000000000"');
     WHEN 'unknown_binding' THEN c:=jsonb_set(c,'{personalisation_binding,client_approved}','true');
     WHEN 'wrong_kind' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,kind}','"wodRow"');
     WHEN 'decimal_package_schema' THEN c:=jsonb_set(c,'{package_schema_version}','3.0'::jsonb);
     WHEN 'decimal_binding_schema' THEN c:=jsonb_set(c,'{personalisation_binding,binding_schema_version}','1.0'::jsonb);
     WHEN 'malformed_version' THEN c:=jsonb_set(c,'{personalisation_binding,targets,0,exercise,version}','"7"');
   END CASE;
   changed:=body||jsonb_build_object('programme_version_id',gen_random_uuid(),'package_canonical_json',public.cohort_tracking_canonical_text(c),'package_content_hash',public.cohort_v3_hash(c));
   PERFORM set_config('role','service_role',true);
   result:=public.publish_private_exact_programme_version_v3(changed);
   PERFORM set_config('role','none',true);
   PERFORM public.v3_gate_assert(result->>'status'='validation_failure','forged recomputed hash cannot authorise '||p);
 END LOOP;
 BEGIN
   ALTER TABLE public.session_blocks DISABLE TRIGGER USER;
   UPDATE public.session_blocks SET timer_config=timer_config||'{"stations":[{"exercise":"mixed-WOD"}]}'::jsonb
     WHERE session_id='v3.synthetic.source' AND position=2;
   ALTER TABLE public.session_blocks ENABLE TRIGGER USER;
   c:=(body->>'package_canonical_json')::jsonb;
   SELECT jsonb_set(c,'{personalisation_binding,targets}',jsonb_agg(x||jsonb_build_object('session_body_sha256',
      public.cohort_v3_hash(public.cohort_v3_session_source(c->'sessions'->0))))) INTO c
     FROM jsonb_array_elements(c#>'{personalisation_binding,targets}') x;
   changed:=body||jsonb_build_object('programme_version_id',gen_random_uuid(),'package_canonical_json',public.cohort_tracking_canonical_text(c),'package_content_hash',public.cohort_v3_hash(c));
   PERFORM set_config('role','service_role',true);result:=public.publish_private_exact_programme_version_v3(changed);PERFORM set_config('role','none',true);
   PERFORM public.v3_gate_assert(result->>'reason'='wrong_dedicated_interval_scope','correctly rehashed mixed-station source still refuses row pace');
   RAISE EXCEPTION 'rollback synthetic malformed source' USING ERRCODE='40001';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 PERFORM set_config('request.jwt.claim.sub','bc230000-0000-4000-8000-000000000003',true);
 PERFORM set_config('role','authenticated',true);
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.programme_occurrence_v3_prescription_snapshots)=0,'foreign snapshot RLS');
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.programme_v3_prescription_reviews)=0,'foreign review RLS');
 PERFORM public.v3_gate_assert((SELECT count(*) FROM public.programme_v3_prescription_consents)=0,'foreign consent RLS');
 PERFORM set_config('role','none',true);
END $$;
SELECT 'V3_EFFECTIVE_ROLE_RLS_IMMUTABILITY_FORGED_ADMISSION=PASS' AS result;
