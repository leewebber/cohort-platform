-- Historical, generic close of parent training_sessions that already have
-- exactly one linked terminal performance record.
-- Depends on 20260914120000 (future-path trigger). No athlete-specific IDs.
-- Does not rewrite records, result trees, occurrences, slot outcomes, or cursors.
-- Idempotent: a second apply updates zero rows.
-- Excludes abandoned/in-progress-only parents, missing completed_at, empty
-- result trees, athlete mismatch, and any multi-record parent.

CREATE OR REPLACE FUNCTION public.cohort_reconcile_terminal_training_sessions_from_records()
RETURNS TABLE (
  training_session_id BIGINT,
  record_id UUID,
  previous_status TEXT,
  new_status TEXT,
  used_completed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  WITH linked_counts AS (
    SELECT
      r.training_session_id,
      COUNT(*) AS linked_count,
      COUNT(*) FILTER (
        WHERE r.status IN ('completed', 'partially_completed')
      ) AS terminal_count,
      COUNT(*) FILTER (
        WHERE r.status IN ('completed', 'partially_completed')
          AND r.completed_at IS NOT NULL
      ) AS dated_terminal_count
    FROM public.training_session_records r
    WHERE r.training_session_id IS NOT NULL
    GROUP BY r.training_session_id
  ),
  qualified AS (
    SELECT
      r.record_id,
      r.training_session_id,
      r.status AS record_status,
      r.completed_at,
      ts.status AS previous_status
    FROM public.training_session_records r
    JOIN linked_counts c ON c.training_session_id = r.training_session_id
    JOIN public.training_sessions ts ON ts.id = r.training_session_id
    WHERE r.status IN ('completed', 'partially_completed')
      AND r.completed_at IS NOT NULL
      AND c.linked_count = 1
      AND c.terminal_count = 1
      AND c.dated_terminal_count = 1
      AND ts.status IS DISTINCT FROM 'completed'
      AND (
        ts.athlete_id IS NULL
        OR r.athlete_id IS NULL
        OR ts.athlete_id = r.athlete_id
      )
      AND EXISTS (
        SELECT 1
        FROM public.training_block_results b
        WHERE b.session_record_id = r.record_id
      )
  ),
  updated AS (
    UPDATE public.training_sessions ts
    SET status = 'completed',
        completed_at = COALESCE(ts.completed_at, q.completed_at),
        ended_early = CASE
          WHEN q.record_status = 'partially_completed' THEN TRUE
          ELSE ts.ended_early
        END,
        updated_at = NOW()
    FROM qualified q
    WHERE ts.id = q.training_session_id
      AND ts.status IS DISTINCT FROM 'completed'
    RETURNING
      ts.id,
      q.record_id,
      q.previous_status,
      ts.status,
      ts.completed_at
  )
  SELECT
    updated.id,
    updated.record_id,
    updated.previous_status,
    updated.status,
    updated.completed_at
  FROM updated;
END;
$$;

COMMENT ON FUNCTION public.cohort_reconcile_terminal_training_sessions_from_records() IS
  'Idempotent historical close of non-terminal training_sessions that have exactly one linked completed or partially_completed record with completed_at and at least one block result. Does not close abandoned or in-progress-only parents, does not invent timestamps, and does not mutate records, occurrences, slot outcomes, or assignment cursors.';

SELECT *
FROM public.cohort_reconcile_terminal_training_sessions_from_records();
