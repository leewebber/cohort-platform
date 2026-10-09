SELECT p.oid IS NOT NULL AS present,
 (SELECT count(*)=1 FROM pg_proc WHERE pronamespace='public'::regnamespace
   AND proname='complete_backfilled_fixed_programme_occurrence') AS exact_single_overload,
 pg_get_userbyid(p.proowner)='postgres' AS expected_owner,
 p.prosecdef AS security_definer,
 p.proconfig=ARRAY['search_path=public, pg_temp'] AS unchanged_search_path,
 md5(p.prosrc)='4c15b85653f6c576c67071035249adcf' AS unchanged_public_wrapper_body,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 NOT has_function_privilege('service_role',p.oid,'EXECUTE') AS service_role_effectively_denied,
 NOT has_function_privilege('anon',p.oid,'EXECUTE') AS anon_effectively_denied,
 NOT EXISTS (SELECT FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
   WHERE a.privilege_type='EXECUTE' AND (a.grantee NOT IN
     (p.proowner,'authenticated'::regrole::oid) OR a.is_grantable)) AS only_owner_authenticated_no_public_or_grant_options
FROM (VALUES (to_regprocedure('public.complete_backfilled_fixed_programme_occurrence(jsonb)'))) t(oid)
LEFT JOIN pg_proc p ON p.oid=t.oid;
