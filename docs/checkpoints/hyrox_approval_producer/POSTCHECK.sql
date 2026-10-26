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

-- Schema-only deployment has no seeds or actual approval/delivery records.
SELECT 'drafts' AS category,count(*) AS rows FROM public.publication_approval_drafts
UNION ALL SELECT 'approval_events',count(*) FROM public.publication_approval_events
UNION ALL SELECT 'deliveries',count(*) FROM public.publication_event_delivery;

BEGIN READ ONLY;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM (VALUES
 ('approve_publication_event_v1','d197bdd62c6cdbe26d91262a537716a264b3ef4c67c434ec75203cfe238f4037'),
 ('claim_publication_delivery_v1','34e7c5c10b69b01ea5e37dfc762c23112f0aab08995ac6cec6826af98af030fa'),
 ('finish_publication_delivery_v1','4e740ea4793197d8565008e7745c477ce8518bebdda8dd81a1d0be5c9ce147a8'),
 ('list_publication_deliveries_v1','8b61dde265061588d637d9fad161d689c1f236f35b077063f46b0c71c2dfe789'),
 ('prepare_publication_approval_v1','f6f6b379f02b982dc01e2bf065dfd70c03fba88ab64393f4f32ab2cf6185e013'),
 ('read_publication_approval_draft_v1','f8da2d18ff288d0b0cf2d0a339d94ce84064b6762cae5839daa095aad0e09d87'),
 ('resolve_publication_approval_event_v1','385ead7d7c7fec4f38412e582be362013dc9f7cff28a240b43dd65b7e909964f'),
 ('retry_publication_delivery_v1','ec213c3f8616856447aa678e7a3bdd8ca1cfc1da9570d82d958534019fd6bd2f')) expected(name,body_sha256)
 LEFT JOIN pg_proc p ON p.pronamespace='public'::regnamespace AND p.proname=expected.name
 WHERE p.oid IS NULL OR encode(extensions.digest(convert_to(p.prosrc,'UTF8'),'sha256'),'hex') IS DISTINCT FROM expected.body_sha256) THEN RAISE EXCEPTION 'exact approval/delivery body mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM public.publication_approval_drafts) OR EXISTS(SELECT 1 FROM public.publication_approval_events) OR EXISTS(SELECT 1 FROM public.publication_event_delivery) THEN RAISE EXCEPTION 'schema-only install unexpectedly has approval/delivery rows'; END IF;
END $$;
SELECT 'EXACT_BODY_EMPTY_SCHEMA_POSTCHECK=PASS' AS result;
COMMIT;
