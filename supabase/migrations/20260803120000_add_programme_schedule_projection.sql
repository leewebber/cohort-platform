-- Sprint 1.7C: Durable programme schedule projection, revision, operation log,
-- and atomic baseline initialisation (ensure) RPC.
--
-- Authorised durable write in this sprint: idempotent baseline initialisation only.
-- Does NOT apply Move/Swap/Push/Skip, mutate cursor, clear prepared state,
-- fabricate completion, or invoke adaptation / Coach Brain / Adaptive Progression.
--
-- Lifecycle owner: lazy ensure on first scheduling-state load
-- (ensure_programme_schedule_projection). Not wired into Start Programme UI.

-- ---------------------------------------------------------------------------
-- 1. Assignment schedule_revision (CAS mirror; authoritative value on projection)
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_assignments
  ADD COLUMN IF NOT EXISTS schedule_revision INT NOT NULL DEFAULT 0;

ALTER TABLE public.programme_assignments
  DROP CONSTRAINT IF EXISTS programme_assignments_schedule_revision_nonneg;

ALTER TABLE public.programme_assignments
  ADD CONSTRAINT programme_assignments_schedule_revision_nonneg
  CHECK (schedule_revision >= 0);

COMMENT ON COLUMN public.programme_assignments.schedule_revision IS
  'Sprint 1.7C: monotonic schedule revision mirror for CAS. Baseline = 0. Advanced only by later authorised apply RPCs (1.7D/E), never by direct client writes.';

CREATE OR REPLACE FUNCTION public.cohort_programme_assignment_protect_schedule_revision()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF COALESCE(current_setting('cohort.allow_schedule_write', true), '') = 'on'
     OR COALESCE(current_setting('cohort.allow_materialisation_write', true), '') = 'on'
     OR current_user IN ('postgres', 'supabase_admin')
  THEN
    RETURN NEW;
  END IF;

  IF NEW.schedule_revision IS DISTINCT FROM OLD.schedule_revision THEN
    RAISE EXCEPTION 'programme_assignments.schedule_revision is RPC-only'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS programme_assignments_protect_schedule_revision
  ON public.programme_assignments;

CREATE TRIGGER programme_assignments_protect_schedule_revision
  BEFORE UPDATE ON public.programme_assignments
  FOR EACH ROW
  EXECUTE FUNCTION public.cohort_programme_assignment_protect_schedule_revision();

