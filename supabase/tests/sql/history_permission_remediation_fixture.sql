-- Adverse permissions from the immutable readiness audit; synthetic data only.
-- These grants deliberately recreate the defect BEFORE remediation, never make
-- a denied operation pass. Extra PUBLIC/column grants exercise revocation drift.
CREATE FUNCTION public.history_permission_assert(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'HISTORY_PERMISSION_GATE: %', label; END IF;
END $$;

INSERT INTO public.training_sessions(id,athlete_id,protocol_id,status)
VALUES (987010,'c2000000-0000-4000-8000-000000000002','synthetic.protocol.b','completed');

-- Exact synthetic block/field bindings; no title or comparison-context inference.
INSERT INTO public.training_session_records(record_id,athlete_id,status,session_snapshot,started_at,completed_at)
SELECT ('d7100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'c2000000-0000-4000-8000-000000000001','completed','{}','2026-01-02T12:00:00Z','2026-01-02T12:01:00Z'
FROM generate_series(1,2) n;
INSERT INTO public.training_block_results(block_result_id,session_record_id,source_block_id,block_snapshot,status,result_type,result_data,position)
SELECT ('d7200000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('d7100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'permission.distance',
 '{"sourceBlockId":"permission.distance"}','completed','distance',
 jsonb_build_object('resultType','distance','distanceUnit','km','distance',n-1),1
FROM generate_series(1,2) n;

CREATE TABLE public.history_permission_data_before(relation_name text PRIMARY KEY, digest text);
DO $$ DECLARE t record; d text; BEGIN
  FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r' AND c.relname<>'history_permission_data_before'
  LOOP
    EXECUTE format('SELECT md5(coalesce(string_agg(to_jsonb(t)::text, chr(10) ORDER BY to_jsonb(t)::text),%L)) FROM public.%I t','',t.relname) INTO d;
    INSERT INTO public.history_permission_data_before VALUES(t.relname,d);
  END LOOP;
END $$;
CREATE TABLE public.history_permission_functions_before AS
SELECT oid,md5(pg_get_functiondef(oid)) AS digest,proacl::text AS acl
FROM pg_proc WHERE pronamespace='public'::regnamespace AND prokind='f';
CREATE TABLE public.history_permission_policies_before AS
SELECT polrelid,polname,polcmd,polroles,polpermissive,
 pg_get_expr(polqual,polrelid) AS qual,pg_get_expr(polwithcheck,polrelid) AS checked
FROM pg_policy WHERE polrelid<>'public.training_sessions'::regclass;
CREATE TABLE public.history_permission_server_grants_before AS
SELECT c.oid,r.rolname,x.privilege,has_table_privilege(r.oid,c.oid,x.privilege) AS allowed
FROM pg_class c CROSS JOIN pg_roles r CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) x(privilege)
WHERE c.oid IN ('public.training_sessions'::regclass,'public.training_session_records'::regclass,
 'public.training_block_results'::regclass,'public.training_exercise_results'::regclass,
 'public.training_set_results'::regclass,'public.performance_result_corrections'::regclass,
 'public.coach_athlete_relationships'::regclass,'public.profiles'::regclass)
AND r.rolname IN ('postgres','service_role');

DROP POLICY training_sessions_athlete_select ON public.training_sessions;
ALTER TABLE public.training_sessions DISABLE ROW LEVEL SECURITY;
GRANT ALL PRIVILEGES ON public.training_sessions,public.training_session_records,
 public.training_block_results,public.training_exercise_results,public.training_set_results,
 public.coach_athlete_relationships,public.profiles TO anon;
GRANT SELECT,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN ON public.performance_result_corrections TO anon,authenticated;
GRANT SELECT,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN ON public.training_sessions TO authenticated;
GRANT ALL PRIVILEGES ON public.training_session_records,public.training_block_results,
 public.training_exercise_results,public.training_set_results,public.coach_athlete_relationships,
 public.profiles TO authenticated;
GRANT SELECT ON public.training_sessions TO PUBLIC;
GRANT SELECT(athlete_id),UPDATE(athlete_id) ON public.training_sessions TO PUBLIC,anon,authenticated;
GRANT SELECT,USAGE,UPDATE ON public.training_sessions_id_seq TO PUBLIC,anon,authenticated;
SELECT public.history_permission_assert(has_table_privilege('anon','public.training_sessions','SELECT')
 AND NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.training_sessions'::regclass), 'adverse input actually reproduces audited session exposure');
\echo HISTORY_PERMISSION_ADVERSE_INPUT=PASS
