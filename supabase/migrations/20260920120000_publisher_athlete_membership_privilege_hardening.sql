-- M10 privilege hardening. Additive grants only.
-- Does not seed invitations/memberships/events or rewrite assignments/manifests.

-- ---------------------------------------------------------------------------
-- Tables: RPC-only mutation. No client table SELECT (canonical path is RPC).
-- Default privileges previously left authenticated ALL; REVOKE those extras.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE public.publisher_athlete_invitations FROM PUBLIC;
REVOKE ALL ON TABLE public.publisher_athlete_invitations FROM anon;
REVOKE ALL ON TABLE public.publisher_athlete_invitations FROM authenticated;
REVOKE ALL ON TABLE public.publisher_athlete_memberships FROM PUBLIC;
REVOKE ALL ON TABLE public.publisher_athlete_memberships FROM anon;
REVOKE ALL ON TABLE public.publisher_athlete_memberships FROM authenticated;
REVOKE ALL ON TABLE public.publisher_athlete_membership_events FROM PUBLIC;
REVOKE ALL ON TABLE public.publisher_athlete_membership_events FROM anon;
REVOKE ALL ON TABLE public.publisher_athlete_membership_events FROM authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.publisher_athlete_invitations TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.publisher_athlete_memberships TO service_role;
GRANT SELECT, INSERT, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.publisher_athlete_membership_events TO service_role;
REVOKE UPDATE ON TABLE public.publisher_athlete_membership_events FROM service_role;

-- ---------------------------------------------------------------------------
-- View: security_invoker remains. Client reads go through inspect RPCs.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE public.publisher_athlete_roster FROM PUBLIC;
REVOKE ALL ON TABLE public.publisher_athlete_roster FROM anon;
REVOKE ALL ON TABLE public.publisher_athlete_roster FROM authenticated;
GRANT SELECT ON TABLE public.publisher_athlete_roster TO service_role;

-- ---------------------------------------------------------------------------
-- Trigger helpers: no client EXECUTE; search_path fixed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.publisher_athlete_prevent_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'publisher_athlete_membership_events is append-only'
    USING ERRCODE = 'P0001';
END;
$$;

CREATE OR REPLACE FUNCTION public.publisher_athlete_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.publisher_athlete_prevent_event_mutation()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publisher_athlete_set_updated_at()
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Internal helpers: DEFINER RPCs call these as owner. No client EXECUTE.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.publisher_athlete_expire_pending()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publisher_athlete_record_event(
  UUID, UUID, UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publisher_athlete_assignment_is_own(UUID, UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publisher_athlete_expire_pending()
  TO service_role;
GRANT EXECUTE ON FUNCTION public.publisher_athlete_record_event(
  UUID, UUID, UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
) TO service_role;
GRANT EXECUTE ON FUNCTION public.publisher_athlete_assignment_is_own(UUID, UUID)
  TO service_role;

-- ---------------------------------------------------------------------------
-- Client RPCs: authenticated + service_role only. No PUBLIC/anon.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_invite(
  UUID, UUID, TIMESTAMPTZ, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_accept_invitation(
  UUID, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_decline_invitation(
  UUID, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_cancel_invitation(
  UUID, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_revoke_membership(
  UUID, TEXT, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_inspect_roster(
  UUID, INTEGER, INTEGER
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_list_pending_invitations(
  UUID, INTEGER, INTEGER
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_inspect_memberships()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cohort_publisher_athlete_inspect_audit(
  UUID, UUID, INTEGER, INTEGER
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_invite(
  UUID, UUID, TIMESTAMPTZ, TEXT
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_accept_invitation(
  UUID, TEXT
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_decline_invitation(
  UUID, TEXT
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_cancel_invitation(
  UUID, TEXT
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_revoke_membership(
  UUID, TEXT, TEXT
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_inspect_roster(
  UUID, INTEGER, INTEGER
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_list_pending_invitations(
  UUID, INTEGER, INTEGER
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_inspect_memberships()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_inspect_audit(
  UUID, UUID, INTEGER, INTEGER
) TO authenticated, service_role;

-- Capability probe: keep authenticated + service_role; still no PUBLIC/anon.
REVOKE ALL ON FUNCTION public.cohort_athlete_runtime_capabilities()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_athlete_runtime_capabilities()
  TO authenticated, service_role;
