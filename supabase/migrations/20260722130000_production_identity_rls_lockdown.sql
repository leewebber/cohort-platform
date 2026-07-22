-- V2.0 Sprint 8: Production identity and RLS lockdown
-- Removes permissive development policies and anon fallbacks.
-- Applies after 20260722120000_add_dual_role_self_assignment_policies.sql
--
-- Policies removed: all dev_programme_* and programme_adaptation_events_dev_* policies
-- Identity helpers: auth.uid() only — no dev-coach / lee fallbacks
-- Anon write access removed from private programme and performance tables

-- ---------------------------------------------------------------------------
-- Role helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_auth_is_coach()
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
  );
$$;

CREATE OR REPLACE FUNCTION cohort_auth_is_athlete()
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
      AND p.is_athlete = TRUE
  );
$$;

COMMENT ON FUNCTION cohort_auth_is_coach() IS
  'True when authenticated user has coach role on their profile.';

COMMENT ON FUNCTION cohort_auth_is_athlete() IS
  'True when authenticated user has athlete role on their profile.';

-- ---------------------------------------------------------------------------
-- Identity helpers — authenticated only (no anon fallbacks)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_programme_dev_coach_id()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN auth.uid() IS NOT NULL AND cohort_auth_is_coach()
    THEN auth.uid()::TEXT
    ELSE NULL
  END;
$$;

COMMENT ON FUNCTION cohort_programme_dev_coach_id() IS
  'Authenticated coach id (auth.uid). Returns NULL when unauthenticated or not a coach.';

CREATE OR REPLACE FUNCTION cohort_programme_dev_athlete_ids()
RETURNS TEXT[]
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN auth.uid() IS NOT NULL AND cohort_auth_is_athlete()
    THEN ARRAY[auth.uid()::TEXT]
    ELSE ARRAY[]::TEXT[]
  END;
$$;

COMMENT ON FUNCTION cohort_programme_dev_athlete_ids() IS
  'Authenticated athlete id array. Empty when unauthenticated or not an athlete.';

-- ---------------------------------------------------------------------------
-- Coach authoring SECURITY DEFINER helpers — auth.uid() ownership
-- ---------------------------------------------------------------------------

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
      AND auth.uid() IS NOT NULL
      AND cohort_auth_is_coach()
      AND l.created_by = auth.uid()::TEXT
  );
$$;

CREATE OR REPLACE FUNCTION cohort_programme_lineage_is_dev_coach_deletable(p_lineage_id UUID)
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
      AND auth.uid() IS NOT NULL
      AND cohort_auth_is_coach()
      AND l.created_by = auth.uid()::TEXT
      AND NOT EXISTS (
        SELECT 1
        FROM programme_versions v
        WHERE v.lineage_id = l.id
          AND v.lifecycle_status = 'published'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM programme_versions v
        JOIN programme_assignments a ON a.programme_version_id = v.id
        WHERE v.lineage_id = l.id
      )
  );
$$;

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_coach_readable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    WHERE v.id = p_version_id
      AND auth.uid() IS NOT NULL
      AND cohort_auth_is_coach()
      AND v.owner_type = 'coach'
      AND v.owner_id = auth.uid()::TEXT
      AND v.library_scope = 'coach_private'
      AND v.organisation_id IS NULL
      AND v.lifecycle_status IN ('draft', 'published', 'archived')
  );
$$;

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_coach_draft_writable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    JOIN programme_lineages l ON l.id = v.lineage_id
    WHERE v.id = p_version_id
      AND auth.uid() IS NOT NULL
      AND cohort_auth_is_coach()
      AND v.lifecycle_status = 'draft'
      AND v.owner_type = 'coach'
      AND v.owner_id = auth.uid()::TEXT
      AND v.library_scope = 'coach_private'
      AND v.approved_for_global = FALSE
      AND v.organisation_id IS NULL
      AND l.created_by = auth.uid()::TEXT
  );
$$;

