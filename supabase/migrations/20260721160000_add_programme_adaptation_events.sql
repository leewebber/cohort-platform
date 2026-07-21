-- Programme adaptation audit events for post-completion deterministic execution.

CREATE TABLE programme_adaptation_events (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id              UUID NOT NULL
                               REFERENCES programme_assignments (id) ON DELETE CASCADE,
  athlete_id                 UUID NOT NULL,
  trigger_training_session_id BIGINT NOT NULL
                               REFERENCES training_sessions (id) ON DELETE CASCADE,
  trigger_slot_id            UUID,
  adaptation_type            TEXT NOT NULL,
  explanation                TEXT NOT NULL,
  athlete_summary            TEXT NOT NULL,
  affected_slot_ids          JSONB NOT NULL DEFAULT '[]'::jsonb,
  payload                    JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_adaptation_events_type_check
    CHECK (adaptation_type IN ('load_progression', 'protocol_substitution')),
  CONSTRAINT programme_adaptation_events_assignment_session_unique
    UNIQUE (assignment_id, trigger_training_session_id)
);

CREATE INDEX idx_programme_adaptation_events_assignment_created
  ON programme_adaptation_events (assignment_id, created_at DESC);

COMMENT ON TABLE programme_adaptation_events IS
  'Deterministic post-completion adaptation audit trail. One event per completed training session.';

ALTER TABLE programme_adaptation_events ENABLE ROW LEVEL SECURITY;

-- Dev / authenticated access mirrors programme slot outcomes.
CREATE POLICY programme_adaptation_events_dev_athlete_select
  ON programme_adaptation_events
  FOR SELECT
  TO anon, authenticated
  USING (
    athlete_id::text = ANY (cohort_programme_dev_athlete_ids())
    OR athlete_id::text = auth.uid()::text
  );

CREATE POLICY programme_adaptation_events_dev_athlete_insert
  ON programme_adaptation_events
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    athlete_id::text = ANY (cohort_programme_dev_athlete_ids())
    OR athlete_id::text = auth.uid()::text
  );

CREATE POLICY programme_adaptation_events_dev_coach_select
  ON programme_adaptation_events
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM programme_assignments pa
      JOIN coach_athlete_relationships car
        ON car.athlete_id = pa.athlete_id
      WHERE pa.id = programme_adaptation_events.assignment_id
        AND car.coach_id::text = cohort_programme_dev_coach_id()
        AND car.status = 'active'
    )
    OR EXISTS (
      SELECT 1
      FROM coach_athlete_relationships car
      WHERE car.athlete_id = programme_adaptation_events.athlete_id
        AND car.coach_id::text = auth.uid()::text
        AND car.status = 'active'
    )
  );
