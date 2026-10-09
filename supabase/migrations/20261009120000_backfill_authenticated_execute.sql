-- Preserve the reviewed authenticated-only public backfill contract when a
-- creation-time service_role default grant survived the original wrapper ACL.
-- No function replacement, default privileges, role membership or body change.
BEGIN;

REVOKE EXECUTE ON FUNCTION
  public.complete_backfilled_fixed_programme_occurrence(jsonb)
  FROM service_role;

-- A direct revoke cannot remove inherited/PUBLIC authority. Stop atomically on
-- unexpected authority instead of weakening the contract or changing roles.
DO $$
DECLARE
  target oid := 'public.complete_backfilled_fixed_programme_occurrence(jsonb)'::regprocedure;
BEGIN
  IF NOT has_function_privilege('authenticated', target, 'EXECUTE')
    OR has_function_privilege('anon', target, 'EXECUTE')
    OR has_function_privilege('service_role', target, 'EXECUTE')
    OR EXISTS (
      SELECT 1 FROM pg_proc p,
        LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      WHERE p.oid = target AND a.privilege_type = 'EXECUTE'
        AND (a.grantee NOT IN (p.proowner, 'authenticated'::regrole::oid)
          OR a.is_grantable)
    ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'backfill_authenticated_execute_contract_mismatch';
  END IF;
END;
$$;

COMMIT;
