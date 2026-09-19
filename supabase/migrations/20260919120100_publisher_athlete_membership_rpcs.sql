-- M10 Sprint 2: typed consent transactions. No enrolment, pin, or manifest writes.

CREATE OR REPLACE FUNCTION public.publisher_athlete_expire_pending()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT *
    FROM public.publisher_athlete_invitations
    WHERE state = 'pending'
      AND expires_at <= NOW()
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.publisher_athlete_invitations
    SET state = 'expired', responded_at = NOW()
    WHERE id = r.id;
    INSERT INTO public.publisher_athlete_membership_events (
      invitation_id, publisher_id, athlete_id, actor_id, actor_type,
      transition, previous_state, new_state
    ) VALUES (
      r.id, r.publisher_id, r.athlete_id, NULL, 'system',
      'invitation_expired', 'pending', 'expired'
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.publisher_athlete_record_event(
  p_invitation_id UUID,
  p_membership_id UUID,
  p_publisher_id UUID,
  p_athlete_id UUID,
  p_actor_id UUID,
  p_actor_type TEXT,
  p_transition TEXT,
  p_previous_state TEXT,
  p_new_state TEXT,
  p_reason_category TEXT DEFAULT NULL,
  p_request_id TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.publisher_athlete_membership_events (
    invitation_id, membership_id, publisher_id, athlete_id, actor_id,
    actor_type, transition, previous_state, new_state, reason_category,
    request_id
  ) VALUES (
    p_invitation_id, p_membership_id, p_publisher_id, p_athlete_id, p_actor_id,
    p_actor_type, p_transition, p_previous_state, p_new_state, p_reason_category,
    NULLIF(BTRIM(p_request_id), '')
  )
  ;
EXCEPTION
  WHEN unique_violation THEN
    NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_invite(
  p_publisher_id UUID,
  p_athlete_id UUID,
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_request_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_publisher public.content_publishers%ROWTYPE;
  v_profile public.profiles%ROWTYPE;
  v_existing public.publisher_athlete_invitations%ROWTYPE;
  v_id UUID;
  v_expires TIMESTAMPTZ := COALESCE(p_expires_at, NOW() + INTERVAL '7 days');
BEGIN
  PERFORM public.publisher_athlete_expire_pending();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT * INTO v_publisher FROM public.content_publishers WHERE id = p_publisher_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'publisher_inactive');
  END IF;
  IF v_publisher.lifecycle IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('status', 'publisher_inactive');
  END IF;
  IF NOT public.content_graph_publisher_may_operate(p_publisher_id) THEN
    IF EXISTS (
      SELECT 1 FROM public.content_publisher_principals
      WHERE publisher_id = p_publisher_id AND principal_id = v_uid
    ) THEN
      RETURN jsonb_build_object('status', 'principal_inactive');
    END IF;
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id = p_athlete_id;
  IF NOT FOUND OR NOT v_profile.is_athlete OR p_athlete_id = v_uid THEN
    RETURN jsonb_build_object('status', 'invalid_target');
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.publisher_athlete_memberships
    WHERE publisher_id = p_publisher_id AND athlete_id = p_athlete_id AND state = 'active'
  ) THEN
    RETURN jsonb_build_object('status', 'already_active');
  END IF;
  SELECT * INTO v_existing
  FROM public.publisher_athlete_invitations
  WHERE publisher_id = p_publisher_id AND athlete_id = p_athlete_id AND state = 'pending'
  FOR UPDATE;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'already_pending',
      'invitation_id', v_existing.id
    );
  END IF;
  INSERT INTO public.publisher_athlete_invitations (
    publisher_id, athlete_id, invited_by, state, expires_at, request_id
  ) VALUES (
    p_publisher_id, p_athlete_id, v_uid, 'pending', v_expires,
    NULLIF(BTRIM(p_request_id), '')
  )
  RETURNING id INTO v_id;
  PERFORM public.publisher_athlete_record_event(
    v_id, NULL, p_publisher_id, p_athlete_id, v_uid, 'publisher',
    'invitation_created', NULL, 'pending', NULL, p_request_id
  );
  RETURN jsonb_build_object('status', 'invited', 'invitation_id', v_id);