CREATE OR REPLACE FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(p_version_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM programme_versions v
    WHERE v.id = p_version_id
      AND auth.uid() IS NOT NULL
      AND cohort_auth_is_coach()
      AND v.lifecycle_status = 'draft'
      AND v.owner_type = 'coach'
      AND v.owner_id = auth.uid()::TEXT
      AND v.library_scope = 'coach_private'
      AND v.organisation_id IS NULL
      AND v.published_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM programme_assignments a
        WHERE a.programme_version_id = v.id
      )
  );
$$;

REVOKE ALL ON FUNCTION cohort_auth_is_coach() FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_auth_is_athlete() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cohort_auth_is_coach() TO authenticated;
GRANT EXECUTE ON FUNCTION cohort_auth_is_athlete() TO authenticated;

REVOKE ALL ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_lineage_is_dev_coach_deletable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_coach_readable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_coach_draft_writable(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION cohort_programme_lineage_is_dev_coach_owned(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_lineage_is_dev_coach_deletable(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_coach_readable(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_coach_draft_writable(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cohort_programme_version_is_dev_coach_draft_deletable(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- DROP obsolete development policies (additive permissive policies)
-- ---------------------------------------------------------------------------

-- programme_lineages
DROP POLICY IF EXISTS dev_programme_lineages_select ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_insert ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_update ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_insert_coach ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_select_coach ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_update_coach ON programme_lineages;
DROP POLICY IF EXISTS dev_programme_lineages_delete_coach ON programme_lineages;

-- programme_versions
DROP POLICY IF EXISTS dev_programme_versions_select_catalogue ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_insert_draft_global ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_update_draft_global ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_select_coach ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_insert_coach_draft ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_update_coach_draft ON programme_versions;
DROP POLICY IF EXISTS dev_programme_versions_delete_coach_draft ON programme_versions;

-- template structure (global dev)
DROP POLICY IF EXISTS dev_programme_version_phases_select ON programme_version_phases;
DROP POLICY IF EXISTS dev_programme_version_phases_write ON programme_version_phases;
DROP POLICY IF EXISTS dev_programme_version_weeks_select ON programme_version_weeks;
DROP POLICY IF EXISTS dev_programme_version_weeks_write ON programme_version_weeks;
DROP POLICY IF EXISTS dev_programme_version_days_select ON programme_version_days;
DROP POLICY IF EXISTS dev_programme_version_days_write ON programme_version_days;
DROP POLICY IF EXISTS dev_programme_version_session_slots_select ON programme_version_session_slots;
DROP POLICY IF EXISTS dev_programme_version_session_slots_write ON programme_version_session_slots;

-- template structure (coach dev)
DROP POLICY IF EXISTS dev_programme_version_phases_select_coach ON programme_version_phases;
DROP POLICY IF EXISTS dev_programme_version_phases_write_coach ON programme_version_phases;
DROP POLICY IF EXISTS dev_programme_version_weeks_select_coach ON programme_version_weeks;
DROP POLICY IF EXISTS dev_programme_version_weeks_write_coach ON programme_version_weeks;
DROP POLICY IF EXISTS dev_programme_version_days_select_coach ON programme_version_days;
DROP POLICY IF EXISTS dev_programme_version_days_write_coach ON programme_version_days;
DROP POLICY IF EXISTS dev_programme_version_session_slots_select_coach ON programme_version_session_slots;
DROP POLICY IF EXISTS dev_programme_version_session_slots_write_coach ON programme_version_session_slots;

-- assignments and outcomes (athlete dev)
DROP POLICY IF EXISTS dev_programme_assignments_select ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_insert ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_update ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_select ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_insert ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_update ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_delete ON programme_slot_outcomes;

-- assignments and outcomes (coach dev naming — production logic retained below)
DROP POLICY IF EXISTS dev_programme_assignments_coach_select ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_coach_insert ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_assignments_coach_update ON programme_assignments;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_coach_select ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_coach_insert ON programme_slot_outcomes;
DROP POLICY IF EXISTS dev_programme_slot_outcomes_coach_update ON programme_slot_outcomes;

-- adaptation events
DROP POLICY IF EXISTS programme_adaptation_events_dev_athlete_select ON programme_adaptation_events;
DROP POLICY IF EXISTS programme_adaptation_events_dev_athlete_insert ON programme_adaptation_events;
DROP POLICY IF EXISTS programme_adaptation_events_dev_coach_select ON programme_adaptation_events;

-- performance records
DROP POLICY IF EXISTS dev_performance_records_select ON training_session_records;
DROP POLICY IF EXISTS dev_performance_records_insert ON training_session_records;
DROP POLICY IF EXISTS dev_performance_records_update ON training_session_records;
DROP POLICY IF EXISTS dev_performance_block_results_all ON training_block_results;
DROP POLICY IF EXISTS dev_performance_exercise_results_all ON training_exercise_results;
DROP POLICY IF EXISTS dev_performance_set_results_all ON training_set_results;

-- ---------------------------------------------------------------------------
-- Production programme_lineages policies
-- ---------------------------------------------------------------------------

CREATE POLICY programme_lineages_select_catalogue
  ON programme_lineages
  FOR SELECT
  TO authenticated
  USING (cohort_programme_lineage_has_dev_readable_version(id));

COMMENT ON POLICY programme_lineages_select_catalogue ON programme_lineages IS
  'Authenticated read for lineages with readable Cohort Global catalogue versions.';

CREATE POLICY programme_lineages_insert_coach
  ON programme_lineages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    cohort_auth_is_coach()
    AND created_by = auth.uid()::TEXT
  );

CREATE POLICY programme_lineages_select_coach
  ON programme_lineages
  FOR SELECT
  TO authenticated
  USING (cohort_programme_lineage_is_dev_coach_owned(id));

CREATE POLICY programme_lineages_update_coach
  ON programme_lineages
  FOR UPDATE
  TO authenticated
  USING (cohort_programme_lineage_is_dev_coach_owned(id))
  WITH CHECK (
    cohort_auth_is_coach()
    AND created_by = auth.uid()::TEXT
  );

CREATE POLICY programme_lineages_delete_coach
  ON programme_lineages
  FOR DELETE
  TO authenticated
  USING (cohort_programme_lineage_is_dev_coach_deletable(id));

-- ---------------------------------------------------------------------------
-- Production programme_versions policies
-- ---------------------------------------------------------------------------

CREATE POLICY programme_versions_select_catalogue
  ON programme_versions
  FOR SELECT
  TO authenticated
  USING (
    (
      lifecycle_status = 'published'
      AND library_scope = 'cohort_global'
      AND approved_for_global = TRUE
    )
    OR (
      lifecycle_status = 'draft'
      AND library_scope = 'cohort_global'
      AND owner_type = 'global'
    )
  );

COMMENT ON POLICY programme_versions_select_catalogue ON programme_versions IS
  'Authenticated read for published global catalogue and global draft fixtures.';

CREATE POLICY programme_versions_select_coach
  ON programme_versions
  FOR SELECT
  TO authenticated
  USING (cohort_programme_version_is_dev_coach_readable(id));

CREATE POLICY programme_versions_insert_coach_draft
  ON programme_versions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    cohort_auth_is_coach()
    AND lifecycle_status = 'draft'
    AND owner_type = 'coach'
    AND owner_id = auth.uid()::TEXT
    AND library_scope = 'coach_private'
    AND approved_for_global = FALSE
    AND organisation_id IS NULL
    AND cohort_programme_lineage_is_dev_coach_owned(lineage_id)
  );

CREATE POLICY programme_versions_update_coach_draft
  ON programme_versions
  FOR UPDATE
  TO authenticated
  USING (cohort_programme_version_is_dev_coach_draft_writable(id))
  WITH CHECK (cohort_programme_version_is_dev_coach_draft_writable(id));

CREATE POLICY programme_versions_delete_coach_draft
  ON programme_versions
  FOR DELETE
  TO authenticated
  USING (cohort_programme_version_is_dev_coach_draft_deletable(id));

-- ---------------------------------------------------------------------------
-- Production template tree policies (coach-owned drafts)
-- ---------------------------------------------------------------------------

CREATE POLICY programme_version_phases_select_coach
  ON programme_version_phases
  FOR SELECT
  TO authenticated
  USING (cohort_programme_version_is_dev_coach_readable(version_id));

CREATE POLICY programme_version_phases_write_coach
  ON programme_version_phases
  FOR ALL
  TO authenticated
  USING (cohort_programme_version_is_dev_coach_draft_writable(version_id))
  WITH CHECK (cohort_programme_version_is_dev_coach_draft_writable(version_id));

CREATE POLICY programme_version_weeks_select_coach
  ON programme_version_weeks
  FOR SELECT
  TO authenticated
  USING (cohort_programme_version_is_dev_coach_readable(version_id));

CREATE POLICY programme_version_weeks_write_coach
  ON programme_version_weeks
  FOR ALL
  TO authenticated
  USING (cohort_programme_version_is_dev_coach_draft_writable(version_id))
  WITH CHECK (cohort_programme_version_is_dev_coach_draft_writable(version_id));

CREATE POLICY programme_version_days_select_coach
  ON programme_version_days
  FOR SELECT
  TO authenticated
  USING (cohort_programme_day_is_dev_coach_readable(id));

CREATE POLICY programme_version_days_write_coach
  ON programme_version_days
  FOR ALL
  TO authenticated
  USING (cohort_programme_day_is_dev_coach_draft_writable(id))
  WITH CHECK (cohort_programme_day_is_dev_coach_draft_writable(id));

CREATE POLICY programme_version_session_slots_select_coach
  ON programme_version_session_slots
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_version_is_dev_coach_readable(w.version_id)
    )
  );

CREATE POLICY programme_version_session_slots_write_coach
  ON programme_version_session_slots
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_day_is_dev_coach_draft_writable(d.id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_day_is_dev_coach_draft_writable(d.id)
    )
  );

-- Global catalogue template read (authenticated)
CREATE POLICY programme_version_phases_select_catalogue
  ON programme_version_phases
  FOR SELECT
  TO authenticated
  USING (cohort_programme_version_is_dev_readable(version_id));

CREATE POLICY programme_version_weeks_select_catalogue
  ON programme_version_weeks
  FOR SELECT
  TO authenticated
  USING (cohort_programme_version_is_dev_readable(version_id));

CREATE POLICY programme_version_days_select_catalogue
  ON programme_version_days
  FOR SELECT
  TO authenticated
  USING (cohort_programme_week_is_dev_readable(week_id));

CREATE POLICY programme_version_session_slots_select_catalogue
  ON programme_version_session_slots
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_version_days d
      JOIN programme_version_weeks w ON w.id = d.week_id
      WHERE d.id = programme_version_session_slots.day_id
        AND cohort_programme_version_is_dev_readable(w.version_id)
    )
  );

