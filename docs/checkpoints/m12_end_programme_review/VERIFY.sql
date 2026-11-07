-- Run before and after the separately approved deployment against the verified
-- target. Bind athlete_id, bali_assignment_id, bali_version_id and
-- hybrid_version_id as psql variables using the retained identity evidence.
\set ON_ERROR_STOP on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '20s';

SELECT jsonb_agg(jsonb_build_object(
  'version', version, 'name', name, 'statement_count', cardinality(statements),
  'statement_array_sha256',
    encode(extensions.digest(convert_to(to_jsonb(statements)::text, 'UTF8'), 'sha256'), 'hex')
) ORDER BY version) AS ledger
FROM supabase_migrations.schema_migrations;

SELECT current_database(), current_user, current_setting('default_transaction_isolation');
SELECT coalesce(r.rolname, 'ALL') AS role_name, s.setconfig
FROM pg_db_role_setting s
LEFT JOIN pg_roles r ON r.oid = s.setrole
WHERE (s.setdatabase = 0 OR s.setdatabase = (SELECT oid FROM pg_database WHERE datname = current_database()))
AND (s.setrole = 0 OR r.rolname IN ('authenticator', 'authenticated'))
AND EXISTS (SELECT FROM unnest(s.setconfig) c WHERE c LIKE 'default_transaction_isolation=%');

SELECT p.oid::regprocedure AS signature, pg_get_userbyid(p.proowner) AS owner,
       p.proacl, p.prosecdef, p.provolatile, p.proconfig,
       EXISTS (SELECT FROM aclexplode(coalesce(p.proacl, acldefault('f', p.proowner)))
         WHERE grantee = 0 AND privilege_type = 'EXECUTE') AS public_execute,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS athlete_execute,
       has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_execute,
       encode(extensions.digest(convert_to(pg_get_functiondef(p.oid), 'UTF8'), 'sha256'), 'hex') AS definition_sha256
FROM pg_proc p
WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'
AND p.proname IN (
  'cohort_auth_is_athlete', 'acquire_my_private_programme',
  'enrol_athlete_in_private_programme_version', 'cohort_programme_assignment_protect_materialisation',
  'create_or_resume_fixed_programme_occurrence_session', 'create_or_resume_programme_training_session',
  'cohort_create_or_resume_fixed_occurrence_at', 'cohort_create_or_resume_fixed_occurrence_pre_v3',
  'cohort_start_v3_occurrence_at', 'complete_fixed_programme_occurrence_and_advance',
  'resolve_fixed_programme_calendar', 'end_my_fixed_programme', 'cohort_protect_programme_end'
)
ORDER BY p.oid::regprocedure::text;

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'programme_assignments' AND column_name = 'ended_at';

SELECT conname, convalidated, pg_get_constraintdef(oid)
FROM pg_constraint WHERE conrelid = 'public.programme_assignments'::regclass
ORDER BY conname;

SELECT tgname, tgenabled, pg_get_triggerdef(oid)
FROM pg_trigger WHERE tgrelid = 'public.programme_assignments'::regclass AND NOT tgisinternal
ORDER BY tgname;

SELECT i.indexrelid::regclass, i.indisunique, i.indisvalid, pg_get_indexdef(i.indexrelid)
FROM pg_index i WHERE i.indrelid = 'public.programme_assignments'::regclass AND i.indisunique
ORDER BY i.indexrelid::regclass::text;

SELECT c.relrowsecurity, c.relforcerowsecurity, pg_get_userbyid(c.relowner) AS owner,
       c.relacl
FROM pg_class c WHERE c.oid = 'public.programme_assignments'::regclass;
SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname = 'public' AND tablename = 'programme_assignments'
ORDER BY policyname;
SELECT a.attname, a.attacl FROM pg_attribute a
WHERE a.attrelid = 'public.programme_assignments'::regclass AND a.attnum > 0
AND NOT a.attisdropped ORDER BY a.attnum;

