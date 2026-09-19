-- M10 Sprint 2: consent-based publisher–athlete membership schema.
-- Additive. Does not seed rows, infer membership from assignments, or
-- rewrite pins/manifests/programmes.

CREATE TABLE IF NOT EXISTS public.publisher_athlete_invitations (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  publisher_id        UUID NOT NULL
                        REFERENCES public.content_publishers (id) ON DELETE RESTRICT,
  athlete_id          UUID NOT NULL
                        REFERENCES public.profiles (id) ON DELETE RESTRICT,
  invited_by          UUID NOT NULL,
  state               TEXT NOT NULL DEFAULT 'pending',
  invited_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at          TIMESTAMPTZ NOT NULL,
  responded_at        TIMESTAMPTZ,
  cancelled_at        TIMESTAMPTZ,
  request_id          TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT publisher_athlete_invitations_state_check
    CHECK (state IN ('pending', 'accepted', 'declined', 'expired', 'cancelled')),
  CONSTRAINT publisher_athlete_invitations_not_self
    CHECK (athlete_id <> invited_by),
  CONSTRAINT publisher_athlete_invitations_expiry_after_invite
    CHECK (expires_at > invited_at)
);

COMMENT ON TABLE public.publisher_athlete_invitations IS
  'M10 management invitation. Pending grants no roster or training-data access. athlete_id is profiles.id. Display names and emails are not keys. No invite token is stored.';

CREATE UNIQUE INDEX IF NOT EXISTS publisher_athlete_invitations_one_pending
  ON public.publisher_athlete_invitations (publisher_id, athlete_id)
  WHERE state = 'pending';

CREATE INDEX IF NOT EXISTS idx_publisher_athlete_invitations_athlete_pending
  ON public.publisher_athlete_invitations (athlete_id, invited_at DESC)
  WHERE state = 'pending';

CREATE INDEX IF NOT EXISTS idx_publisher_athlete_invitations_publisher
  ON public.publisher_athlete_invitations (publisher_id, invited_at DESC);

CREATE TABLE IF NOT EXISTS public.publisher_athlete_memberships (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  publisher_id        UUID NOT NULL
                        REFERENCES public.content_publishers (id) ON DELETE RESTRICT,
  athlete_id          UUID NOT NULL
                        REFERENCES public.profiles (id) ON DELETE RESTRICT,
  invitation_id       UUID
                        REFERENCES public.publisher_athlete_invitations (id)
                        ON DELETE RESTRICT,
  invited_by          UUID NOT NULL,
  state               TEXT NOT NULL DEFAULT 'active',
  activated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at          TIMESTAMPTZ,
  revoked_by          UUID,
  revoked_by_role     TEXT,
  revocation_reason   TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT publisher_athlete_memberships_state_check
    CHECK (state IN ('active', 'revoked')),
  CONSTRAINT publisher_athlete_memberships_revoked_consistent
    CHECK (
      (state = 'active' AND revoked_at IS NULL AND revoked_by IS NULL)
      OR (state = 'revoked' AND revoked_at IS NOT NULL AND revoked_by IS NOT NULL)
    ),
  CONSTRAINT publisher_athlete_memberships_revoked_by_role_check
    CHECK (
      revoked_by_role IS NULL
      OR revoked_by_role IN ('athlete', 'publisher', 'service')
    )
);

COMMENT ON TABLE public.publisher_athlete_memberships IS
  'M10 consented management relationship. Not created by enrolment or assignment. A publisher does not own the athlete.';

CREATE UNIQUE INDEX IF NOT EXISTS publisher_athlete_memberships_one_active
  ON public.publisher_athlete_memberships (publisher_id, athlete_id)
  WHERE state = 'active';

CREATE INDEX IF NOT EXISTS idx_publisher_athlete_memberships_publisher_active
  ON public.publisher_athlete_memberships (publisher_id, activated_at DESC)
  WHERE state = 'active';

CREATE INDEX IF NOT EXISTS idx_publisher_athlete_memberships_athlete
  ON public.publisher_athlete_memberships (athlete_id, activated_at DESC);

CREATE TABLE IF NOT EXISTS public.publisher_athlete_membership_events (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id       UUID
                        REFERENCES public.publisher_athlete_invitations (id)
                        ON DELETE RESTRICT,
  membership_id       UUID
                        REFERENCES public.publisher_athlete_memberships (id)
                        ON DELETE RESTRICT,
  publisher_id        UUID NOT NULL
                        REFERENCES public.content_publishers (id) ON DELETE RESTRICT,
  athlete_id          UUID NOT NULL
                        REFERENCES public.profiles (id) ON DELETE RESTRICT,
  actor_id            UUID,
  actor_type          TEXT NOT NULL,
  transition          TEXT NOT NULL,
  previous_state      TEXT,
  new_state           TEXT NOT NULL,
  reason_category     TEXT,
  request_id          TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT publisher_athlete_membership_events_actor_type_check
    CHECK (actor_type IN ('athlete', 'publisher', 'system', 'service')),
  CONSTRAINT publisher_athlete_membership_events_transition_check
    CHECK (transition IN (
      'invitation_created',
      'invitation_cancelled',
      'invitation_accepted',
      'invitation_declined',
      'invitation_expired',
      'membership_revoked_by_athlete',
      'membership_revoked_by_publisher'
    )),
  CONSTRAINT publisher_athlete_membership_events_subject
    CHECK (invitation_id IS NOT NULL OR membership_id IS NOT NULL)
);

COMMENT ON TABLE public.publisher_athlete_membership_events IS
  'Append-only M10 consent audit. No cross-publisher visibility.';

CREATE UNIQUE INDEX IF NOT EXISTS publisher_athlete_membership_events_request_transition
  ON public.publisher_athlete_membership_events (request_id, transition)
  WHERE request_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_publisher_athlete_membership_events_publisher
  ON public.publisher_athlete_membership_events (publisher_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_publisher_athlete_membership_events_athlete
  ON public.publisher_athlete_membership_events (athlete_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_publisher_athlete_membership_events_membership
  ON public.publisher_athlete_membership_events (membership_id, created_at DESC)
  WHERE membership_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.publisher_athlete_prevent_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'publisher_athlete_membership_events is append-only'
    USING ERRCODE = 'P0001';
END;
$$;

DROP TRIGGER IF EXISTS trg_publisher_athlete_membership_events_immutable
  ON public.publisher_athlete_membership_events;
CREATE TRIGGER trg_publisher_athlete_membership_events_immutable
  BEFORE UPDATE OR DELETE ON public.publisher_athlete_membership_events
  FOR EACH ROW
  EXECUTE FUNCTION public.publisher_athlete_prevent_event_mutation();

CREATE OR REPLACE FUNCTION public.publisher_athlete_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_publisher_athlete_invitations_updated
  ON public.publisher_athlete_invitations;
CREATE TRIGGER trg_publisher_athlete_invitations_updated
  BEFORE UPDATE ON public.publisher_athlete_invitations
  FOR EACH ROW
  EXECUTE FUNCTION public.publisher_athlete_set_updated_at();

DROP TRIGGER IF EXISTS trg_publisher_athlete_memberships_updated
  ON public.publisher_athlete_memberships;
CREATE TRIGGER trg_publisher_athlete_memberships_updated
  BEFORE UPDATE ON public.publisher_athlete_memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.publisher_athlete_set_updated_at();