EXCEPTION
  WHEN unique_violation THEN
    SELECT * INTO v_existing
    FROM public.publisher_athlete_invitations
    WHERE publisher_id = p_publisher_id
      AND athlete_id = p_athlete_id
      AND state = 'pending';
    RETURN jsonb_build_object(
      'status', 'already_pending',
      'invitation_id', v_existing.id
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_accept_invitation(
  p_invitation_id UUID,
  p_request_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_inv public.publisher_athlete_invitations%ROWTYPE;
  v_mem public.publisher_athlete_memberships%ROWTYPE;
  v_id UUID;
BEGIN
  PERFORM public.publisher_athlete_expire_pending();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT * INTO v_inv
  FROM public.publisher_athlete_invitations
  WHERE id = p_invitation_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'invalid_target');
  END IF;
  IF v_inv.athlete_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  IF v_inv.state = 'accepted' THEN
    SELECT * INTO v_mem FROM public.publisher_athlete_memberships
    WHERE invitation_id = v_inv.id
    ORDER BY created_at DESC LIMIT 1;
    RETURN jsonb_build_object(
      'status', 'already_active',
      'invitation_id', v_inv.id,
      'membership_id', v_mem.id
    );
  END IF;
  IF v_inv.state = 'declined' THEN
    RETURN jsonb_build_object('status', 'already_declined', 'invitation_id', v_inv.id);
  END IF;
  IF v_inv.state = 'cancelled' THEN
    RETURN jsonb_build_object('status', 'cancelled', 'invitation_id', v_inv.id);
  END IF;
  IF v_inv.state = 'expired' OR v_inv.expires_at <= NOW() THEN
    IF v_inv.state = 'pending' THEN
      UPDATE public.publisher_athlete_invitations
      SET state = 'expired', responded_at = NOW()
      WHERE id = v_inv.id;
      PERFORM public.publisher_athlete_record_event(
        v_inv.id, NULL, v_inv.publisher_id, v_inv.athlete_id, NULL, 'system',
        'invitation_expired', 'pending', 'expired', NULL, p_request_id
      );
    END IF;
    RETURN jsonb_build_object('status', 'expired', 'invitation_id', v_inv.id);
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.publisher_athlete_memberships
    WHERE publisher_id = v_inv.publisher_id AND athlete_id = v_inv.athlete_id AND state = 'active'
  ) THEN
    UPDATE public.publisher_athlete_invitations
    SET state = 'accepted', responded_at = NOW()
    WHERE id = v_inv.id;
    SELECT * INTO v_mem FROM public.publisher_athlete_memberships
    WHERE publisher_id = v_inv.publisher_id AND athlete_id = v_inv.athlete_id AND state = 'active';
    RETURN jsonb_build_object(
      'status', 'already_active',
      'invitation_id', v_inv.id,
      'membership_id', v_mem.id
    );
  END IF;
  UPDATE public.publisher_athlete_invitations
  SET state = 'accepted', responded_at = NOW()
  WHERE id = v_inv.id;
  INSERT INTO public.publisher_athlete_memberships (
    publisher_id, athlete_id, invitation_id, invited_by, state
  ) VALUES (
    v_inv.publisher_id, v_inv.athlete_id, v_inv.id, v_inv.invited_by, 'active'
  )
  RETURNING id INTO v_id;
  PERFORM public.publisher_athlete_record_event(
    v_inv.id, v_id, v_inv.publisher_id, v_inv.athlete_id, v_uid, 'athlete',
    'invitation_accepted', 'pending', 'accepted', NULL, p_request_id
  );
  RETURN jsonb_build_object(
    'status', 'accepted',
    'invitation_id', v_inv.id,
    'membership_id', v_id
  );
