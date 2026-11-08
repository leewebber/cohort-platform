-- Read-only fingerprint for this migration. Run with psql -X -At -f.
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL search_path = pg_catalog, pg_temp;
WITH functions AS (
  SELECT p.oid, n.nspname, p.proname, p.prosecdef, p.provolatile,
    p.proconfig, pg_get_userbyid(p.proowner) AS owner
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.oid IN (
      to_regprocedure('public.read_m31_thursday_trial_permission(uuid,uuid,text)'),
      to_regprocedure('public.cohort_m31_seed_thursday_trial_permission()'),
      to_regprocedure('public.cohort_m31_require_thursday_trial_seal()')
    )
), triggers AS (
  SELECT t.oid, t.tgname, t.tgenabled, t.tgdeferrable, t.tginitdeferred
  FROM pg_trigger t
  WHERE t.tgrelid = 'public.programme_versions'::regclass
    AND t.tgname IN ('programme_versions_m31_seed_thursday_trial_permission',
                    'programme_versions_m31_require_thursday_trial_seal')
)
SELECT jsonb_build_object(
  'functions', (SELECT coalesce(jsonb_agg(jsonb_build_object(
    'signature', oid::regprocedure::text, 'owner', owner,
    'security_definer', prosecdef, 'volatility', provolatile,
    'configuration', proconfig,
    'public_execute', has_function_privilege('public', oid, 'EXECUTE'),
    'anon_execute', has_function_privilege('anon', oid, 'EXECUTE'),
    'authenticated_execute', has_function_privilege('authenticated', oid, 'EXECUTE'),
    'service_role_execute', has_function_privilege('service_role', oid, 'EXECUTE'),
    'definition_sha256', encode(extensions.digest(
      convert_to(pg_get_functiondef(oid), 'UTF8'), 'sha256'), 'hex')
  ) ORDER BY proname), '[]'::jsonb) FROM functions),
  'triggers', (SELECT coalesce(jsonb_agg(jsonb_build_object(
    'name', tgname, 'enabled', tgenabled,
    'deferrable', tgdeferrable, 'initially_deferred', tginitdeferred,
    'definition_sha256', encode(extensions.digest(
      convert_to(pg_get_triggerdef(oid), 'UTF8'), 'sha256'), 'hex')
  ) ORDER BY tgname), '[]'::jsonb) FROM triggers)
);
COMMIT;
