-- Prepared for separately approved hosted SELECT-only postchecks.
-- Executed only against disposable local resources in this milestone.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
DO $$ DECLARE p record; r text; BEGIN
 SELECT * INTO STRICT p FROM pg_proc WHERE oid='public.retain_published_exercise_event_v1(text,jsonb,jsonb)'::regprocedure;
 IF NOT p.prosecdef OR p.provolatile<>'v' OR cardinality(p.proconfig) IS DISTINCT FROM 1
  OR replace(p.proconfig[1],' ','') IS DISTINCT FROM 'search_path=pg_catalog,pg_temp'
  OR p.proowner<>(SELECT proowner FROM pg_proc WHERE oid='public.retain_published_exercise_definition_v1(text,jsonb)'::regprocedure)
  OR encode(sha256(convert_to(p.prosrc,'UTF8')),'hex')<>'61c16aa40d97be7ff2d776baceea9ca973b80d214c3284a28ff3db58d5ff99f2' THEN
  RAISE EXCEPTION 'atomic producer body/owner/security drift';
 END IF;
 IF EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))
  WHERE grantee NOT IN (p.proowner,'cohort_exercise_version_publisher'::regrole)) THEN
  RAISE EXCEPTION 'unexpected atomic producer function principal';
 END IF;
 FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role','cohort_exercise_version_publisher'] LOOP
  IF has_function_privilege(r,p.oid,'EXECUTE') IS DISTINCT FROM (r='cohort_exercise_version_publisher') THEN
   RAISE EXCEPTION 'unexpected effective atomic producer function grant';
  END IF;
 END LOOP;
END $$;
SELECT 'ATOMIC_EXERCISE_EVENT_BODY_OWNER_CAPABILITY_POSTCHECK=PASS' AS result;
COMMIT;
