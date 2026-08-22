-- Restore the base privilege required for the existing authenticated profile
-- RLS policies. Row access remains limited by profiles_select_own and
-- profiles_select_linked_users; this grants no anonymous access.

GRANT SELECT ON TABLE public.profiles TO authenticated;

-- profiles_select_linked_users references this table. Its existing RLS
-- policies still limit relationship rows to the authenticated coach/athlete;
-- the grant merely lets PostgreSQL evaluate the profile policy.
GRANT SELECT ON TABLE public.coach_athlete_relationships TO authenticated;
