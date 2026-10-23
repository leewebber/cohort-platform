-- READ ONLY. Hosted execution requires separate target-specific authority.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SELECT current_database(),current_user,version();
SELECT version FROM supabase_migrations.schema_migrations
 WHERE version >= '20261007120000' ORDER BY version;
SELECT x AS missing_required_migration FROM unnest(ARRAY[
 '20261007120000','20261007130000','20261008120000','20261008121000','20261009120000',
 '20261022120000','20261022121000']) x
 WHERE NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations m WHERE m.version=x);
-- Initial apply requires all three below absent; present/partial state is review-only.
SELECT to_regclass('public.published_exercise_definition_versions') AS retained_versions,
 to_regclass('public.programme_v3_publication_artifacts') AS artifacts,
 to_regclass('public.programme_occurrence_v3_prescription_snapshots') AS snapshots;
SELECT rolname,rolcanlogin,rolinherit,rolsuper,rolcreatedb,rolcreaterole,rolbypassrls
 FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','cohort_exercise_version_publisher');
SELECT r.rolname AS capability,m.rolname AS member,a.admin_option,a.inherit_option,a.set_option
 FROM pg_auth_members a JOIN pg_roles r ON r.oid=a.roleid JOIN pg_roles m ON m.oid=a.member
 WHERE r.rolname='cohort_exercise_version_publisher' OR m.rolname='cohort_exercise_version_publisher';
SELECT p.oid::regprocedure,pg_get_userbyid(p.proowner) AS owner,p.prosecdef,p.proconfig,p.proacl,
 encode(extensions.digest(convert_to(p.prosrc,'UTF8'),'sha256'),'hex') AS body_sha256
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname IN ('cohort_create_or_resume_fixed_occurrence_pre_v3',
 'cohort_create_or_resume_programme_training_session_pre_v3','cohort_create_or_resume_fixed_occurrence_at',
 'create_or_resume_fixed_programme_occurrence_session','publish_private_exact_programme_version',
 'cohort_reject_unresolved_package_version');
SELECT defaclrole::regrole,defaclnamespace::regnamespace,defaclobjtype,defaclacl FROM pg_default_acl;
SELECT c.oid::regclass,c.relrowsecurity,c.relacl FROM pg_class c
 WHERE c.oid IN ('public.programme_versions'::regclass,'public.programme_assignments'::regclass,
 'public.training_sessions'::regclass,'public.programme_slot_outcomes'::regclass);
COMMIT;
