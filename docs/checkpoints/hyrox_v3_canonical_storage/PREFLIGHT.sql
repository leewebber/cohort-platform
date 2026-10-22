-- READ ONLY. No hosted execution authorised by this file.
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
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) r
    WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r)) THEN
    RAISE EXCEPTION 'required roles unresolved';
  END IF;
  IF (SELECT count(*) FROM supabase_migrations.schema_migrations
    WHERE version IN ('20261007120000','20261007130000','20261008120000','20261008121000','20261009120000')) <> 5 THEN
    RAISE EXCEPTION 'prior permission/ownership/identity/link/ACL deployment prerequisites missing';
  END IF;
  IF to_regprocedure('public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamp with time zone)') IS NULL
    OR to_regprocedure('public.create_or_resume_programme_training_session(jsonb)') IS NULL THEN
    RAISE EXCEPTION 'canonical start source missing';
  END IF;
  IF has_function_privilege('anon','public.create_or_resume_programme_training_session(jsonb)','EXECUTE')
    OR EXISTS (SELECT 1 FROM pg_proc p,LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
      WHERE p.oid='public.create_or_resume_programme_training_session(jsonb)'::regprocedure
      AND a.grantee=0 AND a.privilege_type='EXECUTE') THEN
    RAISE EXCEPTION 'unexpected public canonical start execution; separate review';
  END IF;
END $$;
SELECT version FROM supabase_migrations.schema_migrations
WHERE version IN ('20261007120000','20261007130000','20261008120000','20261008121000',
 '20261009120000','20261022120000','20261022121000') ORDER BY version;
-- Before a new deployment both new versions must be absent; partial state stops apply.
SELECT to_regclass('public.hyrox_base_benchmark_revisions') AS evidence_table,
 to_regclass('public.hyrox_base_benchmark_selections') AS selection_table;
SELECT p.oid::regprocedure AS function,p.proowner::regrole AS owner,p.proconfig,
 encode(extensions.digest(p.prosrc,'sha256'),'hex') AS body_sha256,p.proacl
FROM pg_proc p WHERE p.oid IN (
 'public.cohort_create_or_resume_fixed_occurrence_at(uuid,timestamp with time zone)'::regprocedure,
 'public.create_or_resume_programme_training_session(jsonb)'::regprocedure);
ROLLBACK;
