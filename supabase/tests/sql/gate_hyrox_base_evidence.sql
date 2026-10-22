-- Disposable synthetic identities only. No programme/target eligibility is granted.
\set ON_ERROR_STOP on
CREATE FUNCTION pg_temp.base_assert(ok boolean, description text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'BASE_GATE: %',description; END IF; END $$;

INSERT INTO auth.users (id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
VALUES ('ba220000-0000-4000-8000-000000000001','authenticated','authenticated','base-a@example.invalid','{}','{}'),
       ('ba220000-0000-4000-8000-000000000002','authenticated','authenticated','base-b@example.invalid','{}','{}');
INSERT INTO public.profiles (id,display_name,is_athlete,is_coach)
SELECT id,'Synthetic Base gate',true,false FROM auth.users WHERE id::text LIKE 'ba220000-%';

DO $$
DECLARE r jsonb; p jsonb; revision uuid; selection uuid; corrected uuid; digest text; n integer;
BEGIN
  PERFORM set_config('request.jwt.claim.sub','ba220000-0000-4000-8000-000000000001',true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('role','authenticated',true);
  p := jsonb_build_object('command_id',gen_random_uuid(),'metric','run10km','value','40','unit','minutes',
    'test_date','2026-10-22','source_type','knownResult','source_reference','gate-run',
    'previous_revision_id',NULL,'correction_reason',NULL);
  r := public.record_hyrox_base_benchmark(p); revision := (r->>'revision_id')::uuid; digest := r->>'retained_digest';
  PERFORM pg_temp.base_assert(r->>'status'='recorded','owned record');
  PERFORM pg_temp.base_assert((SELECT canonical_value=2400000 FROM public.hyrox_base_benchmark_revisions WHERE revision_id=revision),'server conversion');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p)->>'status'='replayed','idempotent record');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p || '{"value":"60"}')->>'code'='command_conflict','conflicting retry');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p || jsonb_build_object('athlete_id',auth.uid()))->>'status'='validation_failure','forged owner key');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p || jsonb_build_object('retained_digest',digest))->>'status'='validation_failure','supplied digest');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p || '{"value":40}')->>'status'='validation_failure','wrong scalar type');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p || '{"test_date":"2026-02-30"}')->>'status'='validation_failure','invalid civil date');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p || '{"source_type":"syntheticExample"}')->>'status'='validation_failure','synthetic provenance refused');
  r := public.select_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','run10km',
    'selected_revision_id',revision,'expected_selection_id',NULL,'consent','use_declared_benchmark_for_future_previews_only'));
  selection := (r->>'selection_id')::uuid;
  PERFORM pg_temp.base_assert(r->>'status'='accepted','explicit selection');
  PERFORM pg_temp.base_assert(public.read_hyrox_base_selections()->'selections'->0->>'preview_state'='selected_declared_result','current selection read');
  r := public.record_hyrox_base_benchmark(p || jsonb_build_object('command_id',gen_random_uuid(),
    'value','60','previous_revision_id',revision,'correction_reason','correct transcription'));
  corrected := (r->>'revision_id')::uuid;
  PERFORM pg_temp.base_assert(r->>'status'='recorded','append correction');
  PERFORM pg_temp.base_assert(public.read_hyrox_base_selections()->'selections'->0->>'preview_state'='unavailable_stale_selection','correction invalidates numeric use, never auto selects');
  PERFORM pg_temp.base_assert((SELECT retained_digest=digest AND canonical_value=2400000 FROM public.hyrox_base_benchmark_revisions WHERE revision_id=revision),'old revision unchanged');
  PERFORM pg_temp.base_assert(public.select_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','run10km',
    'selected_revision_id',corrected,'expected_selection_id',NULL,'consent','use_declared_benchmark_for_future_previews_only'))->>'code'='stale_selection','stale selection CAS');
  PERFORM pg_temp.base_assert(public.select_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','run10km',
    'selected_revision_id',revision,'expected_selection_id',selection,'consent','use_declared_benchmark_for_future_previews_only'))->>'code'='superseded_benchmark','superseded revision cannot be freshly selected');
  PERFORM pg_temp.base_assert(public.select_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','row2km',
    'selected_revision_id',corrected,'expected_selection_id',NULL,'consent','use_declared_benchmark_for_future_previews_only'))->>'code'='unresolved_owned_benchmark','exact metric required');
  PERFORM set_config('request.jwt.claim.sub','ba220000-0000-4000-8000-000000000002',true);
  SELECT count(*) INTO n FROM public.hyrox_base_benchmark_revisions;
  PERFORM pg_temp.base_assert(n=0,'cross-owner RLS evidence');
  SELECT count(*) INTO n FROM public.hyrox_base_benchmark_selections;
  PERFORM pg_temp.base_assert(n=0,'cross-owner RLS selection');
  PERFORM pg_temp.base_assert(public.record_hyrox_base_benchmark(p)->>'code'='command_conflict','foreign retry no data');
  PERFORM pg_temp.base_assert(public.select_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','run10km',
    'selected_revision_id',corrected,'expected_selection_id',NULL,'consent','use_declared_benchmark_for_future_previews_only'))->>'code'='unresolved_owned_benchmark','foreign selection refused');
  PERFORM set_config('role','none',true);
  BEGIN DELETE FROM public.hyrox_base_benchmark_revisions WHERE revision_id=revision;
    RAISE EXCEPTION 'delete accepted'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;
  BEGIN UPDATE public.hyrox_base_benchmark_selections SET selected_revision_id=corrected WHERE selection_id=selection;
    RAISE EXCEPTION 'update accepted'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;
  BEGIN
    INSERT INTO public.hyrox_base_benchmark_selections (athlete_id,metric,selected_revision_id,generation,command_id,request)
    VALUES ('ba220000-0000-4000-8000-000000000002','run10km',corrected,1,gen_random_uuid(),'{}');
    RAISE EXCEPTION 'cross-owner FK accepted'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
