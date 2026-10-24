-- PREPARED ONLY. Not executed against hosted catalogs in this checkpoint.
-- Confirm management project identity FIRST. Use a read-only connection; no mutation RPCs.
-- PostgreSQL 17 metadata; no secrets, query text, addresses or athlete identities returned.
-- psql: stop on the first error. This script does not certify state by merely returning rows.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SELECT clock_timestamp() AS observed_at, current_database(), current_user,
 current_setting('transaction_read_only') AS transaction_read_only, version();

-- Complete ledger. Canonical statement-array fingerprint is NOT a raw migration-file hash.
SELECT m.version, to_jsonb(m)->>'name' AS migration_name,
 CASE WHEN jsonb_typeof(to_jsonb(m)->'statements')='array'
  THEN jsonb_array_length(to_jsonb(m)->'statements') ELSE NULL END AS statement_count,
 encode(sha256(convert_to(coalesce((to_jsonb(m)->'statements')::text,''),'UTF8')),'hex') AS ledger_statement_array_sha256
FROM supabase_migrations.schema_migrations m ORDER BY m.version;

-- Initial absence / partial-state discovery, before any conditional data SELECT.
SELECT name, to_regclass('public.'||name) IS NOT NULL AS present
FROM unnest(ARRAY['hyrox_base_benchmark_revisions','hyrox_base_benchmark_selections',
 'published_exercise_definition_versions','published_exercise_version_retirements',
 'hyrox_prescription_dependencies','programme_v3_publication_artifacts','cohort_v3_publication_claims',
 'programme_v3_prescription_reviews','programme_v3_prescription_consents',
 'programme_occurrence_v3_prescription_snapshots']) name ORDER BY name;
SELECT e.extname,e.extversion FROM pg_extension e ORDER BY e.extname;
SELECT to_regclass('cron.job') IS NOT NULL AS cron_catalog_present;
-- If present, separately inspect active job counts/schedule metadata without command text.

-- Runtime/capability graph, including indirect ancestors and all direct producer links.
WITH RECURSIVE relevant(oid) AS (
 SELECT oid FROM pg_roles WHERE rolname IN
 ('anon','authenticated','service_role','cohort_exercise_version_publisher')
 UNION SELECT m.roleid FROM pg_auth_members m JOIN relevant r ON r.oid=m.member
)
SELECT r.rolname,r.rolcanlogin,r.rolinherit,r.rolsuper,r.rolcreatedb,r.rolcreaterole,r.rolbypassrls
FROM pg_roles r WHERE r.oid IN (SELECT oid FROM relevant) ORDER BY r.rolname;
WITH RECURSIVE relevant(oid) AS (
 SELECT oid FROM pg_roles WHERE rolname IN
 ('anon','authenticated','service_role','cohort_exercise_version_publisher')
 UNION SELECT m.roleid FROM pg_auth_members m JOIN relevant r ON r.oid=m.member
)
SELECT parent.rolname AS granted_role,child.rolname AS member,
 grantor.rolname AS grantor,m.admin_option,m.inherit_option,m.set_option
FROM pg_auth_members m JOIN pg_roles parent ON parent.oid=m.roleid
 JOIN pg_roles child ON child.oid=m.member JOIN pg_roles grantor ON grantor.oid=m.grantor
WHERE m.member IN (SELECT oid FROM relevant) OR parent.rolname='cohort_exercise_version_publisher'
 OR child.rolname='cohort_exercise_version_publisher'
ORDER BY parent.rolname,child.rolname;

SELECT d.defaclrole::regrole AS owner,d.defaclnamespace::regnamespace AS namespace,
 d.defaclobjtype,d.defaclacl FROM pg_default_acl d ORDER BY 1,2,3;

-- All public function metadata includes existing canonical/completion/B2/C2/C3 owners.
-- Fingerprints permit comparison without returning arbitrary deployed body text.
SELECT p.oid,p.oid::regprocedure AS signature,pg_get_userbyid(p.proowner) AS owner,
 p.prosecdef,p.proconfig,p.proacl,
 encode(sha256(convert_to(p.prosrc,'UTF8')),'hex') AS body_sha256,
 encode(sha256(convert_to(pg_get_functiondef(p.oid),'UTF8')),'hex') AS definition_sha256,
 EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  WHERE a.grantee=0 AND a.privilege_type='EXECUTE') AS public_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind IN ('f','p') ORDER BY p.oid::regprocedure::text;
SELECT p.oid::regprocedure AS signature,r.rolname,
 has_function_privilege(r.oid,p.oid,'EXECUTE') AS effective_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN pg_roles r
WHERE n.nspname='public' AND r.rolname IN
 ('anon','authenticated','service_role','cohort_exercise_version_publisher')
ORDER BY p.oid::regprocedure::text,r.rolname;

