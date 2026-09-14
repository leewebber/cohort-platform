-- Close the parent training_sessions row when a performance record becomes
-- terminal. Programme completion RPCs persist records and slot outcomes but
-- historically left training_sessions.status = in_progress unless a secondary
-- Dart write succeeded.
--
-- Additive: trigger + function only. No migration-time row writes.
-- Does not mark a session completed without a terminal record.
-- Abandoned records do not close the parent.
-- Compatible with prior app builds: extra parent-status update is observational
-- for Home/Calendar (those already use slot outcomes / occurrences).

CREATE OR REPLACE FUNCTION public.cohort_sync_training_session_from_terminal_record()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.training_session_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status NOT IN ('completed', 'partially_completed') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.status IN ('completed', 'partially_completed') THEN
    RETURN NEW;
  END IF;

  UPDATE public.training_sessions
  SET status = 'completed',
      completed_at = COALESCE(completed_at, NEW.completed_at, NOW()),
      ended_early = CASE
        WHEN NEW.status = 'partially_completed' THEN TRUE
        ELSE ended_early
      END,
      updated_at = NOW()
  WHERE id = NEW.training_session_id
    AND status IS DISTINCT FROM 'completed';

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_training_session_from_terminal_record
  ON public.training_session_records;

CREATE TRIGGER trg_sync_training_session_from_terminal_record
  AFTER INSERT OR UPDATE OF status ON public.training_session_records
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_sync_training_session_from_terminal_record();

COMMENT ON FUNCTION public.cohort_sync_training_session_from_terminal_record() IS
  'When a training_session_record becomes completed or partially_completed, close the linked training_sessions row. Never closes a parent without that terminal evidence.';
