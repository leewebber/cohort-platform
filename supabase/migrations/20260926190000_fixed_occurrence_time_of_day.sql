-- Presentation field only: expose authored slot time_of_day on the existing
-- calendar occurrence JSON. Does not change dates, assignments, or outcomes.

CREATE OR REPLACE FUNCTION public.cohort_fixed_occurrence_projection_json(
  p_occurrence_id UUID,
  p_today DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'id', o.id,
    'session_slot_id', o.session_slot_id,
    'programme_version_id', o.programme_version_id,
    'scheduled_date', o.scheduled_date,
    'original_scheduled_date', o.original_scheduled_date,
    'week_number', o.week_number,
    'day_key', o.day_key,
    'session_order', o.session_order,
    'protocol_id', o.protocol_id,
    'programmed_session_key', o.programmed_session_key,
    'session_title', COALESCE(NULLIF(TRIM(p.name), ''), o.protocol_id),
    'session_lineage_id', p.session_lineage_id,
    'session_revision_number', p.revision_number,
    'training_session_id', x.training_session_id,
    'time_of_day', COALESCE(s.time_of_day, 'any'),
    'state', CASE
      WHEN o.disposition = 'completed'
        OR x.outcome_status IN ('completed', 'completed_partial')
        THEN 'COMPLETED'
      WHEN o.disposition = 'skipped'
        OR x.outcome_status = 'skipped'
        THEN 'SKIPPED'
      WHEN x.outcome_status = 'in_progress'
        AND o.scheduled_date < p_today
        THEN 'IN_PROGRESS_OVERDUE'
      WHEN x.outcome_status = 'in_progress'
        THEN 'IN_PROGRESS'
      WHEN o.scheduled_date < p_today
        THEN 'OVERDUE'
      WHEN o.scheduled_date = p_today
        THEN 'TODAY'
      ELSE 'PLANNED'
    END
  )
  FROM public.programme_schedule_occurrences o
  JOIN public.performance_protocols p
    ON p.protocol_id = o.protocol_id
  LEFT JOIN public.programme_version_session_slots s
    ON s.id = o.session_slot_id
  LEFT JOIN public.programme_slot_outcomes x
    ON x.assignment_id = o.assignment_id
   AND x.session_slot_id = o.session_slot_id
  WHERE o.id = p_occurrence_id;
$$;
