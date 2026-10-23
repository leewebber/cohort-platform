-- READ ONLY. No real benchmark, consent, publication or session commands.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
DO $$ DECLARE f record; r text; t text; BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher'
  AND (rolcanlogin OR rolinherit OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls))
  OR NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='cohort_exercise_version_publisher') THEN
  RAISE EXCEPTION 'unexpected producer role attributes'; END IF;
 IF EXISTS(SELECT 1 FROM pg_auth_members WHERE
   (roleid='cohort_exercise_version_publisher'::regrole AND
    (member<>(SELECT proowner FROM pg_proc WHERE oid='public.retain_published_exercise_definition_v1(text,jsonb)'::regprocedure)
     OR inherit_option OR set_option OR NOT admin_option)) OR member='cohort_exercise_version_publisher'::regrole) THEN
  RAISE EXCEPTION 'unexpected usable producer membership'; END IF;
 FOR f IN SELECT p.oid,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
  AND (p.proname LIKE 'cohort_v3_%' OR p.proname IN ('cohort_start_v3_occurrence_at',
  'retain_published_exercise_definition_v1','retire_published_exercise_version_v1','lookup_published_exercise_version',
  'publish_private_exact_programme_version_v3','read_v3_publication_dependencies',
  'review_hyrox_programme_prescription','consent_hyrox_programme_prescription')) LOOP
  IF EXISTS(SELECT 1 FROM aclexplode((SELECT proacl FROM pg_proc WHERE oid=f.oid)) WHERE grantee=0 AND privilege_type='EXECUTE') THEN
   RAISE EXCEPTION 'PUBLIC execution on %',f.proname; END IF;
  FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','cohort_exercise_version_publisher'] LOOP
   IF has_function_privilege(r,f.oid,'EXECUTE') IS DISTINCT FROM
    ((r='authenticated' AND f.proname IN ('review_hyrox_programme_prescription','consent_hyrox_programme_prescription'))
    OR (r='service_role' AND f.proname IN ('lookup_published_exercise_version','publish_private_exact_programme_version_v3','read_v3_publication_dependencies'))
    OR (r='cohort_exercise_version_publisher' AND f.proname IN ('retain_published_exercise_definition_v1','retire_published_exercise_version_v1'))) THEN
    RAISE EXCEPTION 'unexpected effective function grant %/%',r,f.proname; END IF;
  END LOOP;
 END LOOP;
 FOREACH t IN ARRAY ARRAY['published_exercise_definition_versions','published_exercise_version_retirements','hyrox_prescription_dependencies',
 'programme_v3_publication_artifacts','cohort_v3_publication_claims','programme_v3_prescription_reviews',
 'programme_v3_prescription_consents','programme_occurrence_v3_prescription_snapshots'] LOOP
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass) THEN RAISE EXCEPTION 'RLS disabled %',t; END IF;
  FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','cohort_exercise_version_publisher'] LOOP
   IF has_table_privilege(r,'public.'||t,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
    OR has_any_column_privilege(r,'public.'||t,'INSERT,UPDATE,REFERENCES') THEN RAISE EXCEPTION 'direct mutation grant %/%',r,t; END IF;
   IF has_table_privilege(r,'public.'||t,'SELECT') IS DISTINCT FROM
    (r='authenticated' AND t IN ('programme_v3_prescription_reviews','programme_v3_prescription_consents','programme_occurrence_v3_prescription_snapshots')) THEN
    RAISE EXCEPTION 'read grant %/%',r,t; END IF;
  END LOOP;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.cohort_v3_publication_claims) THEN RAISE EXCEPTION 'orphan publication claim'; END IF;
END $$;
SELECT p.oid::regprocedure,p.proacl,p.proconfig,pg_get_userbyid(p.proowner) AS owner,
 encode(extensions.digest(convert_to(p.prosrc,'UTF8'),'sha256'),'hex') AS body_sha256
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN ('cohort_create_or_resume_fixed_occurrence_pre_v3',
 'cohort_create_or_resume_programme_training_session_pre_v3','create_or_resume_fixed_programme_occurrence_session');
SELECT 'AUTHORITATIVE_V3_METADATA_POSTCHECK=PASS' AS result;
COMMIT;
