-- Sprint 1.3: Athlete catalogue enrolment (non-commercial test / closed-beta access)
--
-- Extends programme_assignments as the exact-version enrolment record.
-- Authenticated athletes enrol via SECURITY DEFINER RPC only (no broad INSERT grant).
-- Temporary authorisation: non-commercial test path for Self-Test 1 / closed beta.
-- Future commercial entitlement (likely recurring subscription) must replace/precede
-- cohort_athlete_may_use_non_commercial_catalogue_enrolment() without changing
-- exact-version binding, ownership, or idempotency of enrol_athlete_in_catalogue_programme_version.
--
-- Does NOT implement payments, subscriptions, purchases, or athlete-plan materialisation.

-- ---------------------------------------------------------------------------
-- 1. Enrolment source column (how access was authorised — not a payment record)
-- ---------------------------------------------------------------------------

ALTER TABLE public.programme_assignments
  ADD COLUMN IF NOT EXISTS enrolment_source TEXT;

ALTER TABLE public.programme_assignments
  DROP CONSTRAINT IF EXISTS programme_assignments_enrolment_source_check;

ALTER TABLE public.programme_assignments
  ADD CONSTRAINT programme_assignments_enrolment_source_check
  CHECK (
    enrolment_source IS NULL
    OR enrolment_source IN (
      'non_commercial_test',
      'coach_assigned',
      'dual_role_self'
    )
  );

COMMENT ON COLUMN public.programme_assignments.enrolment_source IS
  'How this enrolment was authorised. non_commercial_test = Sprint 1.3 temporary Self-Test/closed-beta path. NULL = pre-Sprint-1.3 or unspecified. Not a payment, purchase, or subscription record.';

COMMENT ON TABLE public.programme_assignments IS
  'Athlete enrolment on a pinned published programme version (exact programme_version_id). Source of truth for programme cursor. Sprint 1.3: also the catalogue enrolment record. Not proof of payment or individual programme ownership.';

-- Idempotent active binding: one active row per athlete already enforced by
-- programme_assignments_one_active_per_athlete. Document exact-version uniqueness
-- for the active enrolment of that athlete+version pair via the enrol RPC.

-- ---------------------------------------------------------------------------
-- 2. Eligibility + temporary non-commercial authorisation seam
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cohort_programme_version_is_catalogue_eligible(
  p_version_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.programme_versions v
    WHERE v.id = p_version_id
      AND v.lifecycle_status = 'published'
      AND v.library_scope = 'cohort_global'
      AND v.owner_type = 'global'
      AND v.approved_for_global = TRUE
      AND v.archived_at IS NULL
  );
$$;

