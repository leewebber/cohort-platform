-- Existing programme structure RLS policies limit rows to catalogue-visible
-- versions and linked coach access. Restore only the base privileges needed by
-- the athlete ProgrammeStore tree read.
GRANT SELECT ON TABLE public.programme_version_phases TO authenticated;
GRANT SELECT ON TABLE public.programme_version_weeks TO authenticated;
GRANT SELECT ON TABLE public.programme_version_days TO authenticated;
GRANT SELECT ON TABLE public.programme_version_session_slots TO authenticated;