-- ---------------------------------------------------------------------------
-- Production programme_assignments policies
-- ---------------------------------------------------------------------------

CREATE POLICY programme_assignments_athlete_select
  ON programme_assignments
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid()::TEXT);

CREATE POLICY programme_assignments_athlete_update
  ON programme_assignments
  FOR UPDATE
  TO authenticated
  USING (athlete_id = auth.uid()::TEXT)
  WITH CHECK (athlete_id = auth.uid()::TEXT);

-- programme_assignments_dual_role_self_insert retained from 20260722120000

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

-- ---------------------------------------------------------------------------
-- Production programme_slot_outcomes policies
-- ---------------------------------------------------------------------------

CREATE POLICY programme_slot_outcomes_athlete_select
  ON programme_slot_outcomes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = auth.uid()::TEXT
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
        AND a.athlete_id = auth.uid()::TEXT
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
        AND a.athlete_id = auth.uid()::TEXT
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = auth.uid()::TEXT
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

-- ---------------------------------------------------------------------------
-- Production programme_adaptation_events policies
-- ---------------------------------------------------------------------------

CREATE POLICY programme_adaptation_events_athlete_select
  ON programme_adaptation_events
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid());

CREATE POLICY programme_adaptation_events_athlete_insert
  ON programme_adaptation_events
  FOR INSERT
  TO authenticated
  WITH CHECK (athlete_id = auth.uid());

