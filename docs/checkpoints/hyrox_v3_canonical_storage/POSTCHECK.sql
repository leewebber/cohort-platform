-- READ ONLY. No hosted execution authorised by this file. Metadata only.
BEGIN READ ONLY;
DO $$ BEGIN
  IF (SELECT encode(extensions.digest(prosrc,'sha256'),'hex') FROM pg_proc WHERE oid=coalesce(
    to_regprocedure('public.cohort_create_or_resume_fixed_occurrence_pre_v3(uuid,timestamptz)'),
    to_regprocedure('public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamptz)')))
      IS DISTINCT FROM 'a9c7d9addebfc734ff59f5863bf4580a4b6d8f5b0d16041f5e91eb39830113e9'
    OR (SELECT encode(extensions.digest(prosrc,'sha256'),'hex') FROM pg_proc WHERE oid=coalesce(
    to_regprocedure('public.cohort_create_or_resume_programme_training_session_pre_v3(jsonb)'),
    to_regprocedure('public.create_or_resume_programme_training_session(jsonb)')))
      IS DISTINCT FROM '24e315c9996db3e19d0f332e375183230b9554ea33ecf7790b39500d512c3796' THEN
    RAISE EXCEPTION 'retained canonical start body differs from published source; separate review';
  END IF;
END $$;
DO $$ DECLARE t text; r text; f record; privilege text; BEGIN
  FOREACH t IN ARRAY ARRAY['hyrox_base_benchmark_revisions','hyrox_base_benchmark_selections'] LOOP
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass) THEN
      RAISE EXCEPTION 'RLS absent on %',t;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid=('public.'||t)::regclass
      AND NOT tgisinternal AND tgenabled='O' AND tgfoid='public.cohort_base_reject_mutation()'::regprocedure) THEN
      RAISE EXCEPTION 'immutability absent on %',t;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class c,LATERAL aclexplode(c.relacl) a
      WHERE c.oid=('public.'||t)::regclass AND a.grantee=0) THEN
      RAISE EXCEPTION 'PUBLIC grant on %',t;
    END IF;
    FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
      IF has_table_privilege(r,'public.'||t,'SELECT') IS DISTINCT FROM (r='authenticated')
        OR has_any_column_privilege(r,'public.'||t,'INSERT,UPDATE,REFERENCES') THEN
        RAISE EXCEPTION 'unexpected read/column ACL on % for %',t,r;
      END IF;
      FOREACH privilege IN ARRAY ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
        IF has_table_privilege(r,'public.'||t,privilege) THEN
          RAISE EXCEPTION 'unexpected % on % for %',privilege,t,r;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;
  FOR f IN SELECT p.* FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
    AND (p.proname LIKE 'cohort_base_%' OR p.proname IN ('record_hyrox_base_benchmark',
      'select_hyrox_base_benchmark','read_hyrox_base_selections','cohort_reject_unresolved_package_version',
      'cohort_create_or_resume_fixed_occurrence_pre_v3','cohort_create_or_resume_programme_training_session_pre_v3')) LOOP
    IF EXISTS (SELECT 1 FROM aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) WHERE grantee=0 AND privilege_type='EXECUTE') THEN
      RAISE EXCEPTION 'PUBLIC function execution %',f.proname;
    END IF;
    FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
      IF has_function_privilege(r,f.oid,'EXECUTE') IS DISTINCT FROM
        (r='authenticated' AND f.proname IN ('record_hyrox_base_benchmark','select_hyrox_base_benchmark','read_hyrox_base_selections')) THEN
        RAISE EXCEPTION 'unexpected function execution % for %',f.proname,r;
      END IF;
    END LOOP;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.programme_versions'::regclass
    AND tgname='zz_reject_unresolved_package_version' AND tgenabled='O') THEN
    RAISE EXCEPTION 'v3 admission refusal absent';
  END IF;
END $$;
SELECT p.oid::regprocedure AS function,p.proacl,p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND (p.proname LIKE 'cohort_base_%' OR p.proname IN
 ('record_hyrox_base_benchmark','select_hyrox_base_benchmark','read_hyrox_base_selections')) ORDER BY 1::text;
ROLLBACK;
