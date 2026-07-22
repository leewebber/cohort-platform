-- Normalize programme_assignments UUID RLS policies after Sprint 8 lockdown.
-- Depends on 20260721155000_convert_programme_assignments_athlete_id_to_uuid.sql
-- and 20260722130000_production_identity_rls_lockdown.sql.
--
-- Removes auth.uid()::TEXT casts on UUID athlete_id comparisons.

DROP POLICY IF EXISTS programme_assignments_athlete_select ON programme_assignments;
DROP POLICY IF EXISTS programme_assignments_athlete_update ON programme_assignments;
DROP POLICY IF EXISTS programme_assignments_dual_role_self_insert ON programme_assignments;
DROP POLICY IF EXISTS programme_assignments_coach_select ON programme_assignments;
DROP POLICY IF EXISTS programme_assignments_coach_insert ON programme_assignments;
DROP POLICY IF EXISTS programme_assignments_coach_update ON programme_assignments;

CREATE POLICY programme_assignments_athlete_select
  ON programme_assignments
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid());

CREATE POLICY programme_assignments_athlete_update
  ON programme_assignments
  FOR UPDATE
  TO authenticated
  USING (athlete_id = auth.uid())
  WITH CHECK (athlete_id = auth.uid());

CREATE POLICY programme_assignments_dual_role_self_insert
  ON programme_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    athlete_id = auth.uid()
    AND cohort_auth_is_dual_role_coach_athlete()
  );

CREATE POLICY programme_assignments_coach_select
  ON programme_assignments
  FOR SELECT
  TO authenticated
  USING (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY programme_assignments_coach_insert
  ON programme_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY programme_assignments_coach_update
  ON programme_assignments
  FOR UPDATE
  TO authenticated
  USING (cohort_coach_has_active_athlete(athlete_id))
  WITH CHECK (cohort_coach_has_active_athlete(athlete_id));

DROP POLICY IF EXISTS programme_slot_outcomes_athlete_select ON programme_slot_outcomes;
DROP POLICY IF EXISTS programme_slot_outcomes_athlete_insert ON programme_slot_outcomes;
DROP POLICY IF EXISTS programme_slot_outcomes_athlete_update ON programme_slot_outcomes;
DROP POLICY IF EXISTS programme_slot_outcomes_coach_select ON programme_slot_outcomes;
DROP POLICY IF EXISTS programme_slot_outcomes_coach_insert ON programme_slot_outcomes;
DROP POLICY IF EXISTS programme_slot_outcomes_coach_update ON programme_slot_outcomes;

CREATE POLICY programme_slot_outcomes_athlete_select
  ON programme_slot_outcomes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = auth.uid()
    )
  );

CREATE POLICY programme_slot_outcomes_athlete_insert
  ON programme_slot_outcomes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = auth.uid()
    )
  );

CREATE POLICY programme_slot_outcomes_athlete_update
  ON programme_slot_outcomes
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = auth.uid()
    )
  );

CREATE POLICY programme_slot_outcomes_coach_select
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

CREATE POLICY programme_slot_outcomes_coach_insert
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

CREATE POLICY programme_slot_outcomes_coach_update
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
