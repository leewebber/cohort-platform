-- M10 Sprint 2: least-privilege RLS. Writes are RPC-only.

ALTER TABLE public.publisher_athlete_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.publisher_athlete_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.publisher_athlete_membership_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.publisher_athlete_invitations FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.publisher_athlete_memberships FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.publisher_athlete_membership_events FROM PUBLIC, anon;
REVOKE ALL ON public.publisher_athlete_roster FROM PUBLIC, anon;

GRANT SELECT ON TABLE public.publisher_athlete_invitations TO authenticated, service_role;
GRANT SELECT ON TABLE public.publisher_athlete_memberships TO authenticated, service_role;
GRANT SELECT ON TABLE public.publisher_athlete_membership_events TO authenticated, service_role;
GRANT SELECT ON public.publisher_athlete_roster TO authenticated, service_role;

CREATE POLICY publisher_athlete_invitations_select
  ON public.publisher_athlete_invitations
  FOR SELECT
  TO authenticated
  USING (
    athlete_id = auth.uid()
    OR public.content_graph_publisher_may_operate(publisher_id)
  );

CREATE POLICY publisher_athlete_invitations_no_write
  ON public.publisher_athlete_invitations
  FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

CREATE POLICY publisher_athlete_invitations_no_update
  ON public.publisher_athlete_invitations
  FOR UPDATE
  TO authenticated
  USING (FALSE);

CREATE POLICY publisher_athlete_invitations_no_delete
  ON public.publisher_athlete_invitations
  FOR DELETE
  TO authenticated
  USING (FALSE);

CREATE POLICY publisher_athlete_memberships_select
  ON public.publisher_athlete_memberships
  FOR SELECT
  TO authenticated
  USING (
    athlete_id = auth.uid()
    OR public.content_graph_publisher_may_operate(publisher_id)
  );

CREATE POLICY publisher_athlete_memberships_no_insert
  ON public.publisher_athlete_memberships
  FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

CREATE POLICY publisher_athlete_memberships_no_update
  ON public.publisher_athlete_memberships
  FOR UPDATE
  TO authenticated
  USING (FALSE);

CREATE POLICY publisher_athlete_memberships_no_delete
  ON public.publisher_athlete_memberships
  FOR DELETE
  TO authenticated
  USING (FALSE);

CREATE POLICY publisher_athlete_membership_events_select
  ON public.publisher_athlete_membership_events
  FOR SELECT
  TO authenticated
  USING (
    athlete_id = auth.uid()
    OR public.content_graph_publisher_may_operate(publisher_id)
  );

CREATE POLICY publisher_athlete_membership_events_no_insert
  ON public.publisher_athlete_membership_events
  FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

CREATE POLICY publisher_athlete_membership_events_no_update
  ON public.publisher_athlete_membership_events
  FOR UPDATE
  TO authenticated
  USING (FALSE);

CREATE POLICY publisher_athlete_membership_events_no_delete
  ON public.publisher_athlete_membership_events
  FOR DELETE
  TO authenticated
  USING (FALSE);