REVOKE ALL ON FUNCTION public.cohort_programme_version_is_catalogue_eligible(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_catalogue_eligible(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_programme_version_is_catalogue_eligible(UUID) TO service_role;

COMMENT ON FUNCTION public.cohort_programme_version_is_catalogue_eligible(UUID) IS
  'TRUE when a programme version is published, cohort_global, approved_for_global, and not archived. Matches Sprint 1.2 catalogue visibility.';

CREATE OR REPLACE FUNCTION public.cohort_athlete_may_use_non_commercial_catalogue_enrolment()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  -- Sprint 1.3 temporary seam: any authenticated athlete may enrol for
  -- Self-Test 1 / approved closed-beta testing without payment.
  -- Future commercial entitlement (directional: recurring subscription) should
  -- replace or precede this check. Do not encode prices, tiers, or providers here.
  SELECT auth.uid() IS NOT NULL
    AND public.cohort_auth_is_athlete();
$$;

REVOKE ALL ON FUNCTION public.cohort_athlete_may_use_non_commercial_catalogue_enrolment() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cohort_athlete_may_use_non_commercial_catalogue_enrolment() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cohort_athlete_may_use_non_commercial_catalogue_enrolment() TO service_role;

COMMENT ON FUNCTION public.cohort_athlete_may_use_non_commercial_catalogue_enrolment() IS
  'TEMPORARY Sprint 1.3 non-commercial catalogue enrolment authorisation. Replace/precede with commercial entitlement check without changing enrol_athlete_in_catalogue_programme_version exact-version contract.';

-- ---------------------------------------------------------------------------
-- 3. Enrolment RPC
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enrol_athlete_in_catalogue_programme_version(
  p_programme_version_id UUID,
  p_timezone TEXT DEFAULT NULL,
  p_replace_active BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_athlete_id UUID := auth.uid();
  v_version public.programme_versions%ROWTYPE;
  v_lineage_code TEXT;
  v_active public.programme_assignments%ROWTYPE;
  v_has_active BOOLEAN := FALSE;
  v_replaced_id UUID := NULL;
  v_new_id UUID;
  v_week INT;
  v_day_key TEXT;
  v_slot INT;
  v_tz TEXT;
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

  IF NOT public.cohort_athlete_may_use_non_commercial_catalogue_enrolment() THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'catalogue_enrolment_not_authorised'
    );
  END IF;

  IF p_programme_version_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'invalid_args'
    );
  END IF;

  SELECT * INTO v_version
  FROM public.programme_versions
  WHERE id = p_programme_version_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'version_not_found'
    );
  END IF;

  IF NOT public.cohort_programme_version_is_catalogue_eligible(p_programme_version_id) THEN
    RETURN jsonb_build_object(
      'status', 'authorization_failure',
      'code', 'version_not_catalogue_eligible'
    );
  END IF;

  SELECT l.code INTO v_lineage_code
  FROM public.programme_lineages l
  WHERE l.id = v_version.lineage_id;

  IF v_lineage_code IS NULL OR length(trim(v_lineage_code)) = 0 THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'lineage_missing'
    );
  END IF;

  SELECT * INTO v_active
  FROM public.programme_assignments
  WHERE athlete_id = v_athlete_id
    AND status = 'active'
  FOR UPDATE;

  v_has_active := FOUND;

  IF v_has_active THEN
    IF v_active.programme_version_id = p_programme_version_id THEN
      RETURN jsonb_build_object(
        'status', 'already_enrolled',
        'enrolment_id', v_active.id,
        'programme_version_id', v_active.programme_version_id,
        'lineage_code', v_active.lineage_code,
        'enrolment_source', v_active.enrolment_source,
        'athlete_id', v_athlete_id
      );
    END IF;

    IF NOT COALESCE(p_replace_active, FALSE) THEN
      RETURN jsonb_build_object(
        'status', 'conflict',
        'code', 'active_enrolment_exists',
        'enrolment_id', v_active.id,
        'programme_version_id', v_active.programme_version_id
      );
    END IF;

    v_replaced_id := v_active.id;

    UPDATE public.programme_assignments
    SET status = 'reassigned',
        updated_at = NOW()
    WHERE id = v_active.id;
  END IF;

  -- Initial cursor: first week / first day / first slot (or rest-day defaults).
  SELECT w.week_number,
         d.day_key,
         COALESCE(
           (
             SELECT MIN(s.session_order)
             FROM public.programme_version_session_slots s
             WHERE s.day_id = d.id
           ),
           1
         )
    INTO v_week, v_day_key, v_slot
  FROM public.programme_version_weeks w
  JOIN public.programme_version_days d ON d.week_id = w.id
  WHERE w.version_id = p_programme_version_id
  ORDER BY w.week_number ASC, d.day_order ASC
  LIMIT 1;

  IF v_week IS NULL OR v_day_key IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'validation_failure',
      'code', 'empty_programme_structure'
    );
  END IF;

  v_tz := nullif(trim(COALESCE(p_timezone, '')), '');
  v_new_id := gen_random_uuid();

  INSERT INTO public.programme_assignments (
    id,
    athlete_id,
    programme_version_id,
    lineage_code,
    status,
    started_at,
    timezone,
    current_week_number,
    current_day_key,
    current_slot_order,
    enrolment_source
  ) VALUES (
    v_new_id,
    v_athlete_id,
    p_programme_version_id,
    v_lineage_code,
    'active',
    CURRENT_DATE,
    v_tz,
    v_week,
    v_day_key,
    v_slot,
    'non_commercial_test'
  );

  IF v_replaced_id IS NOT NULL THEN
    UPDATE public.programme_assignments
    SET superseded_by_assignment_id = v_new_id,
        updated_at = NOW()
    WHERE id = v_replaced_id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'enrolled',
    'enrolment_id', v_new_id,
    'programme_version_id', p_programme_version_id,
    'lineage_code', v_lineage_code,
    'enrolment_source', 'non_commercial_test',
    'athlete_id', v_athlete_id,
    'replaced_enrolment_id', v_replaced_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN)
  FROM anon;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN)
  TO service_role;

COMMENT ON FUNCTION public.enrol_athlete_in_catalogue_programme_version(UUID, TEXT, BOOLEAN) IS
  'Sprint 1.3: authenticated athlete enrols in an eligible catalogue programme version. Athlete identity from auth.uid() only. Pins exact programme_version_id. Idempotent for same active version. Non-commercial test authorisation via cohort_athlete_may_use_non_commercial_catalogue_enrolment. Not a purchase.';

-- Athletes must be able to read/update own enrolment rows (RLS still scopes ownership).
-- Catalogue enrolment INSERT remains RPC-only (no authenticated INSERT grant).
GRANT SELECT, UPDATE ON TABLE public.programme_assignments TO authenticated;

-- Preserve Sprint 1.2: no client INSERT/UPDATE/DELETE grants added on package tables.
-- Dual-role self-insert policy retained for personal-training paths; catalogue enrolment uses RPC.