END $$;

DO $$
DECLARE role_name text; t text; f record; privilege text;
BEGIN
  FOR f IN SELECT p.oid,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND (p.proname LIKE 'cohort_base_%' OR p.proname IN (
      'record_hyrox_base_benchmark','select_hyrox_base_benchmark','read_hyrox_base_selections',
      'cohort_reject_unresolved_package_version','cohort_create_or_resume_fixed_occurrence_pre_v3',
      'cohort_create_or_resume_programme_training_session_pre_v3')) LOOP
    PERFORM pg_temp.base_assert(NOT EXISTS(SELECT 1 FROM aclexplode((SELECT proacl FROM pg_proc WHERE oid=f.oid))
      WHERE grantee=0 AND privilege_type='EXECUTE'),'no PUBLIC execute '||f.proname);
    FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
      PERFORM pg_temp.base_assert(has_function_privilege(role_name,f.oid,'EXECUTE') =
        (role_name='authenticated' AND f.proname IN ('record_hyrox_base_benchmark','select_hyrox_base_benchmark','read_hyrox_base_selections')),
        'effective function grant '||role_name||' '||f.proname);
    END LOOP;
    PERFORM pg_temp.base_assert((SELECT proconfig @> ARRAY['search_path=pg_catalog, pg_temp'] FROM pg_proc WHERE oid=f.oid)
      OR f.proname LIKE '%pre_v3','secured path '||f.proname);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['hyrox_base_benchmark_revisions','hyrox_base_benchmark_selections'] LOOP
    PERFORM pg_temp.base_assert((SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass),'RLS enabled '||t);
    PERFORM pg_temp.base_assert(NOT EXISTS(SELECT 1 FROM aclexplode((SELECT relacl FROM pg_class WHERE oid=('public.'||t)::regclass)) WHERE grantee=0),'no PUBLIC table grant '||t);
    FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
      FOREACH privilege IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
        PERFORM pg_temp.base_assert(NOT has_table_privilege(role_name,'public.'||t,privilege),'no mutation '||role_name||' '||t||' '||privilege);
      END LOOP;
      PERFORM pg_temp.base_assert(has_table_privilege(role_name,'public.'||t,'SELECT')=(role_name='authenticated'),'exact table read grant');
      PERFORM pg_temp.base_assert(NOT has_any_column_privilege(role_name,'public.'||t,'INSERT,UPDATE,REFERENCES'),'no column mutation');
    END LOOP;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub','ba220000-0000-4000-8000-000000000001',true);
  FOREACH role_name IN ARRAY ARRAY['anon','service_role'] LOOP
    PERFORM set_config('role',role_name,true);
    BEGIN PERFORM public.read_hyrox_base_selections(); RAISE EXCEPTION 'role executed';
      EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    PERFORM set_config('role','none',true);
  END LOOP;
END $$;

