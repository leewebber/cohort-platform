-- Convert programme_assignments.athlete_id from legacy TEXT to production UUID.
-- Must run BEFORE 20260721160000_add_programme_adaptation_events.sql, which joins
-- coach_athlete_relationships.athlete_id (UUID) to programme_assignments.athlete_id.
--
-- Production type: UUID NOT NULL referencing profiles.id (auth.users.id).
--
-- Legacy invalid values (e.g. dev-athlete 'lee'):
--   Rows with non-UUID athlete_id cannot map to authenticated profiles and are
--   deleted before conversion. Dependent slot outcomes and adaptation events
--   cascade via assignment_id ON DELETE CASCADE.
--
-- Valid UUID strings without a matching profile row are also removed so the
-- profiles FK can be enforced on hosted beta databases.

-- ---------------------------------------------------------------------------
-- Step 1 — Drop policies that compare programme_assignments.athlete_id
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS dev_programme_assignments_select ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_insert ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_update ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_coach_select ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_coach_insert ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_coach_update ON programme_assignments;

-- Slot outcome policies reference assignment athlete_id via subquery.
DROP POLICY IF EXISTS dev_programme_slot_outcomes_select ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_insert ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_update ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_delete ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_coach_select ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_coach_insert ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_coach_update ON programme_slot_outcomes;

-- ---------------------------------------------------------------------------
-- Step 2 — Remove legacy rows that cannot convert to UUID / profiles
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_invalid_count INTEGER;
  v_orphan_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO v_invalid_count
  FROM programme_assignments
  WHERE athlete_id !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';

  IF v_invalid_count > 0 THEN
    RAISE NOTICE
      'Removing % programme_assignments with non-UUID athlete_id (legacy dev values such as lee).',
      v_invalid_count;
  END IF;
END $$;

DELETE FROM programme_assignments
WHERE athlete_id !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';

DELETE FROM programme_assignments pa
WHERE NOT EXISTS (
  SELECT 1
  FROM profiles p
  WHERE p.id::TEXT = pa.athlete_id
);

-- ---------------------------------------------------------------------------
-- Step 3 — Convert column type (indexes rebuild automatically)
-- ---------------------------------------------------------------------------

ALTER TABLE programme_assignments
  ALTER COLUMN athlete_id TYPE UUID
  USING athlete_id::UUID;

ALTER TABLE programme_assignments
  ADD CONSTRAINT programme_assignments_athlete_id_fkey
  FOREIGN KEY (athlete_id) REFERENCES profiles (id) ON DELETE RESTRICT;

COMMENT ON COLUMN programme_assignments.athlete_id IS
  'Authenticated athlete identity (profiles.id / auth.users.id). Production UUID — not legacy TEXT dev ids.';

-- ---------------------------------------------------------------------------
-- Step 4 — Coach helper: UUID-native implementation + TEXT wrapper for
-- training_session_records.athlete_id (still TEXT until a future migration).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_coach_has_active_athlete(p_athlete_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM coach_athlete_relationships r
    WHERE r.coach_id = auth.uid()
      AND r.athlete_id = p_athlete_id
      AND r.status = 'active'
  );
$$;

COMMENT ON FUNCTION cohort_coach_has_active_athlete(UUID) IS
  'True when authenticated coach has an active relationship with the athlete UUID.';

CREATE OR REPLACE FUNCTION cohort_coach_has_active_athlete(p_athlete_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_athlete_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    THEN cohort_coach_has_active_athlete(p_athlete_id::UUID)
    ELSE FALSE
  END;
$$;

COMMENT ON FUNCTION cohort_coach_has_active_athlete(TEXT) IS
  'TEXT wrapper for legacy TEXT athlete columns (e.g. training_session_records).';

REVOKE ALL ON FUNCTION cohort_coach_has_active_athlete(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cohort_coach_has_active_athlete(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cohort_coach_has_active_athlete(TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- Step 5 — Recreate interim dev / coach policies until Sprint 8 lockdown
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_assignments_select
  ON programme_assignments
  FOR SELECT
  TO anon, authenticated
  USING (athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids()));

CREATE POLICY dev_programme_assignments_insert
  ON programme_assignments
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids()));

CREATE POLICY dev_programme_assignments_update
  ON programme_assignments
  FOR UPDATE
  TO anon, authenticated
  USING (athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids()))
  WITH CHECK (athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids()));

CREATE POLICY dev_programme_assignments_coach_select
  ON programme_assignments
  FOR SELECT
  TO authenticated
  USING (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY dev_programme_assignments_coach_insert
  ON programme_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY dev_programme_assignments_coach_update
  ON programme_assignments
  FOR UPDATE
  TO authenticated
  USING (cohort_coach_has_active_athlete(athlete_id))
  WITH CHECK (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY dev_programme_slot_outcomes_select
  ON programme_slot_outcomes
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids())
    )
  );

CREATE POLICY dev_programme_slot_outcomes_insert
  ON programme_slot_outcomes
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids())
    )
  );

CREATE POLICY dev_programme_slot_outcomes_update
  ON programme_slot_outcomes
  FOR UPDATE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids())
    )
  );

CREATE POLICY dev_programme_slot_outcomes_delete
  ON programme_slot_outcomes
  FOR DELETE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id::TEXT = ANY (cohort_programme_dev_athlete_ids())
    )
  );

CREATE POLICY dev_programme_slot_outcomes_coach_select
  ON programme_slot_outcomes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  );

CREATE POLICY dev_programme_slot_outcomes_coach_insert
  ON programme_slot_outcomes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  );

CREATE POLICY dev_programme_slot_outcomes_coach_update
  ON programme_slot_outcomes
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  );

-- ---------------------------------------------------------------------------
-- Hosted verification
-- ---------------------------------------------------------------------------
-- SELECT pg_typeof(athlete_id) FROM programme_assignments LIMIT 1;  -- uuid
-- SELECT conname FROM pg_constraint
--   WHERE conrelid = 'programme_assignments'::regclass
--     AND conname = 'programme_assignments_athlete_id_fkey';
-- Invalid legacy rows:
-- SELECT COUNT(*) FROM programme_assignments
--   WHERE athlete_id::text = 'lee';  -- expect 0
