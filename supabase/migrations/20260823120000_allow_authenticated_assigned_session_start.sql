-- Athlete programme-session start follows the canonical create/resume RPC.
-- Once that RPC has resolved an athlete-owned materialised session, the
-- workout player persists its in-progress performance draft through the
-- existing training_*_results tree. The production RLS policies already
-- constrain this tree to the authenticated athlete and in-progress records;
-- these grants restore the underlying PostgREST privileges required before
-- those policies can be evaluated.
--
-- Deliberately do not grant direct mutation of training_sessions,
-- programme_slot_outcomes, or programme_assignments. Those transitions
-- remain owned by their canonical RPCs.

GRANT SELECT, INSERT, UPDATE ON TABLE public.training_session_records
  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.training_block_results
  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.training_exercise_results
  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.training_set_results
  TO authenticated;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.training_sessions FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.programme_slot_outcomes FROM authenticated;

COMMENT ON TABLE public.training_session_records IS
  'Athlete performance drafts are readable and writable only through restrictive RLS; programme session transitions remain RPC-owned.';
