-- Read-only metadata assertions; no real events or write-based smoke tests.
BEGIN READ ONLY;
DO $$ DECLARE t text;r text;priv text;f record;expected boolean;BEGIN
 FOREACH r IN ARRAY ARRAY['cohort_publication_approval_writer','cohort_publication_event_delivery'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r) OR EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r AND (rolcanlogin OR rolinherit OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls OR rolconfig IS NOT NULL OR rolvaliduntil IS NOT NULL)) THEN RAISE EXCEPTION 'unexpected capability attributes %',r; END IF;
  IF EXISTS(SELECT 1 FROM pg_auth_members WHERE (roleid=r::regrole AND(member<>'postgres'::regrole OR set_option OR inherit_option OR NOT admin_option)) OR member=r::regrole) THEN RAISE EXCEPTION 'unexpected usable capability membership %',r; END IF;
 END LOOP;
 FOREACH t IN ARRAY ARRAY['publication_approval_drafts','publication_approval_events','publication_event_delivery'] LOOP
  IF NOT(SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass) OR (SELECT relowner FROM pg_class WHERE oid=('public.'||t)::regclass)<>'postgres'::regrole THEN RAISE EXCEPTION 'owner/RLS %',t; END IF;
  IF EXISTS(SELECT 1 FROM pg_class c,LATERAL aclexplode(c.relacl)a WHERE c.oid=('public.'||t)::regclass AND a.grantee=0) THEN RAISE EXCEPTION 'PUBLIC table grant %',t; END IF;
  FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','cohort_exercise_version_publisher','cohort_publication_approval_writer','cohort_publication_event_delivery'] LOOP
   FOREACH priv IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'] LOOP
    IF has_table_privilege(r,'public.'||t,priv) THEN RAISE EXCEPTION 'direct effective table privilege %/%/%',r,t,priv; END IF;
   END LOOP;
   IF has_any_column_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,REFERENCES') THEN RAISE EXCEPTION 'effective column privilege %/%',r,t; END IF;
  END LOOP;
 END LOOP;
 FOR f IN SELECT p.* FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname IN ('prepare_publication_approval_v1','read_publication_approval_draft_v1','approve_publication_event_v1','resolve_publication_approval_event_v1','list_publication_deliveries_v1','claim_publication_delivery_v1','finish_publication_delivery_v1','retry_publication_delivery_v1') LOOP
  IF f.proowner<>'postgres'::regrole OR NOT f.prosecdef OR f.proconfig IS DISTINCT FROM ARRAY['search_path=pg_catalog, pg_temp'] OR EXISTS(SELECT 1 FROM aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) WHERE grantee=0) THEN RAISE EXCEPTION 'function boundary %',f.proname; END IF;
  FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','cohort_exercise_version_publisher','cohort_publication_approval_writer','cohort_publication_event_delivery'] LOOP
   expected:=(r='cohort_publication_approval_writer' AND f.proname IN ('prepare_publication_approval_v1','read_publication_approval_draft_v1','approve_publication_event_v1')) OR (r='cohort_publication_event_delivery' AND f.proname IN ('resolve_publication_approval_event_v1','list_publication_deliveries_v1','claim_publication_delivery_v1','finish_publication_delivery_v1','retry_publication_delivery_v1'));
   IF has_function_privilege(r,f.oid,'EXECUTE') IS DISTINCT FROM expected THEN RAISE EXCEPTION 'effective function authority %/%',r,f.proname; END IF;
  END LOOP;
 END LOOP;
 IF (SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN ('prepare_publication_approval_v1','read_publication_approval_draft_v1','approve_publication_event_v1','resolve_publication_approval_event_v1','list_publication_deliveries_v1','claim_publication_delivery_v1','finish_publication_delivery_v1','retry_publication_delivery_v1'))<>8 THEN RAISE EXCEPTION 'function set mismatch'; END IF;
 IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('publication_draft_immutable','publication_approval_event_immutable') AND tgenabled='O' AND tgfoid='public.cohort_tracking_artifact_immutable()'::regprocedure)<>2 THEN RAISE EXCEPTION 'immutability guards absent'; END IF;
END $$;
SELECT 'DURABLE_PUBLICATION_APPROVAL_METADATA=PASS' AS result;
COMMIT;
