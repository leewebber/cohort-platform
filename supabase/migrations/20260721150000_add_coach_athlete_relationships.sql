-- V2.0: Coach–athlete relationships and private invitation codes
-- Enables authenticated multi-user coaching without organisations or public discovery.

-- ---------------------------------------------------------------------------
-- coach_athlete_relationships
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS coach_athlete_relationships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id    UUID NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
  athlete_id  UUID NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at    TIMESTAMPTZ,
  CONSTRAINT coach_athlete_relationships_status_check
    CHECK (status IN ('active', 'ended')),
  CONSTRAINT coach_athlete_relationships_not_self
    CHECK (coach_id <> athlete_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS coach_athlete_relationships_one_active_per_athlete
  ON coach_athlete_relationships (athlete_id)
  WHERE status = 'active';

CREATE UNIQUE INDEX IF NOT EXISTS coach_athlete_relationships_active_pair_unique
  ON coach_athlete_relationships (coach_id, athlete_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_coach_athlete_relationships_coach_active
  ON coach_athlete_relationships (coach_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_coach_athlete_relationships_athlete_active
  ON coach_athlete_relationships (athlete_id)
  WHERE status = 'active';

COMMENT ON TABLE coach_athlete_relationships IS
  'Private coach–athlete link. V2 supports one active coach per athlete.';

-- ---------------------------------------------------------------------------
-- coach_athlete_invites
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS coach_athlete_invites (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id                UUID NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
  code                    TEXT NOT NULL,
  status                  TEXT NOT NULL DEFAULT 'pending',
  expires_at              TIMESTAMPTZ NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at             TIMESTAMPTZ,
  accepted_by_athlete_id  UUID REFERENCES profiles (id) ON DELETE SET NULL,
  CONSTRAINT coach_athlete_invites_status_check
    CHECK (status IN ('pending', 'accepted', 'revoked')),
  CONSTRAINT coach_athlete_invites_code_format_check
    CHECK (code ~ '^[A-Z2-9]{8}$')
);

CREATE UNIQUE INDEX IF NOT EXISTS coach_athlete_invites_code_unique
  ON coach_athlete_invites (UPPER(code));

CREATE INDEX IF NOT EXISTS idx_coach_athlete_invites_coach_pending
  ON coach_athlete_invites (coach_id, created_at DESC)
  WHERE status = 'pending';

COMMENT ON TABLE coach_athlete_invites IS
  'Single-use private invitation codes. Expiry evaluated from expires_at.';

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cohort_coach_has_active_athlete(p_athlete_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM coach_athlete_relationships r
    WHERE r.coach_id = auth.uid()
      AND r.athlete_id::TEXT = TRIM(p_athlete_id)
      AND r.status = 'active'
  );
$$;

COMMENT ON FUNCTION cohort_coach_has_active_athlete(TEXT) IS
  'True when authenticated coach has an active relationship with the athlete.';

CREATE OR REPLACE FUNCTION cohort_athlete_has_active_coach(p_coach_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM coach_athlete_relationships r
    WHERE r.athlete_id = auth.uid()
      AND r.coach_id::TEXT = TRIM(p_coach_id)
      AND r.status = 'active'
  );
$$;

-- ---------------------------------------------------------------------------
-- Invite acceptance (transactional)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION accept_coach_athlete_invite(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_invite coach_athlete_invites%ROWTYPE;
  v_profile profiles%ROWTYPE;
  v_coach_name TEXT;
  v_normalized_code TEXT := UPPER(TRIM(p_code));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in to join a coach.'
      USING ERRCODE = '42501';
  END IF;

  SELECT *
  INTO v_profile
  FROM profiles
  WHERE id = v_user_id;

  IF NOT FOUND OR NOT v_profile.is_athlete THEN
    RAISE EXCEPTION 'An athlete profile is required to accept an invitation.'
      USING ERRCODE = '42501';
  END IF;

  IF v_normalized_code IS NULL OR v_normalized_code = '' THEN
    RAISE EXCEPTION 'Enter a valid invitation code.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_invite
  FROM coach_athlete_invites
  WHERE UPPER(code) = v_normalized_code
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That invitation code is not valid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_invite.coach_id = v_user_id THEN
    RAISE EXCEPTION 'You cannot accept your own invitation.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_invite.status = 'revoked' THEN
    RAISE EXCEPTION 'This invitation has been revoked.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_invite.status = 'accepted' THEN
    RAISE EXCEPTION 'This invitation has already been used.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_invite.expires_at <= NOW() THEN
    RAISE EXCEPTION 'This invitation has expired.'
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM coach_athlete_relationships
    WHERE athlete_id = v_user_id
      AND coach_id = v_invite.coach_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'You are already linked to this coach.'
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM coach_athlete_relationships
    WHERE athlete_id = v_user_id
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'You are already linked to a coach.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE coach_athlete_invites
  SET
    status = 'accepted',
    accepted_at = NOW(),
    accepted_by_athlete_id = v_user_id
  WHERE id = v_invite.id;

  INSERT INTO coach_athlete_relationships (coach_id, athlete_id, status)
  VALUES (v_invite.coach_id, v_user_id, 'active');

  SELECT display_name
  INTO v_coach_name
  FROM profiles
  WHERE id = v_invite.coach_id;

  RETURN jsonb_build_object(
    'coachDisplayName', COALESCE(v_coach_name, 'Your coach'),
    'coachId', v_invite.coach_id::TEXT
  );
END;
$$;

COMMENT ON FUNCTION accept_coach_athlete_invite(TEXT) IS
  'Athlete accepts a pending, unexpired invite and creates an active relationship.';

GRANT EXECUTE ON FUNCTION accept_coach_athlete_invite(TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS: relationships
-- ---------------------------------------------------------------------------

ALTER TABLE coach_athlete_relationships ENABLE ROW LEVEL SECURITY;

CREATE POLICY coach_athlete_relationships_coach_select
  ON coach_athlete_relationships
  FOR SELECT
  TO authenticated
  USING (coach_id = auth.uid());

CREATE POLICY coach_athlete_relationships_athlete_select
  ON coach_athlete_relationships
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid());

-- ---------------------------------------------------------------------------
-- RLS: invites (coach-managed; athletes accept via SECURITY DEFINER function)
-- ---------------------------------------------------------------------------

ALTER TABLE coach_athlete_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY coach_athlete_invites_coach_select
  ON coach_athlete_invites
  FOR SELECT
  TO authenticated
  USING (coach_id = auth.uid());

CREATE POLICY coach_athlete_invites_coach_insert
  ON coach_athlete_invites
  FOR INSERT
  TO authenticated
  WITH CHECK (
    coach_id = auth.uid()
    AND status = 'pending'
    AND expires_at > NOW()
  );

CREATE POLICY coach_athlete_invites_coach_update
  ON coach_athlete_invites
  FOR UPDATE
  TO authenticated
  USING (coach_id = auth.uid() AND status = 'pending')
  WITH CHECK (coach_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Profile visibility for linked coach/athlete roster display
-- ---------------------------------------------------------------------------

CREATE POLICY profiles_select_linked_users
  ON profiles
  FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM coach_athlete_relationships r
      WHERE r.status = 'active'
        AND (
          (r.coach_id = auth.uid() AND r.athlete_id = profiles.id)
          OR (r.athlete_id = auth.uid() AND r.coach_id = profiles.id)
        )
    )
  );

-- ---------------------------------------------------------------------------
-- Programme assignments: coach access for linked athletes
-- ---------------------------------------------------------------------------

CREATE POLICY dev_programme_assignments_coach_select
  ON programme_assignments
  FOR SELECT
  TO authenticated
  USING (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY dev_programme_assignments_coach_insert
  ON programme_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (cohort_coach_has_active_athlete(athlete_id));

CREATE POLICY dev_programme_assignments_coach_update
  ON programme_assignments
  FOR UPDATE
  TO authenticated
  USING (cohort_coach_has_active_athlete(athlete_id))
  WITH CHECK (cohort_coach_has_active_athlete(athlete_id));

-- Slot outcomes: coach read via linked assignment
CREATE POLICY dev_programme_slot_outcomes_coach_select
  ON programme_slot_outcomes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  );

CREATE POLICY dev_programme_slot_outcomes_coach_insert
  ON programme_slot_outcomes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  );

CREATE POLICY dev_programme_slot_outcomes_coach_update
  ON programme_slot_outcomes
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM programme_assignments a
      WHERE a.id = programme_slot_outcomes.assignment_id
        AND cohort_coach_has_active_athlete(a.athlete_id)
    )
  );