-- The private kernel is not an authenticated prescription RPC.
CREATE TEMP TABLE base_vectors (document jsonb);
\copy base_vectors FROM '/tmp/hyrox_base_calculation_vectors.jsonl' WITH (FORMAT csv, DELIMITER E'\x01', QUOTE E'\x02');
DO $$
DECLARE v jsonb; actual jsonb; count_vectors integer := 0;
BEGIN
  FOR v IN SELECT document FROM base_vectors LOOP
    actual := public.cohort_base_calculate_v1(v->>'kind',1,(v->>'week')::integer,(v->>'value')::bigint,(v->>'increment')::bigint);
    PERFORM pg_temp.base_assert(actual = v->'expected','Dart/SQL parity '||v::text);
    count_vectors := count_vectors+1;
  END LOOP;
  PERFORM pg_temp.base_assert(count_vectors=136,'all generated vectors');
  PERFORM pg_temp.base_assert(public.cohort_base_canonical_value('backSquat5rm','220','pounds')=99790321400,'exact lb conversion');
  PERFORM pg_temp.base_assert(public.cohort_base_canonical_value('strictPullUps','0','count')=0,'zero pullups valid');
  BEGIN PERFORM public.cohort_base_canonical_value('row2km','1','kilograms');
    RAISE EXCEPTION 'wrong unit accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN PERFORM public.cohort_base_canonical_value('run10km','40.000001','minutes');
    RAISE EXCEPTION 'precision rounded'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM pg_temp.base_assert(public.cohort_base_calculate_v1('wodRow',1,1,480000)->>'code'='unsupported_rule','WOD row refused');
  PERFORM pg_temp.base_assert(public.cohort_base_calculate_v1('backSquat',2,1,100000000000,2500)->>'code'='unsupported_rule','future rule refused');
  PERFORM pg_temp.base_assert(public.cohort_base_calculate_v1('runningIntervals',1,1,NULL)->>'code'='missing_benchmark','missing evidence');
  PERFORM pg_temp.base_assert(public.cohort_base_calculate_v1('backSquat',1,1,100000000000)->>'code'='missing_or_invalid_increment','no guessed increment');
END $$;
SELECT 'HYROX_BASE_EVIDENCE_SQL=PASS; DART_SQL_VECTORS=136' AS result;

-- Rollback removes an inserted revision/selection, including any idempotency key.
DO $$ DECLARE n bigint; head uuid; latest uuid; r jsonb; BEGIN
  PERFORM set_config('request.jwt.claim.sub','ba220000-0000-4000-8000-000000000001',true);
  PERFORM set_config('role','authenticated',true);
  SELECT count(*) INTO n FROM public.hyrox_base_benchmark_revisions;
  BEGIN
    r:=public.record_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','strictPullUps',
      'value','0','unit','count','test_date','2026-10-22','source_type','knownResult','source_reference','rollback-only',
      'previous_revision_id',NULL,'correction_reason',NULL));
    PERFORM pg_temp.base_assert(r->>'status'='recorded','rollback record inserted');
    RAISE EXCEPTION 'injected transaction failure' USING ERRCODE='40001';
  EXCEPTION WHEN serialization_failure THEN NULL; END;
  PERFORM pg_temp.base_assert((SELECT count(*) FROM public.hyrox_base_benchmark_revisions)=n,'no partial record after rollback');
  SELECT selection_id INTO head FROM public.hyrox_base_benchmark_selections WHERE metric='run10km' ORDER BY generation DESC LIMIT 1;
  SELECT revision_id INTO latest FROM public.hyrox_base_benchmark_revisions WHERE metric='run10km' ORDER BY revision_number DESC LIMIT 1;
  BEGIN
    r:=public.select_hyrox_base_benchmark(jsonb_build_object('command_id',gen_random_uuid(),'metric','run10km',
      'selected_revision_id',latest,'expected_selection_id',head,'consent','use_declared_benchmark_for_future_previews_only'));
    PERFORM pg_temp.base_assert(r->>'status'='accepted','rollback selection inserted');
    RAISE EXCEPTION 'injected transaction failure' USING ERRCODE='40001';
  EXCEPTION WHEN serialization_failure THEN NULL; END;
  PERFORM pg_temp.base_assert((SELECT selection_id FROM public.hyrox_base_benchmark_selections WHERE metric='run10km' ORDER BY generation DESC LIMIT 1)=head,'no partial consent after rollback');
  PERFORM set_config('role','none',true);
END $$;
-- Even an accidentally over-granted public RPC cannot accept a service actor's sub.
BEGIN;
GRANT EXECUTE ON FUNCTION public.read_hyrox_base_selections() TO service_role;
DO $$ BEGIN
  PERFORM set_config('request.jwt.claim.sub','ba220000-0000-4000-8000-000000000001',true);
  PERFORM set_config('role','service_role',true);
  BEGIN PERFORM public.read_hyrox_base_selections(); RAISE EXCEPTION 'forged service actor accepted';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'HYROX_BASE_ROLLBACK_AND_SERVICE_ACTOR=PASS' AS result;