REVOKE ALL ON FUNCTION public.cohort_programme_assignment_protect_schedule_revision() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 2. Projection header
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.programme_schedule_projections (
  assignment_id              UUID PRIMARY KEY
    REFERENCES public.programme_assignments (id) ON DELETE CASCADE,
  athlete_id                 UUID NOT NULL,
  programme_version_id       UUID NOT NULL
    REFERENCES public.programme_versions (id) ON DELETE RESTRICT,
  package_content_hash       TEXT NOT NULL,
  timezone                   TEXT NOT NULL,
  started_at                 DATE NOT NULL,
  schedule_revision          INT NOT NULL DEFAULT 0,
  schema_version             TEXT NOT NULL DEFAULT 'programme.schedule.projection.v1',
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_schedule_projections_hash_check
    CHECK (package_content_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT programme_schedule_projections_revision_nonneg
    CHECK (schedule_revision >= 0),
  CONSTRAINT programme_schedule_projections_timezone_nonempty
    CHECK (nullif(trim(timezone), '') IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS programme_schedule_projections_assignment_version_hash_uidx
  ON public.programme_schedule_projections (
    assignment_id,
    programme_version_id,
    package_content_hash
  );

CREATE INDEX IF NOT EXISTS idx_programme_schedule_projections_athlete
  ON public.programme_schedule_projections (athlete_id);

COMMENT ON TABLE public.programme_schedule_projections IS
  'Sprint 1.7C authoritative schedule projection header per materialised assignment. Server is source of truth; local cache is subordinate.';

-- ---------------------------------------------------------------------------
-- 3. Occurrence rows (identity excludes scheduled_date)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.programme_schedule_occurrences (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id              UUID NOT NULL
    REFERENCES public.programme_schedule_projections (assignment_id) ON DELETE CASCADE,
  session_slot_id            UUID NOT NULL
    REFERENCES public.programme_version_session_slots (id) ON DELETE RESTRICT,
  programme_version_id       UUID NOT NULL,
  package_content_hash       TEXT NOT NULL,
  week_number                INT NOT NULL,
  day_key                    TEXT NOT NULL,
  session_order              INT NOT NULL,
  protocol_id                TEXT NOT NULL,
  programmed_session_key     TEXT NOT NULL,
  scheduled_date             DATE NOT NULL,
  disposition                TEXT NOT NULL DEFAULT 'scheduled',
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_schedule_occurrences_disposition_check
    CHECK (disposition IN ('scheduled', 'skipped', 'completed')),
  CONSTRAINT programme_schedule_occurrences_week_positive
    CHECK (week_number > 0),
  CONSTRAINT programme_schedule_occurrences_session_order_positive
    CHECK (session_order > 0),
  CONSTRAINT programme_schedule_occurrences_day_key_check
    CHECK (day_key ~ '^day_[1-9][0-9]*$'),
  CONSTRAINT programme_schedule_occurrences_hash_check
    CHECK (package_content_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT programme_schedule_occurrences_psk_nonempty
    CHECK (nullif(trim(programmed_session_key), '') IS NOT NULL),
  CONSTRAINT programme_schedule_occurrences_protocol_nonempty
    CHECK (nullif(trim(protocol_id), '') IS NOT NULL)
);

-- Stable occurrence identity: assignment + slot (date is not identity).
CREATE UNIQUE INDEX IF NOT EXISTS programme_schedule_occurrences_assignment_slot_uidx
  ON public.programme_schedule_occurrences (assignment_id, session_slot_id);

-- Authored-order uniqueness within a projection.
CREATE UNIQUE INDEX IF NOT EXISTS programme_schedule_occurrences_authored_order_uidx
  ON public.programme_schedule_occurrences (
    assignment_id,
    week_number,
    day_key,
    session_order
  );

CREATE UNIQUE INDEX IF NOT EXISTS programme_schedule_occurrences_psk_uidx
  ON public.programme_schedule_occurrences (assignment_id, programmed_session_key);

CREATE INDEX IF NOT EXISTS idx_programme_schedule_occurrences_date
  ON public.programme_schedule_occurrences (assignment_id, scheduled_date);

COMMENT ON TABLE public.programme_schedule_occurrences IS
  'Sprint 1.7C scheduled occurrence rows. Identity is authored provenance; scheduled_date is placement only. No prescription payload.';

-- ---------------------------------------------------------------------------
-- 4. Append-only operation log (structure only; athlete ops not applied in 1.7C)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.programme_schedule_operations (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id              UUID NOT NULL
    REFERENCES public.programme_schedule_projections (assignment_id) ON DELETE CASCADE,
  athlete_id                 UUID NOT NULL,
  operation_type             TEXT NOT NULL,
  idempotency_key            TEXT NOT NULL,
  preview_fingerprint        TEXT,
  base_revision              INT,
  result_revision            INT NOT NULL,
  policy_version             TEXT NOT NULL DEFAULT 'programme.scheduling.policy.v1',
  affected_before            JSONB NOT NULL DEFAULT '[]'::jsonb,
  affected_after             JSONB NOT NULL DEFAULT '[]'::jsonb,
  prior_snapshot             JSONB,
  operated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  undo_expires_at            TIMESTAMPTZ,
  undo_consumed_at           TIMESTAMPTZ,
  undo_invalidated_at        TIMESTAMPTZ,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT programme_schedule_operations_type_check
    CHECK (operation_type IN (
      'baseline_initialisation',
      'move',
      'swap',
      'push',
      'skip',
      'undo'
    )),
  CONSTRAINT programme_schedule_operations_result_revision_nonneg
    CHECK (result_revision >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS programme_schedule_operations_idempotency_uidx
  ON public.programme_schedule_operations (assignment_id, idempotency_key);

CREATE INDEX IF NOT EXISTS idx_programme_schedule_operations_assignment_time
  ON public.programme_schedule_operations (assignment_id, operated_at DESC);

COMMENT ON TABLE public.programme_schedule_operations IS
  'Sprint 1.7C bounded append-only scheduling operation log for later exact apply and one-level Undo. Not general event sourcing. Athlete Move/Swap/Push/Skip rows are not written in 1.7C.';

COMMENT ON COLUMN public.programme_schedule_operations.operation_type IS
  'baseline_initialisation is an audit of projection creation, not an athlete scheduling operation. move/swap/push/skip/undo reserved for 1.7D–1.7F.';

-- ---------------------------------------------------------------------------
-- 5. RLS — athletes may SELECT own rows; all mutation is RPC-only
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_schedule_projections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programme_schedule_occurrences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programme_schedule_operations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS programme_schedule_projections_athlete_select
  ON public.programme_schedule_projections;
CREATE POLICY programme_schedule_projections_athlete_select
  ON public.programme_schedule_projections
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid());

DROP POLICY IF EXISTS programme_schedule_projections_coach_select
  ON public.programme_schedule_projections;
CREATE POLICY programme_schedule_projections_coach_select
  ON public.programme_schedule_projections
  FOR SELECT
  TO authenticated
  USING (public.cohort_coach_has_active_athlete(athlete_id));

DROP POLICY IF EXISTS programme_schedule_occurrences_athlete_select
  ON public.programme_schedule_occurrences;
CREATE POLICY programme_schedule_occurrences_athlete_select
  ON public.programme_schedule_occurrences
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_schedule_projections p
      WHERE p.assignment_id = programme_schedule_occurrences.assignment_id
        AND p.athlete_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS programme_schedule_occurrences_coach_select
  ON public.programme_schedule_occurrences;
CREATE POLICY programme_schedule_occurrences_coach_select
  ON public.programme_schedule_occurrences
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.programme_schedule_projections p
      WHERE p.assignment_id = programme_schedule_occurrences.assignment_id
        AND public.cohort_coach_has_active_athlete(p.athlete_id)
    )
  );

DROP POLICY IF EXISTS programme_schedule_operations_athlete_select
  ON public.programme_schedule_operations;
CREATE POLICY programme_schedule_operations_athlete_select
  ON public.programme_schedule_operations
  FOR SELECT
  TO authenticated
  USING (athlete_id = auth.uid());

DROP POLICY IF EXISTS programme_schedule_operations_coach_select
  ON public.programme_schedule_operations;
CREATE POLICY programme_schedule_operations_coach_select
  ON public.programme_schedule_operations
  FOR SELECT
  TO authenticated
  USING (public.cohort_coach_has_active_athlete(athlete_id));

-- Explicitly no INSERT/UPDATE/DELETE policies for authenticated.
REVOKE ALL ON TABLE public.programme_schedule_projections FROM PUBLIC;
REVOKE ALL ON TABLE public.programme_schedule_projections FROM anon;
REVOKE ALL ON TABLE public.programme_schedule_occurrences FROM PUBLIC;
REVOKE ALL ON TABLE public.programme_schedule_occurrences FROM anon;
REVOKE ALL ON TABLE public.programme_schedule_operations FROM PUBLIC;
REVOKE ALL ON TABLE public.programme_schedule_operations FROM anon;

GRANT SELECT ON TABLE public.programme_schedule_projections TO authenticated;
GRANT SELECT ON TABLE public.programme_schedule_occurrences TO authenticated;
GRANT SELECT ON TABLE public.programme_schedule_operations TO authenticated;

GRANT ALL ON TABLE public.programme_schedule_projections TO service_role;
GRANT ALL ON TABLE public.programme_schedule_occurrences TO service_role;
GRANT ALL ON TABLE public.programme_schedule_operations TO service_role;

-- ---------------------------------------------------------------------------
-- 6. Helpers: executable slots + projection JSON assembler
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_schedule_programmed_session_key(
  p_assignment_id UUID,
  p_programme_version_id UUID,
  p_week INT,
  p_day_key TEXT,
  p_session_order INT,
  p_protocol_id TEXT
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT format(
    'prog:%s@%s:w%s:%s:s%s:%s',
    p_assignment_id::text,
    p_programme_version_id::text,
    p_week,
    p_day_key,
    p_session_order,
    trim(p_protocol_id)
  );
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_schedule_programmed_session_key(UUID, UUID, INT, TEXT, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_schedule_programmed_session_key(UUID, UUID, INT, TEXT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_schedule_programmed_session_key(UUID, UUID, INT, TEXT, INT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.cohort_programme_schedule_projection_json(
  p_assignment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_header public.programme_schedule_projections%ROWTYPE;
  v_occurrences JSONB;
BEGIN
  SELECT * INTO v_header
  FROM public.programme_schedule_projections
  WHERE assignment_id = p_assignment_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'session_slot_id', o.session_slot_id,
        'programme_version_id', o.programme_version_id,
        'package_content_hash', o.package_content_hash,
        'week_number', o.week_number,
        'day_key', o.day_key,
        'session_order', o.session_order,
        'protocol_id', o.protocol_id,
        'programmed_session_key', o.programmed_session_key,
        'scheduled_date', o.scheduled_date,
        'disposition', o.disposition
      )
      ORDER BY o.week_number ASC,
               (substring(o.day_key from 5))::INT ASC,
               o.session_order ASC
    ),
    '[]'::jsonb
  )
  INTO v_occurrences
  FROM public.programme_schedule_occurrences o
  WHERE o.assignment_id = p_assignment_id;

  RETURN jsonb_build_object(
    'assignment_id', v_header.assignment_id,
    'athlete_id', v_header.athlete_id,
    'programme_version_id', v_header.programme_version_id,
    'package_content_hash', v_header.package_content_hash,
    'timezone', v_header.timezone,
    'started_at', v_header.started_at,
    'schedule_revision', v_header.schedule_revision,
    'schema_version', v_header.schema_version,
    'created_at', v_header.created_at,
    'updated_at', v_header.updated_at,
    'occurrences', v_occurrences
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_schedule_projection_json(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_schedule_projection_json(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_schedule_projection_json(UUID) TO service_role;

-- ---------------------------------------------------------------------------
-- 7. Ensure / initialise baseline (sole durable write path in 1.7C)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ensure_programme_schedule_projection(
  p_programme_assignment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_assignment public.programme_assignments%ROWTYPE;
  v_existing public.programme_schedule_projections%ROWTYPE;
  v_hash TEXT;
  v_slot RECORD;
  v_day_offset INT := 0;
  v_scheduled DATE;
  v_disposition TEXT;
  v_outcome TEXT;
  v_psk TEXT;
  v_count INT := 0;
  v_projection JSONB;
  v_idem TEXT;
BEGIN
  IF v_athlete_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'not_authenticated'
    );
  END IF;

  IF NOT public.cohort_auth_is_athlete() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'athlete_role_required'
    );
  END IF;

  IF p_programme_assignment_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_args'
    );
  END IF;

  -- Serialise ensure attempts per assignment.
  PERFORM pg_advisory_xact_lock(
    84201703,
    hashtext(p_programme_assignment_id::text)
  );

  SELECT * INTO v_assignment
  FROM public.programme_assignments
  WHERE id = p_programme_assignment_id
    AND athlete_id = v_athlete_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'assignment_not_found'
    );
  END IF;

  IF v_assignment.materialised_at IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'assignment_not_materialised',
      'assignment_id', v_assignment.id
    );
  END IF;

  IF v_assignment.status IS DISTINCT FROM 'active'
     AND v_assignment.status IS DISTINCT FROM 'paused'
     AND v_assignment.status IS DISTINCT FROM 'completed'
  THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'assignment_ineligible',
      'assignment_id', v_assignment.id,
      'assignment_status', v_assignment.status
    );
  END IF;

  v_hash := nullif(trim(COALESCE(v_assignment.materialised_package_content_hash, '')), '');
  IF v_hash IS NULL OR v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'package_provenance_mismatch',
      'assignment_id', v_assignment.id
    );
  END IF;

  IF nullif(trim(COALESCE(v_assignment.timezone, '')), '') IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'timezone_required',
      'assignment_id', v_assignment.id
    );
  END IF;

  SELECT * INTO v_existing
  FROM public.programme_schedule_projections
  WHERE assignment_id = v_assignment.id
  FOR UPDATE;

  IF FOUND THEN
    IF v_existing.programme_version_id IS DISTINCT FROM v_assignment.programme_version_id
       OR v_existing.package_content_hash IS DISTINCT FROM v_hash
       OR v_existing.timezone IS DISTINCT FROM v_assignment.timezone
       OR v_existing.started_at IS DISTINCT FROM v_assignment.started_at
    THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'projection_provenance_conflict',
        'assignment_id', v_assignment.id,
        'projection', public.cohort_programme_schedule_projection_json(v_assignment.id)
      );
    END IF;

    v_projection := public.cohort_programme_schedule_projection_json(v_assignment.id);
    RETURN jsonb_build_object(
      'status', 'already_exists',
      'code', 'projection_already_exists',
      'assignment_id', v_assignment.id,
      'schedule_revision', v_existing.schedule_revision,
      'projection', v_projection
    );
  END IF;

  -- Count executable slots (non-rest, protocol present).
  SELECT COUNT(*) INTO v_count
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  JOIN public.programme_version_session_slots s ON s.day_id = d.id
  WHERE w.version_id = v_assignment.programme_version_id
    AND COALESCE(d.day_type, '') <> 'rest'
    AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL;

  IF v_count IS NULL OR v_count < 1 THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'empty_programme_structure',
      'assignment_id', v_assignment.id,
      'programme_version_id', v_assignment.programme_version_id
    );
  END IF;

  PERFORM set_config('cohort.allow_schedule_write', 'on', true);

  INSERT INTO public.programme_schedule_projections (
    assignment_id,
    athlete_id,
    programme_version_id,
    package_content_hash,
    timezone,
    started_at,
    schedule_revision,
    schema_version
  ) VALUES (
    v_assignment.id,
    v_athlete_id,
    v_assignment.programme_version_id,
    v_hash,
    v_assignment.timezone,
    v_assignment.started_at,
    0,
    'programme.schedule.projection.v1'
  );

  v_day_offset := 0;
  FOR v_slot IN
    SELECT
      s.id AS session_slot_id,
      w.week_number,
      d.day_key,
      s.session_order,
      trim(s.protocol_id) AS protocol_id
    FROM public.programme_version_weeks w
    JOIN public.programme_version_days d ON d.week_id = w.id
    JOIN public.programme_version_session_slots s ON s.day_id = d.id
    WHERE w.version_id = v_assignment.programme_version_id
      AND COALESCE(d.day_type, '') <> 'rest'
      AND nullif(trim(COALESCE(s.protocol_id, '')), '') IS NOT NULL
    ORDER BY w.week_number ASC, d.day_order ASC, s.session_order ASC
  LOOP
    v_scheduled := v_assignment.started_at + v_day_offset;
    v_day_offset := v_day_offset + 1;

    SELECT o.outcome_status INTO v_outcome
    FROM public.programme_slot_outcomes o
    WHERE o.assignment_id = v_assignment.id
      AND o.session_slot_id = v_slot.session_slot_id
    LIMIT 1;

    v_disposition := CASE
      WHEN v_outcome IN ('completed', 'completed_partial') THEN 'completed'
      WHEN v_outcome = 'skipped' THEN 'skipped'
      ELSE 'scheduled'
    END;

    v_psk := public.cohort_programme_schedule_programmed_session_key(
      v_assignment.id,
      v_assignment.programme_version_id,
      v_slot.week_number,
      v_slot.day_key,
      v_slot.session_order,
      v_slot.protocol_id
    );

    INSERT INTO public.programme_schedule_occurrences (
      assignment_id,
      session_slot_id,
      programme_version_id,
      package_content_hash,
      week_number,
      day_key,
      session_order,
      protocol_id,
      programmed_session_key,
      scheduled_date,
      disposition
    ) VALUES (
      v_assignment.id,
      v_slot.session_slot_id,
      v_assignment.programme_version_id,
      v_hash,
      v_slot.week_number,
      v_slot.day_key,
      v_slot.session_order,
      v_slot.protocol_id,
      v_psk,
      v_scheduled,
      v_disposition
    );
  END LOOP;

  -- Mirror baseline revision onto assignment (still 0; not an athlete op).
  UPDATE public.programme_assignments
  SET schedule_revision = 0,
      updated_at = NOW()
  WHERE id = v_assignment.id;

  v_idem := format(
    'baseline:%s:%s:%s',
    v_assignment.id::text,
    v_assignment.programme_version_id::text,
    v_hash
  );

  INSERT INTO public.programme_schedule_operations (
    assignment_id,
    athlete_id,
    operation_type,
    idempotency_key,
    preview_fingerprint,
    base_revision,
    result_revision,
    policy_version,
    affected_before,
    affected_after,
    prior_snapshot,
    operated_at
  ) VALUES (
    v_assignment.id,
    v_athlete_id,
    'baseline_initialisation',
    v_idem,
    NULL,
    NULL,
    0,
    'programme.scheduling.policy.v1',
    '[]'::jsonb,
    jsonb_build_object('occurrence_count', v_count, 'schedule_revision', 0),
    NULL,
    NOW()
  )
  ON CONFLICT (assignment_id, idempotency_key) DO NOTHING;

  v_projection := public.cohort_programme_schedule_projection_json(v_assignment.id);

  RETURN jsonb_build_object(
    'status', 'initialised',
    'code', 'projection_initialised',
    'assignment_id', v_assignment.id,
    'schedule_revision', 0,
    'projection', v_projection
  );
