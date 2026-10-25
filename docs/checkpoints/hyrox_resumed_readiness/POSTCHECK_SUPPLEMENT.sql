-- Prepared SELECT-only postchecks for the exact eight-file schema-only stage.
-- Catalog checks are valid before apply and deliberately report absent/false.
-- Require every present/body field TRUE after all eight migrations commit.
WITH expected(signature,sha256) AS (VALUES
('retain_published_exercise_event_v1(text,jsonb,jsonb)','61c16aa40d97be7ff2d776baceea9ca973b80d214c3284a28ff3db58d5ff99f2'),
('cohort_v3_validate(jsonb)','8bf66b2d62cffb7e143997835e9c29f586615492faeb6a472ad0c89a54de982d'),
('create_or_resume_fixed_programme_occurrence_session(uuid,uuid,jsonb)','49f852b9448f247c4599cfcc8e1006e47925974f55c692ccb9ee49580f8a80ab'),
('create_or_resume_fixed_programme_occurrence_session(uuid,uuid)','57ab3abf68a8b95a3260e98ac1dd8bf531f3e393b71feee5842025ba85871b57'),
('cohort_duration_record_prescription_guard()','627a8c14d1a5a0648d3dd151691124e5e685a292600fa0c74bc83ad6c16a1e86'),
('cohort_fixed_occurrence_before_duration_choice(uuid,uuid)','bd512c2cbf79fa0be75039dc884d9d8f86e105cef939c5d96e834906d314a560'))
SELECT e.signature,p.oid IS NOT NULL AS present,
 encode(sha256(convert_to(p.prosrc,'UTF8')),'hex')=e.sha256 AS exact_final_body,
 pg_get_userbyid(p.proowner) AS owner,p.prosecdef,p.proconfig,p.proacl
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure('public.'||e.signature)
ORDER BY e.signature;

-- Capability remains unusable: no login/privileged flags and only a possible
-- creator ADMIN-only link, with SET and INHERIT false. Never provision a login here.
SELECT rolname,NOT(rolcanlogin OR rolinherit OR rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls) AS exact_unusable_flags
FROM pg_roles WHERE rolname='cohort_exercise_version_publisher';
WITH capability AS (SELECT oid FROM pg_roles WHERE rolname='cohort_exercise_version_publisher'),
 owner AS (SELECT proowner FROM pg_proc WHERE oid=to_regprocedure('public.retain_published_exercise_definition_v1(text,jsonb)'))
SELECT count(*) AS unexpected_memberships FROM pg_auth_members m
WHERE (m.roleid IN(SELECT oid FROM capability) AND
 (m.member IS DISTINCT FROM(SELECT proowner FROM owner) OR m.inherit_option OR m.set_option OR NOT m.admin_option))
 OR m.member IN(SELECT oid FROM capability);

-- Atomic retention is publisher-only. New start overloads are athlete-only;
-- private delegates, validators and trigger functions have no external EXECUTE.
WITH expected(signature,allowed_role) AS (VALUES
 ('retain_published_exercise_event_v1(text,jsonb,jsonb)','cohort_exercise_version_publisher'),
 ('create_or_resume_fixed_programme_occurrence_session(uuid,uuid,jsonb)','authenticated'),
 ('create_or_resume_fixed_programme_occurrence_session(uuid,uuid)','authenticated'),
 ('cohort_fixed_occurrence_before_duration_choice(uuid,uuid)',NULL),
 ('cohort_v3_validate(jsonb)',NULL),('cohort_duration_record_prescription_guard()',NULL))
SELECT e.signature,r.rolname,p.oid IS NOT NULL AS present,
 has_function_privilege(r.oid,p.oid,'EXECUTE') IS NOT DISTINCT FROM coalesce(r.rolname=e.allowed_role,false) AS expected_effective_execute,
 NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE') AS no_public_execute
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure('public.'||e.signature)
CROSS JOIN pg_roles r WHERE r.rolname IN('anon','authenticated','service_role','cohort_exercise_version_publisher')
ORDER BY e.signature,r.rolname;

SELECT c.relname,c.relrowsecurity,c.relforcerowsecurity,pg_get_userbyid(c.relowner) AS owner,c.relacl
FROM pg_class c WHERE c.oid=to_regclass('public.programme_occurrence_duration_choices');
SELECT t.tgname,t.tgenabled,pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger t WHERE NOT t.tgisinternal AND t.tgname IN('duration_choice_immutable','guard_duration_record_prescription') ORDER BY t.tgname;
SELECT polname,pg_get_expr(polqual,polrelid) AS owner_predicate
FROM pg_policy WHERE polrelid=to_regclass('public.programme_occurrence_duration_choices');