EXCEPTION
  WHEN unique_violation THEN
    SELECT * INTO v_mem FROM public.publisher_athlete_memberships
    WHERE publisher_id = v_inv.publisher_id
      AND athlete_id = v_inv.athlete_id
      AND state = 'active';
    RETURN jsonb_build_object(
      'status', 'already_active',
      'invitation_id', v_inv.id,
      'membership_id', v_mem.id
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_decline_invitation(
  p_invitation_id UUID,
  p_request_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_inv public.publisher_athlete_invitations%ROWTYPE;
BEGIN
  PERFORM public.publisher_athlete_expire_pending();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT * INTO v_inv
  FROM public.publisher_athlete_invitations
  WHERE id = p_invitation_id
  FOR UPDATE;
  IF NOT FOUND OR v_inv.athlete_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  IF v_inv.state = 'declined' THEN
    RETURN jsonb_build_object('status', 'already_declined', 'invitation_id', v_inv.id);
  END IF;
  IF v_inv.state IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('status', v_inv.state, 'invitation_id', v_inv.id);
  END IF;
  IF v_inv.expires_at <= NOW() THEN
    UPDATE public.publisher_athlete_invitations
    SET state = 'expired', responded_at = NOW() WHERE id = v_inv.id;
    RETURN jsonb_build_object('status', 'expired', 'invitation_id', v_inv.id);
  END IF;
  UPDATE public.publisher_athlete_invitations
  SET state = 'declined', responded_at = NOW()
  WHERE id = v_inv.id;
  PERFORM public.publisher_athlete_record_event(
    v_inv.id, NULL, v_inv.publisher_id, v_inv.athlete_id, v_uid, 'athlete',
    'invitation_declined', 'pending', 'declined', NULL, p_request_id
  );
  RETURN jsonb_build_object('status', 'declined', 'invitation_id', v_inv.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_cancel_invitation(
  p_invitation_id UUID,
  p_request_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_inv public.publisher_athlete_invitations%ROWTYPE;
BEGIN
  PERFORM public.publisher_athlete_expire_pending();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT * INTO v_inv
  FROM public.publisher_athlete_invitations
  WHERE id = p_invitation_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'invalid_target');
  END IF;
  IF NOT public.content_graph_publisher_may_operate(v_inv.publisher_id) THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  IF v_inv.state = 'cancelled' THEN
    RETURN jsonb_build_object('status', 'already_cancelled', 'invitation_id', v_inv.id);
  END IF;
  IF v_inv.state IS DISTINCT FROM 'pending' THEN
    RETURN jsonb_build_object('status', v_inv.state, 'invitation_id', v_inv.id);
  END IF;
  UPDATE public.publisher_athlete_invitations
  SET state = 'cancelled', cancelled_at = NOW(), responded_at = NOW()
  WHERE id = v_inv.id;
  PERFORM public.publisher_athlete_record_event(
    v_inv.id, NULL, v_inv.publisher_id, v_inv.athlete_id, v_uid, 'publisher',
    'invitation_cancelled', 'pending', 'cancelled', NULL, p_request_id
  );
  RETURN jsonb_build_object('status', 'cancelled', 'invitation_id', v_inv.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.cohort_publisher_athlete_revoke_membership(
  p_membership_id UUID,
  p_reason_category TEXT DEFAULT NULL,
  p_request_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_mem public.publisher_athlete_memberships%ROWTYPE;
  v_as_publisher BOOLEAN;
  v_transition TEXT;
  v_role TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  SELECT * INTO v_mem
  FROM public.publisher_athlete_memberships
  WHERE id = p_membership_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'invalid_target');
  END IF;
  v_as_publisher := public.content_graph_publisher_may_operate(v_mem.publisher_id);
  IF v_mem.athlete_id IS DISTINCT FROM v_uid AND NOT v_as_publisher THEN
    RETURN jsonb_build_object('status', 'unauthorised');
  END IF;
  IF v_mem.state = 'revoked' THEN
    RETURN jsonb_build_object(
      'status', 'already_revoked',
      'membership_id', v_mem.id
    );
  END IF;
  IF v_mem.athlete_id = v_uid THEN
    v_transition := 'membership_revoked_by_athlete';
    v_role := 'athlete';
  ELSE
    v_transition := 'membership_revoked_by_publisher';
    v_role := 'publisher';
  END IF;
  UPDATE public.publisher_athlete_memberships
  SET
    state = 'revoked',
    revoked_at = NOW(),
    revoked_by = v_uid,
    revoked_by_role = v_role,
    revocation_reason = NULLIF(BTRIM(p_reason_category), '')
  WHERE id = v_mem.id;
  PERFORM public.publisher_athlete_record_event(
    v_mem.invitation_id, v_mem.id, v_mem.publisher_id, v_mem.athlete_id,
    v_uid, v_role, v_transition, 'active', 'revoked', p_reason_category,
    p_request_id
  );
  RETURN jsonb_build_object('status', 'revoked', 'membership_id', v_mem.id);
END;
$$;

REVOKE ALL ON FUNCTION public.publisher_athlete_expire_pending() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.publisher_athlete_record_event(
  UUID, UUID, UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_invite(UUID, UUID, TIMESTAMPTZ, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_accept_invitation(UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_decline_invitation(UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_cancel_invitation(UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_publisher_athlete_revoke_membership(UUID, TEXT, TEXT)
  TO authenticated;
