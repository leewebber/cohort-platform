-- Bounded History/session permission remediation. No evidence or programme writes.
-- Canonical start/completion remain owner-checked SECURITY DEFINER transactions.
-- Direct training_sessions INSERT/UPDATE/DELETE were explicitly retired by
-- 20260823120000; the legacy unmounted launcher is not a grant authority.
BEGIN;

-- Fail closed if this target has an unreviewed session policy. Adding an owner
-- policy beside an unknown permissive policy would not establish isolation.
DO $guard$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_policy
    WHERE polrelid = 'public.training_sessions'::regclass
      AND polname <> 'training_sessions_athlete_select') THEN
    RAISE EXCEPTION 'unreviewed_training_sessions_policy';
  END IF;
END;
$guard$;

-- Reset only the eight audited relations. PUBLIC and column grants must also be
-- removed: a table-level REVOKE alone does not revoke a separate column grant.
REVOKE ALL PRIVILEGES ON TABLE public.training_sessions,
  public.training_session_records, public.training_block_results,
  public.training_exercise_results, public.training_set_results,
  public.performance_result_corrections, public.coach_athlete_relationships,
  public.profiles FROM PUBLIC, anon, authenticated;

DO $columns$
DECLARE
  relation_name text;
  columns_sql text;
BEGIN
  FOREACH relation_name IN ARRAY ARRAY['training_sessions',
    'training_session_records','training_block_results','training_exercise_results',
    'training_set_results','performance_result_corrections',
    'coach_athlete_relationships','profiles'] LOOP
    SELECT string_agg(quote_ident(attname), ', ' ORDER BY attnum) INTO columns_sql
    FROM pg_catalog.pg_attribute
    WHERE attrelid = format('public.%I', relation_name)::regclass
      AND attnum > 0 AND NOT attisdropped;
    EXECUTE format('REVOKE SELECT (%1$s), INSERT (%1$s), UPDATE (%1$s), REFERENCES (%1$s)
      ON TABLE public.%2$I FROM PUBLIC, anon, authenticated', columns_sql, relation_name);
  END LOOP;
END;
$columns$;

-- Identity allocation is exclusively server-owned along with session creation.
DO $sequence$
DECLARE sequence_name text := pg_get_serial_sequence('public.training_sessions','id');
BEGIN
  IF sequence_name IS NULL THEN RAISE EXCEPTION 'training_sessions_identity_missing'; END IF;
  EXECUTE format('REVOKE ALL PRIVILEGES ON SEQUENCE %s FROM PUBLIC, anon, authenticated', sequence_name);
END;
$sequence$;

ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS training_sessions_athlete_select ON public.training_sessions;
CREATE POLICY training_sessions_athlete_select ON public.training_sessions
  FOR SELECT TO authenticated
  USING (athlete_id = auth.uid()::text AND public.cohort_auth_is_athlete());

-- Required restore/previous-performance parent reads; no client session mutation.
GRANT SELECT ON TABLE public.training_sessions TO authenticated;
-- Existing in-progress draft RLS and active-relationship coach reads are retained.
GRANT SELECT, INSERT, UPDATE ON TABLE public.training_session_records,
  public.training_block_results, public.training_exercise_results,
  public.training_set_results TO authenticated;
GRANT SELECT ON TABLE public.performance_result_corrections,
  public.coach_athlete_relationships TO authenticated;
-- Existing own-profile provisioning/edit policies remain the identity boundary.
GRANT SELECT, INSERT, UPDATE ON TABLE public.profiles TO authenticated;

-- No service-role/postgres grants, existing History policies, RPC bodies/grants,
-- publication artifacts, assignments, package contracts or release guards change.
COMMIT;