EXCEPTION
  WHEN unique_violation THEN
    -- Concurrent winner: reload if provenance matches.
    SELECT * INTO v_existing
    FROM public.programme_schedule_projections
    WHERE assignment_id = p_programme_assignment_id;

    IF FOUND THEN
      v_projection := public.cohort_programme_schedule_projection_json(p_programme_assignment_id);
      RETURN jsonb_build_object(
        'status', 'already_exists',
        'code', 'projection_already_exists',
        'assignment_id', p_programme_assignment_id,
        'schedule_revision', v_existing.schedule_revision,
        'projection', v_projection
      );
    END IF;

    RETURN jsonb_build_object(
      'status', 'conflict',
      'code', 'duplicate_occurrence_identity',
      'assignment_id', p_programme_assignment_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_programme_schedule_projection(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ensure_programme_schedule_projection(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.ensure_programme_schedule_projection(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_programme_schedule_projection(UUID) TO service_role;

COMMENT ON FUNCTION public.ensure_programme_schedule_projection(UUID) IS
  'Sprint 1.7C: atomic idempotent baseline schedule projection initialisation / reload. Sole durable scheduling write path in 1.7C. Does not apply Move/Swap/Push/Skip.';

-- ---------------------------------------------------------------------------
-- 8. Fail-closed apply placeholder (not an athlete mutation path)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.apply_programme_schedule_operation(
  payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Intentionally non-operational until Sprint 1.7D/1.7E.
  -- Not granted to authenticated athletes.
  RETURN jsonb_build_object(
    'status', 'unsupported',
    'code', 'schedule_apply_not_implemented',
    'message', 'Athlete scheduling apply is assigned to Sprint 1.7D/1.7E.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.apply_programme_schedule_operation(JSONB) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO service_role;

COMMENT ON FUNCTION public.apply_programme_schedule_operation(JSONB) IS
  'Sprint 1.7C fail-closed placeholder for later exact-preview apply. Not granted to authenticated; does not persist occurrence changes.';
