-- Temporary dev DELETE policy for programme_slot_outcomes reset workflow
-- Related: lib/features/programme/debug/programme_debug_actions.dart
--
-- PROBLEM:
--   Reset Test Programme Assignment calls deleteOutcomesForAssignment via the
--   anon Supabase client. Dev RLS (20260715130000) granted SELECT/INSERT/UPDATE
--   on programme_slot_outcomes but not DELETE. With RLS enabled and no DELETE
--   policy, PostgREST DELETE succeeds with 0 rows removed — reset appeared to
--   work while completed day_1 outcomes remained, causing dayComplete resolution.
--
-- STRATEGY:
--   Add a narrowly scoped temporary DELETE policy scoped through parent
--   programme_assignments for cohort_programme_dev_athlete_ids() only.
--   No USING (true). Coach-private and organisation outcomes remain denied.
--
-- BEFORE BETA:
--   Drop dev_programme_slot_outcomes_delete with other dev_programme_* policies.
--
-- VALIDATION (after apply):
-- SELECT policyname, cmd
-- FROM pg_policies
-- WHERE tablename = 'programme_slot_outcomes'
--   AND policyname = 'dev_programme_slot_outcomes_delete';

CREATE POLICY dev_programme_slot_outcomes_delete
  ON programme_slot_outcomes
  FOR DELETE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND a.athlete_id = ANY (cohort_programme_dev_athlete_ids())
    )
  );

COMMENT ON POLICY dev_programme_slot_outcomes_delete ON programme_slot_outcomes IS
  'TEMPORARY DEV: allows Reset Test Programme Assignment to delete lee assignment outcomes. Drop before beta.';