CREATE POLICY programme_adaptation_events_coach_select
  ON programme_adaptation_events
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM coach_athlete_relationships car
      WHERE car.athlete_id = programme_adaptation_events.athlete_id
        AND car.coach_id = auth.uid()
        AND car.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Production performance record policies
-- ---------------------------------------------------------------------------

CREATE POLICY performance_records_athlete_select
  ON training_session_records
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid()::TEXT);

CREATE POLICY performance_records_athlete_insert
  ON training_session_records
  FOR INSERT
  TO authenticated
  WITH CHECK (athlete_id = auth.uid()::TEXT);

CREATE POLICY performance_records_athlete_update
  ON training_session_records
  FOR UPDATE
  TO authenticated
  USING (
    athlete_id = auth.uid()::TEXT
    AND status = 'in_progress'
  )
  WITH CHECK (athlete_id = auth.uid()::TEXT);

CREATE POLICY performance_records_coach_select
  ON training_session_records
  FOR SELECT
  TO authenticated
  USING (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY performance_block_results_athlete_all
  ON training_block_results
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM training_session_records r
      WHERE r.record_id = training_block_results.session_record_id
        AND r.athlete_id = auth.uid()::TEXT
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM training_session_records r
      WHERE r.record_id = training_block_results.session_record_id
        AND r.athlete_id = auth.uid()::TEXT
        AND r.status = 'in_progress'
    )
  );

