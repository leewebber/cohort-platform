-- Run after the four pending migrations, before the additive ACL fix.
DO $$ BEGIN
  IF NOT has_function_privilege('service_role',
      'public.complete_backfilled_fixed_programme_occurrence(jsonb)', 'EXECUTE')
    OR NOT has_function_privilege('authenticated',
      'public.complete_backfilled_fixed_programme_occurrence(jsonb)', 'EXECUTE')
    OR has_function_privilege('anon',
      'public.complete_backfilled_fixed_programme_occurrence(jsonb)', 'EXECUTE')
    OR EXISTS (SELECT FROM pg_proc p,
      LATERAL aclexplode(p.proacl) a
      WHERE p.oid='public.complete_backfilled_fixed_programme_occurrence(jsonb)'::regprocedure
        AND a.grantee=0 AND a.privilege_type='EXECUTE') THEN
    RAISE EXCEPTION 'hosted_backfill_acl_defect_not_reproduced';
  END IF;
END $$;
CREATE TABLE public.backfill_acl_functions_before AS
SELECT oid, to_jsonb(p)-'proacl' AS definition, proacl::text AS acl
FROM pg_proc p WHERE pronamespace='public'::regnamespace AND prokind='f';
CREATE TABLE public.backfill_acl_defaults_before AS SELECT * FROM pg_default_acl;
CREATE TABLE public.backfill_acl_data_before(relation_name text PRIMARY KEY, digest text);
DO $$ DECLARE t record; d text; BEGIN
  FOR t IN SELECT relname FROM pg_class WHERE relnamespace='public'::regnamespace
    AND relkind='r' AND relname NOT LIKE 'backfill_acl_%' LOOP
    EXECUTE format('SELECT md5(coalesce(string_agg(to_jsonb(t)::text,chr(10) ORDER BY to_jsonb(t)::text),%L)) FROM public.%I t','',t.relname) INTO d;
    INSERT INTO public.backfill_acl_data_before VALUES(t.relname,d);
  END LOOP;
END $$;
\echo BACKFILL_HOSTED_DEFAULT_DEFECT_REPRODUCED=PASS
