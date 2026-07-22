-- V2.0: Dual-role personal training self-assignment
-- Allows coach+athlete users to assign programmes to themselves without a coach–athlete relationship.
-- Tightens athlete-scoped assignment INSERT to dual-role profiles only.

CREATE OR REPLACE FUNCTION cohort_auth_is_dual_role_coach_athlete()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles p
    WHERE p.id = auth.uid()
      AND p.is_coach = TRUE
      AND p.is_athlete = TRUE
  );
$$;

COMMENT ON FUNCTION cohort_auth_is_dual_role_coach_athlete() IS
  'True when authenticated user has both coach and athlete roles on their profile.';

-- Replace broad dev athlete insert with dual-role self-assignment only.
DROP POLICY IF EXISTS dev_programme_assignments_insert ON programme_assignments;

CREATE POLICY programme_assignments_dual_role_self_insert
  ON programme_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    athlete_id = auth.uid()::TEXT
    AND cohort_auth_is_dual_role_coach_athlete()
  );

COMMENT ON POLICY programme_assignments_dual_role_self_insert ON programme_assignments IS
  'Dual-role users may assign programmes to their own athlete identity.';
