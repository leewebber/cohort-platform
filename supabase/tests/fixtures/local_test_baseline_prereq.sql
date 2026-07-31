-- TEST-ONLY disposable baseline stub for Sprint 1.2 local validation.
--
-- NOT an authoritative hosted schema dump.
-- Must never live under the repository's production supabase/migrations/.
-- Copied only into an isolated temporary Supabase workdir by the local harness.
--
-- Repository production migrations begin at 20260713140000 and assume preexisting
-- training_sessions, performance_protocols, protocol_steps, athlete_state, and
-- exercises_v2. This stub supplies the minimum shapes needed for those migrations
-- to apply in a disposable environment so Sprint 1.2 behavioural RPCs can be exercised.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.training_sessions (
  id            BIGSERIAL PRIMARY KEY,
  athlete_id    TEXT,
  programme_id  TEXT,
  status        TEXT NOT NULL DEFAULT 'planned',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.performance_protocols (
  protocol_id              TEXT PRIMARY KEY,
  name                     TEXT NOT NULL,
  purpose                  TEXT,
  published                TEXT NOT NULL DEFAULT 'false',
  primary_capability       TEXT,
  session_type             TEXT,
  duration_min             INTEGER,
  duration_category        TEXT,
  technical_complexity     TEXT,
  environment              TEXT,
  required_equipment       TEXT,
  optional_equipment       TEXT,
  suitable_for             TEXT,
  physiological_demand     TEXT,
  recovery_cost            TEXT,
  adaptability             INTEGER,
  running_required         BOOLEAN,
  running_replaceable      BOOLEAN,
  hotel_friendly           BOOLEAN,
  indoor_friendly          BOOLEAN,
  noise_friendly           BOOLEAN,
  coaching_notes           TEXT,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.protocol_steps (
  id            BIGSERIAL PRIMARY KEY,
  protocol_id   TEXT NOT NULL
                  REFERENCES public.performance_protocols (protocol_id)
                  ON DELETE CASCADE,
  step_order    INTEGER NOT NULL,
  section       TEXT,
  step_type     TEXT,
  display_style TEXT,
  exercise_id   TEXT,
  title         TEXT,
  notes         TEXT,
  metadata      JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_protocol_steps_protocol_id
  ON public.protocol_steps (protocol_id);

CREATE TABLE IF NOT EXISTS public.athlete_state (
  id            BIGSERIAL PRIMARY KEY,
  athlete_id    TEXT NOT NULL,
  current_week  INTEGER,
  current_day   INTEGER,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.exercises_v2 (
  exercise_id          TEXT PRIMARY KEY,
  name                 TEXT NOT NULL,
  slug                 TEXT NOT NULL UNIQUE,
  published            BOOLEAN NOT NULL DEFAULT TRUE,
  category             TEXT,
  movement_pattern     TEXT,
  equipment            TEXT,
  primary_muscles      TEXT,
  primary_capability   TEXT,
  loading_options      TEXT,
  purpose              TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.training_sessions IS
  'TEST-ONLY disposable baseline stub — not authoritative hosted DDL.';
COMMENT ON TABLE public.performance_protocols IS
  'TEST-ONLY disposable baseline stub — not authoritative hosted DDL.';
COMMENT ON TABLE public.protocol_steps IS
  'TEST-ONLY disposable baseline stub — not authoritative hosted DDL.';
COMMENT ON TABLE public.athlete_state IS
  'TEST-ONLY disposable baseline stub — not authoritative hosted DDL.';
COMMENT ON TABLE public.exercises_v2 IS
  'TEST-ONLY disposable baseline stub — not authoritative hosted DDL.';