CREATE POLICY performance_block_results_coach_select
  ON training_block_results
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM training_session_records r
      WHERE r.record_id = training_block_results.session_record_id
        AND cohort_coach_has_active_athlete(r.athlete_id)
    )
  );

CREATE POLICY performance_exercise_results_athlete_all
  ON training_exercise_results
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM training_block_results b
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE b.block_result_id = training_exercise_results.block_result_id
        AND r.athlete_id = auth.uid()::TEXT
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM training_block_results b
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE b.block_result_id = training_exercise_results.block_result_id
        AND r.athlete_id = auth.uid()::TEXT
        AND r.status = 'in_progress'
    )
  );

CREATE POLICY performance_exercise_results_coach_select
  ON training_exercise_results
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM training_block_results b
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE b.block_result_id = training_exercise_results.block_result_id
        AND cohort_coach_has_active_athlete(r.athlete_id)
    )
  );

CREATE POLICY performance_set_results_athlete_all
  ON training_set_results
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM training_exercise_results e
      JOIN training_block_results b ON b.block_result_id = e.block_result_id
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE e.exercise_result_id = training_set_results.exercise_result_id
        AND r.athlete_id = auth.uid()::TEXT
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM training_exercise_results e
      JOIN training_block_results b ON b.block_result_id = e.block_result_id
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE e.exercise_result_id = training_set_results.exercise_result_id
        AND r.athlete_id = auth.uid()::TEXT
        AND r.status = 'in_progress'
    )
  );

CREATE POLICY performance_set_results_coach_select
  ON training_set_results
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM training_exercise_results e
      JOIN training_block_results b ON b.block_result_id = e.block_result_id
      JOIN training_session_records r ON r.record_id = b.session_record_id
      WHERE e.exercise_result_id = training_set_results.exercise_result_id
        AND cohort_coach_has_active_athlete(r.athlete_id)
    )
  );

-- ---------------------------------------------------------------------------
-- Hosted verification checklist (manual)
-- ---------------------------------------------------------------------------
-- 1. Authenticated coach can INSERT programme_lineages with created_by = auth.uid()
-- 2. Authenticated coach can create coach_private draft version under owned lineage
-- 3. Unauthenticated anon cannot SELECT/INSERT programme_versions (42501)
-- 4. Athlete can SELECT own programme_assignments; unrelated athlete denied
-- 5. Dual-role user can self-assign (programme_assignments_dual_role_self_insert)
-- 6. Linked coach can assign to linked athlete; unrelated coach denied
-- 7. Cohort Global published catalogue readable when authenticated
-- 8. Legacy dev-coach rows without ownership migration remain inaccessible (expected)
