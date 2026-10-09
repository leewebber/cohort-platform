-- Exact effective access, real-role denial and zero body/default/evidence changes.
BEGIN;
CREATE ROLE backfill_public_probe NOLOGIN NOINHERIT;
GRANT backfill_public_probe TO postgres WITH INHERIT FALSE, SET TRUE;
GRANT USAGE ON SCHEMA public TO backfill_public_probe;
DO $$ DECLARE r text; t record; d text; BEGIN
  IF NOT has_function_privilege('authenticated',
    'public.complete_backfilled_fixed_programme_occurrence(jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated_backfill_execute_missing';
  END IF;
  FOREACH r IN ARRAY ARRAY['anon','service_role','backfill_public_probe'] LOOP
    IF has_function_privilege(r,
      'public.complete_backfilled_fixed_programme_occurrence(jsonb)', 'EXECUTE') THEN
      RAISE EXCEPTION 'unexpected_effective_backfill_execute: %',r;
    END IF;
    EXECUTE format('SET LOCAL ROLE %I',r);
    BEGIN
      PERFORM public.complete_backfilled_fixed_programme_occurrence('{}'::jsonb);
      RAISE EXCEPTION 'denied_role_entered_backfill';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    RESET ROLE;
  END LOOP;
  IF EXISTS (SELECT FROM public.backfill_acl_functions_before b
    LEFT JOIN pg_proc p ON p.oid=b.oid
    WHERE p.oid IS NULL OR (to_jsonb(p)-'proacl') IS DISTINCT FROM b.definition
      OR (p.oid<>'public.complete_backfilled_fixed_programme_occurrence(jsonb)'::regprocedure
        AND p.proacl::text IS DISTINCT FROM b.acl)) THEN
    RAISE EXCEPTION 'unintended_function_change';
  END IF;
  IF EXISTS ((SELECT * FROM pg_default_acl EXCEPT SELECT * FROM public.backfill_acl_defaults_before)
    UNION ALL (SELECT * FROM public.backfill_acl_defaults_before EXCEPT SELECT * FROM pg_default_acl)) THEN
    RAISE EXCEPTION 'default_privileges_changed';
  END IF;
  FOR t IN SELECT * FROM public.backfill_acl_data_before LOOP
    EXECUTE format('SELECT md5(coalesce(string_agg(to_jsonb(t)::text,chr(10) ORDER BY to_jsonb(t)::text),%L)) FROM public.%I t','',t.relation_name) INTO d;
    IF d IS DISTINCT FROM t.digest THEN RAISE EXCEPTION 'backfill_evidence_changed'; END IF;
  END LOOP;
END $$;
ROLLBACK;
SELECT r,has_function_privilege(r,
 'public.complete_backfilled_fixed_programme_occurrence(jsonb)','EXECUTE') AS effective_execute
FROM unnest(ARRAY['authenticated','service_role','anon']) r;
\echo BACKFILL_EXACT_ACL_REAL_ROLE_AND_PRESERVATION=PASS