SELECT c.oid::regclass AS relation,pg_get_userbyid(c.relowner) AS owner,
 c.relkind,c.relrowsecurity,c.relforcerowsecurity,c.relacl
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind IN ('r','p','S') ORDER BY c.relname;
SELECT c.oid::regclass AS relation,r.rolname,v.privilege,
 has_table_privilege(r.oid,c.oid,v.privilege) AS effective_table_privilege
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN pg_roles r
CROSS JOIN (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) v(privilege)
WHERE n.nspname='public' AND c.relkind IN ('r','p') AND r.rolname IN
 ('anon','authenticated','service_role','cohort_exercise_version_publisher')
ORDER BY c.relname,r.rolname,v.privilege;
SELECT c.oid::regclass AS relation,a.attname,a.attacl,r.rolname,v.privilege,
 has_column_privilege(r.oid,c.oid,a.attnum,v.privilege) AS effective_column_privilege
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN pg_roles r
 CROSS JOIN (VALUES ('SELECT'),('INSERT'),('UPDATE'),('REFERENCES')) v(privilege)
WHERE n.nspname='public' AND c.relkind IN ('r','p') AND a.attnum>0 AND NOT a.attisdropped
 AND r.rolname IN ('anon','authenticated','service_role','cohort_exercise_version_publisher')
ORDER BY c.relname,a.attnum,r.rolname,v.privilege;
SELECT c.oid::regclass AS sequence,r.rolname,v.privilege,
 has_sequence_privilege(r.oid,c.oid,v.privilege) AS effective_sequence_privilege
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN pg_roles r
 CROSS JOIN (VALUES ('USAGE'),('SELECT'),('UPDATE')) v(privilege)
WHERE n.nspname='public' AND c.relkind='S' AND r.rolname IN
 ('anon','authenticated','service_role','cohort_exercise_version_publisher')
ORDER BY c.relname,r.rolname,v.privilege;
SELECT pol.polrelid::regclass AS relation,pol.polname,pol.polpermissive,pol.polcmd,
 ARRAY(SELECT r.rolname FROM pg_roles r WHERE r.oid=ANY(pol.polroles)) AS named_roles,
 0=ANY(pol.polroles) AS public_role,
 encode(sha256(convert_to(coalesce(pg_get_expr(pol.polqual,pol.polrelid),''),'UTF8')),'hex') AS using_sha256,
 encode(sha256(convert_to(coalesce(pg_get_expr(pol.polwithcheck,pol.polrelid),''),'UTF8')),'hex') AS check_sha256
FROM pg_policy pol JOIN pg_class c ON c.oid=pol.polrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
ORDER BY c.relname,pol.polname;
SELECT t.tgrelid::regclass AS relation,t.tgname,t.tgenabled,
 encode(sha256(convert_to(pg_get_triggerdef(t.oid),'UTF8')),'hex') AS definition_sha256
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal
ORDER BY c.relname,t.tgname;
SELECT c.conrelid::regclass AS relation,c.conname,c.contype,c.convalidated,
 encode(sha256(convert_to(pg_get_constraintdef(c.oid),'UTF8')),'hex') AS definition_sha256
FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
WHERE n.nspname='public' ORDER BY c.conrelid::regclass::text,c.conname;
SELECT c.oid::regclass AS relation,i.relname AS index_name,x.indisvalid,x.indisready,
 encode(sha256(convert_to(pg_get_indexdef(i.oid),'UTF8')),'hex') AS definition_sha256
FROM pg_index x JOIN pg_class c ON c.oid=x.indrelid JOIN pg_class i ON i.oid=x.indexrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
ORDER BY c.relname,i.relname;

-- A drain observation is not a writer hold. Require adequate inspection visibility.
SELECT clock_timestamp() AS observed_at,current_user AS inspection_role,
 current_setting('transaction_read_only') AS transaction_read_only,
 (SELECT count(*) FROM pg_stat_activity WHERE pid<>pg_backend_pid() AND backend_type='client backend'
  AND state IN ('active','idle in transaction','idle in transaction (aborted)')) AS other_active_or_open_client_transactions,
 (SELECT count(*) FROM pg_stat_activity WHERE pid<>pg_backend_pid() AND backend_type='client backend'
  AND (backend_xid IS NOT NULL OR state LIKE 'idle in transaction%')) AS other_client_write_or_idle_transactions,
 (SELECT count(*) FROM pg_stat_activity WHERE pid<>pg_backend_pid() AND backend_type='client backend'
  AND (state IS NULL OR (state IN ('active','idle in transaction','idle in transaction (aborted)')
   AND (query IS NULL OR query='<insufficient privilege>')))) AS unobservable_client_activity,
 (SELECT count(*) FROM pg_locks l JOIN pg_class c ON c.oid=l.relation JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE l.pid IS DISTINCT FROM pg_backend_pid() AND n.nspname='public'
  AND l.mode<>'AccessShareLock') AS protected_non_read_relation_locks_granted_or_waiting,
 (SELECT count(*) FROM pg_prepared_xacts) AS prepared_transactions,
 (SELECT count(*) FROM pg_subscription WHERE subenabled) AS enabled_logical_replication_subscriptions;
COMMIT;
