-- Prepared SELECT-only metadata verification. No hosted execution authorised here.
SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,
 p.prosecdef,p.proconfig,p.proacl
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN
 ('read_hyrox_programme_prescription_state','cohort_v3_record_prescription_guard',
  'cohort_v3_block_actuals_guard','cohort_canonicalize_interval_result_data')
ORDER BY p.proname;
SELECT c.relname,t.tgname,t.tgenabled,pg_get_triggerdef(t.oid)
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
WHERE NOT t.tgisinternal AND t.tgname IN ('guard_v3_record_prescription','guard_v3_block_actuals')
ORDER BY c.relname,t.tgname;
SELECT r.rolname,
 has_function_privilege(r.oid,'public.read_hyrox_programme_prescription_state(uuid,uuid)','EXECUTE') AS state_reader,
 has_function_privilege(r.oid,'public.cohort_v3_record_prescription_guard()','EXECUTE') AS record_guard,
 has_function_privilege(r.oid,'public.cohort_v3_block_actuals_guard()','EXECUTE') AS block_guard
FROM pg_roles r WHERE r.rolname IN ('anon','authenticated','service_role') ORDER BY r.rolname;