WITH
  assignments AS (
    SELECT * FROM public.programme_assignments WHERE athlete_id = :'athlete_id'::uuid
  ),
  outcomes AS (
    SELECT o.* FROM public.programme_slot_outcomes o JOIN assignments a ON a.id = o.assignment_id
  ),
  records AS (
    SELECT * FROM public.training_session_records WHERE athlete_id = :'athlete_id'
  ),
  blocks AS (
    SELECT b.* FROM public.training_block_results b JOIN records r ON r.record_id = b.session_record_id
  ),
  exercises AS (
    SELECT e.* FROM public.training_exercise_results e JOIN blocks b USING (block_result_id)
  ),
  protected AS (
    SELECT 'assignments' AS subject, to_jsonb(a) - 'ended_at' AS row_data FROM assignments a
    UNION ALL SELECT 'occurrences', to_jsonb(o) FROM public.programme_schedule_occurrences o JOIN assignments a ON a.id = o.assignment_id
    UNION ALL SELECT 'projections', to_jsonb(p) FROM public.programme_schedule_projections p JOIN assignments a ON a.id = p.assignment_id
    UNION ALL SELECT 'outcomes', to_jsonb(o) FROM outcomes o
    UNION ALL SELECT 'training_sessions', to_jsonb(s) FROM public.training_sessions s WHERE s.athlete_id = :'athlete_id'
    UNION ALL SELECT 'session_records', to_jsonb(r) FROM records r
    UNION ALL SELECT 'block_results', to_jsonb(b) FROM blocks b
    UNION ALL SELECT 'exercise_results', to_jsonb(e) FROM exercises e
    UNION ALL SELECT 'set_results', to_jsonb(s) FROM public.training_set_results s JOIN exercises e USING (exercise_result_id)
    UNION ALL SELECT 'eligibility', to_jsonb(e) FROM public.private_programme_alpha_eligibility e WHERE e.athlete_id = :'athlete_id'::uuid
    UNION ALL SELECT 'hybrid_version', to_jsonb(v) FROM public.programme_versions v WHERE v.id = :'hybrid_version_id'::uuid
  )
SELECT subject, count(*), encode(extensions.digest(convert_to(jsonb_agg(row_data ORDER BY row_data)::text, 'UTF8'), 'sha256'), 'hex') AS sha256
FROM protected GROUP BY subject ORDER BY subject;

SELECT jsonb_build_object(
  'verified_athlete', (SELECT count(*) FROM public.profiles p JOIN auth.users u ON u.id = p.id
    WHERE p.id = :'athlete_id'::uuid AND p.is_athlete AND u.email_confirmed_at IS NOT NULL),
  'hybrid_published', (SELECT count(*) FROM public.programme_versions v
    WHERE v.id = :'hybrid_version_id'::uuid AND v.lifecycle_status = 'published' AND v.archived_at IS NULL),
  'hybrid_scope_seal_sha256', (SELECT scope_seal_hash FROM public.programme_publication_artifacts
    WHERE programme_version_id = :'hybrid_version_id'::uuid),
  'bali_exact_active', (SELECT count(*) FROM public.programme_assignments a
    WHERE a.id = :'bali_assignment_id'::uuid AND a.athlete_id = :'athlete_id'::uuid
    AND a.programme_version_id = :'bali_version_id'::uuid AND a.status = 'active'
    AND a.schedule_mode = 'fixed_schedule' AND a.materialised_at IS NOT NULL
    AND to_jsonb(a)->>'ended_at' IS NULL),
  'athlete_active', (SELECT count(*) FROM public.programme_assignments a
    WHERE a.athlete_id = :'athlete_id'::uuid AND a.status = 'active'),
  'hybrid_assignments', (SELECT count(*) FROM public.programme_assignments a
    WHERE a.athlete_id = :'athlete_id'::uuid AND a.programme_version_id = :'hybrid_version_id'::uuid),
  'ended_assignments', (SELECT count(*) FROM public.programme_assignments a WHERE to_jsonb(a)->>'ended_at' IS NOT NULL)
);
COMMIT;
