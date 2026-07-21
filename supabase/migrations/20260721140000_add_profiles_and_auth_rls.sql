-- V2.0: User profiles and authenticated RLS bridge
-- Enables Supabase Auth users to access athlete/coach data via auth.uid().
-- Legacy dev identities ('lee', 'dev-coach') remain accessible for transition.

-- ---------------------------------------------------------------------------
-- profiles — one row per auth user
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  is_coach    BOOLEAN NOT NULL DEFAULT FALSE,
  is_athlete  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT profiles_role_check CHECK (is_coach OR is_athlete)
);

COMMENT ON TABLE profiles IS
  'Coach/athlete identity for authenticated Cohort users. id matches auth.users.id.';

CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION cohort_set_updated_at();

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select_own
  ON profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY profiles_insert_own
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY profiles_update_own
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ---------------------------------------------------------------------------
-- Bridge dev RLS helpers to auth.uid()
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_programme_dev_athlete_ids()
RETURNS TEXT[]
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN auth.uid() IS NOT NULL THEN ARRAY[auth.uid()::TEXT]
    ELSE ARRAY['lee']::TEXT[]
  END;
$$;

COMMENT ON FUNCTION cohort_programme_dev_athlete_ids() IS
  'Authenticated: current user athlete id. Anon fallback: legacy dev athlete (lee).';

CREATE OR REPLACE FUNCTION cohort_programme_dev_coach_id()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(auth.uid()::TEXT, 'dev-coach');
$$;

COMMENT ON FUNCTION cohort_programme_dev_coach_id() IS
  'Authenticated: current user coach id. Anon fallback: legacy dev-coach.';

-- Allow authenticated coaches to access legacy dev-coach authored content during transition.
CREATE OR REPLACE FUNCTION cohort_programme_lineage_is_dev_coach_owned(p_lineage_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_lineages l
    WHERE l.id = p_lineage_id
      AND (
        l.created_by = cohort_programme_dev_coach_id()
        OR (auth.uid() IS NOT NULL AND l.created_by = 'dev-coach')
        OR l.created_by IS NULL
      )
  );
$$;
